//! ArangoDB graph database
//!
//! Used for:
//! - Dependency graphs
//! - Repository relationships
//! - Compliance inheritance
//! - Impact analysis

use crate::{Result, RsrError};
use arangors::client::reqwest::ReqwestClient;
use arangors::{AqlQuery, Connection, Database};
use serde::{Deserialize, Serialize};

/// ArangoDB connection pool
pub struct ArangoPool {
    db: Database<ReqwestClient>,
    #[allow(dead_code)]
    url: String,
}

impl ArangoPool {
    /// Connect from environment variables
    pub async fn connect_from_env() -> Result<Self> {
        let url = std::env::var("RSR_ARANGODB_URL")
            .unwrap_or_else(|_| "http://localhost:8529".to_string());
        let database = std::env::var("RSR_ARANGODB_DB")
            .unwrap_or_else(|_| "rsr_graphs".to_string());
        let username = std::env::var("RSR_ARANGODB_USER")
            .unwrap_or_else(|_| "root".to_string());
        let password = std::env::var("RSR_ARANGODB_PASS")
            .unwrap_or_else(|_| "".to_string());

        Self::connect(&url, &database, &username, &password).await
    }

    /// Connect to ArangoDB
    pub async fn connect(url: &str, database: &str, username: &str, password: &str) -> Result<Self> {
        tracing::info!("Connecting to ArangoDB: {}/{}", url, database);

        let conn = Connection::establish_basic_auth(url, username, password)
            .await
            .map_err(|e| RsrError::Platform(format!("ArangoDB connection failed: {}", e)))?;

        let db = conn
            .db(database)
            .await
            .map_err(|e| RsrError::Platform(format!("ArangoDB database access failed: {}", e)))?;

        Ok(Self {
            db,
            url: url.to_string(),
        })
    }

    /// Ping the database
    pub async fn ping(&self) -> Result<()> {
        // Run a simple AQL query to verify connection
        self.db
            .aql_str::<serde_json::Value>("RETURN 1")
            .await
            .map_err(|e| RsrError::Platform(format!("ArangoDB ping failed: {}", e)))?;
        tracing::debug!("ArangoDB ping successful");
        Ok(())
    }

    /// Run database migrations
    pub async fn migrate(&self) -> Result<()> {
        tracing::info!("Running ArangoDB migrations");

        // Create vertex collections
        let collections = ["repositories", "packages", "vulnerabilities"];
        for name in collections {
            if self.db.collection(name).await.is_err() {
                self.db
                    .create_collection(name)
                    .await
                    .map_err(|e| RsrError::Platform(format!("Failed to create collection {}: {}", name, e)))?;
                tracing::debug!("Created collection: {}", name);
            }
        }

        // Create edge collections
        let edge_collections = ["depends_on", "affects", "forks"];
        for name in edge_collections {
            if self.db.collection(name).await.is_err() {
                // Use raw create for edge collection
                match self.db.create_edge_collection(name).await {
                    Ok(_) => tracing::debug!("Created edge collection: {}", name),
                    Err(_) => tracing::debug!("Edge collection {} may already exist", name),
                }
            }
        }

        // Create graph if it doesn't exist
        self.create_dependency_graph().await?;

        tracing::info!("ArangoDB migrations complete");
        Ok(())
    }

    /// Create the dependency graph
    async fn create_dependency_graph(&self) -> Result<()> {
        // Check if graph exists via AQL
        let existing: Vec<serde_json::Value> = self.db
            .aql_str("FOR g IN _graphs() FILTER g._key == 'dependency_graph' RETURN g")
            .await
            .unwrap_or_default();

        if existing.is_empty() {
            // Create graph via AQL (arangors graph API is complex)
            let create_graph_aql = r#"
                LET edgeDefs = [
                    { collection: "depends_on", from: ["repositories"], to: ["packages"] },
                    { collection: "affects", from: ["vulnerabilities"], to: ["packages"] },
                    { collection: "forks", from: ["repositories"], to: ["repositories"] }
                ]
                INSERT { _key: "dependency_graph", edgeDefinitions: edgeDefs } INTO _graphs
                RETURN NEW
            "#;
            self.db
                .aql_str::<serde_json::Value>(create_graph_aql)
                .await
                .map_err(|e| RsrError::Platform(format!("Failed to create graph: {}", e)))?;
            tracing::debug!("Created dependency_graph");
        }

        Ok(())
    }

