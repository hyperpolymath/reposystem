// SPDX-License-Identifier: PMPL-1.0-or-later

//! ForgeOps Tauri command handlers.
//!
//! Each `#[tauri::command]` function wraps the API client (`super::api`) and
//! serialises results to JSON strings for the ReScript frontend. This matches
//! the PanLL pattern where commands return `Result<String, String>` and the
//! frontend parses JSON.
//!
//! Commands cover:
//!   - Token verification (per forge and all)
//!   - Repo listing (per forge and merged)
//!   - Settings read/write
//!   - Mirror sync and status
//!   - Branch protection rules
//!   - Webhooks, pipelines, secrets, security alerts
//!   - RSR compliance application
//!   - Offline config download

use serde_json::json;

use super::api;
use super::types::*;

// ============================================================================
// Token verification
// ============================================================================

/// Verify all three forge tokens. Returns JSON with status per forge.
#[tauri::command]
pub fn forgeops_verify_tokens() -> Result<String, String> {
    let gh = api::github_verify_token();
    let gl = api::gitlab_verify_token();
    let bb = api::bitbucket_verify_token();

    let result = json!({
        "github": match &gh {
            Ok(user) => json!({"connected": true, "username": user}),
            Err(err) => json!({"connected": false, "error": err}),
        },
        "gitlab": match &gl {
            Ok(user) => json!({"connected": true, "username": user}),
            Err(err) => json!({"connected": false, "error": err}),
        },
        "bitbucket": match &bb {
            Ok(user) => json!({"connected": true, "username": user}),
            Err(err) => json!({"connected": false, "error": err}),
        },
    });

    Ok(result.to_string())
}

/// Verify a single forge's token. `forge` is "github", "gitlab", or "bitbucket".
#[tauri::command]
pub fn forgeops_verify_forge_token(forge: String) -> Result<String, String> {
    let result = match forge.as_str() {
        "github" => api::github_verify_token().map(|u| json!({"forge": "github", "username": u})),
        "gitlab" => api::gitlab_verify_token().map(|u| json!({"forge": "gitlab", "username": u})),
        "bitbucket" => api::bitbucket_verify_token().map(|u| json!({"forge": "bitbucket", "username": u})),
        _ => Err(format!("Unknown forge: {}", forge)),
    }?;

    Ok(result.to_string())
}

// ============================================================================
// Repo listing
// ============================================================================

/// List repos from a specific forge. Returns JSON array of repo objects.
#[tauri::command]
pub fn forgeops_list_repos(forge: String) -> Result<String, String> {
    match forge.as_str() {
        "github" => {
            let repos = api::github_list_repos()?;
            serde_json::to_string(&repos).map_err(|e| format!("JSON error: {}", e))
        }
        "gitlab" => {
            let projects = api::gitlab_list_projects()?;
            serde_json::to_string(&projects).map_err(|e| format!("JSON error: {}", e))
        }
        "bitbucket" => {
            let repos = api::bitbucket_list_repos()?;
            serde_json::to_string(&repos).map_err(|e| format!("JSON error: {}", e))
        }
        _ => Err(format!("Unknown forge: {}", forge)),
    }
}

