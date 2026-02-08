//! Universal event type definitions
//!
//! These types abstract away platform-specific webhook payloads into
//! a unified representation that the compliance engine can process.

use serde::{Deserialize, Serialize};

/// Universal repository event - platform agnostic
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum RepoEvent {
    Push(PushEvent),
    PullRequest(PullRequestEvent),
    Issue(IssueEvent),
    Release(ReleaseEvent),
    SecurityAlert(SecurityAlertEvent),
    WorkflowRun(WorkflowEvent),
    Comment(CommentEvent),
}

/// Push event - commits pushed to a branch
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PushEvent {
    pub repo_owner: String,
    pub repo_name: String,
    pub branch: String,
    pub before: String,
    pub after: String,
    pub commits: Vec<Commit>,
    pub pusher: User,
}

/// Pull/Merge request event
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PullRequestEvent {
    pub repo_owner: String,
    pub repo_name: String,
    pub action: PullRequestAction,
    pub number: u64,
    pub title: String,
    pub body: Option<String>,
    pub source_branch: String,
    pub target_branch: String,
    pub author: User,
    pub draft: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PullRequestAction {
    Opened,
    Closed,
    Merged,
    Reopened,
    Edited,
    Synchronize,
    ReviewRequested,
    ReviewRequestRemoved,
    Labeled,
    Unlabeled,
    ReadyForReview,
    ConvertedToDraft,
}

/// Issue event
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IssueEvent {
    pub repo_owner: String,
    pub repo_name: String,
    pub action: IssueAction,
    pub number: u64,
    pub title: String,
    pub body: Option<String>,
    pub author: User,
    pub labels: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum IssueAction {
    Opened,
    Closed,
    Reopened,
    Edited,
    Labeled,
    Unlabeled,
    Assigned,
    Unassigned,
}

/// Release event
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReleaseEvent {
    pub repo_owner: String,
    pub repo_name: String,
    pub action: ReleaseAction,
    pub tag_name: String,
    pub name: Option<String>,
    pub body: Option<String>,
    pub draft: bool,
    pub prerelease: bool,
    pub author: User,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ReleaseAction {
    Published,
    Created,
    Edited,
    Deleted,
    Prereleased,
    Released,
}

/// Security advisory/alert event
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SecurityAlertEvent {
    pub repo_owner: String,
    pub repo_name: String,
    pub action: SecurityAlertAction,
    pub severity: Severity,
    pub package_name: Option<String>,
    pub vulnerable_version: Option<String>,
    pub patched_version: Option<String>,
    pub cve_id: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SecurityAlertAction {
    Created,
    Dismissed,
    Fixed,
    Reopened,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Severity {
    Critical,
    High,
    Medium,
    Low,
    Unknown,
}

/// CI/CD workflow event
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WorkflowEvent {
    pub repo_owner: String,
    pub repo_name: String,
    pub workflow_name: String,
    pub action: WorkflowAction,
    pub status: WorkflowStatus,
    pub conclusion: Option<WorkflowConclusion>,
    pub branch: String,
    pub commit_sha: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum WorkflowAction {
    Requested,
    Completed,
    InProgress,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum WorkflowStatus {
    Queued,
    InProgress,
    Completed,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum WorkflowConclusion {
    Success,
    Failure,
    Cancelled,
    Skipped,
    TimedOut,
    ActionRequired,
}

/// Comment event (issue, PR, commit)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CommentEvent {
    pub repo_owner: String,
    pub repo_name: String,
    pub action: CommentAction,
    pub comment_type: CommentType,
    pub body: String,
    pub author: User,
    pub parent_id: Option<u64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CommentAction {
    Created,
    Edited,
    Deleted,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CommentType {
    Issue,
    PullRequest,
    Commit,
    Review,
}

/// Commit representation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Commit {
    pub sha: String,
    pub message: String,
    pub author: User,
    pub timestamp: String,
    pub added: Vec<String>,
    pub modified: Vec<String>,
    pub removed: Vec<String>,
}

/// User representation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct User {
    pub id: String,
    pub username: String,
    pub email: Option<String>,
    pub avatar_url: Option<String>,
}

impl RepoEvent {
    /// Get the repository owner from any event type
    pub fn repo_owner(&self) -> &str {
        match self {
            Self::Push(e) => &e.repo_owner,
            Self::PullRequest(e) => &e.repo_owner,
            Self::Issue(e) => &e.repo_owner,
            Self::Release(e) => &e.repo_owner,
            Self::SecurityAlert(e) => &e.repo_owner,
            Self::WorkflowRun(e) => &e.repo_owner,
            Self::Comment(e) => &e.repo_owner,
        }
    }

    /// Get the repository name from any event type
    pub fn repo_name(&self) -> &str {
        match self {
            Self::Push(e) => &e.repo_name,
            Self::PullRequest(e) => &e.repo_name,
            Self::Issue(e) => &e.repo_name,
            Self::Release(e) => &e.repo_name,
            Self::SecurityAlert(e) => &e.repo_name,
            Self::WorkflowRun(e) => &e.repo_name,
            Self::Comment(e) => &e.repo_name,
        }
    }
}
