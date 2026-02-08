//! Database abstraction layer for RSR compliance data
//!
//! Multi-database architecture:
//! - DragonflyDB: Caching, job queues (Redis-compatible)
//! - SurrealDB: Documents, compliance reports
//! - ArangoDB: Dependency graphs, relationships

pub mod cache;
pub mod documents;
pub mod graphs;

use crate::Result;

/// Initialize all database connections
pub async fn init() -> Result<DatabasePool> {
    let cache = cache::DragonflyPool::connect_from_env().await?;
    let docs = documents::SurrealPool::connect_from_env().await?;
    let graphs = graphs::ArangoPool::connect_from_env().await?;

    Ok(DatabasePool { cache, docs, graphs })
}

/// Combined database pool
pub struct DatabasePool {
    pub cache: cache::DragonflyPool,
    pub docs: documents::SurrealPool,
    pub graphs: graphs::ArangoPool,
}

impl DatabasePool {
    /// Run database migrations
    pub async fn migrate(&self) -> Result<()> {
        self.docs.migrate().await?;
        self.graphs.migrate().await?;
        Ok(())
    }

    /// Health check all databases
    pub async fn health_check(&self) -> Result<DatabaseHealth> {
        Ok(DatabaseHealth {
            cache: self.cache.ping().await.is_ok(),
            documents: self.docs.ping().await.is_ok(),
            graphs: self.graphs.ping().await.is_ok(),
        })
    }
}

/// Database health status
#[derive(Debug, Clone, serde::Serialize)]
pub struct DatabaseHealth {
    pub cache: bool,
    pub documents: bool,
    pub graphs: bool,
}
