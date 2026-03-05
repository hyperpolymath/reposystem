// SPDX-License-Identifier: PMPL-1.0-or-later

//! ForgeOps API client — rate-limited reqwest wrappers for GitHub, GitLab, Bitbucket.
//!
//! All forge API calls go through this module. It handles:
//! - Token-based authentication (Bearer for GH/GL, Basic for BB)
//! - Request rate limiting per forge
//! - Pagination for list endpoints
//! - Error extraction from API responses
//!
//! Uses `reqwest::blocking` to match PanLL's existing pattern. Tauri spawns
//! these on a blocking thread pool automatically.
//!
//! Tokens sourced from environment variables:
//! - `GITHUB_TOKEN` — GitHub personal access token or fine-grained token
//! - `GITLAB_TOKEN` — GitLab personal access token
//! - `BITBUCKET_TOKEN` — Atlassian API token with Bitbucket scopes
//! - `BITBUCKET_USER` — Atlassian account email (NOT Bitbucket username)

use std::env;
use std::sync::Mutex;
use std::time::{Duration, Instant};

use once_cell::sync::Lazy;
use reqwest::blocking::Client;
use serde_json::Value;

use super::types::*;

// ============================================================================
// API base URLs
// ============================================================================

const GITHUB_API_BASE: &str = "https://api.github.com";
const GITLAB_API_BASE: &str = "https://gitlab.com/api/v4";
const BITBUCKET_API_BASE: &str = "https://api.bitbucket.org/2.0";

/// Rate limiter per forge: minimum interval between requests.
const GH_MIN_INTERVAL: Duration = Duration::from_millis(200);  // 5000/hr = ~1.4/sec
const GL_MIN_INTERVAL: Duration = Duration::from_millis(100);  // 600/min for projects
const BB_MIN_INTERVAL: Duration = Duration::from_millis(200);  // 1000/hr

static GH_LAST_REQUEST: Lazy<Mutex<Instant>> = Lazy::new(|| {
    Mutex::new(Instant::now() - GH_MIN_INTERVAL)
});
static GL_LAST_REQUEST: Lazy<Mutex<Instant>> = Lazy::new(|| {
    Mutex::new(Instant::now() - GL_MIN_INTERVAL)
});
static BB_LAST_REQUEST: Lazy<Mutex<Instant>> = Lazy::new(|| {
    Mutex::new(Instant::now() - BB_MIN_INTERVAL)
});

// ============================================================================
// Token helpers
// ============================================================================

fn github_token() -> Result<String, String> {
    env::var("GITHUB_TOKEN")
        .map_err(|_| "GITHUB_TOKEN not set. Configure your GitHub personal access token.".into())
}

fn gitlab_token() -> Result<String, String> {
    env::var("GITLAB_TOKEN")
        .map_err(|_| "GITLAB_TOKEN not set. Configure your GitLab personal access token.".into())
}

fn bitbucket_credentials() -> Result<(String, String), String> {
    let user = env::var("BITBUCKET_USER")
        .map_err(|_| "BITBUCKET_USER not set. Use your Atlassian account email.".to_string())?;
    let token = env::var("BITBUCKET_TOKEN")
        .map_err(|_| "BITBUCKET_TOKEN not set. Create an Atlassian API token with Bitbucket scopes.".to_string())?;
    Ok((user, token))
}

// ============================================================================
// Rate limiting and HTTP helpers
// ============================================================================

fn rate_limit(last: &Lazy<Mutex<Instant>>, interval: Duration) {
    let mut ts = last.lock().unwrap_or_else(|e| e.into_inner());
    let elapsed = ts.elapsed();
    if elapsed < interval {
        std::thread::sleep(interval - elapsed);
    }
    *ts = Instant::now();
}

fn http_client(timeout_secs: u64) -> Result<Client, String> {
    Client::builder()
        .timeout(Duration::from_secs(timeout_secs))
        .user_agent("ForgeOps/0.1.0 (hyperpolymath)")
        .build()
        .map_err(|e| format!("Failed to create HTTP client: {}", e))
}

// ============================================================================
// GitHub API operations
// ============================================================================

