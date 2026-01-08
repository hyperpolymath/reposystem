// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//! Integration tests for the reposystem CLI commands

use std::process::Command;
use std::path::PathBuf;
use tempfile::TempDir;

/// Get the path to the reposystem binary
fn reposystem_binary() -> PathBuf {
    // For cargo test, the binary is in target/debug/
    let mut path = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    path.push("target");
    path.push("debug");
    path.push("reposystem");
    path
}

/// Run reposystem with the given arguments and data directory
fn run_reposystem(data_dir: &TempDir, args: &[&str]) -> std::process::Output {
    Command::new(reposystem_binary())
        .env("REPOSYSTEM_DATA_DIR", data_dir.path())
        .args(args)
        .output()
        .expect("Failed to execute reposystem")
}

/// Helper to get stdout as string
fn stdout_str(output: &std::process::Output) -> String {
    String::from_utf8_lossy(&output.stdout).to_string()
}

/// Helper to get stderr as string
fn stderr_str(output: &std::process::Output) -> String {
    String::from_utf8_lossy(&output.stderr).to_string()
}

#[test]
fn test_edge_lifecycle() {
    let data_dir = TempDir::new().unwrap();

    // Create a mock graph with two repos
    let graph_json = r#"{
        "repos": [
            {
                "kind": "Repo",
                "id": "repo:gh:test/alpha",
                "forge": "gh",
                "owner": "test",
                "name": "alpha",
                "default_branch": "main",
                "visibility": "public",
                "tags": [],
                "imports": {
                    "source": "test",
                    "path_hint": null,
                    "imported_at": "2025-01-01T00:00:00Z"
                },
                "local_path": null
            },
            {
                "kind": "Repo",
                "id": "repo:gh:test/beta",
                "forge": "gh",
                "owner": "test",
                "name": "beta",
                "default_branch": "main",
                "visibility": "public",
                "tags": [],
                "imports": {
                    "source": "test",
                    "path_hint": null,
                    "imported_at": "2025-01-01T00:00:00Z"
                },
                "local_path": null
            }
        ],
        "components": [],
        "groups": [],
        "edges": []
    }"#;

    std::fs::write(data_dir.path().join("graph.json"), graph_json).unwrap();

    // List edges (should be empty)
    let output = run_reposystem(&data_dir, &["edge", "list"]);
    if !output.status.success() {
        eprintln!("STDOUT: {}", stdout_str(&output));
        eprintln!("STDERR: {}", stderr_str(&output));
    }
    assert!(output.status.success(), "edge list failed: {}", stderr_str(&output));
    assert!(stdout_str(&output).contains("No edges defined"));

    // Add an edge
    let output = run_reposystem(&data_dir, &[
        "edge", "add",
        "--from", "alpha",
        "--to", "beta",
        "--rel", "uses",
        "--label", "test dependency"
    ]);
    assert!(output.status.success(), "Failed to add edge: {}", stderr_str(&output));
    assert!(stdout_str(&output).contains("Created edge"));

    // List edges (should have one)
    let output = run_reposystem(&data_dir, &["edge", "list"]);
    assert!(output.status.success());
    assert!(stdout_str(&output).contains("alpha"));
    assert!(stdout_str(&output).contains("beta"));

    // Remove the edge
    let output = run_reposystem(&data_dir, &[
        "edge", "remove",
        "--from", "alpha",
        "--to", "beta"
    ]);
    assert!(output.status.success());
    assert!(stdout_str(&output).contains("Removed"));

    // List edges (should be empty again)
    let output = run_reposystem(&data_dir, &["edge", "list"]);
    assert!(output.status.success());
    assert!(stdout_str(&output).contains("No edges defined"));
}

#[test]
fn test_group_lifecycle() {
    let data_dir = TempDir::new().unwrap();

    // Create a mock graph with repos
    let graph_json = r#"{
        "repos": [
            {
                "kind": "Repo",
                "id": "repo:gh:test/alpha",
                "forge": "gh",
                "owner": "test",
                "name": "alpha",
                "default_branch": "main",
                "visibility": "public",
                "tags": [],
                "imports": {
                    "source": "test",
                    "path_hint": null,
                    "imported_at": "2025-01-01T00:00:00Z"
                },
                "local_path": null
            },
            {
                "kind": "Repo",
                "id": "repo:gh:test/beta",
                "forge": "gh",
                "owner": "test",
                "name": "beta",
                "default_branch": "main",
                "visibility": "public",
                "tags": [],
                "imports": {
                    "source": "test",
                    "path_hint": null,
                    "imported_at": "2025-01-01T00:00:00Z"
                },
                "local_path": null
            }
        ],
        "components": [],
        "groups": [],
        "edges": []
    }"#;

    std::fs::write(data_dir.path().join("graph.json"), graph_json).unwrap();

    // List groups (should be empty)
    let output = run_reposystem(&data_dir, &["group", "list"]);
    assert!(output.status.success());
    assert!(stdout_str(&output).contains("No groups defined"));

    // Create a group with one member
    let output = run_reposystem(&data_dir, &["group", "create", "Test Group", "alpha"]);
    assert!(output.status.success(), "Failed to create group: {}", stderr_str(&output));
    assert!(stdout_str(&output).contains("Created group"));

    // Add another member
    let output = run_reposystem(&data_dir, &["group", "add", "Test Group", "beta"]);
    assert!(output.status.success());
    assert!(stdout_str(&output).contains("Added"));

    // Show the group
    let output = run_reposystem(&data_dir, &["group", "show", "Test Group"]);
    assert!(output.status.success());
    assert!(stdout_str(&output).contains("alpha"));
    assert!(stdout_str(&output).contains("beta"));

    // Remove a member
    let output = run_reposystem(&data_dir, &["group", "rm", "Test Group", "alpha"]);
    assert!(output.status.success());
    assert!(stdout_str(&output).contains("Removed"));

    // Delete the group
    let output = run_reposystem(&data_dir, &["group", "delete", "Test Group"]);
    assert!(output.status.success());
    assert!(stdout_str(&output).contains("Deleted"));

    // List groups (should be empty again)
    let output = run_reposystem(&data_dir, &["group", "list"]);
    assert!(output.status.success());
    assert!(stdout_str(&output).contains("No groups defined"));
}

