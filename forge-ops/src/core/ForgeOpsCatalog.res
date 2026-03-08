// SPDX-License-Identifier: PMPL-1.0-or-later

/// ForgeOps Catalog — Complete git forge settings reference.
///
/// Hardcoded catalog of all forge settings, organised by category.
/// Each entry declares the setting ID, display label, description,
/// forge/tier requirement, value type, and RSR default value.
///
/// This is the single source of truth for what settings exist, what forge
/// and tier they require, and what value the RSR policy expects. The catalog
/// drives the settings grid UI and the compliance engine.
///
/// Category structure:
///   Common (all forges): Repos, Mirroring, Protection, CI/CD, Secrets,
///                        Webhooks, Releases, Security
///   Forge-specific:      GitHub, GitLab, Bitbucket

open ForgeOpsModel

// ============================================================================
// Catalog entry — metadata about a setting (NOT live data)
// ============================================================================

/// A catalog entry describing one forge setting.
type catalogEntry = {
  id: string,                       // Setting ID
  label: string,                    // Human-readable display label
  description: string,              // Tooltip/help text
  category: forgeCategory,          // Which tab
  availability: settingAvailability, // Forge/tier gating
  valueType: string,                // "toggle" | "select" | "number" | "object"
  options: option<array<string>>,   // Valid options for "select" type
  defaultValue: settingValue,       // RSR policy default
}

// ============================================================================
// Repos — common settings across all forges
// ============================================================================

let repoSettings: array<catalogEntry> = [
  {
    id: "visibility",
    label: "Repository Visibility",
    description: "Public repos are visible to everyone. Private repos require explicit access.",
    category: Repos,
    availability: Available,
    valueType: "select",
    options: Some(["public", "private", "internal"]),
    defaultValue: StringValue("public"),
  },
  {
    id: "description",
    label: "Repository Description",
    description: "Short description displayed on the repo page and in search results.",
    category: Repos,
    availability: Available,
    valueType: "object",
    options: None,
    defaultValue: StringValue(""),
  },
  {
    id: "default_branch",
    label: "Default Branch",
    description: "The branch that PRs/MRs target by default. RSR standard is 'main'.",
    category: Repos,
    availability: Available,
    valueType: "select",
    options: Some(["main", "master", "develop", "trunk"]),
    defaultValue: StringValue("main"),
  },
  {
    id: "has_issues",
    label: "Issues Enabled",
    description: "Enable the issue tracker for bug reports and feature requests.",
    category: Repos,
    availability: Available,
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(true),
  },
  {
    id: "has_wiki",
    label: "Wiki Enabled",
    description: "Enable the built-in wiki. RSR prefers docs/ in-repo over wiki.",
    category: Repos,
    availability: Available,
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(false),
  },
  {
    id: "has_projects",
    label: "Projects Enabled",
    description: "Enable the project boards feature (GitHub/GitLab).",
    category: Repos,
    availability: ForgeOnly(GitHub),
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(false),
  },
  {
    id: "archived",
    label: "Archived",
    description: "Archived repos are read-only. No new issues, PRs, or pushes.",
    category: Repos,
    availability: Available,
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(false),
  },
  {
    id: "is_template",
    label: "Template Repository",
    description: "Mark as a template repo that others can generate from. RSR template = rsr-template-repo.",
    category: Repos,
    availability: ForgeOnly(GitHub),
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(false),
  },
  {
    id: "allow_forking",
    label: "Allow Forking",
    description: "Whether others can fork this repository.",
    category: Repos,
    availability: Available,
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(true),
  },
  {
    id: "license",
    label: "License",
    description: "SPDX license identifier. RSR standard is PMPL-1.0-or-later.",
    category: Repos,
    availability: Available,
    valueType: "select",
    options: Some(["PMPL-1.0-or-later", "MPL-2.0", "MIT", "Apache-2.0", "GPL-3.0-or-later", "NONE"]),
    defaultValue: StringValue("PMPL-1.0-or-later"),
  },
  {
    id: "topics",
    label: "Topics/Tags",
    description: "Repository topics for discoverability. RSR repos should include 'rsr' topic.",
    category: Repos,
    availability: Available,
    valueType: "object",
    options: None,
    defaultValue: ObjectValue("[]"),
  },
  {
    id: "delete_branch_on_merge",
    label: "Auto-Delete Head Branch",
    description: "Automatically delete the head branch after a PR/MR is merged.",
    category: Repos,
    availability: Available,
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(true),
  },
  {
    id: "squash_merge",
    label: "Squash Merge Allowed",
    description: "Allow squash-merging pull requests.",
    category: Repos,
    availability: Available,
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(true),
  },
  {
    id: "merge_commit",
    label: "Merge Commit Allowed",
    description: "Allow creating merge commits for pull requests.",
    category: Repos,
    availability: Available,
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(true),
  },
  {
    id: "rebase_merge",
    label: "Rebase Merge Allowed",
    description: "Allow rebase-merging pull requests.",
    category: Repos,
    availability: Available,
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(true),
  },
]