/// List all GitHub repos for the authenticated user (or org "hyperpolymath").
pub fn github_list_repos() -> Result<Vec<GitHubRepo>, String> {
    let token = github_token()?;
    let client = http_client(15)?;
    let mut all_repos = Vec::new();
    let mut page = 1u32;

    loop {
        rate_limit(&GH_LAST_REQUEST, GH_MIN_INTERVAL);
        let url = format!(
            "{}/users/hyperpolymath/repos?page={}&per_page=100&sort=full_name",
            GITHUB_API_BASE, page
        );
        let resp = client
            .get(&url)
            .bearer_auth(&token)
            .header("Accept", "application/vnd.github+json")
            .header("X-GitHub-Api-Version", "2022-11-28")
            .send()
            .map_err(|e| format!("GitHub API request failed: {}", e))?;

        if !resp.status().is_success() {
            let status = resp.status();
            let body = resp.text().unwrap_or_default();
            return Err(format!("GitHub API error {}: {}", status, body));
        }

        let repos: Vec<GitHubRepo> = resp
            .json()
            .map_err(|e| format!("Failed to parse GitHub repos response: {}", e))?;

        let count = repos.len();
        all_repos.extend(repos);
        if count < 100 {
            break;
        }
        page += 1;
    }

    Ok(all_repos)
}

/// Get GitHub branch protection for a repo's default branch.
pub fn github_get_protection(repo_name: &str, branch: &str) -> Result<GitHubBranchProtection, String> {
    let token = github_token()?;
    let client = http_client(10)?;
    rate_limit(&GH_LAST_REQUEST, GH_MIN_INTERVAL);

    let url = format!(
        "{}/repos/hyperpolymath/{}/branches/{}/protection",
        GITHUB_API_BASE, repo_name, branch
    );
    let resp = client
        .get(&url)
        .bearer_auth(&token)
        .header("Accept", "application/vnd.github+json")
        .header("X-GitHub-Api-Version", "2022-11-28")
        .send()
        .map_err(|e| format!("GitHub API request failed: {}", e))?;

    if !resp.status().is_success() {
        let status = resp.status();
        return Err(format!("GitHub protection API error {}", status));
    }

    resp.json()
        .map_err(|e| format!("Failed to parse protection response: {}", e))
}

/// List GitHub Actions workflows for a repo.
pub fn github_list_workflows(repo_name: &str) -> Result<Vec<GitHubWorkflow>, String> {
    let token = github_token()?;
    let client = http_client(10)?;
    rate_limit(&GH_LAST_REQUEST, GH_MIN_INTERVAL);

    let url = format!(
        "{}/repos/hyperpolymath/{}/actions/workflows",
        GITHUB_API_BASE, repo_name
    );
    let resp = client
        .get(&url)
        .bearer_auth(&token)
        .header("Accept", "application/vnd.github+json")
        .header("X-GitHub-Api-Version", "2022-11-28")
        .send()
        .map_err(|e| format!("GitHub API request failed: {}", e))?;

    if !resp.status().is_success() {
        return Err(format!("GitHub workflows API error {}", resp.status()));
    }

    let body: Value = resp.json().map_err(|e| format!("Parse error: {}", e))?;
    let workflows: Vec<GitHubWorkflow> = serde_json::from_value(
        body.get("workflows").cloned().unwrap_or(Value::Array(vec![]))
    ).map_err(|e| format!("Failed to parse workflows: {}", e))?;

    Ok(workflows)
}

/// List GitHub webhooks for a repo.
pub fn github_list_webhooks(repo_name: &str) -> Result<Vec<GitHubWebhook>, String> {
    let token = github_token()?;
    let client = http_client(10)?;
    rate_limit(&GH_LAST_REQUEST, GH_MIN_INTERVAL);

    let url = format!(
        "{}/repos/hyperpolymath/{}/hooks",
        GITHUB_API_BASE, repo_name
    );
    let resp = client
        .get(&url)
        .bearer_auth(&token)
        .header("Accept", "application/vnd.github+json")
        .header("X-GitHub-Api-Version", "2022-11-28")
        .send()
        .map_err(|e| format!("GitHub API request failed: {}", e))?;

    if !resp.status().is_success() {
        return Err(format!("GitHub webhooks API error {}", resp.status()));
    }

    resp.json().map_err(|e| format!("Failed to parse webhooks: {}", e))
}

