//! GitLab platform adapter
//!
//! Supports both GitLab.com and self-hosted GitLab instances.

use super::{AdapterConfig, Headers, PlatformAdapter, RepoMetadata};
use crate::events::RepoEvent;
use crate::{ComplianceStatus, RepoRef, Result, RsrError};
use async_trait::async_trait;

const DEFAULT_API_URL: &str = "https://gitlab.com/api/v4";

pub struct GitLabAdapter {
    config: AdapterConfig,
    client: reqwest::Client,
    api_url: String,
}

impl GitLabAdapter {
    pub fn new(config: AdapterConfig) -> Self {
        let api_url = config.api_url.clone().unwrap_or_else(|| DEFAULT_API_URL.to_string());

        Self {
            config,
            client: reqwest::Client::new(),
            api_url,
        }
    }
}

#[async_trait]
impl PlatformAdapter for GitLabAdapter {
    fn platform_id(&self) -> &'static str {
        "gitlab"
    }

    fn verify_webhook(&self, _payload: &[u8], headers: &Headers) -> Result<bool> {
        let Some(ref secret) = self.config.webhook_secret else {
            tracing::warn!("Webhook secret not configured - skipping verification");
            return Ok(true);
        };

        // GitLab uses X-Gitlab-Token header for webhook verification
        let Some(token) = headers.get("x-gitlab-token") else {
            return Err(RsrError::WebhookVerification);
        };

        Ok(token == secret)
    }

    fn parse_webhook(&self, _payload: &[u8], headers: &Headers) -> Result<RepoEvent> {
        let event_type = headers
            .get("x-gitlab-event")
            .ok_or_else(|| RsrError::Platform("Missing X-Gitlab-Event header".to_string()))?;

        let _json: serde_json::Value = serde_json::from_slice(payload)?;

        // TODO: Implement full GitLab webhook parsing
        // For now, return a placeholder error
        Err(RsrError::Platform(format!(
            "GitLab adapter not fully implemented yet. Event type: {}",
            event_type
        )))
    }

    async fn post_status(&self, repo: &RepoRef, commit_sha: &str, status: &ComplianceStatus) -> Result<()> {
        let Some(ref token) = self.config.api_token else {
            return Err(RsrError::Config("API token required for posting status".to_string()));
        };

        // GitLab uses project ID in URL, need to encode owner/repo
        let project_path = format!("{}/{}", repo.owner, repo.repo);
        let encoded_path = urlencoding::encode(&project_path);

        let url = format!(
            "{}/projects/{}/statuses/{}",
            self.api_url, encoded_path, commit_sha
        );

        let state = if status.tier >= crate::CertificationTier::Bronze {
            "success"
        } else {
            "failed"
        };

        let body = serde_json::json!({
            "state": state,
            "target_url": format!("https://rsr-certified.dev/report/{}/{}", repo.owner, repo.repo),
            "description": format!("RSR Compliance: {} ({:.0}%)", status.tier.code(), status.score * 100.0),
            "name": "RSR / Compliance Check"
        });

        let response = self.client
            .post(&url)
            .header("PRIVATE-TOKEN", token)
            .json(&body)
            .send()
            .await?;

        if !response.status().is_success() {
            let error_text = response.text().await.unwrap_or_default();
            return Err(RsrError::Platform(format!("Failed to post status: {}", error_text)));
        }

        Ok(())
    }

    async fn fetch_file(&self, repo: &RepoRef, path: &str) -> Result<Vec<u8>> {
        let Some(ref token) = self.config.api_token else {
            return Err(RsrError::Config("API token required".to_string()));
        };

        let project_path = format!("{}/{}", repo.owner, repo.repo);
        let encoded_project = urlencoding::encode(&project_path);
        let encoded_path = urlencoding::encode(path);
        let branch = repo.branch.as_deref().unwrap_or("HEAD");

        let url = format!(
            "{}/projects/{}/repository/files/{}/raw?ref={}",
            self.api_url, encoded_project, encoded_path, branch
        );

        let response = self.client
            .get(&url)
            .header("PRIVATE-TOKEN", token)
            .send()
            .await?;

        if response.status() == reqwest::StatusCode::NOT_FOUND {
            return Err(RsrError::RepoNotFound {
                owner: repo.owner.clone(),
                repo: repo.repo.clone(),
            });
        }

        Ok(response.bytes().await?.to_vec())
    }

    async fn list_files(&self, repo: &RepoRef, path: Option<&str>) -> Result<Vec<String>> {
        let Some(ref token) = self.config.api_token else {
            return Err(RsrError::Config("API token required".to_string()));
        };

        let project_path = format!("{}/{}", repo.owner, repo.repo);
        let encoded_project = urlencoding::encode(&project_path);
        let branch = repo.branch.as_deref().unwrap_or("HEAD");

        let mut url = format!(
            "{}/projects/{}/repository/tree?ref={}",
            self.api_url, encoded_project, branch
        );

        if let Some(p) = path {
            url.push_str(&format!("&path={}", urlencoding::encode(p)));
        }

        let response = self.client
            .get(&url)
            .header("PRIVATE-TOKEN", token)
            .send()
            .await?;

        let json: serde_json::Value = response.json().await?;

        let files: Vec<String> = json
            .as_array()
            .map(|arr| {
                arr.iter()
                    .filter_map(|item| item["path"].as_str().map(String::from))
                    .collect()
            })
            .unwrap_or_default();

        Ok(files)
    }

    async fn get_metadata(&self, repo: &RepoRef) -> Result<RepoMetadata> {
        let Some(ref token) = self.config.api_token else {
            return Err(RsrError::Config("API token required".to_string()));
        };

        let project_path = format!("{}/{}", repo.owner, repo.repo);
        let encoded_project = urlencoding::encode(&project_path);

        let url = format!("{}/projects/{}", self.api_url, encoded_project);

        let response = self.client
            .get(&url)
            .header("PRIVATE-TOKEN", token)
            .send()
            .await?;

        let json: serde_json::Value = response.json().await?;

        Ok(RepoMetadata {
            default_branch: json["default_branch"].as_str().unwrap_or("main").to_string(),
            description: json["description"].as_str().map(String::from),
            has_issues: json["issues_enabled"].as_bool().unwrap_or(false),
            has_wiki: json["wiki_enabled"].as_bool().unwrap_or(false),
            has_pages: json["pages_access_level"].as_str() == Some("enabled"),
            has_ci: true, // GitLab CI is built-in
            has_branch_protection: false, // Would need separate API call
            has_security_policy: false,
            open_issues_count: json["open_issues_count"].as_u64().unwrap_or(0) as u32,
            stargazers_count: json["star_count"].as_u64().unwrap_or(0) as u32,
            forks_count: json["forks_count"].as_u64().unwrap_or(0) as u32,
            license: None, // Would need separate API call
            topics: json["topics"]
                .as_array()
                .map(|arr| arr.iter().filter_map(|v| v.as_str().map(String::from)).collect())
                .unwrap_or_default(),
            last_push: json["last_activity_at"]
                .as_str()
                .and_then(|s| chrono::DateTime::parse_from_rfc3339(s).ok())
                .map(|dt| dt.with_timezone(&chrono::Utc)),
        })
    }
}