// ============================================================================
// Mirroring — dedicated mirror management section
// ============================================================================

let mirrorSettings: array<catalogEntry> = [
  {
    id: "mirror_to_gitlab",
    label: "Mirror to GitLab",
    description: "Push-mirror this repo to GitLab (hyperpolymath account). RSR requires all repos mirrored.",
    category: Mirroring,
    availability: Available,
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(true),
  },
  {
    id: "mirror_to_bitbucket",
    label: "Mirror to Bitbucket",
    description: "Push-mirror this repo to Bitbucket (hyperpolymath account). RSR requires all repos mirrored.",
    category: Mirroring,
    availability: Available,
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(true),
  },
  {
    id: "mirror_method",
    label: "Mirror Method",
    description: "How mirroring is implemented. GitHub Actions (mirror.yml) is the RSR standard.",
    category: Mirroring,
    availability: Available,
    valueType: "select",
    options: Some(["github_action", "gitlab_pull", "gitlab_push", "bitbucket_pipeline", "manual", "webhook"]),
    defaultValue: StringValue("github_action"),
  },
  {
    id: "mirror_auto_sync",
    label: "Auto-Sync Enabled",
    description: "Automatically sync mirrors on push to the source repo.",
    category: Mirroring,
    availability: Available,
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(true),
  },
  {
    id: "mirror_instant_sync",
    label: "Instant Sync (instant-sync.yml)",
    description: "Use the instant-sync.yml workflow for immediate propagation on every push.",
    category: Mirroring,
    availability: ForgeOnly(GitHub),
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(true),
  },
  {
    id: "mirror_include_tags",
    label: "Mirror Tags",
    description: "Include git tags in mirror sync.",
    category: Mirroring,
    availability: Available,
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(true),
  },
  {
    id: "mirror_include_releases",
    label: "Mirror Releases",
    description: "Create releases on mirror targets when releases are published on source.",
    category: Mirroring,
    availability: Available,
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(false),
  },
]

// ============================================================================
// Protection — branch protection rules
// ============================================================================

let protectionSettings: array<catalogEntry> = [
  {
    id: "protect_main",
    label: "Protect Main Branch",
    description: "Enable branch protection on the default branch. RSR requires this.",
    category: Protection,
    availability: Available,
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(true),
  },
  {
    id: "require_pull_request",
    label: "Require Pull Request",
    description: "Require a pull request before merging to protected branches. No direct pushes.",
    category: Protection,
    availability: Available,
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(true),
  },
  {
    id: "required_approvals",
    label: "Required Approvals",
    description: "Minimum number of approving reviews before merge. 0 = no reviews required.",
    category: Protection,
    availability: Available,
    valueType: "number",
    options: None,
    defaultValue: IntValue(1),
  },
  {
    id: "require_status_checks",
    label: "Require Status Checks",
    description: "Require CI status checks to pass before merge.",
    category: Protection,
    availability: Available,
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(true),
  },
  {
    id: "require_signed_commits",
    label: "Require Signed Commits",
    description: "Require GPG or SSH signed commits on protected branches.",
    category: Protection,
    availability: Available,
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(false),
  },
  {
    id: "require_linear_history",
    label: "Require Linear History",
    description: "Prevent merge commits on protected branches. Forces rebase or squash.",
    category: Protection,
    availability: Available,
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(false),
  },
  {
    id: "allow_force_push",
    label: "Allow Force Push",
    description: "Allow force pushes to protected branches. Should be OFF for main.",
    category: Protection,
    availability: Available,
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(false),
  },
  {
    id: "allow_deletion",
    label: "Allow Branch Deletion",
    description: "Allow deleting protected branches. Should be OFF for main.",
    category: Protection,
    availability: Available,
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(false),
  },
  {
    id: "enforce_admins",
    label: "Enforce for Admins",
    description: "Apply protection rules to repository admins too, not just contributors.",
    category: Protection,
    availability: Available,
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(true),
  },
]

