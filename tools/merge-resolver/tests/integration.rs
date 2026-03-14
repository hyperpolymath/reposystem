// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//! Integration tests for merge-resolver — full session lifecycle.
//!
//! These tests create real temporary git repositories, produce genuine merge
//! conflicts, and exercise the begin/resolve/accept workflow end-to-end.

use merge_resolver::decision::{ConflictType, ResolutionStrategy};
use merge_resolver::{MergeResolver, SessionStatus};
use std::path::Path;
use std::process::Command;
use tempfile::TempDir;

/// Helper: run a git command in a directory, panicking on failure.
fn git(repo: &Path, args: &[&str]) -> String {
    let output = Command::new("git")
        .args(args)
        .current_dir(repo)
        .output()
        .unwrap_or_else(|e| panic!("Failed to run git {:?}: {}", args, e));

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        let stdout = String::from_utf8_lossy(&output.stdout);
        panic!(
            "git {:?} failed:\nstdout: {}\nstderr: {}",
            args, stdout, stderr
        );
    }

    String::from_utf8_lossy(&output.stdout).trim().to_string()
}

/// Helper: write a file relative to the repo root.
fn write_file(repo: &Path, name: &str, content: &str) {
    let path = repo.join(name);
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).unwrap();
    }
    std::fs::write(&path, content).unwrap();
}

/// Helper: create a temporary git repo with an initial commit containing a file.
/// Returns the TempDir (must be kept alive) and the repo path.
fn create_test_repo() -> TempDir {
    let tmpdir = TempDir::new().expect("Failed to create temp dir");
    let repo = tmpdir.path();

    git(repo, &["init", "--initial-branch=main"]);
    git(repo, &["config", "user.name", "Test User"]);
    git(repo, &["config", "user.email", "test@example.com"]);

    // Create an initial file and commit
    write_file(repo, "shared.txt", "line 1\nline 2\nline 3\n");
    git(repo, &["add", "shared.txt"]);
    git(repo, &["commit", "-m", "Initial commit"]);

    tmpdir
}

/// Helper: set up a repo with a conflict on `shared.txt` between `main` and `feature`.
///
/// After this function:
/// - HEAD is on `main` with "main change" content
/// - `feature` branch exists with "feature change" content
/// - Attempting `git merge feature` will produce a conflict on `shared.txt`
fn setup_conflict_repo() -> TempDir {
    let tmpdir = create_test_repo();
    let repo = tmpdir.path();

    // Create a feature branch and modify the file there
    git(repo, &["checkout", "-b", "feature"]);
    write_file(
        repo,
        "shared.txt",
        "line 1 - feature change\nline 2\nline 3\n",
    );
    git(repo, &["add", "shared.txt"]);
    git(repo, &["commit", "-m", "Feature branch change"]);

    // Switch back to main and make a conflicting change
    git(repo, &["checkout", "main"]);
    write_file(
        repo,
        "shared.txt",
        "line 1 - main change\nline 2\nline 3\n",
    );
    git(repo, &["add", "shared.txt"]);
    git(repo, &["commit", "-m", "Main branch change"]);

    tmpdir
}

