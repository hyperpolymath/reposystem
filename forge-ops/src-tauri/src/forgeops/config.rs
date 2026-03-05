// SPDX-License-Identifier: PMPL-1.0-or-later

//! ForgeOps offline config serialisation/deserialisation.
//!
//! Supports downloading the full forge configuration for one or more repos
//! to JSON files, and loading saved configs back. This enables:
//!   - Version-controlled infrastructure-as-code for forge settings
//!   - Offline review and modification of repo configs
//!   - Cross-forge diff between GitHub, GitLab, Bitbucket, and RSR policy
//!
//! Config files stored at `~/.config/forgeops/configs/{repo_name}.json`
//! by default, overridable via `FORGEOPS_CONFIG_DIR`.

use std::env;
use std::fs;
use std::path::PathBuf;

use serde::{Deserialize, Serialize};
use serde_json::json;

use super::api;
use super::types::*;

/// Schema version for offline config files.
const CONFIG_SCHEMA_VERSION: u32 = 1;

/// A complete offline snapshot of a repo's forge configuration.
#[derive(Debug, Serialize, Deserialize)]
pub struct OfflineRepoConfig {
    /// Schema version for forwards-compatibility.
    pub schema_version: u32,
    /// ISO 8601 timestamp when the config was exported.
    pub exported_at: String,
    /// Repository name.
    pub repo_name: String,
    /// GitHub repo data (if present on GitHub).
    pub github: Option<GitHubRepo>,
    /// GitLab project data (if present on GitLab).
    pub gitlab: Option<GitLabProject>,
    /// Bitbucket repo data (if present on Bitbucket).
    pub bitbucket: Option<BitbucketRepo>,
    /// GitHub branch protection (if available).
    pub github_protection: Option<GitHubBranchProtection>,
    /// GitLab protected branches (if available).
    pub gitlab_protection: Option<Vec<GitLabProtectedBranch>>,
    /// Bitbucket branch restrictions (if available).
    pub bitbucket_restrictions: Option<Vec<BitbucketBranchRestriction>>,
    /// GitHub webhooks (if available).
    pub github_webhooks: Option<Vec<GitHubWebhook>>,
    /// GitHub Actions secrets metadata (if available).
    pub github_secrets: Option<Vec<GitHubSecret>>,
    /// GitHub Actions workflows (if available).
    pub github_workflows: Option<Vec<GitHubWorkflow>>,
}

/// Returns the config directory, creating it if necessary.
fn config_dir() -> Result<PathBuf, String> {
    let dir = env::var("FORGEOPS_CONFIG_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|_| {
            dirs::config_dir()
                .unwrap_or_else(|| PathBuf::from("/tmp"))
                .join("forgeops")
                .join("configs")
        });

    fs::create_dir_all(&dir)
        .map_err(|e| format!("Failed to create config directory {:?}: {}", dir, e))?;

    Ok(dir)
}

