// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//
//! Git history operations for Phase 2 of git-morph.
//!
//! Provides history filtering (for inflate) and history squashing (for deflate).
//! Uses `std::process::Command` to invoke git CLI operations for reliability,
//! since `git log --follow` and `git format-patch` / `git am` handle renames
//! and complex history better than raw commit walking for v0.2.0.

use anyhow::{bail, Context, Result};
use std::path::{Path, PathBuf};
use std::process::Command;

/// Filter repository history to only commits touching files matching owned patterns.
///
/// Strategy (practical v0.2.0 approach):
/// 1. Collect commit hashes that touch any file matching `owned_patterns`
///    using `git log --follow -- <pattern>` for each pattern.
/// 2. Deduplicate and sort commits in topological order.
/// 3. Export matching commits via `git format-patch`.
/// 4. Initialise a fresh git repo in `output_dir` and apply patches via `git am`.
///
/// # Arguments
///
/// * `repo_path` — Path to the source repository (monorepo).
/// * `component_path` — Relative path of the component within the monorepo.
/// * `owned_patterns` — Glob patterns identifying owned files.
/// * `output_dir` — Destination directory (already populated with files).
pub fn filter_history_for_component(
    repo_path: &Path,
    component_path: &Path,
    owned_patterns: &[String],
    output_dir: &Path,
) -> Result<usize> {
    // Find the monorepo root (walk up from component_path to find .git)
    let mono_root = find_git_root(repo_path)
        .with_context(|| format!("Cannot find git root from {}", repo_path.display()))?;

    // 1. Collect commit hashes touching owned files
    let commits = collect_commits_for_patterns(&mono_root, component_path, owned_patterns)?;

    if commits.is_empty() {
        tracing::info!("No commits found touching owned files — skipping history filter");
        return Ok(0);
    }

    tracing::info!("Found {} unique commit(s) touching owned files", commits.len());

    // 2. Export patches for those commits
    let patch_dir = create_temp_dir("git-morph-patches")?;

    export_patches(&mono_root, &commits, &patch_dir)?;

    // 3. Initialise git in output_dir and apply patches
    init_git_repo(output_dir)?;
    let applied = apply_patches(output_dir, &patch_dir)?;

    // Clean up temp directory
    let _ = std::fs::remove_dir_all(&patch_dir);

    Ok(applied)
}