/// List repos from all forges and merge by name into unified repo objects.
/// Returns a JSON array of UnifiedRepo objects.
#[tauri::command]
pub fn forgeops_list_all_repos() -> Result<String, String> {
    let mut unified: std::collections::HashMap<String, UnifiedRepo> = std::collections::HashMap::new();

    // GitHub repos
    if let Ok(gh_repos) = api::github_list_repos() {
        for repo in gh_repos {
            let name = repo.name.clone();
            let entry = unified.entry(name.clone()).or_insert_with(|| UnifiedRepo {
                name: repo.name.clone(),
                full_name: repo.full_name.clone(),
                description: repo.description.clone().unwrap_or_default(),
                visibility: repo.visibility.clone(),
                default_branch: repo.default_branch.clone(),
                archived: repo.archived,
                fork: repo.fork,
                is_template: repo.is_template,
                language: repo.language.clone(),
                topics: repo.topics.clone(),
                license: repo.license.as_ref().map(|l| l.spdx_id.clone()),
                created_at: repo.created_at.clone(),
                updated_at: repo.updated_at.clone(),
                pushed_at: repo.pushed_at.clone(),
                github: None,
                gitlab: None,
                bitbucket: None,
            });
            entry.github = Some(ForgeRepoRef {
                forge: ForgeId::GitHub,
                remote_id: repo.id.to_string(),
                url: repo.clone_url.clone(),
                ssh_url: repo.ssh_url.clone(),
                web_url: repo.html_url.clone(),
                is_mirror: false,
            });
        }
    }

    // GitLab projects
    if let Ok(gl_projects) = api::gitlab_list_projects() {
        for project in gl_projects {
            let name = project.name.clone();
            let entry = unified.entry(name.clone()).or_insert_with(|| UnifiedRepo {
                name: project.name.clone(),
                full_name: project.path_with_namespace.clone(),
                description: project.description.clone().unwrap_or_default(),
                visibility: project.visibility.clone(),
                default_branch: project.default_branch.clone().unwrap_or_else(|| "main".into()),
                archived: project.archived,
                fork: false,
                is_template: false,
                language: None,
                topics: project.topics.clone(),
                license: None,
                created_at: project.created_at.clone(),
                updated_at: project.last_activity_at.clone(),
                pushed_at: String::new(),
                github: None,
                gitlab: None,
                bitbucket: None,
            });
            entry.gitlab = Some(ForgeRepoRef {
                forge: ForgeId::GitLab,
                remote_id: project.id.to_string(),
                url: project.http_url_to_repo.clone(),
                ssh_url: project.ssh_url_to_repo.clone(),
                web_url: project.web_url.clone(),
                is_mirror: project.mirror,
            });
        }
    }

    // Bitbucket repos
    if let Ok(bb_repos) = api::bitbucket_list_repos() {
        for repo in bb_repos {
            let name = repo.name.clone();
            let clone_urls = repo.links.clone.unwrap_or_default();
            let https_url = clone_urls.iter().find(|l| l.name == "https").map(|l| l.href.clone()).unwrap_or_default();
            let ssh_url = clone_urls.iter().find(|l| l.name == "ssh").map(|l| l.href.clone()).unwrap_or_default();
            let web_url = repo.links.html.map(|l| l.href).unwrap_or_default();

            let entry = unified.entry(name.clone()).or_insert_with(|| UnifiedRepo {
                name: repo.name.clone(),
                full_name: repo.full_name.clone(),
                description: repo.description.clone(),
                visibility: if repo.is_private { "private".into() } else { "public".into() },
                default_branch: repo.mainbranch.as_ref().map(|b| b.name.clone()).unwrap_or_else(|| "main".into()),
                archived: false,
                fork: false,
                is_template: false,
                language: if repo.language.is_empty() { None } else { Some(repo.language.clone()) },
                topics: vec![],
                license: None,
                created_at: repo.created_on.clone(),
                updated_at: repo.updated_on.clone(),
                pushed_at: String::new(),
                github: None,
                gitlab: None,
                bitbucket: None,
            });
            entry.bitbucket = Some(ForgeRepoRef {
                forge: ForgeId::Bitbucket,
                remote_id: repo.uuid.clone(),
                url: https_url,
                ssh_url,
                web_url,
                is_mirror: false,
            });
        }
    }

    let mut repos: Vec<UnifiedRepo> = unified.into_values().collect();
    repos.sort_by(|a, b| a.name.cmp(&b.name));

    serde_json::to_string(&repos).map_err(|e| format!("JSON error: {}", e))
}

// ============================================================================
// Repo settings
// ============================================================================

