// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//! Core flush engine — builds a bottom-up execution plan and runs it.
//!
//! The plan is a tree of dirty submodules. Execution walks the tree depth-first
//! (post-order), committing leaves before parents. This guarantees that when a
//! parent commits its updated submodule pointer, the submodule's commit exists
//! and has been pushed.
//!
//! ## Algorithm
//!
//! 1. `git status --porcelain` on the root repo
//! 2. For each dirty submodule entry (` M submodule-path`):
//!    a. Recurse into the submodule (depth-first)
//!    b. Record its dirty files and child submodules
//! 3. Build a list of (repo_path, depth, change_count) tuples
//! 4. Sort by depth descending (deepest first)
//! 5. For each entry: guard checks → git add -A → git commit → git push
//! 6. After children are committed, parent's `git add -A` picks up new pointer

#![forbid(unsafe_code)]

use crate::guards;
use anyhow::{Context, Result};
use serde::Serialize;
use std::collections::HashSet;
use std::path::{Path, PathBuf};
use std::process::Command;

/// A single node in the flush plan — one repo that needs committing.
#[derive(Debug, Clone, Serialize)]
pub struct FlushNode {
    /// Absolute path to the repo
    pub path: PathBuf,
    /// Repo name (last path component)
    pub name: String,
    /// Depth in the submodule tree (0 = root)
    pub depth: usize,
    /// Number of changed files
    pub change_count: usize,
    /// List of changed files (for display)
    pub changed_files: Vec<String>,
    /// Whether this node has dirty submodules of its own
    pub has_dirty_children: bool,
    /// Guard warnings (non-fatal)
    pub warnings: Vec<String>,
    /// Guard blocks (fatal — won't commit)
    pub blocked: Option<String>,
}

/// The complete flush plan — ordered list of repos to commit.
#[derive(Debug, Serialize)]
pub struct FlushPlan {
    /// Nodes in execution order (deepest first)
    pub nodes: Vec<FlushNode>,
    /// Total files across all nodes
    pub total_files: usize,
    /// Total repos to commit
    pub total_repos: usize,
    /// Maximum depth reached
    pub max_depth_reached: usize,
}

/// Result of executing the flush plan.
#[derive(Debug, Serialize)]
pub struct FlushResult {
    pub committed: Vec<FlushCommitResult>,
    pub skipped: Vec<FlushSkipResult>,
    pub total_committed: usize,
    pub total_skipped: usize,
    pub total_pushed: usize,
    pub clean: bool,
}

#[derive(Debug, Serialize)]
pub struct FlushCommitResult {
    pub name: String,
    pub path: PathBuf,
    pub depth: usize,
    pub files: usize,
    pub commit_hash: String,
    pub pushed: bool,
}

#[derive(Debug, Serialize)]
pub struct FlushSkipResult {
    pub name: String,
    pub path: PathBuf,
    pub reason: String,
}

impl FlushPlan {
    /// Build a flush plan by walking the submodule tree.
    pub fn build(
        root: &Path,
        max_depth: usize,
        skip: &HashSet<String>,
        large_threshold: usize,
        force_large: bool,
    ) -> Result<Self> {
        let mut nodes = Vec::new();
        collect_dirty_repos(root, 0, max_depth, skip, large_threshold, force_large, &mut nodes)?;

        // Sort deepest first (post-order for bottom-up execution)
        nodes.sort_by(|a, b| b.depth.cmp(&a.depth).then(a.name.cmp(&b.name)));

        let total_files: usize = nodes.iter().map(|n| n.change_count).sum();
        let total_repos = nodes.len();
        let max_depth_reached = nodes.iter().map(|n| n.depth).max().unwrap_or(0);

        Ok(Self {
            nodes,
            total_files,
            total_repos,
            max_depth_reached,
        })
    }

    /// Check if the plan is empty (nothing to flush).
    pub fn is_empty(&self) -> bool {
        self.nodes.is_empty()
    }

    /// Display the plan to stdout.
    pub fn display(&self) {
        println!(
            "Flush plan: {} repos, {} files, max depth {}",
            self.total_repos, self.total_files, self.max_depth_reached
        );
        println!();

        for node in &self.nodes {
            let indent = "  ".repeat(node.depth);
            let blocked_marker = if node.blocked.is_some() { " [BLOCKED]" } else { "" };
            let warning_marker = if !node.warnings.is_empty() {
                format!(" [{}w]", node.warnings.len())
            } else {
                String::new()
            };

            println!(
                "  {}{} ({} files, depth {}){blocked_marker}{warning_marker}",
                indent, node.name, node.change_count, node.depth
            );

            if let Some(ref reason) = node.blocked {
                println!("    {}  BLOCKED: {reason}", indent);
            }
            for w in &node.warnings {
                println!("    {}  warning: {w}", indent);
            }
        }
    }

