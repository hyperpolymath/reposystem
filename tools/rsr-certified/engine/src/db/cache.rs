//! DragonflyDB cache layer (Redis-compatible)
//!
//! DragonflyDB is a drop-in Redis replacement that's faster and more
//! memory efficient. We use the standard redis crate to connect.
//!
//! Used for:
//! - Webhook event queue
//! - API response caching
//! - Rate limiting
//! - Session storage

use crate::{Result, RsrError};
use redis::aio::ConnectionManager;
use redis::AsyncCommands;

/// DragonflyDB connection pool (Redis-compatible)
pub struct DragonflyPool {
    conn: ConnectionManager,
    url: String,
}

impl DragonflyPool {
    /// Connect from environment variables
    pub async fn connect_from_env() -> Result<Self> {
        let url = std::env::var("RSR_DRAGONFLY_URL")
            .unwrap_or_else(|_| "redis://localhost:6379".to_string());

        Self::connect(&url).await
    }

    /// Connect to DragonflyDB
    pub async fn connect(url: &str) -> Result<Self> {
        tracing::info!("Connecting to DragonflyDB: {}", url);

        let client = redis::Client::open(url)
            .map_err(|e| RsrError::Platform(format!("Redis client error: {}", e)))?;

        let conn = ConnectionManager::new(client)
            .await
            .map_err(|e| RsrError::Platform(format!("Redis connection error: {}", e)))?;

        Ok(Self {
            conn,
            url: url.to_string(),
        })
    }

    /// Ping the database
    pub async fn ping(&self) -> Result<()> {
        let mut conn = self.conn.clone();
        redis::cmd("PING")
            .query_async::<String>(&mut conn)
            .await
            .map_err(|e| RsrError::Platform(format!("Redis ping failed: {}", e)))?;
        tracing::debug!("DragonflyDB ping successful at {}", self.url);
        Ok(())
    }

    /// Cache a compliance result
    pub async fn cache_compliance(&self, key: &str, value: &str, ttl_secs: u64) -> Result<()> {
        let mut conn = self.conn.clone();
        let cache_key = format!("rsr:compliance:{}", key);

        conn.set_ex::<_, _, ()>(&cache_key, value, ttl_secs)
            .await
            .map_err(|e| RsrError::Platform(format!("Redis set failed: {}", e)))?;

        tracing::debug!("Cached compliance result: {} (TTL: {}s)", key, ttl_secs);
        Ok(())
    }

    /// Get cached compliance result
    pub async fn get_compliance(&self, key: &str) -> Result<Option<String>> {
        let mut conn = self.conn.clone();
        let cache_key = format!("rsr:compliance:{}", key);

        let result: Option<String> = conn
            .get(&cache_key)
            .await
            .map_err(|e| RsrError::Platform(format!("Redis get failed: {}", e)))?;

        tracing::debug!("Cache lookup for {}: {:?}", key, result.is_some());
        Ok(result)
    }

    /// Enqueue a job for background processing
    pub async fn enqueue_job(&self, queue: &str, job: &str) -> Result<()> {
        let mut conn = self.conn.clone();
        let queue_key = format!("rsr:queue:{}", queue);

        conn.lpush::<_, _, ()>(&queue_key, job)
            .await
            .map_err(|e| RsrError::Platform(format!("Redis lpush failed: {}", e)))?;

        tracing::debug!("Enqueued job to {}", queue);
        Ok(())
    }

    /// Dequeue a job for processing (blocking with timeout)
    pub async fn dequeue_job(&self, queue: &str, timeout_secs: u64) -> Result<Option<String>> {
        let mut conn = self.conn.clone();
        let queue_key = format!("rsr:queue:{}", queue);

        let result: Option<(String, String)> = conn
            .brpop(&queue_key, timeout_secs as f64)
            .await
            .map_err(|e| RsrError::Platform(format!("Redis brpop failed: {}", e)))?;

        Ok(result.map(|(_, job)| job))
    }

    /// Increment rate limit counter with sliding window
    pub async fn rate_limit_increment(&self, key: &str, window_secs: u64) -> Result<u64> {
        let mut conn = self.conn.clone();
        let rate_key = format!("rsr:ratelimit:{}", key);

        // Use INCR + EXPIRE for simple rate limiting
        let count: u64 = conn
            .incr(&rate_key, 1u64)
            .await
            .map_err(|e| RsrError::Platform(format!("Redis incr failed: {}", e)))?;

        // Set expiry only on first increment
        if count == 1 {
            conn.expire::<_, ()>(&rate_key, window_secs as i64)
                .await
                .map_err(|e| RsrError::Platform(format!("Redis expire failed: {}", e)))?;
        }

        tracing::debug!("Rate limit {}: {} (window: {}s)", key, count, window_secs);
        Ok(count)
    }

    /// Check if rate limited (returns remaining requests, 0 if limited)
    pub async fn rate_limit_check(&self, key: &str, max_requests: u64) -> Result<u64> {
        let mut conn = self.conn.clone();
        let rate_key = format!("rsr:ratelimit:{}", key);

        let count: u64 = conn
            .get(&rate_key)
            .await
            .unwrap_or(0);

        if count >= max_requests {
            Ok(0)
        } else {
            Ok(max_requests - count)
        }
    }

    /// Store session data
    pub async fn set_session(&self, session_id: &str, data: &str, ttl_secs: u64) -> Result<()> {
        let mut conn = self.conn.clone();
        let session_key = format!("rsr:session:{}", session_id);

        conn.set_ex::<_, _, ()>(&session_key, data, ttl_secs)
            .await
            .map_err(|e| RsrError::Platform(format!("Redis session set failed: {}", e)))?;

        Ok(())
    }

    /// Get session data
    pub async fn get_session(&self, session_id: &str) -> Result<Option<String>> {
        let mut conn = self.conn.clone();
        let session_key = format!("rsr:session:{}", session_id);

        conn.get(&session_key)
            .await
            .map_err(|e| RsrError::Platform(format!("Redis session get failed: {}", e)))
    }

    /// Delete session
    pub async fn delete_session(&self, session_id: &str) -> Result<()> {
        let mut conn = self.conn.clone();
        let session_key = format!("rsr:session:{}", session_id);

        conn.del::<_, ()>(&session_key)
            .await
            .map_err(|e| RsrError::Platform(format!("Redis session del failed: {}", e)))?;

        Ok(())
    }
}