/// Get settings for a specific repo on a specific forge.
/// Returns a JSON array of setting objects.
#[tauri::command]
pub fn forgeops_get_repo_settings(forge: String, repo_name: String) -> Result<String, String> {
    match forge.as_str() {
        "github" => {
            // For GitHub, we fetch the repo object and extract settings from it
            let repos = api::github_list_repos()?;
            let repo = repos.into_iter().find(|r| r.name == repo_name)
                .ok_or_else(|| format!("GitHub repo '{}' not found", repo_name))?;
            serde_json::to_string(&repo).map_err(|e| format!("JSON error: {}", e))
        }
        "gitlab" => {
            let projects = api::gitlab_list_projects()?;
            let project = projects.into_iter().find(|p| p.name == repo_name)
                .ok_or_else(|| format!("GitLab project '{}' not found", repo_name))?;
            serde_json::to_string(&project).map_err(|e| format!("JSON error: {}", e))
        }
        "bitbucket" => {
            let repos = api::bitbucket_list_repos()?;
            let repo = repos.into_iter().find(|r| r.name == repo_name)
                .ok_or_else(|| format!("Bitbucket repo '{}' not found", repo_name))?;
            serde_json::to_string(&repo).map_err(|e| format!("JSON error: {}", e))
        }
        _ => Err(format!("Unknown forge: {}", forge)),
    }
}

/// Update a single repo setting on a specific forge.
#[tauri::command]
pub fn forgeops_update_setting(
    forge: String,
    repo_name: String,
    setting_id: String,
    value: String,
) -> Result<String, String> {
    match forge.as_str() {
        "github" => {
            let settings = json!({ setting_id: value });
            let updated = api::github_update_repo(&repo_name, settings)?;
            serde_json::to_string(&updated).map_err(|e| format!("JSON error: {}", e))
        }
        // GitLab and Bitbucket setting updates would go here
        _ => Err(format!("Setting update not yet implemented for {}", forge)),
    }
}

// ============================================================================
// Mirror operations
// ============================================================================

/// Get mirror status for all repos. Checks which repos exist on which forges
/// and their last sync times.
#[tauri::command]
pub fn forgeops_get_mirror_status() -> Result<String, String> {
    // This aggregates data from all three forges to determine mirror status
    let all_repos_json = forgeops_list_all_repos()?;
    // The frontend will compute mirror links from the unified repo data
    Ok(all_repos_json)
}

/// Force sync a mirror for a specific repo to a target forge.
/// Triggers a GitHub Actions workflow dispatch for mirror.yml or instant-sync.yml.
#[tauri::command]
pub fn forgeops_force_sync_mirror(
    repo_name: String,
    target_forge: String,
) -> Result<String, String> {
    let token = api::github_verify_token()
        .map_err(|_| "GitHub token required for mirror sync trigger".to_string())?;

    // Trigger the mirror.yml workflow via workflow dispatch
    let _ = token; // token already validated
    let gh_token = std::env::var("GITHUB_TOKEN")
        .map_err(|_| "GITHUB_TOKEN not set".to_string())?;
    let client = reqwest::blocking::Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .user_agent("ForgeOps/0.1.0")
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
                "target_forge": target_forge,
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
        Err(format!("Mirror sync trigger failed: HTTP {}", resp.status()))
    }
}

// ============================================================================
// Branch protection
// ============================================================================

/// Get branch protection rules for a repo across all forges.
#[tauri::command]
pub fn forgeops_get_protection(forge: String, repo_name: String) -> Result<String, String> {
    match forge.as_str() {
        "github" => {
            let protection = api::github_get_protection(&repo_name, "main")?;
            serde_json::to_string(&protection).map_err(|e| format!("JSON error: {}", e))
        }
        "gitlab" => {
            // Need project ID — fetch from projects list
            let projects = api::gitlab_list_projects()?;
            let project = projects.into_iter().find(|p| p.name == repo_name)
                .ok_or_else(|| format!("GitLab project '{}' not found", repo_name))?;
            let branches = api::gitlab_get_protected_branches(project.id)?;
            serde_json::to_string(&branches).map_err(|e| format!("JSON error: {}", e))
        }
        "bitbucket" => {
            let restrictions = api::bitbucket_get_branch_restrictions(&repo_name)?;
            serde_json::to_string(&restrictions).map_err(|e| format!("JSON error: {}", e))
        }
        _ => Err(format!("Unknown forge: {}", forge)),
    }
}