// ============================================================================
// CI/CD — pipeline and workflow settings
// ============================================================================

let ciCdSettings: array<catalogEntry> = [
  {
    id: "actions_enabled",
    label: "GitHub Actions Enabled",
    description: "Enable GitHub Actions workflows for this repository.",
    category: CiCd,
    availability: ForgeOnly(GitHub),
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(true),
  },
  {
    id: "actions_permissions",
    label: "Actions Permissions",
    description: "Which actions are allowed to run. RSR standard: selected (pinned SHA only).",
    category: CiCd,
    availability: ForgeOnly(GitHub),
    valueType: "select",
    options: Some(["all", "local_only", "selected", "disabled"]),
    defaultValue: StringValue("selected"),
  },
  {
    id: "gitlab_ci_enabled",
    label: "GitLab CI/CD Enabled",
    description: "Enable GitLab CI/CD pipelines for this project.",
    category: CiCd,
    availability: ForgeOnly(GitLab),
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(true),
  },
  {
    id: "gitlab_auto_devops",
    label: "Auto DevOps",
    description: "Enable GitLab Auto DevOps (automatic CI/CD pipeline).",
    category: CiCd,
    availability: ForgeOnly(GitLab),
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(false),
  },
  {
    id: "bitbucket_pipelines_enabled",
    label: "Bitbucket Pipelines Enabled",
    description: "Enable Bitbucket Pipelines for this repository.",
    category: CiCd,
    availability: ForgeOnly(Bitbucket),
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(true),
  },
  {
    id: "hypatia_scan",
    label: "Hypatia Scan Workflow",
    description: "RSR requires hypatia-scan.yml workflow for neurosymbolic CI intelligence.",
    category: CiCd,
    availability: ForgeOnly(GitHub),
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(true),
  },
  {
    id: "codeql_enabled",
    label: "CodeQL Analysis",
    description: "RSR requires codeql.yml workflow for code analysis.",
    category: CiCd,
    availability: ForgeOnly(GitHub),
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(true),
  },
  {
    id: "scorecard_enabled",
    label: "OpenSSF Scorecard",
    description: "RSR requires scorecard.yml for OpenSSF Scorecard checks.",
    category: CiCd,
    availability: ForgeOnly(GitHub),
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(true),
  },
]

// ============================================================================
// Secrets — repository secrets and variables
// ============================================================================

let secretsSettings: array<catalogEntry> = [
  {
    id: "has_gitlab_token",
    label: "GITLAB_TOKEN Secret",
    description: "GitLab personal access token for mirror.yml workflow. Required for mirroring.",
    category: Secrets,
    availability: ForgeOnly(GitHub),
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(true),
  },
  {
    id: "has_bitbucket_token",
    label: "BITBUCKET_TOKEN Secret",
    description: "Bitbucket API token for mirror.yml workflow. Required for mirroring.",
    category: Secrets,
    availability: ForgeOnly(GitHub),
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(true),
  },
  {
    id: "has_bitbucket_user",
    label: "BITBUCKET_USER Secret",
    description: "Bitbucket username/email for mirror authentication.",
    category: Secrets,
    availability: ForgeOnly(GitHub),
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(true),
  },
  {
    id: "dependabot_secrets",
    label: "Dependabot Secrets",
    description: "Secrets available to Dependabot for private registry access.",
    category: Secrets,
    availability: ForgeOnly(GitHub),
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(false),
  },
]

