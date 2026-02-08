//! Silver tier compliance checks - Established project level

use super::{ComplianceCheck, RepoContents};
use crate::{CertificationTier, CheckResult, Result};
use std::path::Path;

/// Get all Silver tier checks
pub fn get_checks() -> Vec<Box<dyn ComplianceCheck>> {
    vec![
        Box::new(ContributingCheck),
        Box::new(CodeOfConductCheck),
        Box::new(ChangelogCheck),
        Box::new(CiConfigCheck),
        Box::new(SecurityPolicyCheck),
    ]
}

/// Check for CONTRIBUTING.md
pub struct ContributingCheck;

#[async_trait::async_trait]
impl ComplianceCheck for ContributingCheck {
    fn id(&self) -> &'static str {
        "silver.contributing"
    }

    fn name(&self) -> &'static str {
        "Contributing Guide"
    }

    fn tier(&self) -> CertificationTier {
        CertificationTier::Silver
    }

    async fn check_local(&self, path: &Path) -> Result<CheckResult> {
        let files = ["CONTRIBUTING.md", "CONTRIBUTING.adoc", "CONTRIBUTING.rst", ".github/CONTRIBUTING.md"];

        for name in files {
            let file_path = path.join(name);
            if file_path.exists() {
                let content = std::fs::read_to_string(&file_path).unwrap_or_default();
                if content.len() > 100 {
                    return Ok(CheckResult {
                        id: self.id().to_string(),
                        name: self.name().to_string(),
                        tier: self.tier(),
                        passed: true,
                        message: format!("Found contributing guide: {}", name),
                        details: None,
                    });
                }
            }
        }

        Ok(CheckResult {
            id: self.id().to_string(),
            name: self.name().to_string(),
            tier: self.tier(),
            passed: false,
            message: "No CONTRIBUTING guide found".to_string(),
            details: Some("Add CONTRIBUTING.md with contribution guidelines".to_string()),
        })
    }

    async fn check_remote(&self, contents: &RepoContents) -> Result<CheckResult> {
        let contributing_patterns = ["CONTRIBUTING", "contributing"];

        for file in &contents.files {
            let filename = file.path.to_lowercase();
            if contributing_patterns.iter().any(|p| filename.contains(p)) && file.size > 100 {
                return Ok(CheckResult {
                    id: self.id().to_string(),
                    name: self.name().to_string(),
                    tier: self.tier(),
                    passed: true,
                    message: format!("Found contributing guide: {}", file.path),
                    details: None,
                });
            }
        }

        Ok(CheckResult {
            id: self.id().to_string(),
            name: self.name().to_string(),
            tier: self.tier(),
            passed: false,
            message: "No CONTRIBUTING guide found".to_string(),
            details: None,
        })
    }
}

/// Check for CODE_OF_CONDUCT
pub struct CodeOfConductCheck;

#[async_trait::async_trait]
impl ComplianceCheck for CodeOfConductCheck {
    fn id(&self) -> &'static str {
        "silver.code_of_conduct"
    }

    fn name(&self) -> &'static str {
        "Code of Conduct"
    }

    fn tier(&self) -> CertificationTier {
        CertificationTier::Silver
    }

    async fn check_local(&self, path: &Path) -> Result<CheckResult> {
        let files = [
            "CODE_OF_CONDUCT.md",
            "CODE-OF-CONDUCT.md",
            ".github/CODE_OF_CONDUCT.md",
        ];

        for name in files {
            let file_path = path.join(name);
            if file_path.exists() {
                return Ok(CheckResult {
                    id: self.id().to_string(),
                    name: self.name().to_string(),
                    tier: self.tier(),
                    passed: true,
                    message: format!("Found code of conduct: {}", name),
                    details: None,
                });
            }
        }

        Ok(CheckResult {
            id: self.id().to_string(),
            name: self.name().to_string(),
            tier: self.tier(),
            passed: false,
            message: "No CODE_OF_CONDUCT found".to_string(),
            details: Some("Add CODE_OF_CONDUCT.md (consider Contributor Covenant)".to_string()),
        })
    }

    async fn check_remote(&self, contents: &RepoContents) -> Result<CheckResult> {
        for file in &contents.files {
            let filename = file.path.to_lowercase();
            if filename.contains("code_of_conduct") || filename.contains("code-of-conduct") {
                return Ok(CheckResult {
                    id: self.id().to_string(),
                    name: self.name().to_string(),
                    tier: self.tier(),
                    passed: true,
                    message: format!("Found code of conduct: {}", file.path),
                    details: None,
                });
            }
        }

        Ok(CheckResult {
            id: self.id().to_string(),
            name: self.name().to_string(),
            tier: self.tier(),
            passed: false,
            message: "No CODE_OF_CONDUCT found".to_string(),
            details: None,
        })
    }
}