    /// Convert plan to a preview result (for JSON dry-run output).
    pub fn to_preview(&self) -> FlushResult {
        FlushResult {
            committed: Vec::new(),
            skipped: self
                .nodes
                .iter()
                .map(|n| FlushSkipResult {
                    name: n.name.clone(),
                    path: n.path.clone(),
                    reason: "dry-run".to_string(),
                })
                .collect(),
            total_committed: 0,
            total_skipped: self.nodes.len(),
            total_pushed: 0,
            clean: false,
        }
    }

    /// Execute the plan: commit and optionally push each repo bottom-up.
    pub fn execute(
        &self,
        message: &str,
        author: Option<&str>,
        push: bool,
        remote: &str,
        panic_attack: bool,
    ) -> Result<FlushResult> {
        let mut committed = Vec::new();
        let mut skipped = Vec::new();

        for node in &self.nodes {
            // Skip blocked nodes
            if let Some(ref reason) = node.blocked {
                println!("  SKIP {}: {reason}", node.name);
                skipped.push(FlushSkipResult {
                    name: node.name.clone(),
                    path: node.path.clone(),
                    reason: reason.clone(),
                });
                continue;
            }

            // Run panic-attack if requested
            if panic_attack {
                if let Some(warning) = guards::run_panic_attack(&node.path)? {
                    println!("  SKIP {} (panic-attack): {warning}", node.name);
                    skipped.push(FlushSkipResult {
                        name: node.name.clone(),
                        path: node.path.clone(),
                        reason: warning,
                    });
                    continue;
                }
            }

            // Stage all changes
            let add_output = Command::new("git")
                .args(["add", "-A"])
                .current_dir(&node.path)
                .output()
                .context(format!("git add failed in {}", node.name))?;

            if !add_output.status.success() {
                let err = String::from_utf8_lossy(&add_output.stderr);
                skipped.push(FlushSkipResult {
                    name: node.name.clone(),
                    path: node.path.clone(),
                    reason: format!("git add failed: {err}"),
                });
                continue;
            }

            // Check if anything is actually staged (might have been resolved by child commits)
            let diff_output = Command::new("git")
                .args(["diff", "--cached", "--name-only"])
                .current_dir(&node.path)
                .output()?;
            let staged = String::from_utf8_lossy(&diff_output.stdout);
            if staged.trim().is_empty() {
                tracing::debug!("{}: nothing staged after add, skipping", node.name);
                continue;
            }

            // Build commit message with context
            let full_message = format!(
                "{message}\n\nRepo: {}\nDepth: {}\nFiles: {}\n\nCo-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>",
                node.name, node.depth, node.change_count
            );

            // Commit
            let mut commit_args = vec!["commit", "-m", &full_message];
            let author_str;
            if let Some(a) = author {
                author_str = a.to_string();
                commit_args.push("--author");
                commit_args.push(&author_str);
            }

            let commit_output = Command::new("git")
                .args(&commit_args)
                .current_dir(&node.path)
                .output()
                .context(format!("git commit failed in {}", node.name))?;

            if !commit_output.status.success() {
                let err = String::from_utf8_lossy(&commit_output.stderr);
                // Pre-commit hook failure is common — report but continue with other repos
                skipped.push(FlushSkipResult {
                    name: node.name.clone(),
                    path: node.path.clone(),
                    reason: format!("commit failed: {}", err.trim()),
                });
                // Reset the index so the parent doesn't see a half-staged state
                let _ = Command::new("git")
                    .args(["reset", "HEAD"])
                    .current_dir(&node.path)
                    .output();
                continue;
            }

            // Extract commit hash
            let hash_output = Command::new("git")
                .args(["rev-parse", "--short", "HEAD"])
                .current_dir(&node.path)
                .output()?;
            let commit_hash = String::from_utf8_lossy(&hash_output.stdout).trim().to_string();

            println!("  OK {} [{}] ({} files)", node.name, commit_hash, node.change_count);

            // Push
            let mut pushed = false;
            if push {
                let push_output = Command::new("git")
                    .args(["push", remote])
                    .current_dir(&node.path)
                    .output();

                match push_output {
                    Ok(o) if o.status.success() => {
                        pushed = true;
                        tracing::debug!("{}: pushed to {remote}", node.name);
                    }
                    Ok(o) => {
                        let err = String::from_utf8_lossy(&o.stderr);
                        println!("    push failed (commit preserved): {}", err.trim());
                    }
                    Err(e) => {
                        println!("    push error (commit preserved): {e}");
                    }
                }
            }

            committed.push(FlushCommitResult {
                name: node.name.clone(),
                path: node.path.clone(),
                depth: node.depth,
                files: node.change_count,
                commit_hash,
                pushed,
            });
        }

        let total_committed = committed.len();
        let total_pushed = committed.iter().filter(|c| c.pushed).count();
        let total_skipped = skipped.len();

        Ok(FlushResult {
            committed,
            skipped,
            total_committed,
            total_skipped,
            total_pushed,
            clean: false,
        })
    }
}