// ============================================================================
// Webhooks — webhook configuration
// ============================================================================

let webhookSettings: array<catalogEntry> = [
  {
    id: "webhook_ssl_verify",
    label: "SSL Verification",
    description: "Verify SSL certificates for webhook deliveries. Must be ON.",
    category: Webhooks,
    availability: Available,
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(true),
  },
  {
    id: "webhook_content_type",
    label: "Content Type",
    description: "Payload format for webhook deliveries.",
    category: Webhooks,
    availability: Available,
    valueType: "select",
    options: Some(["application/json", "application/x-www-form-urlencoded"]),
    defaultValue: StringValue("application/json"),
  },
]

// ============================================================================
// Releases — release management
// ============================================================================

let releaseSettings: array<catalogEntry> = [
  {
    id: "generate_release_notes",
    label: "Auto-Generate Release Notes",
    description: "Automatically generate release notes from commit messages and PRs.",
    category: Releases,
    availability: ForgeOnly(GitHub),
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(true),
  },
  {
    id: "tag_protection",
    label: "Tag Protection Rules",
    description: "Protect tags matching patterns from being created/deleted by non-admins.",
    category: Releases,
    availability: Available,
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(true),
  },
]

// ============================================================================
// Security — security features
// ============================================================================

let securitySettings: array<catalogEntry> = [
  {
    id: "dependabot_alerts",
    label: "Dependabot Alerts",
    description: "Enable Dependabot vulnerability alerts for dependencies.",
    category: Security,
    availability: ForgeOnly(GitHub),
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(true),
  },
  {
    id: "dependabot_updates",
    label: "Dependabot Security Updates",
    description: "Enable automatic security update PRs from Dependabot.",
    category: Security,
    availability: ForgeOnly(GitHub),
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(true),
  },
  {
    id: "secret_scanning",
    label: "Secret Scanning",
    description: "Scan for accidentally committed secrets (API keys, tokens, etc.).",
    category: Security,
    availability: ForgeOnly(GitHub),
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(true),
  },
  {
    id: "secret_scanning_push_protection",
    label: "Secret Push Protection",
    description: "Block pushes that contain known secret patterns.",
    category: Security,
    availability: ForgeOnly(GitHub),
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(true),
  },
  {
    id: "code_scanning",
    label: "Code Scanning",
    description: "Enable code scanning (CodeQL or third-party) for vulnerability detection.",
    category: Security,
    availability: ForgeOnly(GitHub),
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(true),
  },
  {
    id: "vulnerability_alerts",
    label: "Vulnerability Alerts",
    description: "Receive alerts when dependencies have known vulnerabilities.",
    category: Security,
    availability: Available,
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(true),
  },
  {
    id: "security_policy",
    label: "SECURITY.md Present",
    description: "RSR requires a SECURITY.md file with vulnerability disclosure instructions.",
    category: Security,
    availability: Available,
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(true),
  },
]

// ============================================================================
// GitHub-specific settings
// ============================================================================