/// Squash all history in a repository into a single commit.
///
/// Strategy:
/// 1. Initialise git in `repo_path` if not already a git repo.
/// 2. Add and commit all files.
/// 3. If there is existing history, reset soft to the root commit and recommit.
///
/// # Arguments
///
/// * `repo_path` — Path to the repository to squash.
/// * `message` — Commit message for the squash commit.
pub fn squash_history(repo_path: &Path, message: &str) -> Result<()> {
    // Ensure it is a git repo
    let git_dir = repo_path.join(".git");
    if !git_dir.exists() {
        init_git_repo(repo_path)?;
    }

    // Stage all files
    let status = Command::new("git")
        .args(["add", "-A"])
        .current_dir(repo_path)
        .status()
        .context("Failed to run `git add -A`")?;

    if !status.success() {
        bail!("`git add -A` failed in {}", repo_path.display());
    }

    // Check if there is any existing history
    let log_output = Command::new("git")
        .args(["rev-list", "--count", "HEAD"])
        .current_dir(repo_path)
        .output();

    let has_history = match log_output {
        Ok(output) if output.status.success() => {
            let count_str = String::from_utf8_lossy(&output.stdout).trim().to_string();
            count_str.parse::<u64>().unwrap_or(0) > 0
        }
        _ => false,
    };

    if has_history {
        // Find the root commit
        let root_output = Command::new("git")
            .args(["rev-list", "--max-parents=0", "HEAD"])
            .current_dir(repo_path)
            .output()
            .context("Failed to find root commit")?;

        if !root_output.status.success() {
            bail!("Failed to find root commit in {}", repo_path.display());
        }

        let root_sha = String::from_utf8_lossy(&root_output.stdout)
            .lines()
            .next()
            .unwrap_or("")
            .trim()
            .to_string();

        if root_sha.is_empty() {
            bail!("Could not determine root commit SHA");
        }

        // Soft-reset to root, then amend
        let status = Command::new("git")
            .args(["reset", "--soft", &root_sha])
            .current_dir(repo_path)
            .status()
            .context("Failed to run `git reset --soft`")?;

        if !status.success() {
            bail!("`git reset --soft` to root commit failed");
        }

        // Amend the root commit with all changes
        let status = Command::new("git")
            .args(["commit", "--amend", "-m", message])
            .current_dir(repo_path)
            .env("GIT_COMMITTER_NAME", "git-morph")
            .env("GIT_COMMITTER_EMAIL", "git-morph@localhost")
            .status()
            .context("Failed to amend root commit")?;

        if !status.success() {
            bail!("`git commit --amend` failed");
        }
    } else {
        // No history yet — just create the initial commit
        let status = Command::new("git")
            .args(["commit", "-m", message])
            .current_dir(repo_path)
            .env("GIT_AUTHOR_NAME", "git-morph")
            .env("GIT_AUTHOR_EMAIL", "git-morph@localhost")
            .env("GIT_COMMITTER_NAME", "git-morph")
            .env("GIT_COMMITTER_EMAIL", "git-morph@localhost")
            .status()
            .context("Failed to create initial commit")?;

        if !status.success() {
            bail!("`git commit` failed in {}", repo_path.display());
        }
    }

    Ok(())
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// Create a temporary directory with a descriptive prefix.
/// Uses `std::env::temp_dir()` to avoid requiring `tempfile` as a runtime dependency.
fn create_temp_dir(prefix: &str) -> Result<PathBuf> {
    let base = std::env::temp_dir();
    let unique = format!(
        "{}-{}-{}",
        prefix,
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_nanos()
    );
    let path = base.join(unique);
    std::fs::create_dir_all(&path)
        .with_context(|| format!("Failed to create temp directory {}", path.display()))?;
    Ok(path)
}

/// Walk upward from `start` to find the directory containing `.git`.
fn find_git_root(start: &Path) -> Result<PathBuf> {
    let canonical = std::fs::canonicalize(start)
        .with_context(|| format!("Cannot canonicalize {}", start.display()))?;

    let mut current = canonical.as_path();
    loop {
        if current.join(".git").exists() {
            return Ok(current.to_path_buf());
        }
        match current.parent() {
            Some(parent) => current = parent,
            None => bail!("No .git directory found above {}", start.display()),
        }
    }
}

/// Collect unique commit hashes touching files that match any of the owned patterns,
/// scoped to `component_path` within the repo at `repo_root`.
fn collect_commits_for_patterns(
    repo_root: &Path,
    component_path: &Path,
    owned_patterns: &[String],
) -> Result<Vec<String>> {
    let mut all_commits = Vec::new();

    for pattern in owned_patterns {
        // Build the pathspec: component_path/pattern
        // e.g. "my-component/src/**" for pattern "src/**"
        let pathspec = component_path.join(pattern);
        let pathspec_str = pathspec.to_string_lossy().to_string();

        let output = Command::new("git")
            .args([
                "log",
                "--format=%H",
                "--follow",
                "--diff-filter=ACDMRT",
                "--",
                &pathspec_str,
            ])
            .current_dir(repo_root)
            .output()
            .with_context(|| {
                format!("Failed to run `git log` for pattern {pattern}")
            })?;

        if !output.status.success() {
            // Non-fatal: pattern may not match anything
            tracing::debug!(
                "git log for pattern '{}' returned non-zero (may be no matches)",
                pattern
            );
            continue;
        }

        let stdout = String::from_utf8_lossy(&output.stdout);
        for line in stdout.lines() {
            let sha = line.trim();
            if !sha.is_empty() {
                all_commits.push(sha.to_string());
            }
        }
    }

    // Deduplicate while preserving order (oldest first via reverse)
    // git log outputs newest-first, so reverse to get chronological order
    all_commits.reverse();
    let mut seen = std::collections::HashSet::new();
    all_commits.retain(|sha| seen.insert(sha.clone()));

    Ok(all_commits)
}

/// Export commits as patch files using `git format-patch`.
fn export_patches(repo_root: &Path, commits: &[String], patch_dir: &Path) -> Result<()> {
    // Write commit list to a file for `git format-patch --stdin`
    // We use format-patch with explicit commit ranges for each commit
    for (i, sha) in commits.iter().enumerate() {
        let output = Command::new("git")
            .args([
                "format-patch",
                "-1",
                sha,
                "-o",
                &patch_dir.to_string_lossy(),
                "--start-number",
                &(i + 1).to_string(),
            ])
            .current_dir(repo_root)
            .output()
            .with_context(|| format!("Failed to export patch for commit {sha}"))?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            tracing::warn!("Could not export patch for {sha}: {stderr}");
        }
    }

    Ok(())
}

/// Initialise a fresh git repository at the given path.
fn init_git_repo(path: &Path) -> Result<()> {
    let git_dir = path.join(".git");
    if git_dir.exists() {
        return Ok(());
    }

    std::fs::create_dir_all(path)
        .with_context(|| format!("Failed to create directory {}", path.display()))?;

    let status = Command::new("git")
        .args(["init", "-b", "main"])
        .current_dir(path)
        .status()
        .context("Failed to run `git init`")?;

    if !status.success() {
        bail!("`git init` failed in {}", path.display());
    }

    Ok(())
}

