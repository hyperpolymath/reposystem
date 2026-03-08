// SPDX-License-Identifier: PMPL-1.0-or-later

//! ForgeOps Rust-side types — serde structs for forge API responses
//! and internal data structures.
//!
//! These types mirror the ReScript `ForgeOpsModel.res` leaf types but are
//! designed for serde JSON serialisation/deserialisation against the three
//! forge APIs (GitHub REST v3, GitLab REST v4, Bitbucket REST 2.0).

use serde::{Deserialize, Serialize};

// ============================================================================
// Forge identity
// ============================================================================

/// Supported git forge platforms.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ForgeId {
    GitHub,
    GitLab,
    Bitbucket,
}

impl std::fmt::Display for ForgeId {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ForgeId::GitHub => write!(f, "github"),
            ForgeId::GitLab => write!(f, "gitlab"),
            ForgeId::Bitbucket => write!(f, "bitbucket"),
        }
    }
}

// ============================================================================
// GitHub API types
// ============================================================================

/// A GitHub repository as returned by `GET /user/repos` or `GET /orgs/{org}/repos`.
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct GitHubRepo {
    pub id: u64,
    pub name: String,
    pub full_name: String,
    #[serde(default)]
    pub description: Option<String>,
    #[serde(rename = "private")]
    pub is_private: bool,
    #[serde(default)]
    pub visibility: String,
    #[serde(default)]
    pub default_branch: String,
    #[serde(default)]
    pub archived: bool,
    #[serde(default)]
    pub fork: bool,
    #[serde(default)]
    pub is_template: bool,
    #[serde(default)]
    pub language: Option<String>,
    #[serde(default)]
    pub topics: Vec<String>,
    #[serde(default)]
    pub license: Option<GitHubLicense>,
    #[serde(default)]
    pub html_url: String,
    #[serde(default)]
    pub clone_url: String,
    #[serde(default)]
    pub ssh_url: String,
    #[serde(default)]
    pub has_issues: bool,
    #[serde(default)]
    pub has_wiki: bool,
    #[serde(default)]
    pub has_projects: bool,
    #[serde(default)]
    pub has_discussions: bool,
    #[serde(default)]
    pub allow_forking: bool,
    #[serde(default)]
    pub delete_branch_on_merge: bool,
    #[serde(default)]
    pub allow_squash_merge: bool,
    #[serde(default)]
    pub allow_merge_commit: bool,
    #[serde(default)]
    pub allow_rebase_merge: bool,
    #[serde(default)]
    pub created_at: String,
    #[serde(default)]
    pub updated_at: String,
    #[serde(default)]
    pub pushed_at: String,
}

/// GitHub license info nested in repo response.
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct GitHubLicense {
    #[serde(default)]
    pub spdx_id: String,
    #[serde(default)]
    pub name: String,
}

