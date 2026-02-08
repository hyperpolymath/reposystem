//! Gitea/Forgejo platform adapter
//!
//! Supports Gitea and Forgejo instances (API compatible).

use super::{AdapterConfig, Headers, PlatformAdapter, RepoMetadata};
use crate::events::RepoEvent;
use crate::{ComplianceStatus, RepoRef, Result, RsrError};
use async_trait::async_trait;
use hmac::{Hmac, Mac};
use sha2::Sha256;

type HmacSha256 = Hmac<Sha256>;

pub struct GiteaAdapter {
    config: AdapterConfig,
    client: reqwest::Client,
    api_url: String,
}

impl GiteaAdapter {
    pub fn new(config: AdapterConfig) -> Self {
        // Gitea requires explicit API URL since there's no default cloud instance
        let api_url = config.api_url.clone().unwrap_or_else(|| {
            tracing::warn!("No API URL configured for Gitea - using placeholder");
            "https://gitea.example.com/api/v1".to_string()
        });

        Self {
            config,
            client: reqwest::Client::new(),
            api_url,
        }
    }
}

#[async_trait]
impl PlatformAdapter for GiteaAdapter {
    fn platform_id(&self) -> &'static str {
        "gitea"
    }

    fn verify_webhook(&self, payload: &[u8], headers: &Headers) -> Result<bool> {
        let Some(ref secret) = self.config.webhook_secret else {
            tracing::warn!("Webhook secret not configured - skipping verification");
            return Ok(true);
        };

        // Gitea uses X-Gitea-Signature (HMAC-SHA256)
        let Some(signature) = headers.get("x-gitea-signature") else {
            // Also check for X-Hub-Signature-256 (GitHub-compatible format)
            if let Some(sig) = headers.get("x-hub-signature-256") {
                let expected_prefix = "sha256=";
                if !sig.starts_with(expected_prefix) {
                    return Err(RsrError::WebhookVerification);
                }
                let signature_hex = &sig[expected_prefix.len()..];

                let mut mac = HmacSha256::new_from_slice(secret.as_bytes())
                    .map_err(|_| RsrError::WebhookVerification)?;
                mac.update(payload);
                let result = mac.finalize();
                let computed = hex::encode(result.into_bytes());

                return Ok(constant_time_eq(signature_hex.as_bytes(), computed.as_bytes()));
            }
            return Err(RsrError::WebhookVerification);
        };

        let mut mac = HmacSha256::new_from_slice(secret.as_bytes())
            .map_err(|_| RsrError::WebhookVerification)?;
        mac.update(payload);
        let result = mac.finalize();
        let computed = hex::encode(result.into_bytes());

        Ok(constant_time_eq(signature.as_bytes(), computed.as_bytes()))
    }

    fn parse_webhook(&self, payload: &[u8], headers: &Headers) -> Result<RepoEvent> {
        let event_type = headers
            .get("x-gitea-event")
            .or_else(|| headers.get("x-github-event")) // Gitea is GitHub-compatible
            .ok_or_else(|| RsrError::Platform("Missing X-Gitea-Event header".to_string()))?;

        let _json: serde_json::Value = serde_json::from_slice(payload)?;

        // TODO: Implement full Gitea webhook parsing (similar to GitHub)
        Err(RsrError::Platform(format!(
            "Gitea adapter not fully implemented yet. Event type: {}",
            event_type
        )))
    }

    async fn post_status(&self, repo: &RepoRef, commit_sha: &str, status: &ComplianceStatus) -> Result<()> {
        let Some(ref token) = self.config.api_token else {
            return Err(RsrError::Config("API token required for posting status".to_string()));
        };

        let url = format!(
            "{}/repos/{}/{}/statuses/{}",
            self.api_url, repo.owner, repo.repo, commit_sha
        );

        let state = if status.tier >= crate::CertificationTier::Bronze {
            "success"
        } else {
            "failure"
        };

        let body = serde_json::json!({
            "state": state,
            "target_url": format!("https://rsr-certified.dev/report/{}/{}", repo.owner, repo.repo),
            "description": format!("RSR Compliance: {} ({:.0}%)", status.tier.code(), status.score * 100.0),
            "context": "RSR / Compliance Check"
        });

        let response = self.client
            .post(&url)
            .header("Authorization", format!("token {}", token))
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
            "{}/repos/{}/{}/raw/{}?ref={}",
            self.api_url, repo.owner, repo.repo, path, branch
        );

        let response = self.client
            .get(&url)
            .header("Authorization", format!("token {}", token))
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
        let file_path = path.unwrap_or("");
        let url = format!(
            "{}/repos/{}/{}/contents/{}?ref={}",
            self.api_url, repo.owner, repo.repo, file_path, branch
        );

        let response = self.client
            .get(&url)
            .header("Authorization", format!("token {}", token))
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

        let url = format!(
            "{}/repos/{}/{}",
            self.api_url, repo.owner, repo.repo
        );

        let response = self.client
            .get(&url)
            .header("Authorization", format!("token {}", token))
            .send()
            .await?;

        let json: serde_json::Value = response.json().await?;

        Ok(RepoMetadata {
            default_branch: json["default_branch"].as_str().unwrap_or("main").to_string(),
            description: json["description"].as_str().map(String::from),
            has_issues: json["has_issues"].as_bool().unwrap_or(false),
            has_wiki: json["has_wiki"].as_bool().unwrap_or(false),
            has_pages: false,
            has_ci: false, // Gitea Actions support varies
            has_branch_protection: false,
            has_security_policy: false,
            open_issues_count: json["open_issues_count"].as_u64().unwrap_or(0) as u32,
            stargazers_count: json["stars_count"].as_u64().unwrap_or(0) as u32,
            forks_count: json["forks_count"].as_u64().unwrap_or(0) as u32,
            license: None,
            topics: json["topics"]
                .as_array()
                .map(|arr| arr.iter().filter_map(|v| v.as_str().map(String::from)).collect())
                .unwrap_or_default(),
            last_push: json["updated_at"]
                .as_str()
                .and_then(|s| chrono::DateTime::parse_from_rfc3339(s).ok())
                .map(|dt| dt.with_timezone(&chrono::Utc)),
        })
    }
}

fn constant_time_eq(a: &[u8], b: &[u8]) -> bool {
    if a.len() != b.len() {
        return false;
    }
    a.iter().zip(b.iter()).fold(0, |acc, (x, y)| acc | (x ^ y)) == 0
}