/// Apply patch files from `patch_dir` into the repository at `repo_path`.
/// Returns the number of patches successfully applied.
fn apply_patches(repo_path: &Path, patch_dir: &Path) -> Result<usize> {
    // Collect and sort patch files
    let mut patches: Vec<PathBuf> = std::fs::read_dir(patch_dir)
        .context("Failed to read patch directory")?
        .filter_map(|entry| entry.ok())
        .map(|entry| entry.path())
        .filter(|p| {
            p.extension()
                .map(|ext| ext == "patch")
                .unwrap_or(false)
        })
        .collect();

    patches.sort();

    if patches.is_empty() {
        tracing::info!("No patch files found to apply");
        return Ok(0);
    }

    // First, stage all existing files so `git am` has a clean base
    let status = Command::new("git")
        .args(["add", "-A"])
        .current_dir(repo_path)
        .status()
        .context("Failed to stage files before applying patches")?;

    if !status.success() {
        bail!("`git add -A` failed before patch application");
    }

    // Create an initial commit so git am has something to work with
    let _ = Command::new("git")
        .args(["commit", "--allow-empty", "-m", "Initial commit (git-morph inflate)"])
        .current_dir(repo_path)
        .env("GIT_AUTHOR_NAME", "git-morph")
        .env("GIT_AUTHOR_EMAIL", "git-morph@localhost")
        .env("GIT_COMMITTER_NAME", "git-morph")
        .env("GIT_COMMITTER_EMAIL", "git-morph@localhost")
        .status();

    let mut applied = 0;

    for patch in &patches {
        let status = Command::new("git")
            .args(["am", "--3way", &patch.to_string_lossy()])
            .current_dir(repo_path)
            .status()
            .with_context(|| format!("Failed to apply patch {}", patch.display()))?;

        if status.success() {
            applied += 1;
        } else {
            // Abort the failed am and continue
            tracing::warn!("Patch {} failed to apply, skipping", patch.display());
            let _ = Command::new("git")
                .args(["am", "--abort"])
                .current_dir(repo_path)
                .status();
        }
    }

    Ok(applied)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_find_git_root_fails_on_non_repo() {
        let tmp = tempfile::tempdir().unwrap();
        let result = find_git_root(tmp.path());
        assert!(result.is_err());
    }

    #[test]
    fn test_find_git_root_succeeds_on_repo() {
        let tmp = tempfile::tempdir().unwrap();
        // Create a .git directory
        std::fs::create_dir(tmp.path().join(".git")).unwrap();
        let result = find_git_root(tmp.path());
        assert!(result.is_ok());
        assert_eq!(
            result.unwrap(),
            std::fs::canonicalize(tmp.path()).unwrap()
        );
    }

    #[test]
    fn test_squash_history_on_fresh_repo() {
        let tmp = tempfile::tempdir().unwrap();

        // git init
        Command::new("git")
            .args(["init", "-b", "main"])
            .current_dir(tmp.path())
            .status()
            .unwrap();

        // Configure git identity for the test
        Command::new("git")
            .args(["config", "user.name", "test"])
            .current_dir(tmp.path())
            .status()
            .unwrap();
        Command::new("git")
            .args(["config", "user.email", "test@test.com"])
            .current_dir(tmp.path())
            .status()
            .unwrap();

        // Create a file and commit
        std::fs::write(tmp.path().join("hello.txt"), "hello").unwrap();
        Command::new("git")
            .args(["add", "-A"])
            .current_dir(tmp.path())
            .status()
            .unwrap();
        Command::new("git")
            .args(["commit", "-m", "first"])
            .current_dir(tmp.path())
            .status()
            .unwrap();

        // Create another file and commit
        std::fs::write(tmp.path().join("world.txt"), "world").unwrap();
        Command::new("git")
            .args(["add", "-A"])
            .current_dir(tmp.path())
            .status()
            .unwrap();
        Command::new("git")
            .args(["commit", "-m", "second"])
            .current_dir(tmp.path())
            .status()
            .unwrap();

        // Squash
        squash_history(tmp.path(), "squashed all").unwrap();

        // Verify single commit
        let output = Command::new("git")
            .args(["rev-list", "--count", "HEAD"])
            .current_dir(tmp.path())
            .output()
            .unwrap();
        let count: u64 = String::from_utf8_lossy(&output.stdout)
            .trim()
            .parse()
            .unwrap();
        assert_eq!(count, 1, "Expected exactly 1 commit after squash");
    }
}
