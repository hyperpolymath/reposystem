// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//! merge-resolver — Safe, reversible merge conflict resolution
//!
//! Provides a three-phase workflow:
//! 1. `begin` — snapshot current state, attempt merge, log conflicts
//! 2. `rollback` — revert to pre-merge snapshot (decision log preserved)
//! 3. `accept` — finalize merge, clean up snapshots
//!
//! Every conflict resolution decision is logged as structured JSON,
//! stored as a VeriSimDB hexad, and visualizable in PanLL.

pub mod decision;
pub mod snapshot;
pub mod verify;

use anyhow::{bail, Context, Result};
use chrono::Utc;
use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};
use std::process::Command;
use uuid::Uuid;

use decision::{ConflictDecision, ConflictType, DecisionLog, ResolutionStrategy};
use snapshot::{GitSnapshot, SnapshotManager};

/// Session state for a merge resolution
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum SessionStatus {
    /// Merge in progress, conflicts being resolved
    InProgress,
    /// Merge accepted and finalized
    Accepted,
    /// Merge rolled back to pre-merge state
    RolledBack,
}

/// A complete merge resolution session
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MergeSession {
    /// Unique session identifier
    pub session_id: Uuid,
    /// Repository path
    pub repo_path: PathBuf,
    /// Branch being merged into current HEAD
    pub source_branch: String,
    /// Target branch (the one we're on)
    pub target_branch: String,
    /// Pre-merge snapshot (for rollback)
    pub snapshot: GitSnapshot,
    /// Current session status
    pub status: SessionStatus,
    /// All conflict resolution decisions
    pub decisions: DecisionLog,
    /// Session start time
    pub started_at: String,
    /// Session end time (if completed)
    pub ended_at: Option<String>,
    /// Total files with conflicts
    pub conflict_count: usize,
    /// Files successfully resolved
    pub resolved_count: usize,
}

/// Core merge resolver
pub struct MergeResolver {
    /// Repository path
    repo_path: PathBuf,
    /// Snapshot manager for rollback
    snapshot_mgr: SnapshotManager,
}

impl MergeResolver {
    /// Create a new merge resolver for a repository
    pub fn new(repo_path: &Path) -> Result<Self> {
        if !repo_path.join(".git").exists() {
            bail!("Not a git repository: {}", repo_path.display());
        }

        Ok(Self {
            repo_path: repo_path.to_path_buf(),
            snapshot_mgr: SnapshotManager::new(repo_path),
        })
    }

    /// Begin a merge resolution session.
    ///
    /// 1. Creates a pre-merge snapshot (saves HEAD ref + stashes uncommitted changes)
    /// 2. Attempts the merge
    /// 3. Detects conflicts
    /// 4. Returns a session with conflict information
    pub fn begin(&self, source_branch: &str) -> Result<MergeSession> {
        let session_id = Uuid::new_v4();

        // Get current branch name
        let target_branch = self.current_branch()?;

        // Create pre-merge snapshot
        let snapshot = self.snapshot_mgr.create_snapshot(&session_id)?;
        tracing::info!(
            "Created pre-merge snapshot: HEAD={}, stash={}",
            snapshot.head_ref,
            snapshot.has_stash
        );

        // Attempt merge (allow failure — we want to capture conflicts)
        let merge_output = Command::new("git")
            .args(["merge", source_branch, "--no-commit", "--no-ff"])
            .current_dir(&self.repo_path)
            .output()
            .context("Failed to run git merge")?;

        let merge_stderr = String::from_utf8_lossy(&merge_output.stderr);
        let merge_stdout = String::from_utf8_lossy(&merge_output.stdout);

        // Detect conflicts
        let conflicts = self.detect_conflicts()?;
        let conflict_count = conflicts.len();

        if conflict_count == 0 && merge_output.status.success() {
            tracing::info!("Merge succeeded with no conflicts");
        } else if conflict_count > 0 {
            tracing::info!(
                "Merge has {} conflict(s): {}",
                conflict_count,
                merge_stderr.trim()
            );
        } else {
            tracing::warn!(
                "Merge failed without conflicts: stdout={}, stderr={}",
                merge_stdout.trim(),
                merge_stderr.trim()
            );
        }

        // Initialize decision log
        let mut decisions = DecisionLog::new(session_id);
        for conflict_file in &conflicts {
            decisions.add_pending_conflict(conflict_file.clone());
        }

        let session = MergeSession {
            session_id,
            repo_path: self.repo_path.clone(),
            source_branch: source_branch.to_string(),
            target_branch,
            snapshot,
            status: SessionStatus::InProgress,
            decisions,
            started_at: Utc::now().to_rfc3339(),
            ended_at: None,
            conflict_count,
            resolved_count: 0,
        };

        // Save session to disk
        self.save_session(&session)?;

        Ok(session)
    }

