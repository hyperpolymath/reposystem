//! GitHub platform adapter
//!
//! Supports both GitHub.com and GitHub Enterprise Server.

use super::{AdapterConfig, Headers, PlatformAdapter, RepoMetadata};
use crate::events::*;
use crate::{ComplianceStatus, RepoRef, Result, RsrError};
use async_trait::async_trait;
use hmac::{Hmac, Mac};
use sha2::Sha256;

type HmacSha256 = Hmac<Sha256>;

const DEFAULT_API_URL: &str = "https://api.github.com";

pub struct GitHubAdapter {
    config: AdapterConfig,
    client: reqwest::Client,
    api_url: String,
}

impl GitHubAdapter {
    pub fn new(config: AdapterConfig) -> Self {
        let api_url = config.api_url.clone().unwrap_or_else(|| DEFAULT_API_URL.to_string());

        Self {
            config,
            client: reqwest::Client::new(),
            api_url,
        }
    }

    fn get_event_type(headers: &Headers) -> Option<&str> {
        headers.get("x-github-event").map(|s| s.as_str())
    }
}

#[async_trait]
impl PlatformAdapter for GitHubAdapter {
    fn platform_id(&self) -> &'static str {
        "github"
    }

    fn verify_webhook(&self, payload: &[u8], headers: &Headers) -> Result<bool> {
        let Some(ref secret) = self.config.webhook_secret else {
            // No secret configured - skip verification (not recommended for production)
            tracing::warn!("Webhook secret not configured - skipping signature verification");
            return Ok(true);
        };

        let Some(signature) = headers.get("x-hub-signature-256") else {
            return Err(RsrError::WebhookVerification);
        };

        // GitHub signature format: sha256=<hex>
        let expected_prefix = "sha256=";
        if !signature.starts_with(expected_prefix) {
            return Err(RsrError::WebhookVerification);
        }
        let signature_hex = &signature[expected_prefix.len()..];

        let mut mac = HmacSha256::new_from_slice(secret.as_bytes())
            .map_err(|_| RsrError::WebhookVerification)?;
        mac.update(payload);
        let result = mac.finalize();
        let computed = hex::encode(result.into_bytes());

        // Constant-time comparison
        Ok(constant_time_eq(signature_hex.as_bytes(), computed.as_bytes()))
    }

    fn parse_webhook(&self, payload: &[u8], headers: &Headers) -> Result<RepoEvent> {
        let event_type = Self::get_event_type(headers)
            .ok_or_else(|| RsrError::Platform("Missing X-GitHub-Event header".to_string()))?;

        let json: serde_json::Value = serde_json::from_slice(payload)?;

        match event_type {
            "push" => parse_push_event(&json),
            "pull_request" => parse_pull_request_event(&json),
            "issues" => parse_issue_event(&json),
            "release" => parse_release_event(&json),
            "security_advisory" | "dependabot_alert" => parse_security_event(&json),
            "workflow_run" => parse_workflow_event(&json),
            "issue_comment" | "pull_request_review_comment" => parse_comment_event(&json, event_type),
            _ => Err(RsrError::Platform(format!("Unsupported event type: {}", event_type))),
        }
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
            .header("Authorization", format!("Bearer {}", token))
            .header("Accept", "application/vnd.github+json")
            .header("X-GitHub-Api-Version", "2022-11-28")
            .header("User-Agent", "RSR-Certified/0.1")
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
            "{}/repos/{}/{}/contents/{}?ref={}",
            self.api_url, repo.owner, repo.repo, path, branch
        );

        let response = self.client
            .get(&url)
            .header("Authorization", format!("Bearer {}", token))
            .header("Accept", "application/vnd.github.raw+json")
            .header("X-GitHub-Api-Version", "2022-11-28")
            .header("User-Agent", "RSR-Certified/0.1")
            .send()
            .await?;

        if response.status() == reqwest::StatusCode::NOT_FOUND {
            return Err(RsrError::RepoNotFound {
                owner: repo.owner.clone(),
                repo: repo.repo.clone(),
            });
        }

        if response.status() == reqwest::StatusCode::TOO_MANY_REQUESTS {
            return Err(RsrError::RateLimited);
        }

        Ok(response.bytes().await?.to_vec())
    }

    async fn list_files(&self, repo: &RepoRef, path: Option<&str>) -> Result<Vec<String>> {
        let Some(ref token) = self.config.api_token else {
            return Err(RsrError::Config("API token required".to_string()));
        };

        let branch = repo.branch.as_deref().unwrap_or("HEAD");
        let url = match path {
            Some(p) => format!(
                "{}/repos/{}/{}/contents/{}?ref={}",
                self.api_url, repo.owner, repo.repo, p, branch
            ),
            None => format!(
                "{}/repos/{}/{}/contents?ref={}",
                self.api_url, repo.owner, repo.repo, branch
            ),
        };

        let response = self.client
            .get(&url)
            .header("Authorization", format!("Bearer {}", token))
            .header("Accept", "application/vnd.github+json")
            .header("X-GitHub-Api-Version", "2022-11-28")
            .header("User-Agent", "RSR-Certified/0.1")
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
            .header("Authorization", format!("Bearer {}", token))
            .header("Accept", "application/vnd.github+json")
            .header("X-GitHub-Api-Version", "2022-11-28")
            .header("User-Agent", "RSR-Certified/0.1")
            .send()
            .await?;

        let json: serde_json::Value = response.json().await?;

        Ok(RepoMetadata {
            default_branch: json["default_branch"].as_str().unwrap_or("main").to_string(),
            description: json["description"].as_str().map(String::from),
            has_issues: json["has_issues"].as_bool().unwrap_or(false),
            has_wiki: json["has_wiki"].as_bool().unwrap_or(false),
            has_pages: json["has_pages"].as_bool().unwrap_or(false),
            has_ci: false, // Would need separate API call
            has_branch_protection: false, // Would need separate API call
            has_security_policy: json["security_and_analysis"].is_object(),
            open_issues_count: json["open_issues_count"].as_u64().unwrap_or(0) as u32,
            stargazers_count: json["stargazers_count"].as_u64().unwrap_or(0) as u32,
            forks_count: json["forks_count"].as_u64().unwrap_or(0) as u32,
            license: json["license"]["spdx_id"].as_str().map(String::from),
            topics: json["topics"]
                .as_array()
                .map(|arr| arr.iter().filter_map(|v| v.as_str().map(String::from)).collect())
                .unwrap_or_default(),
            last_push: json["pushed_at"]
                .as_str()
                .and_then(|s| chrono::DateTime::parse_from_rfc3339(s).ok())
                .map(|dt| dt.with_timezone(&chrono::Utc)),
        })
    }
}

