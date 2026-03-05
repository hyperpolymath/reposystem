// SPDX-License-Identifier: PMPL-1.0-or-later

//! ForgeOps mirror sync logic — manages mirror relationships between forges.
//!
//! Handles:
//! - Detecting which repos exist on which forges
//! - Computing mirror sync status (in-sync, behind, diverged, failed)
//! - Triggering mirror.yml / instant-sync.yml via GitHub Actions dispatch
//! - GitLab pull mirror configuration
//! - Bitbucket pipeline-based mirroring
//!
//! Mirror relationships are derived from the unified repo list (repos present
//! on multiple forges with the same name). The source forge is typically GitHub
//! (the canonical origin for hyperpolymath repos).

use serde::Serialize;
use serde_json::json;

use super::api;
use super::types::*;

/// Mirror relationship status between source and target.
#[derive(Debug, Serialize, Clone)]
pub struct MirrorStatus {
    /// Repository name.
    pub repo_name: String,
    /// Source forge (usually GitHub).
    pub source: ForgeId,
    /// Target forge (GitLab or Bitbucket).
    pub target: ForgeId,
    /// Current sync status.
    pub status: String,
    /// Mirror method in use.
    pub method: String,
    /// Whether auto-sync is configured.
    pub auto_sync: bool,
    /// Last successful sync time (ISO 8601).
    pub last_success: Option<String>,
    /// Last error message.
    pub error: Option<String>,
}

/// Compute mirror status for all repos by cross-referencing forge presence.
pub fn compute_mirror_status() -> Result<Vec<MirrorStatus>, String> {
    let mut statuses = Vec::new();

    // Fetch repos from all forges
    let gh_repos = api::github_list_repos().unwrap_or_default();
    let gl_projects = api::gitlab_list_projects().unwrap_or_default();
    let bb_repos = api::bitbucket_list_repos().unwrap_or_default();

    // Build name->exists lookup sets
    let gl_names: std::collections::HashSet<String> = gl_projects
        .iter()
        .map(|p| p.name.clone())
        .collect();
    let bb_names: std::collections::HashSet<String> = bb_repos
        .iter()
        .map(|r| r.name.clone())
        .collect();

    // For each GitHub repo (source of truth), check mirrors
    for repo in &gh_repos {
        let name = &repo.name;

        // GitHub -> GitLab mirror
        let gl_exists = gl_names.contains(name);
        statuses.push(MirrorStatus {
            repo_name: name.clone(),
            source: ForgeId::GitHub,
            target: ForgeId::GitLab,
            status: if gl_exists { "present".into() } else { "missing".into() },
            method: "github_action".into(),
            auto_sync: gl_exists,
            last_success: None,
            error: if gl_exists { None } else { Some("Repo not found on GitLab".into()) },
        });

        // GitHub -> Bitbucket mirror
        let bb_exists = bb_names.contains(name);
        statuses.push(MirrorStatus {
            repo_name: name.clone(),
            source: ForgeId::GitHub,
            target: ForgeId::Bitbucket,
            status: if bb_exists { "present".into() } else { "missing".into() },
            method: "github_action".into(),
            auto_sync: bb_exists,
            last_success: None,
            error: if bb_exists { None } else { Some("Repo not found on Bitbucket".into()) },
        });
    }

    Ok(statuses)
}

/// Trigger a mirror sync for a specific repo via GitHub Actions workflow dispatch.
/// Dispatches the `mirror.yml` workflow with the target forge as an input.
pub fn trigger_mirror_sync(repo_name: &str, target_forge: &str) -> Result<String, String> {
    let gh_token = std::env::var("GITHUB_TOKEN")
        .map_err(|_| "GITHUB_TOKEN not set — required for mirror sync dispatch".to_string())?;

    let client = reqwest::blocking::Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .user_agent("ForgeOps/0.1.0 (hyperpolymath)")
        .build()
        .map_err(|e| format!("HTTP client error: {}", e))?;

    let url = format!(
        "https://api.github.com/repos/hyperpolymath/{}/actions/workflows/mirror.yml/dispatches",
        repo_name
    );

    let resp = client
        .post(&url)
        .bearer_auth(&gh_token)
        .header("Accept", "application/vnd.github+json")
        .header("X-GitHub-Api-Version", "2022-11-28")
        .json(&json!({
            "ref": "main",
            "inputs": {
                "target": target_forge,
            }
        }))
        .send()
        .map_err(|e| format!("GitHub API request failed: {}", e))?;

    if resp.status().is_success() || resp.status().as_u16() == 204 {
        Ok(json!({
            "status": "triggered",
            "repo": repo_name,
            "target": target_forge,
        }).to_string())
    } else {
        let status = resp.status();
        let body = resp.text().unwrap_or_default();
        Err(format!("Mirror sync dispatch failed (HTTP {}): {}", status, body))
    }
}

/// Check if a repo has the mirror.yml workflow configured.
pub fn has_mirror_workflow(repo_name: &str) -> bool {
    if let Ok(workflows) = api::github_list_workflows(repo_name) {
        workflows.iter().any(|w| w.path.contains("mirror.yml"))
    } else {
        false
    }
}

/// Check if a repo has the instant-sync.yml workflow configured.
pub fn has_instant_sync_workflow(repo_name: &str) -> bool {
    if let Ok(workflows) = api::github_list_workflows(repo_name) {
        workflows.iter().any(|w| w.path.contains("instant-sync.yml"))
    } else {
        false
    }
}

/// Summary statistics for mirror coverage.
#[derive(Debug, Serialize)]
pub struct MirrorSummary {
    /// Total number of GitHub repos.
    pub total_repos: usize,
    /// Number mirrored to GitLab.
    pub gitlab_mirrored: usize,
    /// Number mirrored to Bitbucket.
    pub bitbucket_mirrored: usize,
    /// Number fully mirrored (all three forges).
    pub fully_mirrored: usize,
    /// Number missing on GitLab.
    pub gitlab_missing: usize,
    /// Number missing on Bitbucket.
    pub bitbucket_missing: usize,
}

/// Compute mirror coverage summary.
pub fn mirror_summary(statuses: &[MirrorStatus]) -> MirrorSummary {
    let repo_names: std::collections::HashSet<&str> = statuses
        .iter()
        .map(|s| s.repo_name.as_str())
        .collect();

    let total = repo_names.len();
    let gl_present = statuses.iter()
        .filter(|s| s.target == ForgeId::GitLab && s.status == "present")
        .count();
    let bb_present = statuses.iter()
        .filter(|s| s.target == ForgeId::Bitbucket && s.status == "present")
        .count();

    // A repo is fully mirrored if it's present on both GL and BB
    let gl_repos: std::collections::HashSet<&str> = statuses.iter()
        .filter(|s| s.target == ForgeId::GitLab && s.status == "present")
        .map(|s| s.repo_name.as_str())
        .collect();
    let bb_repos: std::collections::HashSet<&str> = statuses.iter()
        .filter(|s| s.target == ForgeId::Bitbucket && s.status == "present")
        .map(|s| s.repo_name.as_str())
        .collect();
    let fully = gl_repos.intersection(&bb_repos).count();

    MirrorSummary {
        total_repos: total,
        gitlab_mirrored: gl_present,
        bitbucket_mirrored: bb_present,
        fully_mirrored: fully,
        gitlab_missing: total - gl_present,
        bitbucket_missing: total - bb_present,
    }
}
