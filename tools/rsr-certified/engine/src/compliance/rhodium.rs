//! Rhodium tier compliance checks - Exemplary level

use super::{ComplianceCheck, RepoContents};
use crate::{CertificationTier, CheckResult, Result};
use std::path::Path;

/// Get all Rhodium tier checks
pub fn get_checks() -> Vec<Box<dyn ComplianceCheck>> {
    vec![
        Box::new(SbomCheck),
        Box::new(ReproducibleBuildsCheck),
        Box::new(ThreatModelCheck),
        Box::new(SlsaComplianceCheck),
    ]
}

/// Check for Software Bill of Materials
pub struct SbomCheck;

#[async_trait::async_trait]
impl ComplianceCheck for SbomCheck {
    fn id(&self) -> &'static str {
        "rhodium.sbom"
    }

    fn name(&self) -> &'static str {
        "Software Bill of Materials"
    }

    fn tier(&self) -> CertificationTier {
        CertificationTier::Rhodium
    }

    async fn check_local(&self, path: &Path) -> Result<CheckResult> {
        // Check for SBOM files
        let sbom_files = [
            "sbom.json",
            "sbom.xml",
            "sbom.spdx",
            "sbom.spdx.json",
            "bom.json",
            "bom.xml",
            "cyclonedx.json",
            "cyclonedx.xml",
        ];

        for name in sbom_files {
            if path.join(name).exists() {
                return Ok(CheckResult {
                    id: self.id().to_string(),
                    name: self.name().to_string(),
                    tier: self.tier(),
                    passed: true,
                    message: format!("Found SBOM: {}", name),
                    details: None,
                });
            }
        }

        // Check CI for SBOM generation
        let ci_path = path.join(".github/workflows");
        if ci_path.is_dir() {
            if let Ok(entries) = std::fs::read_dir(ci_path) {
                for entry in entries.flatten() {
                    if let Ok(content) = std::fs::read_to_string(entry.path()) {
                        if content.contains("sbom") || content.contains("cyclonedx") || content.contains("spdx") {
                            return Ok(CheckResult {
                                id: self.id().to_string(),
                                name: self.name().to_string(),
                                tier: self.tier(),
                                passed: true,
                                message: "SBOM generation configured in CI".to_string(),
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
            message: "No SBOM found".to_string(),
            details: Some("Generate SBOM using CycloneDX or SPDX format".to_string()),
        })
    }

    async fn check_remote(&self, contents: &RepoContents) -> Result<CheckResult> {
        let sbom_patterns = ["sbom", "bom.json", "bom.xml", "cyclonedx", "spdx"];

        for file in &contents.files {
            let path_lower = file.path.to_lowercase();
            if sbom_patterns.iter().any(|p| path_lower.contains(p)) {
                return Ok(CheckResult {
                    id: self.id().to_string(),
                    name: self.name().to_string(),
                    tier: self.tier(),
                    passed: true,
                    message: format!("Found SBOM: {}", file.path),
                    details: None,
                });
            }
        }

        Ok(CheckResult {
            id: self.id().to_string(),
            name: self.name().to_string(),
            tier: self.tier(),
            passed: false,
            message: "No SBOM found".to_string(),
            details: None,
        })
    }
}

/// Check for reproducible builds configuration
pub struct ReproducibleBuildsCheck;

#[async_trait::async_trait]
impl ComplianceCheck for ReproducibleBuildsCheck {
    fn id(&self) -> &'static str {
        "rhodium.reproducible_builds"
    }

    fn name(&self) -> &'static str {
        "Reproducible Builds"
    }

    fn tier(&self) -> CertificationTier {
        CertificationTier::Rhodium
    }

    async fn check_local(&self, path: &Path) -> Result<CheckResult> {
        let mut indicators = Vec::new();

        // Check for lock files (necessary but not sufficient)
        let lock_files = [
            "Cargo.lock",
            "package-lock.json",
            "yarn.lock",
            "pnpm-lock.yaml",
            "poetry.lock",
            "Pipfile.lock",
            "go.sum",
            "Gemfile.lock",
        ];

        for lock in lock_files {
            if path.join(lock).exists() {
                indicators.push(format!("Lock file: {}", lock));
            }
        }

        // Check for containerized builds
        let container_files = ["Dockerfile", "Containerfile"];
        for cf in container_files {
            if path.join(cf).exists() {
                // Check if it uses pinned versions
                if let Ok(content) = std::fs::read_to_string(path.join(cf)) {
                    if content.contains("@sha256:") || content.contains("AS builder") {
                        indicators.push("Containerized build with pinned images".to_string());
                    }
                }
            }
        }

        // Check for Nix/Bazel (strongly reproducible build systems)
        if path.join("flake.nix").exists() || path.join("flake.lock").exists() {
            indicators.push("Nix flake configuration".to_string());
        }
        if path.join("WORKSPACE").exists() || path.join("MODULE.bazel").exists() {
            indicators.push("Bazel build system".to_string());
        }

        // Require at least lock file + one other indicator
        if indicators.len() >= 2 {
            Ok(CheckResult {
                id: self.id().to_string(),
                name: self.name().to_string(),
                tier: self.tier(),
                passed: true,
                message: "Reproducible build indicators found".to_string(),
                details: Some(indicators.join("\n")),
            })
        } else if !indicators.is_empty() {
            Ok(CheckResult {
                id: self.id().to_string(),
                name: self.name().to_string(),
                tier: self.tier(),
                passed: false,
                message: "Partial reproducibility support".to_string(),
                details: Some(format!(
                    "Found: {}\nNeed: pinned containers, Nix, or Bazel",
                    indicators.join(", ")
                )),
            })
        } else {
            Ok(CheckResult {
                id: self.id().to_string(),
                name: self.name().to_string(),
                tier: self.tier(),
                passed: false,
                message: "No reproducible build configuration".to_string(),
                details: Some("Add lock files and consider Nix/Bazel for full reproducibility".to_string()),
            })
        }
    }

    async fn check_remote(&self, contents: &RepoContents) -> Result<CheckResult> {
        let reproducible_patterns = ["cargo.lock", "package-lock", "yarn.lock", "flake.nix", "bazel"];

        let found: Vec<_> = contents
            .files
            .iter()
            .filter(|f| {
                let path_lower = f.path.to_lowercase();
                reproducible_patterns.iter().any(|p| path_lower.contains(p))
            })
            .map(|f| f.path.as_str())
            .collect();

        if found.len() >= 2 {
            Ok(CheckResult {
                id: self.id().to_string(),
                name: self.name().to_string(),
                tier: self.tier(),
                passed: true,
                message: "Reproducible build configuration found".to_string(),
                details: Some(found.join(", ")),
            })
        } else {
            Ok(CheckResult {
                id: self.id().to_string(),
                name: self.name().to_string(),
                tier: self.tier(),
                passed: false,
                message: "Insufficient reproducible build configuration".to_string(),
                details: None,
            })
        }
    }
}

/// Check for threat model documentation
pub struct ThreatModelCheck;

#[async_trait::async_trait]
impl ComplianceCheck for ThreatModelCheck {
    fn id(&self) -> &'static str {
        "rhodium.threat_model"
    }

    fn name(&self) -> &'static str {
        "Threat Model"
    }

    fn tier(&self) -> CertificationTier {
        CertificationTier::Rhodium
    }

    async fn check_local(&self, path: &Path) -> Result<CheckResult> {
        let threat_files = [
            "THREAT_MODEL.md",
            "THREAT-MODEL.md",
            "docs/threat-model.md",
            "docs/security/threat-model.md",
            "SECURITY_MODEL.md",
        ];

        for name in threat_files {
            let file_path = path.join(name);
            if file_path.exists() {
                return Ok(CheckResult {
                    id: self.id().to_string(),
                    name: self.name().to_string(),
                    tier: self.tier(),
                    passed: true,
                    message: format!("Found threat model: {}", name),
                    details: None,
                });
            }
        }

        // Check SECURITY.md for threat model section
        let security_path = path.join("SECURITY.md");
        if security_path.exists() {
            if let Ok(content) = std::fs::read_to_string(&security_path) {
                let content_lower = content.to_lowercase();
                if content_lower.contains("threat model") || content_lower.contains("security model") {
                    return Ok(CheckResult {
                        id: self.id().to_string(),
                        name: self.name().to_string(),
                        tier: self.tier(),
                        passed: true,
                        message: "Threat model found in SECURITY.md".to_string(),
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
            message: "No threat model documentation".to_string(),
            details: Some("Add THREAT_MODEL.md documenting security analysis".to_string()),
        })
    }

    async fn check_remote(&self, contents: &RepoContents) -> Result<CheckResult> {
        let threat_patterns = ["threat_model", "threat-model", "security_model"];

        for file in &contents.files {
            let path_lower = file.path.to_lowercase();
            if threat_patterns.iter().any(|p| path_lower.contains(p)) {
                return Ok(CheckResult {
                    id: self.id().to_string(),
                    name: self.name().to_string(),
                    tier: self.tier(),
                    passed: true,
                    message: format!("Found threat model: {}", file.path),
                    details: None,
                });
            }
        }

        Ok(CheckResult {
            id: self.id().to_string(),
            name: self.name().to_string(),
            tier: self.tier(),
            passed: false,
            message: "No threat model documentation".to_string(),
            details: None,
        })
    }
}

/// Check for SLSA compliance
pub struct SlsaComplianceCheck;

#[async_trait::async_trait]
impl ComplianceCheck for SlsaComplianceCheck {
    fn id(&self) -> &'static str {
        "rhodium.slsa"
    }

    fn name(&self) -> &'static str {
        "SLSA Compliance"
    }

    fn tier(&self) -> CertificationTier {
        CertificationTier::Rhodium
    }

    async fn check_local(&self, path: &Path) -> Result<CheckResult> {
        // Check for SLSA provenance generation in CI
        let ci_path = path.join(".github/workflows");
        if ci_path.is_dir() {
            if let Ok(entries) = std::fs::read_dir(ci_path) {
                for entry in entries.flatten() {
                    if let Ok(content) = std::fs::read_to_string(entry.path()) {
                        // Check for SLSA GitHub generator
                        if content.contains("slsa-framework/slsa-github-generator")
                            || content.contains("slsa-verifier")
                            || content.contains("provenance")
                        {
                            return Ok(CheckResult {
                                id: self.id().to_string(),
                                name: self.name().to_string(),
                                tier: self.tier(),
                                passed: true,
                                message: "SLSA provenance generation configured".to_string(),
                                details: None,
                            });
                        }
                    }
                }
            }
        }

        // Check for attestation files
        if path.join(".slsa").exists() || path.join("attestations").exists() {
            return Ok(CheckResult {
                id: self.id().to_string(),
                name: self.name().to_string(),
                tier: self.tier(),
                passed: true,
                message: "SLSA attestations directory found".to_string(),
                details: None,
            });
        }

        Ok(CheckResult {
            id: self.id().to_string(),
            name: self.name().to_string(),
            tier: self.tier(),
            passed: false,
            message: "No SLSA compliance detected".to_string(),
            details: Some("Configure SLSA provenance generation (Level 2+)".to_string()),
        })
    }

    async fn check_remote(&self, contents: &RepoContents) -> Result<CheckResult> {
        // Check for SLSA-related content in files
        for file in &contents.files {
            if let Some(ref content) = file.content {
                if content.contains("slsa-framework") || content.contains("slsa-github-generator") {
                    return Ok(CheckResult {
                        id: self.id().to_string(),
                        name: self.name().to_string(),
                        tier: self.tier(),
                        passed: true,
                        message: "SLSA configuration found".to_string(),
                        details: Some(format!("In: {}", file.path)),
                    });
                }
            }

            if file.path.contains("slsa") || file.path.contains("attestation") {
                return Ok(CheckResult {
                    id: self.id().to_string(),
                    name: self.name().to_string(),
                    tier: self.tier(),
                    passed: true,
                    message: format!("SLSA-related file found: {}", file.path),
                    details: None,
                });
            }
        }

        Ok(CheckResult {
            id: self.id().to_string(),
            name: self.name().to_string(),
            tier: self.tier(),
            passed: false,
            message: "No SLSA compliance detected".to_string(),
            details: None,
        })
    }
}
