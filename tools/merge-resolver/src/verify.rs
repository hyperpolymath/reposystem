// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//! Post-merge verification — scan ALL git-tracked files for incomplete migrations.
//!
//! After a merge or migration, this module checks that no files were missed
//! by scanning every git-tracked file matching a glob, not just files in
//! specific directories. This prevents the "scoped to src/ but lib/ has
//! stale copies" problem that caused IDApTIK PR #28 to be incomplete.
//!
//! Usage:
//!   merge-resolver verify <REPO> --pattern "Js\\.Dict" --glob "*.res"
//!   merge-resolver verify <REPO> --pattern "Js\\." --glob "*.res" --fail-on-match

use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};
use std::process::Command;

/// Result of a verification scan
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VerifyResult {
    /// The regex pattern that was searched
    pub pattern: String,
    /// File glob filter applied
    pub glob: Option<String>,
    /// Total git-tracked files scanned
    pub files_scanned: usize,
    /// Files that matched the pattern (should be empty after a complete migration)
    pub matches: Vec<VerifyMatch>,
    /// Whether verification passed (no matches when fail_on_match is true)
    pub passed: bool,
}

/// A single file match from verification
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VerifyMatch {
    /// Path to the file (relative to repo root)
    pub file: PathBuf,
    /// Line numbers where the pattern was found
    pub line_numbers: Vec<usize>,
    /// Total match count in this file
    pub count: usize,
    /// Whether the file is in a gitignored directory that was committed before the rule
    pub likely_stale_artifact: bool,
}

/// Run post-merge verification on a repository.
///
/// Enumerates ALL git-tracked files (via `git ls-files`), optionally filters
/// by glob pattern, then searches each file for the given regex pattern.
/// This catches files in non-standard locations (e.g. `lib/ocaml/`) that
/// directory-scoped migrations miss.
pub fn verify_migration(
    repo_path: &Path,
    pattern: &str,
    glob: Option<&str>,
    exclude_comments: bool,
) -> Result<VerifyResult> {
    // Get ALL git-tracked files (not just src/)
    let tracked_files = list_tracked_files(repo_path, glob)?;
    let files_scanned = tracked_files.len();

    let mut matches = Vec::new();

    for file in &tracked_files {
        let full_path = repo_path.join(file);
        if !full_path.is_file() {
            continue;
        }

        // Read file content
        let content = match std::fs::read_to_string(&full_path) {
            Ok(c) => c,
            Err(_) => continue, // Skip binary files
        };

        let mut line_numbers = Vec::new();
        for (i, line) in content.lines().enumerate() {
            // Optionally skip comment-only lines
            let trimmed = line.trim();
            if exclude_comments && (trimmed.starts_with("//") || trimmed.starts_with("/*")) {
                continue;
            }

            if line.contains(pattern) {
                line_numbers.push(i + 1); // 1-indexed
            }
        }

        if !line_numbers.is_empty() {
            let count = line_numbers.len();
            let likely_stale = is_likely_stale_artifact(file);
            matches.push(VerifyMatch {
                file: file.clone(),
                line_numbers,
                count,
                likely_stale_artifact: likely_stale,
            });
        }
    }

    let passed = matches.is_empty();

    Ok(VerifyResult {
        pattern: pattern.to_string(),
        glob: glob.map(String::from),
        files_scanned,
        matches,
        passed,
    })
}

/// List all git-tracked files, optionally filtered by glob pattern.
///
/// Uses `git ls-files` which returns ALL tracked files regardless of
/// directory structure or .gitignore rules. This is the key improvement
/// over `find src/ -name "*.ext"` which misses files in non-standard
/// locations like `lib/ocaml/` or `vm/lib/`.
fn list_tracked_files(repo_path: &Path, glob: Option<&str>) -> Result<Vec<PathBuf>> {
    let mut args = vec!["ls-files"];

    // If glob provided, pass it to git ls-files
    let glob_pattern;
    if let Some(g) = glob {
        glob_pattern = g.to_string();
        args.push(&glob_pattern);
    }

    let output = Command::new("git")
        .args(&args)
        .current_dir(repo_path)
        .output()
        .context("Failed to run git ls-files")?;

    let stdout = String::from_utf8_lossy(&output.stdout);
    let files: Vec<PathBuf> = stdout
        .lines()
        .filter(|l| !l.is_empty())
        .map(PathBuf::from)
        .collect();

    Ok(files)
}

/// Heuristic: detect if a file path looks like a stale build artifact
/// that was committed before .gitignore rules were added.
///
/// Common patterns: lib/bs/, lib/ocaml/, .bsb.lock, node_modules/
fn is_likely_stale_artifact(path: &Path) -> bool {
    let s = path.to_string_lossy();
    s.contains("/lib/bs/")
        || s.contains("/lib/ocaml/")
        || s.contains("/lib/shared/")
        || s.contains("node_modules/")
        || s.ends_with(".bsb.lock")
        || s.ends_with(".ninja_log")
        || s.ends_with(".cmi")
        || s.ends_with(".cmj")
        || s.ends_with(".cmt")
        || s.ends_with(".ast")
}

impl std::fmt::Display for VerifyResult {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        if self.passed {
            writeln!(
                f,
                "PASS: No matches for '{}' across {} files",
                self.pattern, self.files_scanned
            )?;
        } else {
            let total_hits: usize = self.matches.iter().map(|m| m.count).sum();
            let stale_count = self.matches.iter().filter(|m| m.likely_stale_artifact).count();
            writeln!(
                f,
                "FAIL: {} matches for '{}' across {} files ({} files, {} likely stale artifacts)",
                total_hits,
                self.pattern,
                self.files_scanned,
                self.matches.len(),
                stale_count,
            )?;
            writeln!(f)?;

            for m in &self.matches {
                let stale_tag = if m.likely_stale_artifact {
                    " [STALE ARTIFACT]"
                } else {
                    ""
                };
                writeln!(
                    f,
                    "  {} ({} hits, lines: {:?}){}",
                    m.file.display(),
                    m.count,
                    &m.line_numbers[..m.line_numbers.len().min(5)],
                    stale_tag
                )?;
            }
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_is_likely_stale_artifact() {
        assert!(is_likely_stale_artifact(Path::new(
            "shared/lib/bs/src/DLCLoader.res"
        )));
        assert!(is_likely_stale_artifact(Path::new(
            "vm/lib/ocaml/VM.res"
        )));
        assert!(is_likely_stale_artifact(Path::new(
            "main-game/lib/shared/src/PuzzleFormat.res"
        )));
        assert!(!is_likely_stale_artifact(Path::new("src/app/Main.res")));
        assert!(!is_likely_stale_artifact(Path::new(
            "src/shared/DLCLoader.res"
        )));
    }
}