    /// Resolve a single conflict file.
    ///
    /// Records the decision and marks the file as resolved in git.
    pub fn resolve_conflict(
        &self,
        session: &mut MergeSession,
        file: &Path,
        strategy: ResolutionStrategy,
        reasoning: &str,
        confidence: f64,
    ) -> Result<()> {
        if session.status != SessionStatus::InProgress {
            bail!("Session is not in progress (status: {:?})", session.status);
        }

        // Apply the resolution based on strategy
        match strategy {
            ResolutionStrategy::ChoseOurs => {
                Command::new("git")
                    .args(["checkout", "--ours", &file.display().to_string()])
                    .current_dir(&self.repo_path)
                    .output()
                    .context("Failed to checkout --ours")?;
            }
            ResolutionStrategy::ChoseTheirs => {
                Command::new("git")
                    .args(["checkout", "--theirs", &file.display().to_string()])
                    .current_dir(&self.repo_path)
                    .output()
                    .context("Failed to checkout --theirs")?;
            }
            ResolutionStrategy::ManualMerge | ResolutionStrategy::AiMerge => {
                // For manual/AI merge, the file content should already be modified
                // by the caller. We just need to stage it.
            }
        }

        // Stage the resolved file
        Command::new("git")
            .args(["add", &file.display().to_string()])
            .current_dir(&self.repo_path)
            .output()
            .context("Failed to git add resolved file")?;

        // Detect conflict type from git status
        let conflict_type = self.detect_conflict_type(file)?;

        // Record the decision
        let decision = ConflictDecision {
            decision_id: Uuid::new_v4(),
            file: file.to_path_buf(),
            conflict_type,
            strategy,
            reasoning: reasoning.to_string(),
            confidence,
            timestamp: Utc::now().to_rfc3339(),
            reversible: true,
        };

        session.decisions.record_decision(decision);
        session.resolved_count += 1;

        // Save updated session
        self.save_session(session)?;

        Ok(())
    }

    /// Roll back the merge to the pre-merge state.
    ///
    /// Restores HEAD to the saved ref and pops any stash.
    /// The decision log is preserved for analysis.
    pub fn rollback(&self, session: &mut MergeSession) -> Result<()> {
        if session.status != SessionStatus::InProgress {
            bail!("Cannot rollback: session is {:?}", session.status);
        }

        // Abort the merge
        let _ = Command::new("git")
            .args(["merge", "--abort"])
            .current_dir(&self.repo_path)
            .output();

        // Restore snapshot
        self.snapshot_mgr.restore_snapshot(&session.snapshot)?;

        session.status = SessionStatus::RolledBack;
        session.ended_at = Some(Utc::now().to_rfc3339());

        // Save final session state
        self.save_session(session)?;

        tracing::info!(
            "Rolled back merge session {} (decision log preserved)",
            session.session_id
        );

        Ok(())
    }

    /// Accept the merge and finalize.
    ///
    /// Creates a merge commit and cleans up snapshots.
    pub fn accept(&self, session: &mut MergeSession, commit_message: Option<&str>) -> Result<()> {
        if session.status != SessionStatus::InProgress {
            bail!("Cannot accept: session is {:?}", session.status);
        }

        // Check for unresolved conflicts
        let remaining = self.detect_conflicts()?;
        if !remaining.is_empty() {
            bail!(
                "Cannot accept: {} unresolved conflict(s) remain: {:?}",
                remaining.len(),
                remaining
            );
        }

        // Create merge commit
        let default_msg = format!(
            "Merge '{}' into '{}' (merge-resolver session {})",
            session.source_branch, session.target_branch, session.session_id
        );
        let msg = commit_message.unwrap_or(&default_msg);

        let commit_output = Command::new("git")
            .args(["commit", "-m", msg])
            .current_dir(&self.repo_path)
            .output()
            .context("Failed to create merge commit")?;

        if !commit_output.status.success() {
            let stderr = String::from_utf8_lossy(&commit_output.stderr);
            bail!("Merge commit failed: {}", stderr.trim());
        }

        // Clean up snapshot
        self.snapshot_mgr.cleanup_snapshot(&session.snapshot)?;

        session.status = SessionStatus::Accepted;
        session.ended_at = Some(Utc::now().to_rfc3339());

        // Save final session state
        self.save_session(session)?;

        tracing::info!(
            "Accepted merge session {} ({} decisions)",
            session.session_id,
            session.decisions.decisions.len()
        );

        Ok(())
    }