/// Check for CHANGELOG
pub struct ChangelogCheck;

#[async_trait::async_trait]
impl ComplianceCheck for ChangelogCheck {
    fn id(&self) -> &'static str {
        "silver.changelog"
    }

    fn name(&self) -> &'static str {
        "Changelog"
    }

    fn tier(&self) -> CertificationTier {
        CertificationTier::Silver
    }

    async fn check_local(&self, path: &Path) -> Result<CheckResult> {
        let files = [
            "CHANGELOG.md",
            "CHANGELOG.adoc",
            "CHANGELOG",
            "HISTORY.md",
            "CHANGES.md",
            "NEWS.md",
        ];

        for name in files {
            let file_path = path.join(name);
            if file_path.exists() {
                return Ok(CheckResult {
                    id: self.id().to_string(),
                    name: self.name().to_string(),
                    tier: self.tier(),
                    passed: true,
                    message: format!("Found changelog: {}", name),
                    details: None,
                });
            }
        }

        // Also check for GitHub releases as an alternative
        Ok(CheckResult {
            id: self.id().to_string(),
            name: self.name().to_string(),
            tier: self.tier(),
            passed: false,
            message: "No CHANGELOG found".to_string(),
            details: Some("Add CHANGELOG.md or use GitHub Releases".to_string()),
        })
    }

    async fn check_remote(&self, contents: &RepoContents) -> Result<CheckResult> {
        let changelog_patterns = ["changelog", "history", "changes", "news"];

        for file in &contents.files {
            let filename = file.path.to_lowercase();
            if changelog_patterns.iter().any(|p| filename.contains(p)) {
                return Ok(CheckResult {
                    id: self.id().to_string(),
                    name: self.name().to_string(),
                    tier: self.tier(),
                    passed: true,
                    message: format!("Found changelog: {}", file.path),
                    details: None,
                });
            }
        }

        Ok(CheckResult {
            id: self.id().to_string(),
            name: self.name().to_string(),
            tier: self.tier(),
            passed: false,
            message: "No CHANGELOG found".to_string(),
            details: None,
        })
    }
}

/// Check for CI/CD configuration
pub struct CiConfigCheck;