/// Download and save the complete configuration for a repo to disk.
/// Fetches from all available forges and combines into a single JSON file.
pub fn download_repo_config(repo_name: &str) -> Result<String, String> {
    let mut config = OfflineRepoConfig {
        schema_version: CONFIG_SCHEMA_VERSION,
        exported_at: now_iso8601(),
        repo_name: repo_name.to_string(),
        github: None,
        gitlab: None,
        bitbucket: None,
        github_protection: None,
        gitlab_protection: None,
        bitbucket_restrictions: None,
        github_webhooks: None,
        github_secrets: None,
        github_workflows: None,
    };

    // GitHub data
    if let Ok(repos) = api::github_list_repos() {
        if let Some(repo) = repos.into_iter().find(|r| r.name == repo_name) {
            let default_branch = repo.default_branch.clone();
            config.github = Some(repo);

            // Protection rules
            if let Ok(protection) = api::github_get_protection(repo_name, &default_branch) {
                config.github_protection = Some(protection);
            }

            // Webhooks
            if let Ok(hooks) = api::github_list_webhooks(repo_name) {
                config.github_webhooks = Some(hooks);
            }

            // Secrets
            if let Ok(secrets) = api::github_list_secrets(repo_name) {
                config.github_secrets = Some(secrets);
            }

            // Workflows
            if let Ok(workflows) = api::github_list_workflows(repo_name) {
                config.github_workflows = Some(workflows);
            }
        }
    }

    // GitLab data
    if let Ok(projects) = api::gitlab_list_projects() {
        if let Some(project) = projects.into_iter().find(|p| p.name == repo_name) {
            let project_id = project.id;
            config.gitlab = Some(project);

            if let Ok(branches) = api::gitlab_get_protected_branches(project_id) {
                config.gitlab_protection = Some(branches);
            }
        }
    }

    // Bitbucket data
    if let Ok(repos) = api::bitbucket_list_repos() {
        if let Some(repo) = repos.into_iter().find(|r| r.name == repo_name) {
            config.bitbucket = Some(repo);

            if let Ok(restrictions) = api::bitbucket_get_branch_restrictions(repo_name) {
                config.bitbucket_restrictions = Some(restrictions);
            }
        }
    }

    // Save to disk
    let dir = config_dir()?;
    let filename = format!("{}.json", sanitise_filename(repo_name));
    let path = dir.join(&filename);

    let json_str = serde_json::to_string_pretty(&config)
        .map_err(|e| format!("JSON serialisation error: {}", e))?;

    fs::write(&path, json_str)
        .map_err(|e| format!("Failed to write config to {:?}: {}", path, e))?;

    Ok(path.to_string_lossy().to_string())
}

/// Load an offline config from disk for a given repo name.
pub fn load_repo_config(repo_name: &str) -> Result<OfflineRepoConfig, String> {
    let dir = config_dir()?;
    let filename = format!("{}.json", sanitise_filename(repo_name));
    let path = dir.join(&filename);

    let json_str = fs::read_to_string(&path)
        .map_err(|e| format!("Failed to read config {:?}: {}", path, e))?;

    let config: OfflineRepoConfig = serde_json::from_str(&json_str)
        .map_err(|e| format!("Failed to parse config {:?}: {}", path, e))?;

    if config.schema_version > CONFIG_SCHEMA_VERSION {
        return Err(format!(
            "Config schema version {} is newer than supported version {}",
            config.schema_version, CONFIG_SCHEMA_VERSION
        ));
    }

    Ok(config)
}

/// List all saved offline configs.
/// Returns a JSON array of `{ repo_name, exported_at, path }` objects.
pub fn list_saved_configs() -> Result<String, String> {
    let dir = config_dir()?;
    let mut configs = Vec::new();

    let entries = fs::read_dir(&dir)
        .map_err(|e| format!("Failed to read config directory: {}", e))?;

    for entry in entries {
        let entry = entry.map_err(|e| format!("Directory entry error: {}", e))?;
        let path = entry.path();
        if path.extension().and_then(|e| e.to_str()) == Some("json") {
            if let Ok(json_str) = fs::read_to_string(&path) {
                if let Ok(config) = serde_json::from_str::<OfflineRepoConfig>(&json_str) {
                    configs.push(json!({
                        "repo_name": config.repo_name,
                        "exported_at": config.exported_at,
                        "path": path.to_string_lossy(),
                        "has_github": config.github.is_some(),
                        "has_gitlab": config.gitlab.is_some(),
                        "has_bitbucket": config.bitbucket.is_some(),
                    }));
                }
            }
        }
    }

    serde_json::to_string(&configs)
        .map_err(|e| format!("JSON serialisation error: {}", e))
}

/// Sanitise a repo name for use as a filename.
fn sanitise_filename(name: &str) -> String {
    name.chars()
        .map(|c| if c.is_alphanumeric() || c == '-' || c == '_' { c } else { '_' })
        .collect()
}

/// Returns the current time as an ISO 8601 string.
fn now_iso8601() -> String {
    use std::time::{SystemTime, UNIX_EPOCH};
    let secs = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    format!("{}Z", secs)
}