/// List GitHub Actions secrets (metadata only) for a repo.
pub fn github_list_secrets(repo_name: &str) -> Result<Vec<GitHubSecret>, String> {
    let token = github_token()?;
    let client = http_client(10)?;
    rate_limit(&GH_LAST_REQUEST, GH_MIN_INTERVAL);

    let url = format!(
        "{}/repos/hyperpolymath/{}/actions/secrets",
        GITHUB_API_BASE, repo_name
    );
    let resp = client
        .get(&url)
        .bearer_auth(&token)
        .header("Accept", "application/vnd.github+json")
        .header("X-GitHub-Api-Version", "2022-11-28")
        .send()
        .map_err(|e| format!("GitHub API request failed: {}", e))?;

    if !resp.status().is_success() {
        return Err(format!("GitHub secrets API error {}", resp.status()));
    }

    let body: Value = resp.json().map_err(|e| format!("Parse error: {}", e))?;
    let secrets: Vec<GitHubSecret> = serde_json::from_value(
        body.get("secrets").cloned().unwrap_or(Value::Array(vec![]))
    ).map_err(|e| format!("Failed to parse secrets: {}", e))?;

    Ok(secrets)
}

/// Update a GitHub repo setting via PATCH.
pub fn github_update_repo(repo_name: &str, settings: Value) -> Result<GitHubRepo, String> {
    let token = github_token()?;
    let client = http_client(10)?;
    rate_limit(&GH_LAST_REQUEST, GH_MIN_INTERVAL);

    let url = format!("{}/repos/hyperpolymath/{}", GITHUB_API_BASE, repo_name);
    let resp = client
        .patch(&url)
        .bearer_auth(&token)
        .header("Accept", "application/vnd.github+json")
        .header("X-GitHub-Api-Version", "2022-11-28")
        .json(&settings)
        .send()
        .map_err(|e| format!("GitHub API request failed: {}", e))?;

    if !resp.status().is_success() {
        let body = resp.text().unwrap_or_default();
        return Err(format!("GitHub update error: {}", body));
    }

    resp.json().map_err(|e| format!("Failed to parse update response: {}", e))
}

/// Verify the GitHub token by fetching authenticated user info.
pub fn github_verify_token() -> Result<String, String> {
    let token = github_token()?;
    let client = http_client(5)?;
    rate_limit(&GH_LAST_REQUEST, GH_MIN_INTERVAL);

    let url = format!("{}/user", GITHUB_API_BASE);
    let resp = client
        .get(&url)
        .bearer_auth(&token)
        .header("Accept", "application/vnd.github+json")
        .header("X-GitHub-Api-Version", "2022-11-28")
        .send()
        .map_err(|e| format!("GitHub API request failed: {}", e))?;

    if !resp.status().is_success() {
        return Err("GitHub token verification failed".to_string());
    }

    let body: Value = resp.json().map_err(|e| format!("Parse error: {}", e))?;
    let login = body.get("login").and_then(|v| v.as_str()).unwrap_or("unknown");
    Ok(login.to_string())
}

// ============================================================================
// GitLab API operations
// ============================================================================

/// List all GitLab projects for the authenticated user.
pub fn gitlab_list_projects() -> Result<Vec<GitLabProject>, String> {
    let token = gitlab_token()?;
    let client = http_client(15)?;
    let mut all_projects = Vec::new();
    let mut page = 1u32;

    loop {
        rate_limit(&GL_LAST_REQUEST, GL_MIN_INTERVAL);
        let url = format!(
            "{}/users/hyperpolymath/projects?page={}&per_page=100&order_by=name&sort=asc",
            GITLAB_API_BASE, page
        );
        let resp = client
            .get(&url)
            .header("PRIVATE-TOKEN", &token)
            .send()
            .map_err(|e| format!("GitLab API request failed: {}", e))?;

        if !resp.status().is_success() {
            let status = resp.status();
            return Err(format!("GitLab API error {}", status));
        }

        let projects: Vec<GitLabProject> = resp
            .json()
            .map_err(|e| format!("Failed to parse GitLab projects: {}", e))?;

        let count = projects.len();
        all_projects.extend(projects);
        if count < 100 {
            break;
        }
        page += 1;
    }

    Ok(all_projects)
}

