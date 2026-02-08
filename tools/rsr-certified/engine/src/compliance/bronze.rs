//! Bronze tier compliance checks - Foundation level

use super::{ComplianceCheck, RepoContents};
use crate::{CertificationTier, CheckResult, Result};
use std::path::Path;

/// Get all Bronze tier checks
pub fn get_checks() -> Vec<Box<dyn ComplianceCheck>> {
    vec![
        Box::new(LicenseCheck),
        Box::new(ReadmeCheck),
        Box::new(GitignoreCheck),
        Box::new(NoSecretsCheck),
    ]
}

/// Check for valid LICENSE file
pub struct LicenseCheck;

#[async_trait::async_trait]
impl ComplianceCheck for LicenseCheck {
    fn id(&self) -> &'static str {
        "bronze.license"
    }

    fn name(&self) -> &'static str {
        "License File"
    }

    fn tier(&self) -> CertificationTier {
        CertificationTier::Bronze
    }

    async fn check_local(&self, path: &Path) -> Result<CheckResult> {
        let license_files = ["LICENSE", "LICENSE.md", "LICENSE.txt", "LICENCE", "COPYING"];

        for name in license_files {
            let license_path = path.join(name);
            if license_path.exists() {
                let content = std::fs::read_to_string(&license_path).unwrap_or_default();
                if content.len() > 50 {
                    return Ok(CheckResult {
                        id: self.id().to_string(),
                        name: self.name().to_string(),
                        tier: self.tier(),
                        passed: true,
                        message: format!("Found valid license file: {}", name),
                        details: detect_license_type(&content),
                    });
                }
            }
        }

        Ok(CheckResult {
            id: self.id().to_string(),
            name: self.name().to_string(),
            tier: self.tier(),
            passed: false,
            message: "No valid LICENSE file found".to_string(),
            details: Some("Add a LICENSE, LICENSE.md, or COPYING file".to_string()),
        })
    }

    async fn check_remote(&self, contents: &RepoContents) -> Result<CheckResult> {
        let license_files = ["LICENSE", "LICENSE.md", "LICENSE.txt", "LICENCE", "COPYING"];

        for file in &contents.files {
            let filename = file.path.split('/').last().unwrap_or(&file.path);
            if license_files.contains(&filename) {
                if let Some(ref content) = file.content {
                    if content.len() > 50 {
                        return Ok(CheckResult {
                            id: self.id().to_string(),
                            name: self.name().to_string(),
                            tier: self.tier(),
                            passed: true,
                            message: format!("Found valid license file: {}", file.path),
                            details: detect_license_type(content),
                        });
                    }
                }
            }
        }

        Ok(CheckResult {
            id: self.id().to_string(),
            name: self.name().to_string(),
            tier: self.tier(),
            passed: false,
            message: "No valid LICENSE file found".to_string(),
            details: None,
        })
    }
}

/// Check for README file
pub struct ReadmeCheck;

