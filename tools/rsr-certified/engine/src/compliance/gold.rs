//! Gold tier compliance checks - Excellence level

use super::{ComplianceCheck, RepoContents};
use crate::{CertificationTier, CheckResult, Result};
use std::path::Path;

/// Get all Gold tier checks
pub fn get_checks() -> Vec<Box<dyn ComplianceCheck>> {
    vec![
        Box::new(DocumentationCheck),
        Box::new(TestCoverageCheck),
        Box::new(DependencyScanningCheck),
        Box::new(IssueTemplatesCheck),
    ]
}

/// Check for comprehensive documentation
pub struct DocumentationCheck;

#[async_trait::async_trait]
impl ComplianceCheck for DocumentationCheck {
    fn id(&self) -> &'static str {
        "gold.documentation"
    }

    fn name(&self) -> &'static str {
        "Comprehensive Documentation"
    }

    fn tier(&self) -> CertificationTier {
        CertificationTier::Gold
    }

    async fn check_local(&self, path: &Path) -> Result<CheckResult> {
        let doc_indicators = [
            "docs/",
            "doc/",
            "documentation/",
            "API.md",
            "ARCHITECTURE.md",
        ];

        let mut found_docs = Vec::new();

        for indicator in doc_indicators {
            let doc_path = path.join(indicator);
            if doc_path.exists() {
                found_docs.push(indicator);
            }
        }

        // Check for generated docs config
        let doc_configs = [
            "mkdocs.yml",
            "docusaurus.config.js",
            "sphinx/conf.py",
            "jsdoc.json",
            "typedoc.json",
            "rustdoc.toml",
        ];

        for config in doc_configs {
            if path.join(config).exists() {
                found_docs.push(config);
            }
        }

        if !found_docs.is_empty() {
            Ok(CheckResult {
                id: self.id().to_string(),
                name: self.name().to_string(),
                tier: self.tier(),
                passed: true,
                message: format!("Found documentation: {}", found_docs.join(", ")),
                details: None,
            })
        } else {
            Ok(CheckResult {
                id: self.id().to_string(),
                name: self.name().to_string(),
                tier: self.tier(),
                passed: false,
                message: "No comprehensive documentation found".to_string(),
                details: Some("Add docs/ directory or API documentation".to_string()),
            })
        }
    }

    async fn check_remote(&self, contents: &RepoContents) -> Result<CheckResult> {
        let doc_patterns = ["docs/", "doc/", "documentation/", "api.md", "architecture.md"];

        for file in &contents.files {
            let path_lower = file.path.to_lowercase();
            if doc_patterns.iter().any(|p| path_lower.starts_with(p) || path_lower.contains(p)) {
                return Ok(CheckResult {
                    id: self.id().to_string(),
                    name: self.name().to_string(),
                    tier: self.tier(),
                    passed: true,
                    message: format!("Found documentation: {}", file.path),
                    details: None,
                });
            }
        }

        Ok(CheckResult {
            id: self.id().to_string(),
            name: self.name().to_string(),
            tier: self.tier(),
            passed: false,
            message: "No comprehensive documentation found".to_string(),
            details: None,
        })
    }
}

/// Check for test coverage configuration
pub struct TestCoverageCheck;