// Helper function for constant-time comparison
fn constant_time_eq(a: &[u8], b: &[u8]) -> bool {
    if a.len() != b.len() {
        return false;
    }
    a.iter().zip(b.iter()).fold(0, |acc, (x, y)| acc | (x ^ y)) == 0
}

// Event parsing helpers

fn parse_push_event(json: &serde_json::Value) -> Result<RepoEvent> {
    let commits: Vec<Commit> = json["commits"]
        .as_array()
        .map(|arr| {
            arr.iter()
                .map(|c| Commit {
                    sha: c["id"].as_str().unwrap_or_default().to_string(),
                    message: c["message"].as_str().unwrap_or_default().to_string(),
                    author: User {
                        id: c["author"]["username"].as_str().unwrap_or_default().to_string(),
                        username: c["author"]["username"].as_str().unwrap_or_default().to_string(),
                        email: c["author"]["email"].as_str().map(String::from),
                        avatar_url: None,
                    },
                    timestamp: c["timestamp"].as_str().unwrap_or_default().to_string(),
                    added: c["added"].as_array().map(|a| a.iter().filter_map(|v| v.as_str().map(String::from)).collect()).unwrap_or_default(),
                    modified: c["modified"].as_array().map(|a| a.iter().filter_map(|v| v.as_str().map(String::from)).collect()).unwrap_or_default(),
                    removed: c["removed"].as_array().map(|a| a.iter().filter_map(|v| v.as_str().map(String::from)).collect()).unwrap_or_default(),
                })
                .collect()
        })
        .unwrap_or_default();

    Ok(RepoEvent::Push(PushEvent {
        repo_owner: json["repository"]["owner"]["login"].as_str().unwrap_or_default().to_string(),
        repo_name: json["repository"]["name"].as_str().unwrap_or_default().to_string(),
        branch: json["ref"].as_str().unwrap_or_default().replace("refs/heads/", ""),
        before: json["before"].as_str().unwrap_or_default().to_string(),
        after: json["after"].as_str().unwrap_or_default().to_string(),
        commits,
        pusher: User {
            id: json["pusher"]["name"].as_str().unwrap_or_default().to_string(),
            username: json["pusher"]["name"].as_str().unwrap_or_default().to_string(),
            email: json["pusher"]["email"].as_str().map(String::from),
            avatar_url: None,
        },
    }))
}