    /// List files with merge conflicts
    fn detect_conflicts(&self) -> Result<Vec<PathBuf>> {
        let output = Command::new("git")
            .args(["diff", "--name-only", "--diff-filter=U"])
            .current_dir(&self.repo_path)
            .output()
            .context("Failed to detect merge conflicts")?;

        let stdout = String::from_utf8_lossy(&output.stdout);
        let conflicts: Vec<PathBuf> = stdout
            .lines()
            .filter(|l| !l.is_empty())
            .map(PathBuf::from)
            .collect();

        Ok(conflicts)
    }

    /// Detect the type of conflict for a file by parsing `git status --porcelain`.
    ///
    /// Maps git porcelain two-character conflict codes to `ConflictType`:
    /// - `UU` -> BothModified (both branches modified the same file)
    /// - `DU` -> DeleteModify (deleted by us, modified by them)
    /// - `UD` -> DeleteModify (modified by us, deleted by them)
    /// - `AA` -> AddAdd (file added in both branches with different content)
    /// - `AU` / `UA` -> BothModified (added/unmerged combinations)
    ///
    /// Falls back to `BothModified` if the porcelain output cannot be parsed.
    fn detect_conflict_type(&self, file: &Path) -> Result<ConflictType> {
        let output = Command::new("git")
            .args([
                "-C",
                &self.repo_path.display().to_string(),
                "status",
                "--porcelain",
                &file.display().to_string(),
            ])
            .output()
            .context("Failed to run git status --porcelain")?;

        let stdout = String::from_utf8_lossy(&output.stdout);
        let line = stdout.lines().next().unwrap_or("");

        // Porcelain format: XY <path>
        // For unmerged entries the two-character code indicates the conflict type.
        // We need at least 2 characters to read X and Y.
        if line.len() < 2 {
            return Ok(ConflictType::BothModified);
        }

        let xy = &line[..2];
        match xy {
            "UU" => Ok(ConflictType::BothModified),
            "DU" => Ok(ConflictType::DeleteModify),
            "UD" => Ok(ConflictType::DeleteModify),
            "AA" => Ok(ConflictType::AddAdd),
            "AU" | "UA" => Ok(ConflictType::BothModified),
            _ => Ok(ConflictType::BothModified),
        }
    }

    /// Get the current branch name
    fn current_branch(&self) -> Result<String> {
        let output = Command::new("git")
            .args(["rev-parse", "--abbrev-ref", "HEAD"])
            .current_dir(&self.repo_path)
            .output()
            .context("Failed to get current branch")?;

        Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
    }

    /// Save session state to disk
    fn save_session(&self, session: &MergeSession) -> Result<()> {
        let session_dir = self.repo_path.join(".merge-resolver");
        std::fs::create_dir_all(&session_dir)?;

        let session_file = session_dir.join(format!("{}.json", session.session_id));
        let json = serde_json::to_string_pretty(session)?;
        std::fs::write(&session_file, json)?;

        // Also write the decision log separately for easy consumption
        let decisions_file = session_dir.join(format!("{}-decisions.json", session.session_id));
        let decisions_json = serde_json::to_string_pretty(&session.decisions)?;
        std::fs::write(&decisions_file, decisions_json)?;

        Ok(())
    }

    /// Load a previous session from disk
    pub fn load_session(&self, session_id: &Uuid) -> Result<MergeSession> {
        let session_file = self
            .repo_path
            .join(".merge-resolver")
            .join(format!("{}.json", session_id));

        let content = std::fs::read_to_string(&session_file)
            .with_context(|| format!("Session {} not found", session_id))?;

        serde_json::from_str(&content).context("Failed to parse session file")
    }

    /// List all sessions for this repository
    pub fn list_sessions(&self) -> Result<Vec<MergeSession>> {
        let session_dir = self.repo_path.join(".merge-resolver");
        if !session_dir.exists() {
            return Ok(Vec::new());
        }

        let mut sessions = Vec::new();
        for entry in std::fs::read_dir(&session_dir)? {
            let entry = entry?;
            let path = entry.path();
            if path.extension().and_then(|e| e.to_str()) == Some("json")
                && !path
                    .file_name()
                    .and_then(|n| n.to_str())
                    .unwrap_or("")
                    .contains("-decisions")
            {
                if let Ok(content) = std::fs::read_to_string(&path) {
                    if let Ok(session) = serde_json::from_str::<MergeSession>(&content) {
                        sessions.push(session);
                    }
                }
            }
        }

        sessions.sort_by(|a, b| a.started_at.cmp(&b.started_at));
        Ok(sessions)
    }
}