#[async_trait::async_trait]
impl ComplianceCheck for TestCoverageCheck {
    fn id(&self) -> &'static str {
        "gold.test_coverage"
    }

    fn name(&self) -> &'static str {
        "Test Coverage"
    }

    fn tier(&self) -> CertificationTier {
        CertificationTier::Gold
    }

    async fn check_local(&self, path: &Path) -> Result<CheckResult> {
        // Check for test directories
        let test_dirs = ["tests/", "test/", "spec/", "__tests__/", "src/test/"];
        let mut has_tests = false;

        for dir in test_dirs {
            if path.join(dir).exists() {
                has_tests = true;
                break;
            }
        }

        // Check for coverage configuration
        let coverage_configs = [
            "codecov.yml",
            ".codecov.yml",
            "coveralls.yml",
            ".coveragerc",
            "coverage.json",
            "jest.config.js",
            "pytest.ini",
            "tarpaulin.toml",
            ".nycrc",
        ];

        let mut has_coverage = false;
        for config in coverage_configs {
            if path.join(config).exists() {
                has_coverage = true;
                break;
            }
        }

        // Also check CI files for coverage commands
        if !has_coverage {
            let ci_paths = [
                ".github/workflows",
                ".gitlab-ci.yml",
            ];

            for ci_path in ci_paths {
                let full_path = path.join(ci_path);
                if full_path.is_dir() {
                    if let Ok(entries) = std::fs::read_dir(full_path) {
                        for entry in entries.flatten() {
                            if let Ok(content) = std::fs::read_to_string(entry.path()) {
                                if content.contains("coverage") || content.contains("codecov") {
                                    has_coverage = true;
                                    break;
                                }
                            }
                        }
                    }
                } else if full_path.is_file() {
                    if let Ok(content) = std::fs::read_to_string(&full_path) {
                        if content.contains("coverage") {
                            has_coverage = true;
                        }
                    }
                }
            }
        }

        if has_tests && has_coverage {
            Ok(CheckResult {
                id: self.id().to_string(),
                name: self.name().to_string(),
                tier: self.tier(),
                passed: true,
                message: "Tests and coverage configuration found".to_string(),
                details: None,
            })
        } else if has_tests {
            Ok(CheckResult {
                id: self.id().to_string(),
                name: self.name().to_string(),
                tier: self.tier(),
                passed: false,
                message: "Tests found but no coverage configuration".to_string(),
                details: Some("Add coverage reporting (codecov, coveralls, etc.)".to_string()),
            })
        } else {
            Ok(CheckResult {
                id: self.id().to_string(),
                name: self.name().to_string(),
                tier: self.tier(),
                passed: false,
                message: "No test suite found".to_string(),
                details: Some("Add tests/ directory and coverage configuration".to_string()),
            })
        }
    }

    async fn check_remote(&self, contents: &RepoContents) -> Result<CheckResult> {
        let test_patterns = ["test", "tests", "spec", "__tests__"];
        let coverage_patterns = ["codecov", "coverage", "coveralls"];

        let has_tests = contents.files.iter().any(|f| {
            let path_lower = f.path.to_lowercase();
            test_patterns.iter().any(|p| path_lower.contains(p))
        });

        let has_coverage = contents.files.iter().any(|f| {
            let path_lower = f.path.to_lowercase();
            coverage_patterns.iter().any(|p| path_lower.contains(p))
        });

        if has_tests && has_coverage {
            Ok(CheckResult {
                id: self.id().to_string(),
                name: self.name().to_string(),
                tier: self.tier(),
                passed: true,
                message: "Tests and coverage found".to_string(),
                details: None,
            })
        } else {
            Ok(CheckResult {
                id: self.id().to_string(),
                name: self.name().to_string(),
                tier: self.tier(),
                passed: false,
                message: "Test coverage requirements not met".to_string(),
                details: None,
            })
        }
    }
}

/// Check for dependency scanning
pub struct DependencyScanningCheck;