fn parse_pull_request_event(json: &serde_json::Value) -> Result<RepoEvent> {
    let action = match json["action"].as_str().unwrap_or_default() {
        "opened" => PullRequestAction::Opened,
        "closed" => {
            if json["pull_request"]["merged"].as_bool().unwrap_or(false) {
                PullRequestAction::Merged
            } else {
                PullRequestAction::Closed
            }
        }
        "reopened" => PullRequestAction::Reopened,
        "edited" => PullRequestAction::Edited,
        "synchronize" => PullRequestAction::Synchronize,
        "review_requested" => PullRequestAction::ReviewRequested,
        "review_request_removed" => PullRequestAction::ReviewRequestRemoved,
        "labeled" => PullRequestAction::Labeled,
        "unlabeled" => PullRequestAction::Unlabeled,
        "ready_for_review" => PullRequestAction::ReadyForReview,
        "converted_to_draft" => PullRequestAction::ConvertedToDraft,
        _ => PullRequestAction::Edited,
    };

    let pr = &json["pull_request"];

    Ok(RepoEvent::PullRequest(PullRequestEvent {
        repo_owner: json["repository"]["owner"]["login"].as_str().unwrap_or_default().to_string(),
        repo_name: json["repository"]["name"].as_str().unwrap_or_default().to_string(),
        action,
        number: pr["number"].as_u64().unwrap_or(0),
        title: pr["title"].as_str().unwrap_or_default().to_string(),
        body: pr["body"].as_str().map(String::from),
        source_branch: pr["head"]["ref"].as_str().unwrap_or_default().to_string(),
        target_branch: pr["base"]["ref"].as_str().unwrap_or_default().to_string(),
        author: User {
            id: pr["user"]["id"].as_u64().map(|n| n.to_string()).unwrap_or_default(),
            username: pr["user"]["login"].as_str().unwrap_or_default().to_string(),
            email: None,
            avatar_url: pr["user"]["avatar_url"].as_str().map(String::from),
        },
        draft: pr["draft"].as_bool().unwrap_or(false),
    }))
}

fn parse_issue_event(json: &serde_json::Value) -> Result<RepoEvent> {
    let action = match json["action"].as_str().unwrap_or_default() {
        "opened" => IssueAction::Opened,
        "closed" => IssueAction::Closed,
        "reopened" => IssueAction::Reopened,
        "edited" => IssueAction::Edited,
        "labeled" => IssueAction::Labeled,
        "unlabeled" => IssueAction::Unlabeled,
        "assigned" => IssueAction::Assigned,
        "unassigned" => IssueAction::Unassigned,
        _ => IssueAction::Edited,
    };

    let issue = &json["issue"];

    Ok(RepoEvent::Issue(IssueEvent {
        repo_owner: json["repository"]["owner"]["login"].as_str().unwrap_or_default().to_string(),
        repo_name: json["repository"]["name"].as_str().unwrap_or_default().to_string(),
        action,
        number: issue["number"].as_u64().unwrap_or(0),
        title: issue["title"].as_str().unwrap_or_default().to_string(),
        body: issue["body"].as_str().map(String::from),
        author: User {
            id: issue["user"]["id"].as_u64().map(|n| n.to_string()).unwrap_or_default(),
            username: issue["user"]["login"].as_str().unwrap_or_default().to_string(),
            email: None,
            avatar_url: issue["user"]["avatar_url"].as_str().map(String::from),
        },
        labels: issue["labels"]
            .as_array()
            .map(|arr| arr.iter().filter_map(|l| l["name"].as_str().map(String::from)).collect())
            .unwrap_or_default(),
    }))
}

fn parse_release_event(json: &serde_json::Value) -> Result<RepoEvent> {
    let action = match json["action"].as_str().unwrap_or_default() {
        "published" => ReleaseAction::Published,
        "created" => ReleaseAction::Created,
        "edited" => ReleaseAction::Edited,
        "deleted" => ReleaseAction::Deleted,
        "prereleased" => ReleaseAction::Prereleased,
        "released" => ReleaseAction::Released,
        _ => ReleaseAction::Created,
    };

    let release = &json["release"];

    Ok(RepoEvent::Release(ReleaseEvent {
        repo_owner: json["repository"]["owner"]["login"].as_str().unwrap_or_default().to_string(),
        repo_name: json["repository"]["name"].as_str().unwrap_or_default().to_string(),
        action,
        tag_name: release["tag_name"].as_str().unwrap_or_default().to_string(),
        name: release["name"].as_str().map(String::from),
        body: release["body"].as_str().map(String::from),
        draft: release["draft"].as_bool().unwrap_or(false),
        prerelease: release["prerelease"].as_bool().unwrap_or(false),
        author: User {
            id: release["author"]["id"].as_u64().map(|n| n.to_string()).unwrap_or_default(),
            username: release["author"]["login"].as_str().unwrap_or_default().to_string(),
            email: None,
            avatar_url: release["author"]["avatar_url"].as_str().map(String::from),
        },
    }))
}

