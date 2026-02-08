//! SurrealDB document store
//!
//! Used for:
//! - Compliance reports
//! - Repository metadata
//! - User/organization data
//! - Audit history

use crate::{ComplianceStatus, Result, RsrError};
use serde::{Deserialize, Serialize};
use surrealdb::engine::remote::ws::{Client, Ws};
use surrealdb::opt::auth::Root;
use surrealdb::Surreal;

/// SurrealDB connection pool
pub struct SurrealPool {
    client: Surreal<Client>,
    #[allow(dead_code)]
    url: String,
}

/// Record ID wrapper for SurrealDB responses
#[derive(Debug, Deserialize)]
struct Record {
    #[allow(dead_code)]
    id: surrealdb::RecordId,
}

/// Compliance report as stored in SurrealDB
#[derive(Debug, Clone, Serialize, Deserialize)]
struct ComplianceReport {
    platform: String,
    owner: String,
    repo: String,
    tier: String,
    score: f32,
    checks: serde_json::Value,
    created_at: chrono::DateTime<chrono::Utc>,
}

/// Webhook event record
#[derive(Debug, Clone, Serialize, Deserialize)]
struct WebhookEvent {
    platform: String,
    event_type: String,
    payload: serde_json::Value,
    processed: bool,
}

impl SurrealPool {
    /// Connect from environment variables
    pub async fn connect_from_env() -> Result<Self> {
        let url = std::env::var("RSR_SURREALDB_URL")
            .unwrap_or_else(|_| "ws://localhost:8000".to_string());
        let namespace = std::env::var("RSR_SURREALDB_NS")
            .unwrap_or_else(|_| "rsr".to_string());
        let database = std::env::var("RSR_SURREALDB_DB")
            .unwrap_or_else(|_| "compliance".to_string());
        let username = std::env::var("RSR_SURREALDB_USER")
            .unwrap_or_else(|_| "root".to_string());
        let password = std::env::var("RSR_SURREALDB_PASS")
            .unwrap_or_else(|_| "root".to_string());

        Self::connect(&url, &namespace, &database, &username, &password).await
    }

    /// Connect to SurrealDB
    pub async fn connect(
        url: &str,
        namespace: &str,
        database: &str,
        username: &str,
        password: &str,
    ) -> Result<Self> {
        tracing::info!("Connecting to SurrealDB: {}/{}/{}", url, namespace, database);

        // Strip ws:// or wss:// prefix if present for the Ws connector
        let addr = url
            .strip_prefix("ws://")
            .or_else(|| url.strip_prefix("wss://"))
            .unwrap_or(url);

        let client = Surreal::new::<Ws>(addr)
            .await
            .map_err(|e| RsrError::Platform(format!("SurrealDB connection failed: {}", e)))?;

        client
            .signin(Root { username, password })
            .await
            .map_err(|e| RsrError::Platform(format!("SurrealDB auth failed: {}", e)))?;

        client
            .use_ns(namespace)
            .use_db(database)
            .await
            .map_err(|e| RsrError::Platform(format!("SurrealDB use ns/db failed: {}", e)))?;

        Ok(Self {
            client,
            url: url.to_string(),
        })
    }

    /// Ping the database
    pub async fn ping(&self) -> Result<()> {
        // SurrealDB doesn't have a ping, but we can run a simple query
        self.client
            .query("RETURN 1")
            .await
            .map_err(|e| RsrError::Platform(format!("SurrealDB ping failed: {}", e)))?;
        tracing::debug!("SurrealDB ping successful");
        Ok(())
    }