let gitHubSpecificSettings: array<catalogEntry> = [
  {
    id: "gh_discussions",
    label: "Discussions Enabled",
    description: "Enable GitHub Discussions for community Q&A and announcements.",
    category: GitHubSpecific,
    availability: ForgeOnly(GitHub),
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(false),
  },
  {
    id: "gh_sponsorship",
    label: "Sponsors Enabled",
    description: "Enable GitHub Sponsors for this repository.",
    category: GitHubSpecific,
    availability: ForgeOnly(GitHub),
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(false),
  },
  {
    id: "gh_pages",
    label: "GitHub Pages",
    description: "Enable GitHub Pages for this repository.",
    category: GitHubSpecific,
    availability: ForgeOnly(GitHub),
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(false),
  },
  {
    id: "gh_pages_source",
    label: "Pages Source",
    description: "GitHub Pages source branch and directory.",
    category: GitHubSpecific,
    availability: ForgeOnly(GitHub),
    valueType: "select",
    options: Some(["gh-pages", "main", "main/docs", "none"]),
    defaultValue: StringValue("gh-pages"),
  },
  {
    id: "gh_environments",
    label: "Deployment Environments",
    description: "Configure deployment environments with protection rules.",
    category: GitHubSpecific,
    availability: ForgeOnly(GitHub),
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(false),
  },
  {
    id: "gh_codespaces",
    label: "Codespaces Enabled",
    description: "Allow GitHub Codespaces for this repository.",
    category: GitHubSpecific,
    availability: ForgeOnly(GitHub),
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(false),
  },
  {
    id: "gh_copilot",
    label: "Copilot Access",
    description: "Allow GitHub Copilot to access this repository's code.",
    category: GitHubSpecific,
    availability: ForgeOnly(GitHub),
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(false),
  },
  {
    id: "gh_vulnerability_db",
    label: "Security Advisories",
    description: "Enable private security advisory creation for responsible disclosure.",
    category: GitHubSpecific,
    availability: ForgeOnly(GitHub),
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(true),
  },
]

// ============================================================================
// GitLab-specific settings
// ============================================================================

let gitLabSpecificSettings: array<catalogEntry> = [
  {
    id: "gl_container_registry",
    label: "Container Registry",
    description: "Enable GitLab Container Registry for Docker/OCI images.",
    category: GitLabSpecific,
    availability: ForgeOnly(GitLab),
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(false),
  },
  {
    id: "gl_package_registry",
    label: "Package Registry",
    description: "Enable GitLab Package Registry for npm, Maven, NuGet, etc.",
    category: GitLabSpecific,
    availability: ForgeOnly(GitLab),
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(false),
  },
  {
    id: "gl_merge_method",
    label: "Merge Method",
    description: "Default merge method for merge requests.",
    category: GitLabSpecific,
    availability: ForgeOnly(GitLab),
    valueType: "select",
    options: Some(["merge", "rebase_merge", "ff"]),
    defaultValue: StringValue("merge"),
  },
  {
    id: "gl_squash_option",
    label: "Squash Commits",
    description: "Squash commit behaviour for merge requests.",
    category: GitLabSpecific,
    availability: ForgeOnly(GitLab),
    valueType: "select",
    options: Some(["never", "always", "default_on", "default_off"]),
    defaultValue: StringValue("default_off"),
  },
  {
    id: "gl_pages",
    label: "GitLab Pages",
    description: "Enable GitLab Pages for static site hosting.",
    category: GitLabSpecific,
    availability: ForgeOnly(GitLab),
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(false),
  },
  {
    id: "gl_snippets",
    label: "Snippets Enabled",
    description: "Enable GitLab Snippets for sharing code fragments.",
    category: GitLabSpecific,
    availability: ForgeOnly(GitLab),
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(false),
  },
  {
    id: "gl_service_desk",
    label: "Service Desk",
    description: "Enable GitLab Service Desk for email-based issue creation.",
    category: GitLabSpecific,
    availability: ForgeOnly(GitLab),
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(false),
  },
]

// ============================================================================
// Bitbucket-specific settings
// ============================================================================

let bitbucketSpecificSettings: array<catalogEntry> = [
  {
    id: "bb_jira_integration",
    label: "Jira Integration",
    description: "Link this repository to a Jira project for issue tracking.",
    category: BitbucketSpecific,
    availability: ForgeOnly(Bitbucket),
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(false),
  },
  {
    id: "bb_branch_restrictions",
    label: "Branch Restrictions",
    description: "Bitbucket-specific branch restrictions (separate from protection rules).",
    category: BitbucketSpecific,
    availability: ForgeOnly(Bitbucket),
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(true),
  },
  {
    id: "bb_merge_checks",
    label: "Merge Checks",
    description: "Require passing builds and minimum approvals before merge.",
    category: BitbucketSpecific,
    availability: ForgeOnly(Bitbucket),
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(true),
  },
  {
    id: "bb_large_files",
    label: "Git LFS Enabled",
    description: "Enable Git Large File Storage for this repository.",
    category: BitbucketSpecific,
    availability: ForgeOnly(Bitbucket),
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(false),
  },
  {
    id: "bb_default_reviewers",
    label: "Default Reviewers",
    description: "Automatically add default reviewers to pull requests.",
    category: BitbucketSpecific,
    availability: ForgeOnly(Bitbucket),
    valueType: "toggle",
    options: None,
    defaultValue: BoolValue(false),
  },
]