#[test]
fn test_aspect_lifecycle() {
    let data_dir = TempDir::new().unwrap();

    // Create a mock graph with a repo
    let graph_json = r#"{
        "repos": [
            {
                "kind": "Repo",
                "id": "repo:gh:test/alpha",
                "forge": "gh",
                "owner": "test",
                "name": "alpha",
                "default_branch": "main",
                "visibility": "public",
                "tags": [],
                "imports": {
                    "source": "test",
                    "path_hint": null,
                    "imported_at": "2025-01-01T00:00:00Z"
                },
                "local_path": null
            }
        ],
        "components": [],
        "groups": [],
        "edges": []
    }"#;

    std::fs::write(data_dir.path().join("graph.json"), graph_json).unwrap();

    // List aspects
    let output = run_reposystem(&data_dir, &["aspect", "list"]);
    assert!(output.status.success());
    assert!(stdout_str(&output).contains("Security"));
    assert!(stdout_str(&output).contains("Reliability"));

    // Show annotations on a repo (should be none)
    let output = run_reposystem(&data_dir, &["aspect", "show", "--target", "alpha"]);
    assert!(output.status.success());
    assert!(stdout_str(&output).contains("No annotations"));

    // Tag the repo with a security annotation
    let output = run_reposystem(&data_dir, &[
        "aspect", "tag",
        "--target", "alpha",
        "--aspect", "security",
        "--weight", "2",
        "--polarity", "risk",
        "--reason", "Uses external APIs"
    ]);
    assert!(output.status.success(), "Failed to tag: {}", stderr_str(&output));
    assert!(stdout_str(&output).contains("Added security annotation"));

    // Show annotations on the repo
    let output = run_reposystem(&data_dir, &["aspect", "show", "--target", "alpha"]);
    assert!(output.status.success());
    assert!(stdout_str(&output).contains("Security"));
    assert!(stdout_str(&output).contains("Uses external APIs"));

    // Filter by aspect
    let output = run_reposystem(&data_dir, &["aspect", "filter", "--aspect", "security"]);
    assert!(output.status.success());
    assert!(stdout_str(&output).contains("alpha"));

    // Remove the annotation
    let output = run_reposystem(&data_dir, &[
        "aspect", "rm",
        "--target", "alpha",
        "--aspect", "security"
    ]);
    assert!(output.status.success());
    assert!(stdout_str(&output).contains("Removed"));

    // Show annotations (should be none again)
    let output = run_reposystem(&data_dir, &["aspect", "show", "--target", "alpha"]);
    assert!(output.status.success());
    assert!(stdout_str(&output).contains("No annotations"));
}

#[test]
fn test_export_formats() {
    let data_dir = TempDir::new().unwrap();

    // Create a mock graph
    let graph_json = r#"{
        "repos": [
            {
                "kind": "Repo",
                "id": "repo:gh:test/alpha",
                "forge": "gh",
                "owner": "test",
                "name": "alpha",
                "default_branch": "main",
                "visibility": "public",
                "tags": [],
                "imports": {
                    "source": "test",
                    "path_hint": null,
                    "imported_at": "2025-01-01T00:00:00Z"
                },
                "local_path": null
            }
        ],
        "components": [],
        "groups": [],
        "edges": []
    }"#;

    std::fs::write(data_dir.path().join("graph.json"), graph_json).unwrap();

    // Export to DOT
    let output = run_reposystem(&data_dir, &["export", "--format", "dot"]);
    assert!(output.status.success());
    let dot = stdout_str(&output);
    assert!(dot.contains("digraph ecosystem"));
    assert!(dot.contains("alpha"));

    // Export to JSON
    let output = run_reposystem(&data_dir, &["export", "--format", "json"]);
    assert!(output.status.success());
    let json = stdout_str(&output);
    assert!(json.contains("\"repos\""));
    assert!(json.contains("alpha"));
}