/// GitHub branch protection rule.
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct GitHubBranchProtection {
    pub url: String,
    #[serde(default)]
    pub required_status_checks: Option<GitHubStatusChecks>,
    #[serde(default)]
    pub enforce_admins: Option<GitHubEnforcement>,
    #[serde(default)]
    pub required_pull_request_reviews: Option<GitHubPrReviews>,
    #[serde(default)]
    pub restrictions: Option<serde_json::Value>,
    #[serde(default)]
    pub allow_force_pushes: Option<GitHubEnforcement>,
    #[serde(default)]
    pub allow_deletions: Option<GitHubEnforcement>,
    #[serde(default)]
    pub required_linear_history: Option<GitHubEnforcement>,
    #[serde(default)]
    pub required_signatures: Option<GitHubEnforcement>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct GitHubStatusChecks {
    pub strict: bool,
    #[serde(default)]
    pub contexts: Vec<String>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct GitHubEnforcement {
    pub enabled: bool,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct GitHubPrReviews {
    #[serde(default)]
    pub required_approving_review_count: u32,
    #[serde(default)]
    pub dismiss_stale_reviews: bool,
    #[serde(default)]
    pub require_code_owner_reviews: bool,
}

/// GitHub Actions workflow.
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct GitHubWorkflow {
    pub id: u64,
    pub name: String,
    pub path: String,
    pub state: String,
    #[serde(default)]
    pub badge_url: String,
    #[serde(default)]
    pub html_url: String,
}

/// GitHub Actions workflow run.
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct GitHubWorkflowRun {
    pub id: u64,
    pub name: String,
    pub status: String,
    #[serde(default)]
    pub conclusion: Option<String>,
    pub head_branch: String,
    #[serde(default)]
    pub head_sha: String,
    #[serde(default)]
    pub html_url: String,
    #[serde(default)]
    pub created_at: String,
    #[serde(default)]
    pub updated_at: String,
}

/// GitHub webhook.
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct GitHubWebhook {
    pub id: u64,
    pub name: String,
    #[serde(default)]
    pub active: bool,
    #[serde(default)]
    pub events: Vec<String>,
    pub config: GitHubWebhookConfig,
    #[serde(default)]
    pub created_at: String,
    #[serde(default)]
    pub updated_at: String,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct GitHubWebhookConfig {
    #[serde(default)]
    pub url: String,
    #[serde(default)]
    pub content_type: String,
    #[serde(default)]
    pub insecure_ssl: String,
}

/// GitHub repository secret (metadata only — values are never returned).
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct GitHubSecret {
    pub name: String,
    #[serde(default)]
    pub created_at: String,
    #[serde(default)]
    pub updated_at: String,
}

// ============================================================================
// GitLab API types
// ============================================================================

/// A GitLab project.
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct GitLabProject {
    pub id: u64,
    pub name: String,
    #[serde(default)]
    pub path_with_namespace: String,
    #[serde(default)]
    pub description: Option<String>,
    #[serde(default)]
    pub visibility: String,
    #[serde(default)]
    pub default_branch: Option<String>,
    #[serde(default)]
    pub archived: bool,
    #[serde(default)]
    pub http_url_to_repo: String,
    #[serde(default)]
    pub ssh_url_to_repo: String,
    #[serde(default)]
    pub web_url: String,
    #[serde(default)]
    pub topics: Vec<String>,
    #[serde(default)]
    pub created_at: String,
    #[serde(default)]
    pub last_activity_at: String,
    #[serde(default)]
    pub issues_enabled: bool,
    #[serde(default)]
    pub wiki_enabled: bool,
    #[serde(default)]
    pub merge_requests_enabled: bool,
    #[serde(default)]
    pub merge_method: String,
    #[serde(default)]
    pub squash_option: String,
    #[serde(default)]
    pub container_registry_enabled: bool,
    #[serde(default)]
    pub packages_enabled: bool,
    #[serde(default)]
    pub snippets_enabled: bool,
    #[serde(default)]
    pub service_desk_enabled: bool,
    #[serde(default)]
    pub pages_access_level: String,
    #[serde(default)]
    pub mirror: bool,
}

/// GitLab branch protection rule.
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct GitLabProtectedBranch {
    pub id: u64,
    pub name: String,
    #[serde(default)]
    pub push_access_levels: Vec<GitLabAccessLevel>,
    #[serde(default)]
    pub merge_access_levels: Vec<GitLabAccessLevel>,
    #[serde(default)]
    pub allow_force_push: bool,
    #[serde(default)]
    pub code_owner_approval_required: bool,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct GitLabAccessLevel {
    #[serde(default)]
    pub access_level: u32,
    #[serde(default)]
    pub access_level_description: String,
}

// ============================================================================
// Bitbucket API types
// ============================================================================

/// Bitbucket paginated response envelope.
#[derive(Debug, Deserialize)]
pub struct BitbucketPaginated<T> {
    pub pagelen: u32,
    pub page: Option<u32>,
    pub size: Option<u32>,
    pub next: Option<String>,
    pub values: Vec<T>,
}

/// A Bitbucket repository.
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct BitbucketRepo {
    pub uuid: String,
    pub name: String,
    pub full_name: String,
    #[serde(default)]
    pub description: String,
    #[serde(default)]
    pub is_private: bool,
    #[serde(default)]
    pub language: String,
    #[serde(default)]
    pub mainbranch: Option<BitbucketBranch>,
    #[serde(default)]
    pub has_issues: bool,
    #[serde(default)]
    pub has_wiki: bool,
    #[serde(default)]
    pub created_on: String,
    #[serde(default)]
    pub updated_on: String,
    pub links: BitbucketRepoLinks,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct BitbucketBranch {
    pub name: String,
    #[serde(rename = "type")]
    pub branch_type: String,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct BitbucketRepoLinks {
    #[serde(default)]
    pub html: Option<BitbucketLink>,
    #[serde(default)]
    pub clone: Option<Vec<BitbucketCloneLink>>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct BitbucketLink {
    pub href: String,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct BitbucketCloneLink {
    pub href: String,
    pub name: String,
}

/// Bitbucket branch restriction.
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct BitbucketBranchRestriction {
    pub id: u64,
    pub kind: String,
    pub pattern: String,
    #[serde(default)]
    pub value: Option<u32>,
}

// ============================================================================
// Unified types (cross-forge)
// ============================================================================

/// A merged repository representation combining data from all three forges.
/// Serialised to JSON for the frontend.
#[derive(Debug, Serialize, Clone)]
pub struct UnifiedRepo {
    pub name: String,
    pub full_name: String,
    pub description: String,
    pub visibility: String,
    pub default_branch: String,
    pub archived: bool,
    pub fork: bool,
    pub is_template: bool,
    pub language: Option<String>,
    pub topics: Vec<String>,
    pub license: Option<String>,
    pub created_at: String,
    pub updated_at: String,
    pub pushed_at: String,
    pub github: Option<ForgeRepoRef>,
    pub gitlab: Option<ForgeRepoRef>,
    pub bitbucket: Option<ForgeRepoRef>,
}

/// Reference to a repo on a specific forge.
#[derive(Debug, Serialize, Clone)]
pub struct ForgeRepoRef {
    pub forge: ForgeId,
    pub remote_id: String,
    pub url: String,
    pub ssh_url: String,
    pub web_url: String,
    pub is_mirror: bool,
}

/// Unified setting value with forge source annotation.
#[derive(Debug, Serialize, Clone)]
pub struct UnifiedSetting {
    pub id: String,
    pub label: String,
    pub category: String,
    pub value: serde_json::Value,
    pub forge: ForgeId,
    pub editable: bool,
}

/// Forge connection status for a single forge.
#[derive(Debug, Serialize, Clone)]
pub struct ForgeConnectionStatus {
    pub forge: ForgeId,
    pub connected: bool,
    pub username: Option<String>,
    pub error: Option<String>,
}

/// Bulk operation progress.
#[derive(Debug, Serialize, Clone)]
pub struct BulkOperationProgress {
    pub total: u32,
    pub completed: u32,
    pub failed: u32,
    pub current_repo: Option<String>,
    pub current_forge: Option<ForgeId>,
    pub started_at: String,
    pub errors: Vec<(String, String)>,
}
