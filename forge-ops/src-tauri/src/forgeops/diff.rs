// SPDX-License-Identifier: PMPL-1.0-or-later

//! ForgeOps cross-forge diff engine.
//!
//! Compares settings across three forges + RSR policy:
//!   1. **GitHub** — repo settings, protection rules, workflows
//!   2. **GitLab** — project settings, protected branches, CI config
//!   3. **Bitbucket** — repo settings, branch restrictions, pipelines
//!   4. **Policy** — RSR/Trustfile expected values
//!
//! Produces a list of diff entries showing which settings diverge across forges.
//! The frontend renders these in `ForgeOpsDiffViewer.res`.

use serde::Serialize;

use super::api;
use super::config;
use super::types::*;

/// A single entry in the cross-forge diff.
#[derive(Debug, Serialize, Clone)]
pub struct ForgeDiffEntry {
    /// Setting ID (e.g. "has_issues", "visibility").
    pub setting_id: String,
    /// Repository name.
    pub repo_name: String,
    /// Setting category.
    pub category: String,
    /// Value on GitHub (None if setting absent or repo not on GH).
    pub github_value: Option<String>,
    /// Value on GitLab (None if absent or not on GL).
    pub gitlab_value: Option<String>,
    /// Value on Bitbucket (None if absent or not on BB).
    pub bitbucket_value: Option<String>,
    /// Expected value from RSR policy (None if not specified).
    pub policy_value: Option<String>,
    /// Whether all present forge values agree.
    pub consistent: bool,
}

/// Complete cross-forge diff result.
#[derive(Debug, Serialize)]
pub struct ForgeDiffResult {
    /// Repository name.
    pub repo_name: String,
    /// When the diff was computed.
    pub timestamp: String,
    /// All diff entries.
    pub entries: Vec<ForgeDiffEntry>,
    /// Number of settings that differ across forges.
    pub inconsistent_count: u32,
    /// Number of settings present on some forges but not others.
    pub missing_count: u32,
    /// Number of settings matching across all forges.
    pub consistent_count: u32,
}

/// Extract common settings from a GitHub repo as (id, value) pairs.
fn extract_github_settings(repo: &GitHubRepo) -> Vec<(String, String)> {
    vec![
        ("visibility".into(), repo.visibility.clone()),
        ("has_issues".into(), repo.has_issues.to_string()),
        ("has_wiki".into(), repo.has_wiki.to_string()),
        ("has_projects".into(), repo.has_projects.to_string()),
        ("archived".into(), repo.archived.to_string()),
        ("default_branch".into(), repo.default_branch.clone()),
        ("delete_branch_on_merge".into(), repo.delete_branch_on_merge.to_string()),
        ("allow_forking".into(), repo.allow_forking.to_string()),
        ("allow_squash_merge".into(), repo.allow_squash_merge.to_string()),
        ("allow_merge_commit".into(), repo.allow_merge_commit.to_string()),
        ("allow_rebase_merge".into(), repo.allow_rebase_merge.to_string()),
        ("is_template".into(), repo.is_template.to_string()),
        ("license".into(), repo.license.as_ref().map(|l| l.spdx_id.clone()).unwrap_or_else(|| "NONE".into())),
    ]
}

/// Extract common settings from a GitLab project as (id, value) pairs.
fn extract_gitlab_settings(project: &GitLabProject) -> Vec<(String, String)> {
    vec![
        ("visibility".into(), project.visibility.clone()),
        ("has_issues".into(), project.issues_enabled.to_string()),
        ("has_wiki".into(), project.wiki_enabled.to_string()),
        ("archived".into(), project.archived.to_string()),
        ("default_branch".into(), project.default_branch.clone().unwrap_or_else(|| "main".into())),
        ("merge_method".into(), project.merge_method.clone()),
        ("squash_option".into(), project.squash_option.clone()),
        ("container_registry_enabled".into(), project.container_registry_enabled.to_string()),
        ("packages_enabled".into(), project.packages_enabled.to_string()),
        ("snippets_enabled".into(), project.snippets_enabled.to_string()),
        ("service_desk_enabled".into(), project.service_desk_enabled.to_string()),
    ]
}