    /// Add a dependency relationship
    pub async fn add_dependency(
        &self,
        repo_key: &str,
        package_name: &str,
        package_version: &str,
    ) -> Result<()> {
        tracing::debug!(
            "Adding dependency: {} -> {}@{}",
            repo_key, package_name, package_version
        );

        // Ensure package exists
        let package_key = format!("{}@{}", package_name, package_version);
        let upsert_package = r#"
            UPSERT { _key: @key }
            INSERT { _key: @key, name: @name, version: @version }
            UPDATE {}
            IN packages
            RETURN NEW
        "#;
        let aql = AqlQuery::builder()
            .query(upsert_package)
            .bind_var("key", package_key.clone())
            .bind_var("name", package_name.to_string())
            .bind_var("version", package_version.to_string())
            .build();
        self.db
            .aql_query::<serde_json::Value>(aql)
            .await
            .map_err(|e| RsrError::Platform(format!("Failed to upsert package: {}", e)))?;

        // Create edge
        let edge_key = format!("{}__{}", repo_key, package_key);
        let create_edge = r#"
            UPSERT { _key: @key }
            INSERT {
                _key: @key,
                _from: CONCAT("repositories/", @repo),
                _to: CONCAT("packages/", @package)
            }
            UPDATE {}
            IN depends_on
            RETURN NEW
        "#;
        let aql = AqlQuery::builder()
            .query(create_edge)
            .bind_var("key", edge_key)
            .bind_var("repo", repo_key.to_string())
            .bind_var("package", package_key)
            .build();
        self.db
            .aql_query::<serde_json::Value>(aql)
            .await
            .map_err(|e| RsrError::Platform(format!("Failed to create dependency edge: {}", e)))?;

        Ok(())
    }

    /// Get all dependencies for a repository
    pub async fn get_dependencies(&self, repo_key: &str) -> Result<Vec<Dependency>> {
        tracing::debug!("Getting dependencies for {}", repo_key);

        let aql_query = r#"
            FOR v, e, p IN 1..10 OUTBOUND CONCAT("repositories/", @repo)
                GRAPH 'dependency_graph'
                FILTER IS_SAME_COLLECTION("packages", v)
                RETURN DISTINCT {
                    name: v.name,
                    version: v.version,
                    depth: LENGTH(p.edges),
                    direct: LENGTH(p.edges) == 1
                }
        "#;

        let aql = AqlQuery::builder()
            .query(aql_query)
            .bind_var("repo", repo_key.to_string())
            .build();

        let deps: Vec<Dependency> = self.db
            .aql_query(aql)
            .await
            .map_err(|e| RsrError::Platform(format!("Failed to get dependencies: {}", e)))?;

        Ok(deps)
    }

    /// Get repositories affected by a vulnerability
    pub async fn get_affected_repos(&self, vulnerability_id: &str) -> Result<Vec<String>> {
        tracing::debug!("Getting repos affected by {}", vulnerability_id);

        let aql_query = r#"
            FOR v IN 1..10 INBOUND CONCAT("vulnerabilities/", @vuln)
                GRAPH 'dependency_graph'
                FILTER IS_SAME_COLLECTION("repositories", v)
                RETURN DISTINCT v._key
        "#;

        let aql = AqlQuery::builder()
            .query(aql_query)
            .bind_var("vuln", vulnerability_id.to_string())
            .build();

        let repos: Vec<String> = self.db
            .aql_query(aql)
            .await
            .map_err(|e| RsrError::Platform(format!("Failed to get affected repos: {}", e)))?;

        Ok(repos)
    }

    /// Calculate compliance impact (repos depending on this one)
    pub async fn get_dependents(&self, repo_key: &str) -> Result<Vec<String>> {
        tracing::debug!("Getting dependents of {}", repo_key);

        let aql_query = r#"
            FOR v IN 1..10 INBOUND CONCAT("repositories/", @repo)
                GRAPH 'dependency_graph'
                FILTER IS_SAME_COLLECTION("repositories", v)
                RETURN DISTINCT v._key
        "#;

        let aql = AqlQuery::builder()
            .query(aql_query)
            .bind_var("repo", repo_key.to_string())
            .build();

        let repos: Vec<String> = self.db
            .aql_query(aql)
            .await
            .map_err(|e| RsrError::Platform(format!("Failed to get dependents: {}", e)))?;

        Ok(repos)
    }

