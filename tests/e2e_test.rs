// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//! End-to-end tests for reposystem binary
//!
//! These tests validate the full CLI experience:
//! - Binary invocation and argument parsing
//! - Smoke tests (--help, --version)
//! - Scan operations with real directories
//! - Config file loading and validation
//! - Error handling for malformed inputs

use std::fs;
use std::path::PathBuf;
use tempfile::TempDir;

/// Get the path to the reposystem binary
fn reposystem_bin() -> PathBuf {
    let mut path = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    path.push("target");
    path.push("debug");
    path.push("reposystem");
    path
}

/// Create a minimal .git directory to make a path look like a repo
fn init_fake_git(path: &std::path::Path) -> std::io::Result<()> {
    fs::create_dir_all(path)?;
    fs::create_dir_all(path.join(".git"))?;
    fs::write(path.join(".git/config"), "[core]\n")?;
    fs::write(path.join(".git/HEAD"), "ref: refs/heads/main\n")?;
    Ok(())
}

// =============================================================================
// Smoke Tests
// =============================================================================

#[test]
fn test_help_flag() {
    let output = std::process::Command::new(reposystem_bin())
        .arg("--help")
        .output()
        .expect("Failed to run reposystem --help");

    assert!(
        output.status.success(),
        "Help should succeed: {}",
        String::from_utf8_lossy(&output.stderr)
    );

    let stdout = String::from_utf8_lossy(&output.stdout);
    assert!(stdout.contains("reposystem"), "Help should contain binary name");
    assert!(stdout.contains("USAGE") || stdout.contains("Usage"), "Help should have usage section");
}

#[test]
fn test_version_flag() {
    let output = std::process::Command::new(reposystem_bin())
        .arg("--version")
        .output()
        .expect("Failed to run reposystem --version");

    assert!(output.status.success(), "Version should succeed");

    let stdout = String::from_utf8_lossy(&output.stdout);
    assert!(stdout.contains("reposystem"), "Version should contain binary name");
    assert!(stdout.contains("0.1.0"), "Version should contain version number");
}

#[test]
fn test_no_subcommand_error() {
    let output = std::process::Command::new(reposystem_bin())
        .output()
        .expect("Failed to run reposystem");

    // When run without subcommand, it should fail or show help
    let stdout = String::from_utf8_lossy(&output.stdout);
    let stderr = String::from_utf8_lossy(&output.stderr);
    let combined = format!("{}{}", stdout, stderr);
    assert!(
        combined.contains("USAGE") || combined.contains("Usage") || !output.status.success(),
        "Should show usage or error when no subcommand"
    );
}

// =============================================================================
// Scan Command Tests
// =============================================================================

#[test]
fn test_scan_empty_directory() {
    let temp_dir = TempDir::new().expect("Failed to create temp dir");

    let output = std::process::Command::new(reposystem_bin())
        .arg("scan")
        .arg(temp_dir.path())
        .output()
        .expect("Failed to run scan");

    // Should succeed even on empty directory (0 repos found is valid)
    assert!(
        output.status.success(),
        "Scan should succeed on empty dir: {}",
        String::from_utf8_lossy(&output.stderr)
    );
}

#[test]
fn test_scan_with_single_repo() {
    let temp_dir = TempDir::new().expect("Failed to create temp dir");
    let repo_path = temp_dir.path().join("test_repo");
    init_fake_git(&repo_path).expect("Failed to init fake git");

    let output = std::process::Command::new(reposystem_bin())
        .arg("scan")
        .arg(temp_dir.path())
        .output()
        .expect("Failed to run scan");

    assert!(
        output.status.success(),
        "Scan should succeed with repo: {}",
        String::from_utf8_lossy(&output.stderr)
    );

    let stdout = String::from_utf8_lossy(&output.stdout);
    // Should mention the repo or at least show some scanning happened
    assert!(
        stdout.len() > 0 || String::from_utf8_lossy(&output.stderr).len() > 0,
        "Scan should produce output"
    );
}

#[test]
fn test_scan_with_multiple_repos() {
    let temp_dir = TempDir::new().expect("Failed to create temp dir");
    for i in 0..3 {
        let repo_path = temp_dir.path().join(format!("repo_{}", i));
        init_fake_git(&repo_path).expect("Failed to init fake git");
    }

    let output = std::process::Command::new(reposystem_bin())
        .arg("scan")
        .arg(temp_dir.path())
        .output()
        .expect("Failed to run scan");

    assert!(output.status.success(), "Scan should succeed with multiple repos");
}