#[test]
fn test_full_session_lifecycle_chose_ours() {
    let tmpdir = setup_conflict_repo();
    let repo = tmpdir.path();

    // 1. Begin merge session
    let resolver = MergeResolver::new(repo).expect("Failed to create resolver");
    let mut session = resolver.begin("feature").expect("Failed to begin session");

    assert_eq!(session.status, SessionStatus::InProgress);
    assert_eq!(session.conflict_count, 1);
    assert_eq!(session.resolved_count, 0);
    assert_eq!(session.target_branch, "main");
    assert_eq!(session.source_branch, "feature");
    assert!(!session.decisions.pending_conflicts.is_empty());

    // 2. Resolve the conflict with "ours" strategy
    let conflict_file = session.decisions.pending_conflicts[0].clone();
    resolver
        .resolve_conflict(
            &mut session,
            &conflict_file,
            ResolutionStrategy::ChoseOurs,
            "Main branch has the correct version",
            0.95,
        )
        .expect("Failed to resolve conflict");

    assert_eq!(session.resolved_count, 1);
    assert!(session.decisions.pending_conflicts.is_empty());
    assert_eq!(session.decisions.decisions.len(), 1);
    assert_eq!(
        session.decisions.decisions[0].strategy,
        ResolutionStrategy::ChoseOurs
    );

    // 3. Accept the merge
    resolver
        .accept(&mut session, Some("Test merge commit"))
        .expect("Failed to accept merge");

    assert_eq!(session.status, SessionStatus::Accepted);
    assert!(session.ended_at.is_some());

    // 4. Verify clean state — no merge in progress, no conflicts
    let status_output = Command::new("git")
        .args(["status", "--porcelain"])
        .current_dir(repo)
        .output()
        .expect("Failed to run git status");
    let status_text = String::from_utf8_lossy(&status_output.stdout);
    // Only .merge-resolver session files should appear (untracked), no conflicts
    assert!(
        !status_text.contains("UU"),
        "Expected no unmerged files, got: {}",
        status_text
    );

    // Verify the commit was created
    let log = git(repo, &["log", "--oneline", "-1"]);
    assert!(
        log.contains("Test merge commit"),
        "Expected merge commit message in log: {}",
        log
    );
}

#[test]
fn test_full_session_lifecycle_chose_theirs() {
    let tmpdir = setup_conflict_repo();
    let repo = tmpdir.path();

    let resolver = MergeResolver::new(repo).expect("Failed to create resolver");
    let mut session = resolver.begin("feature").expect("Failed to begin session");

    assert_eq!(session.conflict_count, 1);

    let conflict_file = session.decisions.pending_conflicts[0].clone();
    resolver
        .resolve_conflict(
            &mut session,
            &conflict_file,
            ResolutionStrategy::ChoseTheirs,
            "Feature branch has the better version",
            0.80,
        )
        .expect("Failed to resolve conflict");

    resolver
        .accept(&mut session, None)
        .expect("Failed to accept merge");

    assert_eq!(session.status, SessionStatus::Accepted);

    // Verify the file has the "theirs" content
    let content = std::fs::read_to_string(repo.join("shared.txt")).unwrap();
    assert!(
        content.contains("feature change"),
        "Expected feature branch content after choosing theirs, got: {}",
        content
    );
}

#[test]
fn test_session_rollback() {
    let tmpdir = setup_conflict_repo();
    let repo = tmpdir.path();

    // Record pre-merge HEAD for comparison
    let pre_merge_head = git(repo, &["rev-parse", "HEAD"]);

    let resolver = MergeResolver::new(repo).expect("Failed to create resolver");
    let mut session = resolver.begin("feature").expect("Failed to begin session");

    assert_eq!(session.conflict_count, 1);

    // Roll back instead of resolving
    resolver
        .rollback(&mut session)
        .expect("Failed to rollback");

    assert_eq!(session.status, SessionStatus::RolledBack);
    assert!(session.ended_at.is_some());

    // Verify HEAD is back to pre-merge state
    let post_rollback_head = git(repo, &["rev-parse", "HEAD"]);
    assert_eq!(
        pre_merge_head, post_rollback_head,
        "HEAD should be restored after rollback"
    );

    // Verify file content is the main branch version (no conflict markers)
    let content = std::fs::read_to_string(repo.join("shared.txt")).unwrap();
    assert!(
        content.contains("main change"),
        "Expected main branch content after rollback, got: {}",
        content
    );
    assert!(
        !content.contains("<<<<<<<"),
        "Should have no conflict markers after rollback"
    );
}