#[async_trait::async_trait]
impl ComplianceCheck for CiConfigCheck {
    fn id(&self) -> &'static str {
        "silver.ci_config"
    }

    fn name(&self) -> &'static str {
        "CI/CD Configuration"
    }

    fn tier(&self) -> CertificationTier {
        CertificationTier::Silver
    }

    async fn check_local(&self, path: &Path) -> Result<CheckResult> {
        let ci_indicators = [
            ".github/workflows",           // GitHub Actions
            ".gitlab-ci.yml",              // GitLab CI
            "Jenkinsfile",                 // Jenkins
            ".travis.yml",                 // Travis CI
            ".circleci/config.yml",        // CircleCI
            "azure-pipelines.yml",         // Azure DevOps
            ".drone.yml",                  // Drone CI
            "bitbucket-pipelines.yml",     // Bitbucket Pipelines
            ".buildkite",                  // Buildkite
            "appveyor.yml",                // AppVeyor
        ];

        for indicator in ci_indicators {
            let ci_path = path.join(indicator);
            if ci_path.exists() {
                return Ok(CheckResult {
                    id: self.id().to_string(),
                    name: self.name().to_string(),
                    tier: self.tier(),
                    passed: true,
                    message: format!("Found CI configuration: {}", indicator),
                    details: None,
                });
            }
        }

        Ok(CheckResult {
            id: self.id().to_string(),
            name: self.name().to_string(),
            tier: self.tier(),
            passed: false,
            message: "No CI/CD configuration found".to_string(),
            details: Some("Add CI configuration (GitHub Actions, GitLab CI, etc.)".to_string()),
        })
    }

    async fn check_remote(&self, contents: &RepoContents) -> Result<CheckResult> {
        if contents.metadata.has_ci {
            return Ok(CheckResult {
                id: self.id().to_string(),
                name: self.name().to_string(),
                tier: self.tier(),
                passed: true,
                message: "CI/CD is configured".to_string(),
                details: None,
            });
        }

        let ci_patterns = [
            ".github/workflows",
            ".gitlab-ci",
            "jenkinsfile",
            ".travis",
            ".circleci",
            "azure-pipelines",
            ".drone",
            "bitbucket-pipelines",
        ];

        for file in &contents.files {
            let path_lower = file.path.to_lowercase();
            if ci_patterns.iter().any(|p| path_lower.contains(p)) {
                return Ok(CheckResult {
                    id: self.id().to_string(),
                    name: self.name().to_string(),
                    tier: self.tier(),
                    passed: true,
                    message: format!("Found CI configuration: {}", file.path),
                    details: None,
                });
            }
        }

        Ok(CheckResult {
            id: self.id().to_string(),
            name: self.name().to_string(),
            tier: self.tier(),
            passed: false,
            message: "No CI/CD configuration found".to_string(),
            details: None,
        })
    }
}

/// Check for SECURITY.md
pub struct SecurityPolicyCheck;

#[async_trait::async_trait]
impl ComplianceCheck for SecurityPolicyCheck {
    fn id(&self) -> &'static str {
        "silver.security_policy"
    }

    fn name(&self) -> &'static str {
        "Security Policy"
    }

    fn tier(&self) -> CertificationTier {
        CertificationTier::Silver
    }

    async fn check_local(&self, path: &Path) -> Result<CheckResult> {
        let files = ["SECURITY.md", ".github/SECURITY.md"];

        for name in files {
            let file_path = path.join(name);
            if file_path.exists() {
                let content = std::fs::read_to_string(&file_path).unwrap_or_default();
                if content.len() > 50 {
                    return Ok(CheckResult {
                        id: self.id().to_string(),
                        name: self.name().to_string(),
                        tier: self.tier(),
                        passed: true,
                        message: format!("Found security policy: {}", name),
                        details: None,
                    });
                }
            }
        }

        Ok(CheckResult {
            id: self.id().to_string(),
            name: self.name().to_string(),
            tier: self.tier(),
            passed: false,
            message: "No SECURITY.md found".to_string(),
            details: Some("Add SECURITY.md with vulnerability disclosure process".to_string()),
        })
    }

    async fn check_remote(&self, contents: &RepoContents) -> Result<CheckResult> {
        if contents.metadata.has_security_policy {
            return Ok(CheckResult {
                id: self.id().to_string(),
                name: self.name().to_string(),
                tier: self.tier(),
                passed: true,
                message: "Security policy is configured".to_string(),
                details: None,
            });
        }

        for file in &contents.files {
            if file.path.to_lowercase().contains("security") {
                return Ok(CheckResult {
                    id: self.id().to_string(),
                    name: self.name().to_string(),
                    tier: self.tier(),
                    passed: true,
                    message: format!("Found security policy: {}", file.path),
                    details: None,
                });
            }
        }

        Ok(CheckResult {
            id: self.id().to_string(),
            name: self.name().to_string(),
            tier: self.tier(),
            passed: false,
            message: "No SECURITY.md found".to_string(),
            details: None,
        })
    }
}
