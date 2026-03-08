//! Platform adapters for different git hosting services
//!
//! Each adapter implements the `PlatformAdapter` trait, providing a unified
//! interface for webhook parsing, status posting, and content fetching.

pub mod github;
pub mod gitlab;
pub mod bitbucket;
pub mod gitea;

use crate::events::RepoEvent;
use crate::{ComplianceStatus, RepoRef, Result, RsrError};
use async_trait::async_trait;
use std::collections::HashMap;

/// HTTP headers abstraction
pub type Headers = HashMap<String, String>;

/// Platform adapter trait - implement for each git host
#[async_trait]
pub trait PlatformAdapter: Send + Sync {
    /// Platform identifier (github, gitlab, bitbucket, gitea)
    fn platform_id(&self) -> &'static str;

    /// Verify webhook signature
    fn verify_webhook(&self, payload: &[u8], headers: &Headers) -> Result<bool>;

    /// Parse platform-specific webhook into universal event
    fn parse_webhook(&self, payload: &[u8], headers: &Headers) -> Result<RepoEvent>;

    /// Post compliance status back to platform (e.g., commit status, check run)
    async fn post_status(&self, repo: &RepoRef, commit_sha: &str, status: &ComplianceStatus) -> Result<()>;

    /// Fetch repository file contents
    async fn fetch_file(&self, repo: &RepoRef, path: &str) -> Result<Vec<u8>>;

    /// List files in repository
    async fn list_files(&self, repo: &RepoRef, path: Option<&str>) -> Result<Vec<String>>;

    /// Get repository metadata
    async fn get_metadata(&self, repo: &RepoRef) -> Result<RepoMetadata>;
}

/// Repository metadata from platform API
#[derive(Debug, Clone, Default)]
pub struct RepoMetadata {
    pub default_branch: String,
    pub description: Option<String>,
    pub has_issues: bool,
    pub has_wiki: bool,
    pub has_pages: bool,
    pub has_ci: bool,
    pub has_branch_protection: bool,
    pub has_security_policy: bool,
    pub open_issues_count: u32,
    pub stargazers_count: u32,
    pub forks_count: u32,
    pub license: Option<String>,
    pub topics: Vec<String>,
    pub last_push: Option<chrono::DateTime<chrono::Utc>>,
}

/// Factory for creating platform adapters
pub struct AdapterFactory;

impl AdapterFactory {
    /// Create an adapter for the given platform
    pub fn create(platform: &str, config: AdapterConfig) -> Result<Box<dyn PlatformAdapter>> {
        match platform.to_lowercase().as_str() {
            "github" => Ok(Box::new(github::GitHubAdapter::new(config))),
            "gitlab" => Ok(Box::new(gitlab::GitLabAdapter::new(config))),
            "bitbucket" => Ok(Box::new(bitbucket::BitbucketAdapter::new(config))),
            "gitea" | "forgejo" => Ok(Box::new(gitea::GiteaAdapter::new(config))),
            _ => Err(RsrError::Platform(format!("Unknown platform: {}", platform))),
        }
    }

    /// Get list of supported platforms
    pub fn supported_platforms() -> &'static [&'static str] {
        &["github", "gitlab", "bitbucket", "gitea", "forgejo"]
    }
}

/// Configuration for platform adapters
#[derive(Debug, Clone, Default)]
pub struct AdapterConfig {
    /// API base URL (for self-hosted instances)
    pub api_url: Option<String>,
    /// API token/key for authentication
    pub api_token: Option<String>,
    /// Webhook secret for signature verification
    pub webhook_secret: Option<String>,
    /// App ID (for GitHub Apps)
    pub app_id: Option<String>,
    /// Private key (for GitHub Apps)
    pub private_key: Option<String>,
}

impl AdapterConfig {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn with_api_token(mut self, token: impl Into<String>) -> Self {
        self.api_token = Some(token.into());
        self
    }

    pub fn with_webhook_secret(mut self, secret: impl Into<String>) -> Self {
        self.webhook_secret = Some(secret.into());
        self
    }

    pub fn with_api_url(mut self, url: impl Into<String>) -> Self {
        self.api_url = Some(url.into());
        self
    }
}
