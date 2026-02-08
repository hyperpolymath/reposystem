//! Bitbucket platform adapter
//!
//! Supports Bitbucket Cloud (bitbucket.org).

use super::{AdapterConfig, Headers, PlatformAdapter, RepoMetadata};
use crate::events::RepoEvent;
use crate::{ComplianceStatus, RepoRef, Result, RsrError};
use async_trait::async_trait;

const DEFAULT_API_URL: &str = "https://api.bitbucket.org/2.0";

pub struct BitbucketAdapter {
    config: AdapterConfig,
    client: reqwest::Client,
    api_url: String,
}

impl BitbucketAdapter {
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
impl PlatformAdapter for BitbucketAdapter {
    fn platform_id(&self) -> &'static str {
        "bitbucket"
    }

    fn verify_webhook(&self, _payload: &[u8], headers: &Headers) -> Result<bool> {
        // Bitbucket Cloud uses IP allowlisting or webhook signatures
        // For webhook signatures, check X-Hub-Signature header (HMAC-SHA256)
        if let Some(ref _secret) = self.config.webhook_secret {
            // TODO: Implement proper signature verification
            if headers.contains_key("x-hub-signature") {
                tracing::warn!("Bitbucket webhook signature verification not fully implemented");
            }
        }
        Ok(true)
    }

    fn parse_webhook(&self, payload: &[u8], headers: &Headers) -> Result<RepoEvent> {
        let event_type = headers
            .get("x-event-key")
            .ok_or_else(|| RsrError::Platform("Missing X-Event-Key header".to_string()))?;

        let _json: serde_json::Value = serde_json::from_slice(payload)?;

        // TODO: Implement full Bitbucket webhook parsing
        Err(RsrError::Platform(format!(
            "Bitbucket adapter not fully implemented yet. Event type: {}",
            event_type
        )))
    }

    async fn post_status(&self, repo: &RepoRef, commit_sha: &str, status: &ComplianceStatus) -> Result<()> {
        let Some(ref token) = self.config.api_token else {
            return Err(RsrError::Config("API token required for posting status".to_string()));
        };

        let url = format!(
            "{}/repositories/{}/{}/commit/{}/statuses/build",
            self.api_url, repo.owner, repo.repo, commit_sha
        );

        let state = if status.tier >= crate::CertificationTier::Bronze {
            "SUCCESSFUL"
        } else {
            "FAILED"
        };

        let body = serde_json::json!({
            "state": state,
            "key": "RSR-COMPLIANCE",
            "url": format!("https://rsr-certified.dev/report/{}/{}", repo.owner, repo.repo),
            "description": format!("RSR Compliance: {} ({:.0}%)", status.tier.code(), status.score * 100.0),
            "name": "RSR / Compliance Check"
        });

        let response = self.client
            .post(&url)
            .header("Authorization", format!("Bearer {}", token))
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

        let branch = repo.branch.as_deref().unwrap_or("HEAD");
        let url = format!(
            "{}/repositories/{}/{}/src/{}/{}",
            self.api_url, repo.owner, repo.repo, branch, path
        );

        let response = self.client
            .get(&url)
            .header("Authorization", format!("Bearer {}", token))
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

        let branch = repo.branch.as_deref().unwrap_or("HEAD");
        let base_path = path.unwrap_or("");
        let url = format!(
            "{}/repositories/{}/{}/src/{}/{}",
            self.api_url, repo.owner, repo.repo, branch, base_path
        );

        let response = self.client
            .get(&url)
            .header("Authorization", format!("Bearer {}", token))
            .send()
            .await?;

        let json: serde_json::Value = response.json().await?;

        let files: Vec<String> = json["values"]
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

        let url = format!(
            "{}/repositories/{}/{}",
            self.api_url, repo.owner, repo.repo
        );

        let response = self.client
            .get(&url)
            .header("Authorization", format!("Bearer {}", token))
            .send()
            .await?;

        let json: serde_json::Value = response.json().await?;

        Ok(RepoMetadata {
            default_branch: json["mainbranch"]["name"].as_str().unwrap_or("main").to_string(),
            description: json["description"].as_str().map(String::from),
            has_issues: json["has_issues"].as_bool().unwrap_or(false),
            has_wiki: json["has_wiki"].as_bool().unwrap_or(false),
            has_pages: false, // Bitbucket doesn't have pages
            has_ci: false, // Would need to check pipelines config
            has_branch_protection: false,
            has_security_policy: false,
            open_issues_count: 0, // Would need separate API call
            stargazers_count: 0, // Bitbucket doesn't show stars
            forks_count: json["forks_count"].as_u64().unwrap_or(0) as u32,
            license: None,
            topics: Vec::new(), // Bitbucket uses "project" instead of topics
            last_push: json["updated_on"]
                .as_str()
                .and_then(|s| chrono::DateTime::parse_from_rfc3339(s).ok())
                .map(|dt| dt.with_timezone(&chrono::Utc)),
        })
    }
}