#[async_trait::async_trait]
impl ComplianceCheck for ReadmeCheck {
    fn id(&self) -> &'static str {
        "bronze.readme"
    }

    fn name(&self) -> &'static str {
        "README File"
    }

    fn tier(&self) -> CertificationTier {
        CertificationTier::Bronze
    }

    async fn check_local(&self, path: &Path) -> Result<CheckResult> {
        let readme_files = [
            "README.md",
            "README.adoc",
            "README.rst",
            "README.txt",
            "README",
        ];

        for name in readme_files {
            let readme_path = path.join(name);
            if readme_path.exists() {
                let content = std::fs::read_to_string(&readme_path).unwrap_or_default();
                if content.len() > 50 {
                    return Ok(CheckResult {
                        id: self.id().to_string(),
                        name: self.name().to_string(),
                        tier: self.tier(),
                        passed: true,
                        message: format!("Found README: {} ({} chars)", name, content.len()),
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
            message: "No valid README file found".to_string(),
            details: Some("Add a README.md with project description".to_string()),
        })
    }

    async fn check_remote(&self, contents: &RepoContents) -> Result<CheckResult> {
        let readme_files = ["README.md", "README.adoc", "README.rst", "README.txt", "README"];

        for file in &contents.files {
            let filename = file.path.split('/').last().unwrap_or(&file.path);
            if readme_files.contains(&filename) {
                if file.size > 50 {
                    return Ok(CheckResult {
                        id: self.id().to_string(),
                        name: self.name().to_string(),
                        tier: self.tier(),
                        passed: true,
                        message: format!("Found README: {}", file.path),
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
            message: "No valid README file found".to_string(),
            details: None,
        })
    }
}

/// Check for .gitignore file
pub struct GitignoreCheck;

#[async_trait::async_trait]
impl ComplianceCheck for GitignoreCheck {
    fn id(&self) -> &'static str {
        "bronze.gitignore"
    }

    fn name(&self) -> &'static str {
        ".gitignore File"
    }

    fn tier(&self) -> CertificationTier {
        CertificationTier::Bronze
    }

    async fn check_local(&self, path: &Path) -> Result<CheckResult> {
        let gitignore_path = path.join(".gitignore");

        if gitignore_path.exists() {
            let content = std::fs::read_to_string(&gitignore_path).unwrap_or_default();
            let non_empty_lines = content.lines().filter(|l| !l.trim().is_empty() && !l.starts_with('#')).count();

            if non_empty_lines > 0 {
                return Ok(CheckResult {
                    id: self.id().to_string(),
                    name: self.name().to_string(),
                    tier: self.tier(),
                    passed: true,
                    message: format!(".gitignore found with {} patterns", non_empty_lines),
                    details: None,
                });
            }
        }

        Ok(CheckResult {
            id: self.id().to_string(),
            name: self.name().to_string(),
            tier: self.tier(),
            passed: false,
            message: "No .gitignore file found".to_string(),
            details: Some("Add a .gitignore appropriate for your project type".to_string()),
        })
    }

    async fn check_remote(&self, contents: &RepoContents) -> Result<CheckResult> {
        for file in &contents.files {
            if file.path == ".gitignore" || file.path.ends_with("/.gitignore") {
                if file.size > 0 {
                    return Ok(CheckResult {
                        id: self.id().to_string(),
                        name: self.name().to_string(),
                        tier: self.tier(),
                        passed: true,
                        message: ".gitignore found".to_string(),
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
            message: "No .gitignore file found".to_string(),
            details: None,
        })
    }
}

/// Check for hardcoded secrets
pub struct NoSecretsCheck;

#[async_trait::async_trait]
impl ComplianceCheck for NoSecretsCheck {
    fn id(&self) -> &'static str {
        "bronze.no_secrets"
    }

    fn name(&self) -> &'static str {
        "No Hardcoded Secrets"
    }

    fn tier(&self) -> CertificationTier {
        CertificationTier::Bronze
    }

    async fn check_local(&self, path: &Path) -> Result<CheckResult> {
        let mut secrets_found = Vec::new();

        // Check for common secret files
        let secret_files = [".env", ".env.local", "credentials.json", "secrets.json", ".npmrc"];

        for name in secret_files {
            let file_path = path.join(name);
            if file_path.exists() && !is_gitignored(path, name) {
                secrets_found.push(format!("Sensitive file not gitignored: {}", name));
            }
        }

        // Walk source files and check for patterns
        if let Ok(entries) = glob::glob(&format!("{}/**/*.{{rs,js,ts,py,go,java,rb}}", path.display())) {
            for entry in entries.flatten() {
                if let Ok(content) = std::fs::read_to_string(&entry) {
                    if let Some(secret) = detect_secret_patterns(&content) {
                        let relative = entry.strip_prefix(path).unwrap_or(&entry);
                        secrets_found.push(format!("{}: {}", relative.display(), secret));
                    }
                }
            }
        }

        if secrets_found.is_empty() {
            Ok(CheckResult {
                id: self.id().to_string(),
                name: self.name().to_string(),
                tier: self.tier(),
                passed: true,
                message: "No obvious secrets detected".to_string(),
                details: None,
            })
        } else {
            Ok(CheckResult {
                id: self.id().to_string(),
                name: self.name().to_string(),
                tier: self.tier(),
                passed: false,
                message: format!("Found {} potential secret(s)", secrets_found.len()),
                details: Some(secrets_found.join("\n")),
            })
        }
    }

    async fn check_remote(&self, contents: &RepoContents) -> Result<CheckResult> {
        let mut secrets_found = Vec::new();

        for file in &contents.files {
            if let Some(ref content) = file.content {
                if let Some(secret) = detect_secret_patterns(content) {
                    secrets_found.push(format!("{}: {}", file.path, secret));
                }
            }
        }

        if secrets_found.is_empty() {
            Ok(CheckResult {
                id: self.id().to_string(),
                name: self.name().to_string(),
                tier: self.tier(),
                passed: true,
                message: "No obvious secrets detected".to_string(),
                details: None,
            })
        } else {
            Ok(CheckResult {
                id: self.id().to_string(),
                name: self.name().to_string(),
                tier: self.tier(),
                passed: false,
                message: format!("Found {} potential secret(s)", secrets_found.len()),
                details: Some(secrets_found.join("\n")),
            })
        }
    }
}

// Helper functions

fn detect_license_type(content: &str) -> Option<String> {
    let content_lower = content.to_lowercase();

    if content_lower.contains("mit license") || content_lower.contains("permission is hereby granted, free of charge") {
        Some("Detected: MIT License".to_string())
    } else if content_lower.contains("apache license") && content_lower.contains("version 2.0") {
        Some("Detected: Apache License 2.0".to_string())
    } else if content_lower.contains("gnu general public license") {
        Some("Detected: GPL License".to_string())
    } else if content_lower.contains("bsd") {
        Some("Detected: BSD License".to_string())
    } else {
        None
    }
}

fn is_gitignored(repo_path: &Path, file: &str) -> bool {
    let gitignore_path = repo_path.join(".gitignore");
    if let Ok(content) = std::fs::read_to_string(gitignore_path) {
        content.lines().any(|line| {
            let line = line.trim();
            !line.is_empty() && !line.starts_with('#') && (line == file || line == format!("/{}", file))
        })
    } else {
        false
    }
}

fn detect_secret_patterns(content: &str) -> Option<String> {
    let patterns = [
        (r#"(?i)api[_-]?key\s*[:=]\s*["'][a-zA-Z0-9]{20,}["']"#, "Possible API key"),
        (r#"(?i)secret[_-]?key\s*[:=]\s*["'][a-zA-Z0-9]{20,}["']"#, "Possible secret key"),
        (r#"(?i)password\s*[:=]\s*["'][^"']{8,}["']"#, "Possible hardcoded password"),
        (r"AKIA[0-9A-Z]{16}", "AWS Access Key ID"),
        (r"(?i)bearer\s+[a-zA-Z0-9\-_.]{20,}", "Possible Bearer token"),
        (r"-----BEGIN (RSA |EC |DSA )?PRIVATE KEY-----", "Private key"),
        (r"ghp_[a-zA-Z0-9]{36}", "GitHub Personal Access Token"),
        (r"gho_[a-zA-Z0-9]{36}", "GitHub OAuth Token"),
        (r"sk-[a-zA-Z0-9]{48}", "OpenAI API Key"),
    ];

    for (pattern, description) in patterns {
        if let Ok(re) = regex::Regex::new(pattern) {
            if re.is_match(content) {
                return Some(description.to_string());
            }
        }
    }

    None
}