/// Get GitLab protected branches for a project.
pub fn gitlab_get_protected_branches(project_id: u64) -> Result<Vec<GitLabProtectedBranch>, String> {
    let token = gitlab_token()?;
    let client = http_client(10)?;
    rate_limit(&GL_LAST_REQUEST, GL_MIN_INTERVAL);

    let url = format!("{}/projects/{}/protected_branches", GITLAB_API_BASE, project_id);
    let resp = client
        .get(&url)
        .header("PRIVATE-TOKEN", &token)
        .send()
        .map_err(|e| format!("GitLab API request failed: {}", e))?;

    if !resp.status().is_success() {
        return Err(format!("GitLab protection API error {}", resp.status()));
    }

    resp.json().map_err(|e| format!("Failed to parse protected branches: {}", e))
}

/// Verify the GitLab token by fetching authenticated user info.
pub fn gitlab_verify_token() -> Result<String, String> {
    let token = gitlab_token()?;
    let client = http_client(5)?;
    rate_limit(&GL_LAST_REQUEST, GL_MIN_INTERVAL);

    let url = format!("{}/user", GITLAB_API_BASE);
    let resp = client
        .get(&url)
        .header("PRIVATE-TOKEN", &token)
        .send()
        .map_err(|e| format!("GitLab API request failed: {}", e))?;

    if !resp.status().is_success() {
        return Err("GitLab token verification failed".to_string());
    }

    let body: Value = resp.json().map_err(|e| format!("Parse error: {}", e))?;
    let username = body.get("username").and_then(|v| v.as_str()).unwrap_or("unknown");
    Ok(username.to_string())
}

// ============================================================================
// Bitbucket API operations
// ============================================================================

/// List all Bitbucket repositories for the workspace "hyperpolymath".
pub fn bitbucket_list_repos() -> Result<Vec<BitbucketRepo>, String> {
    let (user, token) = bitbucket_credentials()?;
    let client = http_client(15)?;
    let mut all_repos = Vec::new();
    let mut url = format!("{}/repositories/hyperpolymath?pagelen=100", BITBUCKET_API_BASE);

    loop {
        rate_limit(&BB_LAST_REQUEST, BB_MIN_INTERVAL);
        let resp = client
            .get(&url)
            .basic_auth(&user, Some(&token))
            .send()
            .map_err(|e| format!("Bitbucket API request failed: {}", e))?;

        if !resp.status().is_success() {
            let status = resp.status();
            return Err(format!("Bitbucket API error {}", status));
        }

        let page: BitbucketPaginated<BitbucketRepo> = resp
            .json()
            .map_err(|e| format!("Failed to parse Bitbucket repos: {}", e))?;

        all_repos.extend(page.values);

        match page.next {
            Some(next_url) => url = next_url,
            None => break,
        }
    }

    Ok(all_repos)
}

/// Get Bitbucket branch restrictions for a repo.
pub fn bitbucket_get_branch_restrictions(repo_name: &str) -> Result<Vec<BitbucketBranchRestriction>, String> {
    let (user, token) = bitbucket_credentials()?;
    let client = http_client(10)?;
    rate_limit(&BB_LAST_REQUEST, BB_MIN_INTERVAL);

    let url = format!(
        "{}/repositories/hyperpolymath/{}/branch-restrictions",
        BITBUCKET_API_BASE, repo_name
    );
    let resp = client
        .get(&url)
        .basic_auth(&user, Some(&token))
        .send()
        .map_err(|e| format!("Bitbucket API request failed: {}", e))?;

    if !resp.status().is_success() {
        return Err(format!("Bitbucket restrictions API error {}", resp.status()));
    }

    let page: BitbucketPaginated<BitbucketBranchRestriction> = resp
        .json()
        .map_err(|e| format!("Failed to parse branch restrictions: {}", e))?;

    Ok(page.values)
}

/// Verify the Bitbucket token by fetching user info.
pub fn bitbucket_verify_token() -> Result<String, String> {
    let (user, token) = bitbucket_credentials()?;
    let client = http_client(5)?;
    rate_limit(&BB_LAST_REQUEST, BB_MIN_INTERVAL);

    let url = format!("{}/user", BITBUCKET_API_BASE);
    let resp = client
        .get(&url)
        .basic_auth(&user, Some(&token))
        .send()
        .map_err(|e| format!("Bitbucket API request failed: {}", e))?;

    if !resp.status().is_success() {
        return Err("Bitbucket token verification failed".to_string());
    }

    let body: Value = resp.json().map_err(|e| format!("Parse error: {}", e))?;
    let display_name = body.get("display_name").and_then(|v| v.as_str()).unwrap_or("unknown");
    Ok(display_name.to_string())
}
