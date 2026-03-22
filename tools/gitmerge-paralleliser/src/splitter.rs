// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//! Branch splitter — creates per-category branches from classified changes.
//!
//! For each file category, creates a branch off the current HEAD, stages only
//! the files in that category, and commits. The original branch is restored
//! at the end. This produces a set of small, focused branches that can be
//! pushed in parallel and reviewed independently on GitHub.

#![forbid(unsafe_code)]

use crate::classifier::FileClass;
use anyhow::{Context, Result};
use std::collections::BTreeMap;
use std::path::Path;
use tokio::process::Command;

/// Create one branch per file category, each containing only that category's changes.
///
/// Returns the list of branch names created.
pub async fn split_into_branches(
    repo: &Path,
    classified: &BTreeMap<FileClass, Vec<String>>,
    prefix: &str,
    message: &str,
    author: Option<&str>,
) -> Result<Vec<String>> {
    if classified.is_empty() {
        return Ok(Vec::new());
    }

    // Remember current branch/HEAD
    let original_branch = get_current_branch(repo).await?;
    let stash_needed = has_changes(repo).await?;

    // Stash any unstaged changes so we have a clean working tree
    if stash_needed {
        git(repo, &["stash", "push", "-u", "-m", "gitmerge-paralleliser: temp stash"])
            .await
            .context("Failed to stash changes")?;
    }

    let mut created_branches = Vec::new();

    for (class, files) in classified {
        let branch_name = format!("{}{}", prefix, class.branch_suffix());

        // Create branch from current HEAD (or reset if it exists)
        let _ = git(repo, &["branch", "-D", &branch_name]).await; // ignore if doesn't exist
        git(repo, &["checkout", "-b", &branch_name])
            .await
            .context(format!("Failed to create branch {branch_name}"))?;

        // Apply stashed changes
        if stash_needed {
            // Apply without dropping — we'll re-stash after
            let _ = git(repo, &["stash", "apply"]).await;
        }

        // Stage only files in this category
        git(repo, &["reset", "HEAD"]).await?; // unstage everything first
        for file in files {
            // Use git add for each file, ignoring errors (file might be deleted)
            let _ = git(repo, &["add", "--", file]).await;
        }

        // Check if anything is staged
        let staged = git(repo, &["diff", "--cached", "--name-only"]).await?;
        if staged.trim().is_empty() {
            // Nothing staged — skip this category
            git(repo, &["checkout", &original_branch]).await?;
            let _ = git(repo, &["branch", "-D", &branch_name]).await;
            continue;
        }

        // Commit
        let commit_msg = format!(
            "{}({}): {}\n\nCategory: {}\nFiles: {}\n\nCo-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>",
            class.commit_verb(),
            class.short(),
            message,
            class.label(),
            files.len()
        );

        let mut commit_args = vec!["commit", "-m", &commit_msg];
        if let Some(a) = author {
            commit_args.push("--author");
            commit_args.push(a);
        }
        git(repo, &commit_args)
            .await
            .context(format!("Failed to commit on branch {branch_name}"))?;

        created_branches.push(branch_name.clone());

        // Go back to original branch for next iteration
        git(repo, &["checkout", &original_branch]).await?;
    }

    // Restore stash if we created one
    if stash_needed {
        let _ = git(repo, &["stash", "pop"]).await;
    }

    Ok(created_branches)
}

/// Run a git command and return stdout
async fn git(repo: &Path, args: &[&str]) -> Result<String> {
    let output = Command::new("git")
        .args(args)
        .current_dir(repo)
        .output()
        .await
        .context(format!("Failed to execute: git {}", args.join(" ")))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        anyhow::bail!("git {} failed: {}", args.join(" "), stderr.trim());
    }

    Ok(String::from_utf8_lossy(&output.stdout).to_string())
}

/// Get the current branch name (or "HEAD" if detached)
async fn get_current_branch(repo: &Path) -> Result<String> {
    let output = Command::new("git")
        .args(["branch", "--show-current"])
        .current_dir(repo)
        .output()
        .await?;

    let branch = String::from_utf8_lossy(&output.stdout).trim().to_string();
    if branch.is_empty() {
        // Detached HEAD — use the commit hash
        let hash = git(repo, &["rev-parse", "HEAD"]).await?;
        Ok(hash.trim().to_string())
    } else {
        Ok(branch)
    }
}

/// Check if the working tree has any changes (staged or unstaged)
async fn has_changes(repo: &Path) -> Result<bool> {
    let output = Command::new("git")
        .args(["status", "--porcelain"])
        .current_dir(repo)
        .output()
        .await?;

    let stdout = String::from_utf8_lossy(&output.stdout);
    Ok(!stdout.trim().is_empty())
}