// ============================================================================
// Aggregate catalog
// ============================================================================

/// All settings in the catalog, combined from all categories.
let allSettings: array<catalogEntry> = Array.flat([
  repoSettings,
  mirrorSettings,
  protectionSettings,
  ciCdSettings,
  secretsSettings,
  webhookSettings,
  releaseSettings,
  securitySettings,
  gitHubSpecificSettings,
  gitLabSpecificSettings,
  bitbucketSpecificSettings,
])

/// Find a catalog entry by its setting ID.
let findById = (id: string): option<catalogEntry> => {
  allSettings->Array.find(entry => entry.id === id)
}

/// Filter catalog entries by category.
let byCategory = (cat: forgeCategory): array<catalogEntry> => {
  allSettings->Array.filter(entry => entry.category === cat)
}

/// Get all catalog entries available on a given forge.
let availableOnForge = (forge: forgeId): array<catalogEntry> => {
  allSettings->Array.filter(entry => {
    switch entry.availability {
    | Available => true
    | Limited(_) => true
    | ForgeOnly(f) => f === forge
    | Unavailable(_) => false
    }
  })
}

/// Get all catalog entries available on a given tier.
let availableOnTier = (tier: forgeTier): array<catalogEntry> => {
  allSettings->Array.filter(entry => {
    switch entry.availability {
    | Available => true
    | Limited(_) => true
    | ForgeOnly(_) => true
    | Unavailable(required) =>
      switch (tier, required) {
      | (EnterpriseTier, _) => true
      | (TeamTier, EnterpriseTier) => false
      | (TeamTier, _) => true
      | (ProTier, EnterpriseTier) => false
      | (ProTier, TeamTier) => false
      | (ProTier, _) => true
      | (FreeTier, FreeTier) => true
      | (FreeTier, _) => false
      }
    }
  })
}

/// Get the number of settings in each category.
let categoryCounts = (): array<(forgeCategory, int)> => {
  [
    (Repos, Array.length(repoSettings)),
    (Mirroring, Array.length(mirrorSettings)),
    (Protection, Array.length(protectionSettings)),
    (CiCd, Array.length(ciCdSettings)),
    (Secrets, Array.length(secretsSettings)),
    (Webhooks, Array.length(webhookSettings)),
    (Releases, Array.length(releaseSettings)),
    (Security, Array.length(securitySettings)),
    (GitHubSpecific, Array.length(gitHubSpecificSettings)),
    (GitLabSpecific, Array.length(gitLabSpecificSettings)),
    (BitbucketSpecific, Array.length(bitbucketSpecificSettings)),
  ]
}

/// Human-readable label for a setting category.
let categoryLabel = (cat: forgeCategory): string => {
  switch cat {
  | Repos => "Repos"
  | Mirroring => "Mirroring"
  | Protection => "Protection"
  | CiCd => "CI/CD"
  | Secrets => "Secrets"
  | Webhooks => "Webhooks"
  | Releases => "Releases"
  | Security => "Security"
  | GitHubSpecific => "GitHub"
  | GitLabSpecific => "GitLab"
  | BitbucketSpecific => "Bitbucket"
  }
}

/// Human-readable label for a forge ID.
let forgeLabel = (forge: forgeId): string => {
  switch forge {
  | GitHub => "GitHub"
  | GitLab => "GitLab"
  | Bitbucket => "Bitbucket"
  }
}

/// Human-readable label for a forge tier.
let tierLabel = (tier: forgeTier): string => {
  switch tier {
  | FreeTier => "Free"
  | ProTier => "Pro"
  | TeamTier => "Team"
  | EnterpriseTier => "Enterprise"
  }
}