impl FlushResult {
    /// Create a result indicating everything is clean.
    pub fn clean() -> Self {
        Self {
            committed: Vec::new(),
            skipped: Vec::new(),
            total_committed: 0,
            total_skipped: 0,
            total_pushed: 0,
            clean: true,
        }
    }

    /// Display the result to stdout.
    pub fn display(&self) {
        println!();
        println!(
            "Done: {} committed, {} pushed, {} skipped",
            self.total_committed, self.total_pushed, self.total_skipped
        );
        if !self.skipped.is_empty() {
            println!("\nSkipped:");
            for s in &self.skipped {
                println!("  {}: {}", s.name, s.reason);
            }
        }
    }
}

/// Recursively collect dirty repos in the submodule tree.
fn collect_dirty_repos(
    repo: &Path,
    depth: usize,
    max_depth: usize,
    skip: &HashSet<String>,
    large_threshold: usize,
    force_large: bool,
    out: &mut Vec<FlushNode>,
) -> Result<()> {
    let repo_name = repo
        .file_name()
        .map(|f| f.to_string_lossy().to_string())
        .unwrap_or_else(|| "unknown".to_string());

    // Skip if in skip list
    if skip.contains(&repo_name) {
        tracing::debug!("Skipping {repo_name} (in skip list)");
        return Ok(());
    }

    // Get status
    let output = Command::new("git")
        .args(["status", "--porcelain"])
        .current_dir(repo)
        .output()
        .context(format!("git status failed in {}", repo.display()))?;

    let stdout = String::from_utf8_lossy(&output.stdout);
    let lines: Vec<&str> = stdout.lines().filter(|l| !l.is_empty()).collect();

    if lines.is_empty() {
        return Ok(());
    }

    // Separate submodule entries from regular file changes
    let mut dirty_submodules = Vec::new();
    let mut changed_files = Vec::new();

    for line in &lines {
        let file = line.get(3..).unwrap_or("").trim();
        if file.is_empty() {
            continue;
        }

        // Check if this is a submodule by looking for .git inside
        let submod_path = repo.join(file);
        let is_submodule = submod_path.is_dir()
            && (submod_path.join(".git").exists() || submod_path.join(".git").is_file());

        if is_submodule {
            dirty_submodules.push(file.to_string());
        } else {
            changed_files.push(file.to_string());
        }
    }

    // Recurse into dirty submodules (depth-first) if within depth limit
    let has_dirty_children = !dirty_submodules.is_empty();
    if depth < max_depth {
        for submod in &dirty_submodules {
            let submod_path = repo.join(submod);
            if submod_path.exists() {
                collect_dirty_repos(
                    &submod_path,
                    depth + 1,
                    max_depth,
                    skip,
                    large_threshold,
                    force_large,
                    out,
                )?;
            }
        }
    }

    // Only add this node if it has changes (files or submodule pointers)
    let total_changes = lines.len();
    if total_changes == 0 {
        return Ok(());
    }

    // Run safety guards
    let mut warnings = Vec::new();
    let mut blocked = None;

    // Secret detection
    if let Some(warning) = guards::check_for_secrets(repo)? {
        warnings.push(warning);
    }

    // Large changeset guard
    if !force_large {
        if let Some(block_reason) = guards::check_large_changeset(repo, large_threshold)? {
            blocked = Some(block_reason);
        }
    }

    // Pre-commit hook warning
    if guards::check_precommit_hook(repo) {
        warnings.push(format!("{repo_name} has a pre-commit hook — commit may be blocked"));
    }

    out.push(FlushNode {
        path: repo.to_path_buf(),
        name: repo_name,
        depth,
        change_count: total_changes,
        changed_files,
        has_dirty_children,
        warnings,
        blocked,
    });

    Ok(())
}
