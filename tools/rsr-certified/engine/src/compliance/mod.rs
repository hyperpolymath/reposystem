//! Compliance checking logic for RSR certification tiers

mod bronze;
mod gold;
mod rhodium;
mod silver;

use crate::{CertificationTier, CheckResult, ComplianceStatus, RepoRef, Result};
use std::path::Path;

/// Compliance check trait - implemented by each tier's check module
#[async_trait::async_trait]
pub trait ComplianceCheck: Send + Sync {
    /// Unique identifier for this check
    fn id(&self) -> &'static str;

    /// Human-readable name
    fn name(&self) -> &'static str;

    /// Which tier this check belongs to
    fn tier(&self) -> CertificationTier;

    /// Run the check against a local repository path
    async fn check_local(&self, path: &Path) -> Result<CheckResult>;

    /// Run the check against remote repository contents
    async fn check_remote(&self, contents: &RepoContents) -> Result<CheckResult>;
}

/// Repository contents abstraction for remote checking
#[derive(Debug, Default)]
pub struct RepoContents {
    pub files: Vec<FileEntry>,
    pub metadata: RepoMetadata,
}

#[derive(Debug, Clone)]
pub struct FileEntry {
    pub path: String,
    pub content: Option<String>,
    pub size: u64,
}

#[derive(Debug, Default, Clone)]
pub struct RepoMetadata {
    pub has_ci: bool,
    pub has_branch_protection: bool,
    pub has_security_policy: bool,
    pub default_branch: String,
    pub open_issues: u32,
    pub stars: u32,
    pub last_commit_date: Option<chrono::DateTime<chrono::Utc>>,
}

/// Main compliance engine
pub struct ComplianceEngine {
    checks: Vec<Box<dyn ComplianceCheck>>,
}

impl Default for ComplianceEngine {
    fn default() -> Self {
        Self::new()
    }
}

impl ComplianceEngine {
    pub fn new() -> Self {
        let mut checks: Vec<Box<dyn ComplianceCheck>> = Vec::new();

        // Add Bronze tier checks
        checks.extend(bronze::get_checks());

        // Add Silver tier checks
        checks.extend(silver::get_checks());

        // Add Gold tier checks
        checks.extend(gold::get_checks());

        // Add Rhodium tier checks
        checks.extend(rhodium::get_checks());

        Self { checks }
    }

    /// Check compliance of a local repository
    pub async fn check_local(&self, path: &Path) -> Result<ComplianceStatus> {
        let repo_ref = RepoRef::new("local", "local", path.file_name().unwrap_or_default().to_string_lossy());

        let mut results = Vec::new();

        for check in &self.checks {
            match check.check_local(path).await {
                Ok(result) => results.push(result),
                Err(e) => {
                    tracing::warn!("Check {} failed: {}", check.id(), e);
                    results.push(CheckResult {
                        id: check.id().to_string(),
                        name: check.name().to_string(),
                        tier: check.tier(),
                        passed: false,
                        message: format!("Check failed: {}", e),
                        details: None,
                    });
                }
            }
        }

        let tier = calculate_tier(&results);
        let score = calculate_score(&results);

        Ok(ComplianceStatus {
            repo: repo_ref,
            tier,
            score,
            checks: results,
            timestamp: chrono::Utc::now(),
        })
    }

    /// Check compliance using fetched repository contents
    pub async fn check_remote(&self, repo: RepoRef, contents: &RepoContents) -> Result<ComplianceStatus> {
        let mut results = Vec::new();

        for check in &self.checks {
            match check.check_remote(contents).await {
                Ok(result) => results.push(result),
                Err(e) => {
                    tracing::warn!("Check {} failed: {}", check.id(), e);
                    results.push(CheckResult {
                        id: check.id().to_string(),
                        name: check.name().to_string(),
                        tier: check.tier(),
                        passed: false,
                        message: format!("Check failed: {}", e),
                        details: None,
                    });
                }
            }
        }

        let tier = calculate_tier(&results);
        let score = calculate_score(&results);

        Ok(ComplianceStatus {
            repo,
            tier,
            score,
            checks: results,
            timestamp: chrono::Utc::now(),
        })
    }
}

/// Calculate the highest tier where all required checks pass
fn calculate_tier(results: &[CheckResult]) -> CertificationTier {
    let tiers = [
        CertificationTier::Rhodium,
        CertificationTier::Gold,
        CertificationTier::Silver,
        CertificationTier::Bronze,
    ];

    for tier in tiers {
        let tier_checks: Vec<_> = results.iter().filter(|r| r.tier <= tier).collect();
        if tier_checks.iter().all(|r| r.passed) {
            return tier;
        }
    }

    CertificationTier::None
}

/// Calculate a compliance score (0.0 - 1.0)
fn calculate_score(results: &[CheckResult]) -> f32 {
    if results.is_empty() {
        return 0.0;
    }

    let passed = results.iter().filter(|r| r.passed).count();
    passed as f32 / results.len() as f32
}