/// Extract common settings from a Bitbucket repo as (id, value) pairs.
fn extract_bitbucket_settings(repo: &BitbucketRepo) -> Vec<(String, String)> {
    let visibility = if repo.is_private { "private" } else { "public" };
    vec![
        ("visibility".into(), visibility.into()),
        ("has_issues".into(), repo.has_issues.to_string()),
        ("has_wiki".into(), repo.has_wiki.to_string()),
        ("default_branch".into(), repo.mainbranch.as_ref().map(|b| b.name.clone()).unwrap_or_else(|| "main".into())),
        ("language".into(), repo.language.clone()),
    ]
}

/// Compute a cross-forge diff for a repo.
/// Loads data from the offline config if available, otherwise uses live data.
pub fn compute_cross_forge_diff(
    repo_name: &str,
    policy_defaults: &[(String, String)],
) -> Result<ForgeDiffResult, String> {
    // Try offline config first, fall back to live API
    let config = config::load_repo_config(repo_name);

    let gh_settings = match &config {
        Ok(c) => c.github.as_ref().map(extract_github_settings),
        Err(_) => {
            if let Ok(repos) = api::github_list_repos() {
                repos.into_iter().find(|r| r.name == repo_name).map(|r| extract_github_settings(&r))
            } else {
                None
            }
        }
    };

    let gl_settings = match &config {
        Ok(c) => c.gitlab.as_ref().map(extract_gitlab_settings),
        Err(_) => {
            if let Ok(projects) = api::gitlab_list_projects() {
                projects.into_iter().find(|p| p.name == repo_name).map(|p| extract_gitlab_settings(&p))
            } else {
                None
            }
        }
    };

    let bb_settings = match &config {
        Ok(c) => c.bitbucket.as_ref().map(extract_bitbucket_settings),
        Err(_) => {
            if let Ok(repos) = api::bitbucket_list_repos() {
                repos.into_iter().find(|r| r.name == repo_name).map(|r| extract_bitbucket_settings(&r))
            } else {
                None
            }
        }
    };

    // Build lookup maps
    let gh_map: std::collections::HashMap<String, String> = gh_settings
        .unwrap_or_default()
        .into_iter()
        .collect();
    let gl_map: std::collections::HashMap<String, String> = gl_settings
        .unwrap_or_default()
        .into_iter()
        .collect();
    let bb_map: std::collections::HashMap<String, String> = bb_settings
        .unwrap_or_default()
        .into_iter()
        .collect();
    let policy_map: std::collections::HashMap<&str, &str> = policy_defaults
        .iter()
        .map(|(k, v)| (k.as_str(), v.as_str()))
        .collect();

    // Collect all setting IDs
    let mut all_ids: Vec<String> = Vec::new();
    for id in gh_map.keys() {
        if !all_ids.contains(id) { all_ids.push(id.clone()); }
    }
    for id in gl_map.keys() {
        if !all_ids.contains(id) { all_ids.push(id.clone()); }
    }
    for id in bb_map.keys() {
        if !all_ids.contains(id) { all_ids.push(id.clone()); }
    }
    all_ids.sort();

    let mut entries = Vec::new();
    let mut inconsistent_count = 0u32;
    let mut missing_count = 0u32;
    let mut consistent_count = 0u32;

    for id in &all_ids {
        let gh_val = gh_map.get(id).cloned();
        let gl_val = gl_map.get(id).cloned();
        let bb_val = bb_map.get(id).cloned();
        let policy_val = policy_map.get(id.as_str()).map(|s| s.to_string());

        let present_values: Vec<&String> = [&gh_val, &gl_val, &bb_val]
            .iter()
            .filter_map(|v| v.as_ref())
            .collect();

        let all_same = present_values.windows(2).all(|w| w[0] == w[1]);
        let has_missing = present_values.len() < 3
            && (gh_map.contains_key(id) || gl_map.contains_key(id) || bb_map.contains_key(id));

        if has_missing && present_values.len() < 3 {
            missing_count += 1;
        }

        if all_same && present_values.len() > 1 {
            consistent_count += 1;
        } else if !all_same && present_values.len() > 1 {
            inconsistent_count += 1;
        }

        entries.push(ForgeDiffEntry {
            setting_id: id.clone(),
            repo_name: repo_name.to_string(),
            category: "repos".to_string(),
            github_value: gh_val,
            gitlab_value: gl_val,
            bitbucket_value: bb_val,
            policy_value: policy_val,
            consistent: all_same || present_values.len() <= 1,
        });
    }

    let timestamp = format!("{}Z", std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0));

    Ok(ForgeDiffResult {
        repo_name: repo_name.to_string(),
        timestamp,
        entries,
        inconsistent_count,
        missing_count,
        consistent_count,
    })
}
