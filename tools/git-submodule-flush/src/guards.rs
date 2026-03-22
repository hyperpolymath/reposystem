// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//! Safety guards for git-submodule-flush.
//!
//! These checks run before any write operation to prevent damage. Each guard
//! returns a human-readable reason if the operation should be blocked.

#![forbid(unsafe_code)]

use anyhow::Result;
use std::path::Path;
use std::process::Command;

/// Check if a repo has too many changes (suggests this isn't routine submodule dirt).
pub fn check_large_changeset(repo: &Path, threshold: usize) -> Result<Option<String>> {
    let output = Command::new("git")
        .args(["status", "--porcelain"])
        .current_dir(repo)
        .output()?;
    let count = String::from_utf8_lossy(&output.stdout)
        .lines()
        .filter(|l| !l.is_empty())
        .count();

    if count > threshold {
        Ok(Some(format!(
            "{} has {} changed files (threshold: {}). Use --force-large to override.",
            repo.display(),
            count,
            threshold
        )))
    } else {
        Ok(None)
    }
}

/// Check if any changed files look like secrets.
pub fn check_for_secrets(repo: &Path) -> Result<Option<String>> {
    let output = Command::new("git")
        .args(["status", "--porcelain"])
        .current_dir(repo)
        .output()?;
    let stdout = String::from_utf8_lossy(&output.stdout);

    let suspect_patterns = [
        ".env",
        "credentials",
        "secret",
        ".pem",
        ".key",
        ".p12",
        ".pfx",
        "id_rsa",
        "id_ed25519",
        ".netrc",
        "token",
    ];

    let suspects: Vec<String> = stdout
        .lines()
        .filter(|l| !l.is_empty())
        .filter_map(|line| {
            let file = line.get(3..)?;
            let lower = file.to_lowercase();
            for pat in &suspect_patterns {
                if lower.contains(pat) {
                    return Some(file.to_string());
                }
            }
            None
        })
        .collect();

    if suspects.is_empty() {
        Ok(None)
    } else {
        Ok(Some(format!(
            "Possible secrets detected in {}:\n  {}",
            repo.display(),
            suspects.join("\n  ")
        )))
    }
}

/// Run panic-attack assail on a repo. Returns None if clean, Some(warning) if issues found.
pub fn run_panic_attack(repo: &Path) -> Result<Option<String>> {
    let output = Command::new("panic-attack")
        .args(["assail", "--quiet"])
        .current_dir(repo)
        .output();

    match output {
        Ok(o) if o.status.success() => Ok(None),
        Ok(o) => {
            let stderr = String::from_utf8_lossy(&o.stderr);
            Ok(Some(format!(
                "panic-attack assail found issues in {}:\n{}",
                repo.display(),
                stderr.trim()
            )))
        }
        Err(_) => {
            // panic-attack not installed — skip silently
            tracing::debug!("panic-attack not found, skipping security scan");
            Ok(None)
        }
    }
}

/// Check if the repo has a pre-commit hook that might block us.
pub fn check_precommit_hook(repo: &Path) -> bool {
    let hook_path = repo.join(".git/hooks/pre-commit");
    if hook_path.exists() {
        tracing::debug!("Pre-commit hook found at {}", hook_path.display());
        true
    } else {
        false
    }
}