fn parse_security_event(json: &serde_json::Value) -> Result<RepoEvent> {
    let action = match json["action"].as_str().unwrap_or_default() {
        "created" => SecurityAlertAction::Created,
        "dismissed" => SecurityAlertAction::Dismissed,
        "fixed" => SecurityAlertAction::Fixed,
        "reopened" => SecurityAlertAction::Reopened,
        _ => SecurityAlertAction::Created,
    };

    let alert = json.get("alert").or(json.get("security_advisory"));
    let severity = alert
        .and_then(|a| a["severity"].as_str())
        .map(|s| match s.to_lowercase().as_str() {
            "critical" => Severity::Critical,
            "high" => Severity::High,
            "medium" | "moderate" => Severity::Medium,
            "low" => Severity::Low,
            _ => Severity::Unknown,
        })
        .unwrap_or(Severity::Unknown);

    Ok(RepoEvent::SecurityAlert(SecurityAlertEvent {
        repo_owner: json["repository"]["owner"]["login"].as_str().unwrap_or_default().to_string(),
        repo_name: json["repository"]["name"].as_str().unwrap_or_default().to_string(),
        action,
        severity,
        package_name: alert.and_then(|a| a["package"]["name"].as_str().map(String::from)),
        vulnerable_version: alert.and_then(|a| a["vulnerable_version_range"].as_str().map(String::from)),
        patched_version: alert.and_then(|a| a["patched_versions"].as_str().map(String::from)),
        cve_id: alert.and_then(|a| a["cve_id"].as_str().map(String::from)),
    }))
}

fn parse_workflow_event(json: &serde_json::Value) -> Result<RepoEvent> {
    let workflow = &json["workflow_run"];

    let action = match json["action"].as_str().unwrap_or_default() {
        "requested" => WorkflowAction::Requested,
        "completed" => WorkflowAction::Completed,
        "in_progress" => WorkflowAction::InProgress,
        _ => WorkflowAction::Requested,
    };

    let status = match workflow["status"].as_str().unwrap_or_default() {
        "queued" => WorkflowStatus::Queued,
        "in_progress" => WorkflowStatus::InProgress,
        "completed" => WorkflowStatus::Completed,
        _ => WorkflowStatus::Queued,
    };

    let conclusion = workflow["conclusion"].as_str().map(|s| match s {
        "success" => WorkflowConclusion::Success,
        "failure" => WorkflowConclusion::Failure,
        "cancelled" => WorkflowConclusion::Cancelled,
        "skipped" => WorkflowConclusion::Skipped,
        "timed_out" => WorkflowConclusion::TimedOut,
        "action_required" => WorkflowConclusion::ActionRequired,
        _ => WorkflowConclusion::Failure,
    });

    Ok(RepoEvent::WorkflowRun(WorkflowEvent {
        repo_owner: json["repository"]["owner"]["login"].as_str().unwrap_or_default().to_string(),
        repo_name: json["repository"]["name"].as_str().unwrap_or_default().to_string(),
        workflow_name: workflow["name"].as_str().unwrap_or_default().to_string(),
        action,
        status,
        conclusion,
        branch: workflow["head_branch"].as_str().unwrap_or_default().to_string(),
        commit_sha: workflow["head_sha"].as_str().unwrap_or_default().to_string(),
    }))
}

fn parse_comment_event(json: &serde_json::Value, event_type: &str) -> Result<RepoEvent> {
    let action = match json["action"].as_str().unwrap_or_default() {
        "created" => CommentAction::Created,
        "edited" => CommentAction::Edited,
        "deleted" => CommentAction::Deleted,
        _ => CommentAction::Created,
    };

    let comment_type = match event_type {
        "issue_comment" => {
            if json["issue"]["pull_request"].is_object() {
                CommentType::PullRequest
            } else {
                CommentType::Issue
            }
        }
        "pull_request_review_comment" => CommentType::Review,
        "commit_comment" => CommentType::Commit,
        _ => CommentType::Issue,
    };

    let comment = &json["comment"];

    Ok(RepoEvent::Comment(CommentEvent {
        repo_owner: json["repository"]["owner"]["login"].as_str().unwrap_or_default().to_string(),
        repo_name: json["repository"]["name"].as_str().unwrap_or_default().to_string(),
        action,
        comment_type,
        body: comment["body"].as_str().unwrap_or_default().to_string(),
        author: User {
            id: comment["user"]["id"].as_u64().map(|n| n.to_string()).unwrap_or_default(),
            username: comment["user"]["login"].as_str().unwrap_or_default().to_string(),
            email: None,
            avatar_url: comment["user"]["avatar_url"].as_str().map(String::from),
        },
        parent_id: json["issue"]["number"].as_u64().or(json["pull_request"]["number"].as_u64()),
    }))
}