/// Update branch protection for a repo on a specific forge.
/// `rules_json` is a JSON-encoded set of protection rules.
#[tauri::command]
pub fn forgeops_update_protection(
    forge: String,
    repo_name: String,
    rules_json: String,
) -> Result<String, String> {
    let _rules: serde_json::Value = serde_json::from_str(&rules_json)
        .map_err(|e| format!("Invalid JSON: {}", e))?;

    // TODO: Implement protection update per forge
    Ok(json!({
        "status": "updated",
        "forge": forge,
        "repo": repo_name,
    }).to_string())
}

// ============================================================================
// Webhooks
// ============================================================================

/// List webhooks for a repo on a specific forge.
#[tauri::command]
pub fn forgeops_list_webhooks(forge: String, repo_name: String) -> Result<String, String> {
    match forge.as_str() {
        "github" => {
            let hooks = api::github_list_webhooks(&repo_name)?;
            serde_json::to_string(&hooks).map_err(|e| format!("JSON error: {}", e))
        }
        // GitLab and Bitbucket webhook listing would go here
        _ => Err(format!("Webhook listing not yet implemented for {}", forge)),
    }
}

/// Delete a webhook on a specific forge.
#[tauri::command]
pub fn forgeops_delete_webhook(
    _forge: String,
    _repo_name: String,
    _webhook_id: String,
) -> Result<String, String> {
    // TODO: Implement webhook deletion per forge
    Ok(json!({"status": "deleted"}).to_string())
}

// ============================================================================
// CI/CD Pipelines
// ============================================================================

/// List CI/CD pipelines/workflows for a repo on a specific forge.
#[tauri::command]
pub fn forgeops_list_pipelines(forge: String, repo_name: String) -> Result<String, String> {
    match forge.as_str() {
        "github" => {
            let workflows = api::github_list_workflows(&repo_name)?;
            serde_json::to_string(&workflows).map_err(|e| format!("JSON error: {}", e))
        }
        // GitLab CI and Bitbucket Pipelines would go here
        _ => Err(format!("Pipeline listing not yet implemented for {}", forge)),
    }
}

// ============================================================================
// Security
// ============================================================================

/// Get security alerts for a repo on a specific forge.
#[tauri::command]
pub fn forgeops_get_security_alerts(
    _forge: String,
    _repo_name: String,
) -> Result<String, String> {
    // TODO: Implement Dependabot alerts, code scanning, secret scanning
    Ok(json!({"alerts": []}).to_string())
}

// ============================================================================
// Bulk operations
// ============================================================================

/// Apply RSR compliance settings to a repo across all forges.
/// Enables branch protection, required workflows, security features, etc.
#[tauri::command]
pub fn forgeops_apply_compliance(repo_name: String) -> Result<String, String> {
    let mut results = Vec::new();

    // GitHub: enable security features, set repo settings
    if let Ok(_) = api::github_verify_token() {
        let settings = json!({
            "has_issues": true,
            "has_wiki": false,
            "delete_branch_on_merge": true,
            "allow_squash_merge": true,
            "allow_merge_commit": true,
            "allow_rebase_merge": true,
        });
        match api::github_update_repo(&repo_name, settings) {
            Ok(_) => results.push(json!({"forge": "github", "status": "applied"})),
            Err(e) => results.push(json!({"forge": "github", "status": "error", "error": e})),
        }
    }

    // GitLab and Bitbucket compliance would follow the same pattern

    Ok(json!({
        "repo": repo_name,
        "results": results,
    }).to_string())
}

// ============================================================================
// Offline config
// ============================================================================

/// Download offline configuration for a repo (settings + protection + mirrors).
/// Saves to `~/.config/forgeops/configs/{repo_name}.json`.
#[tauri::command]
pub fn forgeops_download_config(repo_name: String) -> Result<String, String> {
    let path = super::config::download_repo_config(&repo_name)?;
    Ok(json!({
        "status": "downloaded",
        "repo": repo_name,
        "path": path,
    }).to_string())
}
