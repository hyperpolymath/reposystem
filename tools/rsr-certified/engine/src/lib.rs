//! RSR Engine - Universal Rhodium Standard Repository Compliance Engine
//!
//! This crate provides a platform-agnostic compliance checking engine
//! for repository certification across GitHub, GitLab, Bitbucket, and more.

pub mod adapters;
pub mod compliance;
pub mod db;
pub mod events;
pub mod server;

use thiserror::Error;

/// RSR Engine error types
#[derive(Error, Debug)]
pub enum RsrError {
    #[error("Platform error: {0}")]
    Platform(String),

    #[error("Configuration error: {0}")]
    Config(String),

    #[error("Compliance check failed: {0}")]
    Compliance(String),

    #[error("Webhook verification failed")]
    WebhookVerification,

    #[error("Repository not found: {owner}/{repo}")]
    RepoNotFound { owner: String, repo: String },

    #[error("Rate limited by platform")]
    RateLimited,

    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("HTTP error: {0}")]
    Http(#[from] reqwest::Error),

    #[error("JSON error: {0}")]
    Json(#[from] serde_json::Error),
}

pub type Result<T> = std::result::Result<T, RsrError>;

/// RSR certification tiers
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum CertificationTier {
    /// No certification - does not meet minimum requirements
    None,
    /// Bronze - Foundation level compliance
    Bronze,
    /// Silver - Established project compliance
    Silver,
    /// Gold - Excellence in compliance
    Gold,
    /// Rhodium - Exemplary compliance
    Rhodium,
}

impl CertificationTier {
    /// Get the tier symbol
    pub fn symbol(&self) -> &'static str {
        match self {
            Self::None => "○",
            Self::Bronze => "●",
            Self::Silver => "☆",
            Self::Gold => "★",
            Self::Rhodium => "◆",
        }
    }

    /// Get the tier designation code
    pub fn code(&self) -> &'static str {
        match self {
            Self::None => "RSR-None",
            Self::Bronze => "RSR-Cu",
            Self::Silver => "RSR-Ag",
            Self::Gold => "RSR-Au",
            Self::Rhodium => "RSR-Rh",
        }
    }

    /// Get the badge color in hex
    pub fn color(&self) -> &'static str {
        match self {
            Self::None => "#808080",
            Self::Bronze => "#CD7F32",
            Self::Silver => "#C0C0C0",
            Self::Gold => "#FFD700",
            Self::Rhodium => "#E8E4E1",
        }
    }
}

impl std::fmt::Display for CertificationTier {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{} {}", self.symbol(), self.code())
    }
}

/// Repository reference - platform agnostic
#[derive(Debug, Clone, PartialEq, Eq, Hash, serde::Serialize, serde::Deserialize)]
pub struct RepoRef {
    pub platform: String,
    pub owner: String,
    pub repo: String,
    pub branch: Option<String>,
}

impl RepoRef {
    pub fn new(platform: impl Into<String>, owner: impl Into<String>, repo: impl Into<String>) -> Self {
        Self {
            platform: platform.into(),
            owner: owner.into(),
            repo: repo.into(),
            branch: None,
        }
    }

    pub fn with_branch(mut self, branch: impl Into<String>) -> Self {
        self.branch = Some(branch.into());
        self
    }
}

impl std::fmt::Display for RepoRef {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}:{}/{}", self.platform, self.owner, self.repo)?;
        if let Some(ref branch) = self.branch {
            write!(f, "@{}", branch)?;
        }
        Ok(())
    }
}

/// Compliance status for a repository
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct ComplianceStatus {
    pub repo: RepoRef,
    pub tier: CertificationTier,
    pub score: f32,
    pub checks: Vec<CheckResult>,
    pub timestamp: chrono::DateTime<chrono::Utc>,
}

/// Result of a single compliance check
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct CheckResult {
    pub id: String,
    pub name: String,
    pub tier: CertificationTier,
    pub passed: bool,
    pub message: String,
    pub details: Option<String>,
}

// Re-export commonly used types
pub use compliance::ComplianceEngine;
pub use events::RepoEvent;