    /// Get dependency tree depth
    pub async fn get_dependency_depth(&self, repo_key: &str) -> Result<u32> {
        tracing::debug!("Getting dependency depth for {}", repo_key);

        let aql_query = r#"
            LET paths = (
                FOR v, e, p IN 1..100 OUTBOUND CONCAT("repositories/", @repo)
                    GRAPH 'dependency_graph'
                    RETURN LENGTH(p.edges)
            )
            RETURN LENGTH(paths) > 0 ? MAX(paths) : 0
        "#;

        let aql = AqlQuery::builder()
            .query(aql_query)
            .bind_var("repo", repo_key.to_string())
            .build();

        let depths: Vec<u32> = self.db
            .aql_query(aql)
            .await
            .map_err(|e| RsrError::Platform(format!("Failed to get dependency depth: {}", e)))?;

        Ok(depths.into_iter().next().unwrap_or(0))
    }

    /// Add a vulnerability affecting a package
    pub async fn add_vulnerability(&self, vuln: &Vulnerability, package_key: &str) -> Result<()> {
        tracing::debug!("Adding vulnerability {} affecting {}", vuln.id, package_key);

        // Upsert vulnerability
        let upsert_vuln = r#"
            UPSERT { _key: @key }
            INSERT {
                _key: @key,
                severity: @severity,
                affected_versions: @affected,
                patched_versions: @patched
            }
            UPDATE {
                severity: @severity,
                affected_versions: @affected,
                patched_versions: @patched
            }
            IN vulnerabilities
            RETURN NEW
        "#;
        let aql = AqlQuery::builder()
            .query(upsert_vuln)
            .bind_var("key", vuln.id.clone())
            .bind_var("severity", vuln.severity.clone())
            .try_bind("affected", &vuln.affected_versions)
            .map_err(|e| RsrError::Platform(format!("Failed to serialize affected_versions: {}", e)))?
            .try_bind("patched", &vuln.patched_versions)
            .map_err(|e| RsrError::Platform(format!("Failed to serialize patched_versions: {}", e)))?
            .build();
        self.db
            .aql_query::<serde_json::Value>(aql)
            .await
            .map_err(|e| RsrError::Platform(format!("Failed to upsert vulnerability: {}", e)))?;

        // Create affects edge
        let edge_key = format!("{}__{}", vuln.id, package_key);
        let create_edge = r#"
            UPSERT { _key: @key }
            INSERT {
                _key: @key,
                _from: CONCAT("vulnerabilities/", @vuln),
                _to: CONCAT("packages/", @package)
            }
            UPDATE {}
            IN affects
            RETURN NEW
        "#;
        let aql = AqlQuery::builder()
            .query(create_edge)
            .bind_var("key", edge_key)
            .bind_var("vuln", vuln.id.clone())
            .bind_var("package", package_key.to_string())
            .build();
        self.db
            .aql_query::<serde_json::Value>(aql)
            .await
            .map_err(|e| RsrError::Platform(format!("Failed to create affects edge: {}", e)))?;

        Ok(())
    }

    /// Register a repository in the graph
    pub async fn register_repository(&self, platform: &str, owner: &str, repo: &str) -> Result<String> {
        let key = format!("{}__{}_{}", platform, owner, repo);

        let upsert = r#"
            UPSERT { _key: @key }
            INSERT { _key: @key, platform: @platform, owner: @owner, repo: @repo }
            UPDATE {}
            IN repositories
            RETURN NEW._key
        "#;

        let aql = AqlQuery::builder()
            .query(upsert)
            .bind_var("key", key.clone())
            .bind_var("platform", platform.to_string())
            .bind_var("owner", owner.to_string())
            .bind_var("repo", repo.to_string())
            .build();

        let keys: Vec<String> = self.db
            .aql_query(aql)
            .await
            .map_err(|e| RsrError::Platform(format!("Failed to register repository: {}", e)))?;

        Ok(keys.into_iter().next().unwrap_or(key))
    }
}

/// Dependency information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Dependency {
    pub name: String,
    pub version: String,
    pub depth: u32,
    pub direct: bool,
}

/// Vulnerability information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Vulnerability {
    pub id: String,
    pub severity: String,
    pub affected_versions: Vec<String>,
    pub patched_versions: Vec<String>,
}