    /// Run database migrations
    pub async fn migrate(&self) -> Result<()> {
        tracing::info!("Running SurrealDB migrations");

        let migrations = r#"
            -- Repository table
            DEFINE TABLE repository SCHEMALESS;
            DEFINE FIELD platform ON repository TYPE string;
            DEFINE FIELD owner ON repository TYPE string;
            DEFINE FIELD name ON repository TYPE string;
            DEFINE INDEX repo_idx ON repository COLUMNS platform, owner, name UNIQUE;

            -- Compliance report table
            DEFINE TABLE compliance_report SCHEMALESS;
            DEFINE FIELD platform ON compliance_report TYPE string;
            DEFINE FIELD owner ON compliance_report TYPE string;
            DEFINE FIELD repo ON compliance_report TYPE string;
            DEFINE FIELD tier ON compliance_report TYPE string;
            DEFINE FIELD score ON compliance_report TYPE float;
            DEFINE FIELD checks ON compliance_report TYPE array;
            DEFINE FIELD created_at ON compliance_report TYPE datetime DEFAULT time::now();
            DEFINE INDEX report_time_idx ON compliance_report COLUMNS platform, owner, repo, created_at;

            -- Webhook event table
            DEFINE TABLE webhook_event SCHEMALESS;
            DEFINE FIELD platform ON webhook_event TYPE string;
            DEFINE FIELD event_type ON webhook_event TYPE string;
            DEFINE FIELD payload ON webhook_event TYPE object;
            DEFINE FIELD processed ON webhook_event TYPE bool DEFAULT false;
            DEFINE FIELD created_at ON webhook_event TYPE datetime DEFAULT time::now();
        "#;

        self.client
            .query(migrations)
            .await
            .map_err(|e| RsrError::Platform(format!("SurrealDB migration failed: {}", e)))?;

        tracing::info!("SurrealDB migrations complete");
        Ok(())
    }

    /// Store a compliance report
    pub async fn store_compliance(&self, status: &ComplianceStatus) -> Result<String> {
        tracing::debug!("Storing compliance report for {}", status.repo);

        let report = ComplianceReport {
            platform: status.repo.platform.clone(),
            owner: status.repo.owner.clone(),
            repo: status.repo.repo.clone(),
            tier: format!("{:?}", status.tier),
            score: status.score,
            checks: serde_json::to_value(&status.checks)
                .map_err(|e| RsrError::Json(e))?,
            created_at: status.timestamp,
        };

        let result: Option<Record> = self.client
            .create("compliance_report")
            .content(report)
            .await
            .map_err(|e| RsrError::Platform(format!("SurrealDB create failed: {}", e)))?;

        let id = result
            .map(|r| r.id.to_string())
            .unwrap_or_else(|| "unknown".to_string());

        tracing::debug!("Stored compliance report with ID: {}", id);
        Ok(id)
    }

    /// Get latest compliance report for a repository
    pub async fn get_latest_compliance(
        &self,
        platform: &str,
        owner: &str,
        repo: &str,
    ) -> Result<Option<ComplianceStatus>> {
        tracing::debug!("Getting latest compliance for {}/{}/{}", platform, owner, repo);

        // Clone strings to satisfy 'static lifetime requirement
        let platform = platform.to_string();
        let owner = owner.to_string();
        let repo = repo.to_string();

        let mut result = self.client
            .query("SELECT * FROM compliance_report WHERE platform = $platform AND owner = $owner AND repo = $repo ORDER BY created_at DESC LIMIT 1")
            .bind(("platform", platform))
            .bind(("owner", owner))
            .bind(("repo", repo.clone()))
            .await
            .map_err(|e| RsrError::Platform(format!("SurrealDB query failed: {}", e)))?;

        let reports: Vec<ComplianceReport> = result
            .take(0)
            .map_err(|e| RsrError::Platform(format!("SurrealDB take failed: {}", e)))?;

        if let Some(report) = reports.into_iter().next() {
            let tier = match report.tier.as_str() {
                "Bronze" => crate::CertificationTier::Bronze,
                "Silver" => crate::CertificationTier::Silver,
                "Gold" => crate::CertificationTier::Gold,
                "Rhodium" => crate::CertificationTier::Rhodium,
                _ => crate::CertificationTier::None,
            };

            let checks: Vec<crate::CheckResult> = serde_json::from_value(report.checks)
                .unwrap_or_default();

            Ok(Some(ComplianceStatus {
                repo: crate::RepoRef::new(&report.platform, &report.owner, &report.repo),
                tier,
                score: report.score,
                checks,
                timestamp: report.created_at,
            }))
        } else {
            Ok(None)
        }
    }