#[test]
fn test_conflict_type_detection_both_modified() {
    let tmpdir = setup_conflict_repo();
    let repo = tmpdir.path();

    let resolver = MergeResolver::new(repo).expect("Failed to create resolver");
    let mut session = resolver.begin("feature").expect("Failed to begin session");

    assert_eq!(session.conflict_count, 1);

    // Resolve and check the detected conflict type
    let conflict_file = session.decisions.pending_conflicts[0].clone();
    resolver
        .resolve_conflict(
            &mut session,
            &conflict_file,
            ResolutionStrategy::ChoseOurs,
            "Testing conflict type detection",
            0.90,
        )
        .expect("Failed to resolve conflict");

    // The conflict was UU (both modified), so the detected type should be BothModified
    assert_eq!(
        session.decisions.decisions[0].conflict_type,
        ConflictType::BothModified,
        "Expected BothModified for UU conflict"
    );
}

#[test]
fn test_accept_fails_with_unresolved_conflicts() {
    let tmpdir = setup_conflict_repo();
    let repo = tmpdir.path();

    let resolver = MergeResolver::new(repo).expect("Failed to create resolver");
    let mut session = resolver.begin("feature").expect("Failed to begin session");

    assert_eq!(session.conflict_count, 1);

    // Try to accept without resolving — should fail
    let result = resolver.accept(&mut session, None);
    assert!(
        result.is_err(),
        "Accept should fail when conflicts remain unresolved"
    );

    let err_msg = result.unwrap_err().to_string();
    assert!(
        err_msg.contains("unresolved"),
        "Error should mention unresolved conflicts: {}",
        err_msg
    );
}

#[test]
fn test_no_conflict_merge() {
    let tmpdir = create_test_repo();
    let repo = tmpdir.path();

    // Create a feature branch that modifies a DIFFERENT file (no conflict)
    git(repo, &["checkout", "-b", "feature"]);
    write_file(repo, "feature_only.txt", "feature content\n");
    git(repo, &["add", "feature_only.txt"]);
    git(repo, &["commit", "-m", "Add feature-only file"]);

    git(repo, &["checkout", "main"]);

    let resolver = MergeResolver::new(repo).expect("Failed to create resolver");
    let mut session = resolver.begin("feature").expect("Failed to begin session");

    assert_eq!(session.conflict_count, 0);
    assert!(session.decisions.pending_conflicts.is_empty());

    // Accept immediately (no conflicts to resolve)
    resolver
        .accept(&mut session, Some("Clean merge"))
        .expect("Failed to accept clean merge");

    assert_eq!(session.status, SessionStatus::Accepted);

    // Verify the merged file exists
    assert!(
        repo.join("feature_only.txt").exists(),
        "Merged file should exist after clean merge"
    );
}

#[test]
fn test_session_persistence_and_reload() {
    let tmpdir = setup_conflict_repo();
    let repo = tmpdir.path();

    let resolver = MergeResolver::new(repo).expect("Failed to create resolver");
    let session = resolver.begin("feature").expect("Failed to begin session");

    let session_id = session.session_id;

    // Reload the session from disk
    let loaded = resolver
        .load_session(&session_id)
        .expect("Failed to load session");

    assert_eq!(loaded.session_id, session_id);
    assert_eq!(loaded.status, SessionStatus::InProgress);
    assert_eq!(loaded.conflict_count, session.conflict_count);
    assert_eq!(loaded.source_branch, "feature");
    assert_eq!(loaded.target_branch, "main");
}

#[test]
fn test_list_sessions() {
    let tmpdir = setup_conflict_repo();
    let repo = tmpdir.path();

    let resolver = MergeResolver::new(repo).expect("Failed to create resolver");

    // No sessions initially
    let sessions = resolver.list_sessions().expect("Failed to list sessions");
    assert!(sessions.is_empty());

    // Begin a session
    let _session = resolver.begin("feature").expect("Failed to begin session");

    // Now there should be one session
    let sessions = resolver.list_sessions().expect("Failed to list sessions");
    assert_eq!(sessions.len(), 1);
    assert_eq!(sessions[0].status, SessionStatus::InProgress);
}