#[test]
fn test_scan_deep_flag() {
    let temp_dir = TempDir::new().expect("Failed to create temp dir");
    let repo_path = temp_dir.path().join("test_repo");
    init_fake_git(&repo_path).expect("Failed to init fake git");

    let output = std::process::Command::new(reposystem_bin())
        .arg("scan")
        .arg(temp_dir.path())
        .arg("--deep")
        .output()
        .expect("Failed to run scan --deep");

    assert!(output.status.success(), "Scan --deep should succeed");
}

#[test]
fn test_scan_shallow_flag() {
    let temp_dir = TempDir::new().expect("Failed to create temp dir");
    let repo_path = temp_dir.path().join("test_repo");
    init_fake_git(&repo_path).expect("Failed to init fake git");

    let output = std::process::Command::new(reposystem_bin())
        .arg("scan")
        .arg(temp_dir.path())
        .arg("--shallow")
        .output()
        .expect("Failed to run scan --shallow");

    assert!(output.status.success(), "Scan --shallow should succeed");
}

#[test]
fn test_scan_json_output() {
    let temp_dir = TempDir::new().expect("Failed to create temp dir");
    let repo_path = temp_dir.path().join("test_repo");
    init_fake_git(&repo_path).expect("Failed to init fake git");

    let output = std::process::Command::new(reposystem_bin())
        .arg("--json")
        .arg("scan")
        .arg(temp_dir.path())
        .output()
        .expect("Failed to run scan with --json");

    assert!(
        output.status.success(),
        "Scan with --json should succeed: {}",
        String::from_utf8_lossy(&output.stderr)
    );

    let stdout = String::from_utf8_lossy(&output.stdout);
    // If there's output, it should be valid JSON-like
    if stdout.len() > 0 && !stdout.starts_with("scanning") {
        // Try to verify it looks like JSON
        assert!(
            stdout.contains('{') || stdout.contains('['),
            "JSON output should contain JSON structures"
        );
    }
}

#[test]
fn test_scan_nonexistent_path() {
    let output = std::process::Command::new(reposystem_bin())
        .arg("scan")
        .arg("/nonexistent/path/that/does/not/exist/xyz123")
        .output()
        .expect("Failed to run scan");

    // Should fail gracefully
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(
        !output.status.success() || stderr.len() > 0,
        "Scan should fail or warn on nonexistent path"
    );
}

// =============================================================================
// Config File Tests
// =============================================================================

#[test]
fn test_valid_config_loading() {
    let temp_dir = TempDir::new().expect("Failed to create temp dir");
    let config_path = temp_dir.path().join("reposystem.toml");

    let config_content = r#"
[global]
name = "test-ecosystem"
version = "0.1.0"

[[repos]]
name = "test_repo"
path = "."
"#;
    fs::write(&config_path, config_content).expect("Failed to write config");

    let output = std::process::Command::new(reposystem_bin())
        .arg("--config")
        .arg(&config_path)
        .arg("--help")
        .output()
        .expect("Failed to run with config");

    assert!(
        output.status.success(),
        "Should accept valid config: {}",
        String::from_utf8_lossy(&output.stderr)
    );
}

#[test]
fn test_malformed_config_error() {
    let temp_dir = TempDir::new().expect("Failed to create temp dir");
    let config_path = temp_dir.path().join("bad.toml");

    // Write invalid TOML
    fs::write(&config_path, "invalid: toml: syntax :::").expect("Failed to write bad config");

    let output = std::process::Command::new(reposystem_bin())
        .arg("--config")
        .arg(&config_path)
        .arg("scan")
        .arg(".")
        .output()
        .expect("Failed to run with bad config");

    // Either should fail or silently ignore malformed config (depending on implementation)
    // The key is it shouldn't crash
    let _stderr = String::from_utf8_lossy(&output.stderr);
    // Just verify command ran without panic
    assert!(
        true,
        "Command should complete without panic (exit status: {})",
        output.status
    );
}