#[async_trait::async_trait]
impl ComplianceCheck for DependencyScanningCheck {
    fn id(&self) -> &'static str {
        "gold.dependency_scanning"
    }

    fn name(&self) -> &'static str {
        "Dependency Scanning"
    }

    fn tier(&self) -> CertificationTier {
        CertificationTier::Gold
    }

    async fn check_local(&self, path: &Path) -> Result<CheckResult> {
        // Check for Dependabot/Renovate config
        let scanning_configs = [
            ".github/dependabot.yml",
            ".github/dependabot.yaml",
            "renovate.json",
            ".renovaterc",
            ".renovaterc.json",
            ".snyk",
        ];

        for config in scanning_configs {
            if path.join(config).exists() {
                return Ok(CheckResult {
                    id: self.id().to_string(),
                    name: self.name().to_string(),
                    tier: self.tier(),
                    passed: true,
                    message: format!("Found dependency scanning config: {}", config),
                    details: None,
                });
            }
        }

        // Check CI for security scanning
        let ci_path = path.join(".github/workflows");
        if ci_path.is_dir() {
            if let Ok(entries) = std::fs::read_dir(ci_path) {
                for entry in entries.flatten() {
                    if let Ok(content) = std::fs::read_to_string(entry.path()) {
                        if content.contains("security") || content.contains("audit") || content.contains("snyk") {
                            return Ok(CheckResult {
                                id: self.id().to_string(),
                                name: self.name().to_string(),
                                tier: self.tier(),
                                passed: true,
                                message: "Found security scanning in CI".to_string(),
                                details: None,
                            });
                        }
                    }
                }
            }
        }

        Ok(CheckResult {
            id: self.id().to_string(),
            name: self.name().to_string(),
            tier: self.tier(),
            passed: false,
            message: "No dependency scanning configured".to_string(),
            details: Some("Add Dependabot, Renovate, or Snyk configuration".to_string()),
        })
    }

    async fn check_remote(&self, contents: &RepoContents) -> Result<CheckResult> {
        let scanning_patterns = ["dependabot", "renovate", "snyk", "security"];

        for file in &contents.files {
            let path_lower = file.path.to_lowercase();
            if scanning_patterns.iter().any(|p| path_lower.contains(p)) {
                return Ok(CheckResult {
                    id: self.id().to_string(),
                    name: self.name().to_string(),
                    tier: self.tier(),
                    passed: true,
                    message: format!("Found dependency scanning: {}", file.path),
                    details: None,
                });
            }
        }

        Ok(CheckResult {
            id: self.id().to_string(),
            name: self.name().to_string(),
            tier: self.tier(),
            passed: false,
            message: "No dependency scanning configured".to_string(),
            details: None,
        })
    }
}

/// Check for issue/PR templates
pub struct IssueTemplatesCheck;

#[async_trait::async_trait]
impl ComplianceCheck for IssueTemplatesCheck {
    fn id(&self) -> &'static str {
        "gold.issue_templates"
    }

    fn name(&self) -> &'static str {
        "Issue/PR Templates"
    }

    fn tier(&self) -> CertificationTier {
        CertificationTier::Gold
    }

    async fn check_local(&self, path: &Path) -> Result<CheckResult> {
        let template_locations = [
            ".github/ISSUE_TEMPLATE",
            ".github/PULL_REQUEST_TEMPLATE.md",
            ".github/pull_request_template.md",
            ".gitlab/issue_templates",
            ".gitlab/merge_request_templates",
        ];

        let mut found = Vec::new();

        for location in template_locations {
            let template_path = path.join(location);
            if template_path.exists() {
                found.push(location);
            }
        }

        if !found.is_empty() {
            Ok(CheckResult {
                id: self.id().to_string(),
                name: self.name().to_string(),
                tier: self.tier(),
                passed: true,
                message: format!("Found templates: {}", found.join(", ")),
                details: None,
            })
        } else {
            Ok(CheckResult {
                id: self.id().to_string(),
                name: self.name().to_string(),
                tier: self.tier(),
                passed: false,
                message: "No issue/PR templates found".to_string(),
                details: Some("Add .github/ISSUE_TEMPLATE/ and PR templates".to_string()),
            })
        }
    }

    async fn check_remote(&self, contents: &RepoContents) -> Result<CheckResult> {
        let template_patterns = ["issue_template", "pull_request_template", "merge_request"];

        for file in &contents.files {
            let path_lower = file.path.to_lowercase();
            if template_patterns.iter().any(|p| path_lower.contains(p)) {
                return Ok(CheckResult {
                    id: self.id().to_string(),
                    name: self.name().to_string(),
                    tier: self.tier(),
                    passed: true,
                    message: format!("Found template: {}", file.path),
                    details: None,
                });
            }
        }

        Ok(CheckResult {
            id: self.id().to_string(),
            name: self.name().to_string(),
            tier: self.tier(),
            passed: false,
            message: "No issue/PR templates found".to_string(),
            details: None,
        })
    }
}
