// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//! Git snapshot management for rollback
//!
//! Provides high-granularity rollback via git reflog + snapshot-based
//! state preservation. Each merge step is individually revertible.
//!
//! Snapshot lifecycle:
//! 1. Save HEAD ref + stash uncommitted work
//! 2. Merge proceeds (may fail with conflicts)
//! 3. On rollback: reset to saved ref + pop stash
//! 4. On accept: clean up saved ref marker

use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};
use std::process::Command;
use uuid::Uuid;

/// A saved git state snapshot for rollback
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GitSnapshot {
    /// Session ID this snapshot belongs to
    pub session_id: Uuid,
    /// The HEAD commit ref at snapshot time
    pub head_ref: String,
    /// The branch name at snapshot time
    pub branch_name: String,
    /// Whether uncommitted changes were stashed
    pub has_stash: bool,
    /// The stash ref (if stashed)
    pub stash_ref: Option<String>,
    /// Snapshot creation timestamp
    pub created_at: String,
}

/// Manages git snapshots for a repository
pub struct SnapshotManager {
    repo_path: PathBuf,
}

impl SnapshotManager {
    /// Create a new snapshot manager
    pub fn new(repo_path: &Path) -> Self {
        Self {
            repo_path: repo_path.to_path_buf(),
        }
    }

    /// Create a pre-merge snapshot.
    ///
    /// Saves the current HEAD ref and optionally stashes uncommitted changes.
    pub fn create_snapshot(&self, session_id: &Uuid) -> Result<GitSnapshot> {
        // Get current HEAD
        let head_ref = self.get_head_ref()?;
        let branch_name = self.get_branch_name()?;

        // Check for uncommitted changes
        let has_changes = self.has_uncommitted_changes()?;
        let mut has_stash = false;
        let mut stash_ref = None;

        if has_changes {
            // Stash with a recognizable message
            let stash_msg = format!("merge-resolver-{}", session_id);
            let output = Command::new("git")
                .args(["stash", "push", "-m", &stash_msg])
                .current_dir(&self.repo_path)
                .output()
                .context("Failed to git stash")?;

            if output.status.success() {
                has_stash = true;
                // Get the stash ref
                let stash_output = Command::new("git")
                    .args(["stash", "list", "--format=%H", "-1"])
                    .current_dir(&self.repo_path)
                    .output()
                    .context("Failed to get stash ref")?;
                stash_ref =
                    Some(String::from_utf8_lossy(&stash_output.stdout).trim().to_string());
            }
        }

        // Create a ref marker for the pre-merge state
        let ref_name = format!("refs/merge-resolver/{}", session_id);
        Command::new("git")
            .args(["update-ref", &ref_name, &head_ref])
            .current_dir(&self.repo_path)
            .output()
            .context("Failed to create snapshot ref")?;

        Ok(GitSnapshot {
            session_id: *session_id,
            head_ref,
            branch_name,
            has_stash,
            stash_ref,
            created_at: chrono::Utc::now().to_rfc3339(),
        })
    }

    /// Restore a snapshot (rollback).
    ///
    /// Resets HEAD to the saved ref and pops stash if applicable.
    pub fn restore_snapshot(&self, snapshot: &GitSnapshot) -> Result<()> {
        // Hard reset to the saved HEAD
        let output = Command::new("git")
            .args(["reset", "--hard", &snapshot.head_ref])
            .current_dir(&self.repo_path)
            .output()
            .context("Failed to git reset to snapshot")?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            anyhow::bail!("Failed to reset to snapshot: {}", stderr.trim());
        }

        // Pop stash if we stashed changes
        if snapshot.has_stash {
            let pop_output = Command::new("git")
                .args(["stash", "pop"])
                .current_dir(&self.repo_path)
                .output()
                .context("Failed to pop stash")?;

            if !pop_output.status.success() {
                tracing::warn!(
                    "Stash pop failed (may have been already popped): {}",
                    String::from_utf8_lossy(&pop_output.stderr).trim()
                );
            }
        }

        Ok(())
    }

    /// Clean up a snapshot ref after successful merge.
    pub fn cleanup_snapshot(&self, snapshot: &GitSnapshot) -> Result<()> {
        let ref_name = format!("refs/merge-resolver/{}", snapshot.session_id);
        let _ = Command::new("git")
            .args(["update-ref", "-d", &ref_name])
            .current_dir(&self.repo_path)
            .output();
        Ok(())
    }

    /// Get the current HEAD commit hash
    fn get_head_ref(&self) -> Result<String> {
        let output = Command::new("git")
            .args(["rev-parse", "HEAD"])
            .current_dir(&self.repo_path)
            .output()
            .context("Failed to get HEAD ref")?;

        Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
    }

    /// Get the current branch name
    fn get_branch_name(&self) -> Result<String> {
        let output = Command::new("git")
            .args(["rev-parse", "--abbrev-ref", "HEAD"])
            .current_dir(&self.repo_path)
            .output()
            .context("Failed to get branch name")?;

        Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
    }

    /// Check if there are uncommitted changes
    fn has_uncommitted_changes(&self) -> Result<bool> {
        let output = Command::new("git")
            .args(["status", "--porcelain"])
            .current_dir(&self.repo_path)
            .output()
            .context("Failed to check git status")?;

        Ok(!String::from_utf8_lossy(&output.stdout).trim().is_empty())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_git_snapshot_serialization() {
        let snapshot = GitSnapshot {
            session_id: Uuid::new_v4(),
            head_ref: "abc123def456".to_string(),
            branch_name: "main".to_string(),
            has_stash: true,
            stash_ref: Some("stash@{0}".to_string()),
            created_at: "2026-03-01T10:00:00Z".to_string(),
        };

        let json = serde_json::to_string(&snapshot).unwrap();
        let deserialized: GitSnapshot = serde_json::from_str(&json).unwrap();
        assert_eq!(deserialized.head_ref, "abc123def456");
        assert_eq!(deserialized.branch_name, "main");
        assert!(deserialized.has_stash);
    }
}