    /// Get compliance history for a repository
    pub async fn get_compliance_history(
        &self,
        platform: &str,
        owner: &str,
        repo: &str,
        limit: u32,
    ) -> Result<Vec<ComplianceStatus>> {
        tracing::debug!(
            "Getting compliance history for {}/{}/{} (limit: {})",
            platform, owner, repo, limit
        );

        // Clone strings to satisfy 'static lifetime requirement
        let platform = platform.to_string();
        let owner = owner.to_string();
        let repo = repo.to_string();

        let mut result = self.client
            .query("SELECT * FROM compliance_report WHERE platform = $platform AND owner = $owner AND repo = $repo ORDER BY created_at DESC LIMIT $limit")
            .bind(("platform", platform))
            .bind(("owner", owner))
            .bind(("repo", repo))
            .bind(("limit", limit))
            .await
            .map_err(|e| RsrError::Platform(format!("SurrealDB query failed: {}", e)))?;

        let reports: Vec<ComplianceReport> = result
            .take(0)
            .map_err(|e| RsrError::Platform(format!("SurrealDB take failed: {}", e)))?;

        let statuses = reports
            .into_iter()
            .map(|report| {
                let tier = match report.tier.as_str() {
                    "Bronze" => crate::CertificationTier::Bronze,
                    "Silver" => crate::CertificationTier::Silver,
                    "Gold" => crate::CertificationTier::Gold,
                    "Rhodium" => crate::CertificationTier::Rhodium,
                    _ => crate::CertificationTier::None,
                };

                let checks: Vec<crate::CheckResult> = serde_json::from_value(report.checks)
                    .unwrap_or_default();

                ComplianceStatus {
                    repo: crate::RepoRef::new(&report.platform, &report.owner, &report.repo),
                    tier,
                    score: report.score,
                    checks,
                    timestamp: report.created_at,
                }
            })
            .collect();

        Ok(statuses)
    }

    /// Store a webhook event for processing
    pub async fn store_webhook_event(
        &self,
        platform: &str,
        event_type: &str,
        payload: &serde_json::Value,
    ) -> Result<String> {
        tracing::debug!("Storing webhook event: {}/{}", platform, event_type);

        let event = WebhookEvent {
            platform: platform.to_string(),
            event_type: event_type.to_string(),
            payload: payload.clone(),
            processed: false,
        };

        let result: Option<Record> = self.client
            .create("webhook_event")
            .content(event)
            .await
            .map_err(|e| RsrError::Platform(format!("SurrealDB create failed: {}", e)))?;

        let id = result
            .map(|r| r.id.to_string())
            .unwrap_or_else(|| "unknown".to_string());

        Ok(id)
    }

    /// Mark a webhook event as processed
    pub async fn mark_event_processed(&self, event_id: &str) -> Result<()> {
        let event_id = event_id.to_string();
        self.client
            .query("UPDATE $id SET processed = true")
            .bind(("id", event_id))
            .await
            .map_err(|e| RsrError::Platform(format!("SurrealDB update failed: {}", e)))?;

        Ok(())
    }

    /// Get unprocessed webhook events
    pub async fn get_pending_events(&self, limit: u32) -> Result<Vec<serde_json::Value>> {
        let mut result = self.client
            .query("SELECT * FROM webhook_event WHERE processed = false ORDER BY created_at ASC LIMIT $limit")
            .bind(("limit", limit))
            .await
            .map_err(|e| RsrError::Platform(format!("SurrealDB query failed: {}", e)))?;

        let events: Vec<serde_json::Value> = result
            .take(0)
            .map_err(|e| RsrError::Platform(format!("SurrealDB take failed: {}", e)))?;

        Ok(events)
    }
}