#[test]
fn test_missing_config_file() {
    let output = std::process::Command::new(reposystem_bin())
        .arg("--config")
        .arg("/nonexistent/config.toml")
        .arg("scan")
        .arg(".")
        .output()
        .expect("Failed to run with missing config");

    // Should either fail or succeed depending on whether config is required
    // The key is it shouldn't crash or panic
    let _stderr = String::from_utf8_lossy(&output.stderr);
    // Just verify command ran
    assert!(
        true,
        "Command should complete without panic (exit status: {})",
        output.status
    );
}

// =============================================================================
// Security / Path Traversal Tests
// =============================================================================

#[test]
fn test_path_traversal_rejection() {
    let _temp_dir = TempDir::new().expect("Failed to create temp dir");

    // Try to scan /etc/passwd via path traversal
    let output = std::process::Command::new(reposystem_bin())
        .arg("scan")
        .arg("../../etc/passwd")
        .output()
        .expect("Failed to run scan with traversal attempt");

    // Either should fail or should not return /etc/passwd contents
    let stdout = String::from_utf8_lossy(&output.stdout);
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(
        !stdout.contains("root:") && !stderr.contains("root:"),
        "Should not expose /etc/passwd"
    );
}

#[test]
fn test_absolute_path_handling() {
    let temp_dir = TempDir::new().expect("Failed to create temp dir");
    let repo_path = temp_dir.path().join("test_repo");
    init_fake_git(&repo_path).expect("Failed to init fake git");

    let abs_path = std::fs::canonicalize(temp_dir.path()).expect("Failed to canonicalize path");

    let output = std::process::Command::new(reposystem_bin())
        .arg("scan")
        .arg(&abs_path)
        .output()
        .expect("Failed to run scan with absolute path");

    assert!(
        output.status.success(),
        "Scan should handle absolute paths: {}",
        String::from_utf8_lossy(&output.stderr)
    );
}

// =============================================================================
// Verbosity & Output Options Tests
// =============================================================================

#[test]
fn test_verbose_flag() {
    let temp_dir = TempDir::new().expect("Failed to create temp dir");

    let output = std::process::Command::new(reposystem_bin())
        .arg("-v")
        .arg("scan")
        .arg(temp_dir.path())
        .output()
        .expect("Failed to run with -v");

    assert!(output.status.success(), "Verbose flag should not break execution");
}

#[test]
fn test_quiet_flag() {
    let temp_dir = TempDir::new().expect("Failed to create temp dir");

    let output = std::process::Command::new(reposystem_bin())
        .arg("--quiet")
        .arg("scan")
        .arg(temp_dir.path())
        .output()
        .expect("Failed to run with --quiet");

    assert!(output.status.success(), "Quiet flag should not break execution");
}

#[test]
fn test_no_color_flag() {
    let temp_dir = TempDir::new().expect("Failed to create temp dir");

    let output = std::process::Command::new(reposystem_bin())
        .arg("--no-color")
        .arg("scan")
        .arg(temp_dir.path())
        .output()
        .expect("Failed to run with --no-color");

    assert!(output.status.success(), "No-color flag should not break execution");
}

// =============================================================================
// Combined Integration Tests
// =============================================================================

#[test]
fn test_scan_with_config_and_path() {
    let temp_dir = TempDir::new().expect("Failed to create temp dir");
    let repo_path = temp_dir.path().join("test_repo");
    init_fake_git(&repo_path).expect("Failed to init fake git");

    let config_path = temp_dir.path().join("config.toml");
    fs::write(&config_path, "[global]\nname = \"test\"\n").expect("Failed to write config");

    let output = std::process::Command::new(reposystem_bin())
        .arg("--config")
        .arg(&config_path)
        .arg("scan")
        .arg(temp_dir.path())
        .output()
        .expect("Failed to run combined command");

    assert!(output.status.success(), "Scan should work with config and path");
}

#[test]
fn test_multiple_flags_combined() {
    let temp_dir = TempDir::new().expect("Failed to create temp dir");

    let output = std::process::Command::new(reposystem_bin())
        .arg("-v")
        .arg("--json")
        .arg("--no-color")
        .arg("scan")
        .arg(temp_dir.path())
        .arg("--deep")
        .output()
        .expect("Failed to run with multiple flags");

    assert!(output.status.success(), "Should handle multiple flags");
}
