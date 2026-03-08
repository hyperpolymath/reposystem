// SPDX-License-Identifier: PMPL-1.0-or-later

/// ForgeOps Model Types — Git forge management across GitHub, GitLab, Bitbucket.
///
/// ForgeOps automates git forge administration: repo settings, mirroring,
/// branch protection, CI/CD, secrets, webhooks, releases, and security
/// scanning. It operates local-first — all configuration is cached and
/// editable offline with sync-on-demand to each forge.
///
/// Three-panel model (PanLL integration):
///   Panel-L → Policy constraints (RSR compliance rules, mirror requirements)
///   Panel-N → AI gap analysis (why settings matter, anomaly detection)
///   Panel-W → Main dashboard (repo ribbon, category tabs, settings grid)
///
/// Category tabs (11):
///   Common:  Repos | Mirroring | Protection | CI/CD | Secrets |
///            Webhooks | Releases | Security
///   Forge-specific: GitHub | GitLab | Bitbucket
///
/// This module has NO dependencies on other modules — leaf of the type
/// dependency graph, following the CloudGuard / VabModel pattern.

// ============================================================================
// Git Forge Identity — which forge a repo lives on
// ============================================================================

/// The three supported git forges.
type forgeId =
  | GitHub
  | GitLab
  | Bitbucket

/// Forge account tier, determines which features are available.
/// Each forge has its own tier names but they map to a common scale.
type forgeTier =
  | FreeTier       // GitHub Free, GitLab Free, Bitbucket Free
  | ProTier        // GitHub Pro, GitLab Premium, Bitbucket Standard
  | TeamTier       // GitHub Team, GitLab Premium (group), Bitbucket Premium
  | EnterpriseTier // GitHub Enterprise, GitLab Ultimate, Bitbucket DC

// ============================================================================
// Setting categories — the tab bar in Panel-W
// ============================================================================

/// Top-level categories for the settings grid. The first 8 are common across
/// all forges; the last 3 are forge-specific feature tabs.
type forgeCategory =
  | Repos          // Common repo settings: visibility, description, topics, default branch
  | Mirroring      // Mirror sync status, last push, force sync, config
  | Protection     // Branch protection rules, required reviews, status checks
  | CiCd           // Actions / GitLab CI / Pipelines: workflow status, runs
  | Secrets        // Repository secrets, environment variables, deploy tokens
  | Webhooks       // Webhook management, delivery history
  | Releases       // Tags, releases, changelogs, artifacts
  | Security       // Dependabot, advisories, code scanning, secret scanning
  | GitHubSpecific // GitHub-only: Discussions, Projects, Sponsors, Codespaces
  | GitLabSpecific // GitLab-only: Container Registry, Package Registry, MR settings
  | BitbucketSpecific // Bitbucket-only: Jira integration, Pipelines config

// ============================================================================
// Setting availability — forge-tier gating for the catalog
// ============================================================================

/// Whether a setting is available on the user's forge plan.
type settingAvailability =
  | Available                   // Setting works on any plan
  | ForgeOnly(forgeId)          // Only available on this specific forge
  | Unavailable(forgeTier)      // Requires this tier or higher
  | Limited(string)             // Available but with limitations (description)

// ============================================================================
// Setting value types — same as CloudGuard pattern
// ============================================================================

/// The value of a single forge setting.
type settingValue =
  | BoolValue(bool)             // On/off toggles (e.g. issues enabled)
  | StringValue(string)         // Enum/string settings (e.g. visibility "public")
  | IntValue(int)               // Numeric settings (e.g. required approvals count)
  | ObjectValue(string)         // Complex nested JSON (serialised)

/// A single forge setting with its current value and metadata.
type forgeSetting = {
  id: string,                   // Setting ID (e.g. "visibility", "has_issues")
  label: string,                // Human-readable label
  description: string,          // Tooltip/help text
  category: forgeCategory,      // Which tab this appears under
  value: settingValue,          // Current value from forge API
  defaultValue: settingValue,   // Policy default (from RSR/Trustfile)
  editable: bool,               // Whether the user can change this
  modified: bool,               // Whether value differs from last-synced state
  availability: settingAvailability, // Forge/tier gating
  forgeId: option<forgeId>,     // Which forge this applies to (None = all)
}

// ============================================================================
// Repository types — the core entity (replaces CloudGuard's cfZone)
// ============================================================================

/// Visibility level for a repository.
type repoVisibility =
  | Public
  | Private
  | Internal // GitLab/GitHub Enterprise only

/// A single repository across one or more forges. The repo ribbon shows
/// these as selectable chips with forge badges.
type forgeRepo = {
  name: string,                 // Repository name (e.g. "proven-servers")
  fullName: string,             // Full name with owner (e.g. "hyperpolymath/proven-servers")
  description: string,          // Repository description
  visibility: repoVisibility,   // Public/Private/Internal
  defaultBranch: string,        // Default branch name (usually "main")
  archived: bool,               // Whether the repo is archived
  fork: bool,                   // Whether the repo is a fork
  template: bool,               // Whether the repo is a template
  language: option<string>,     // Primary language
  topics: array<string>,        // Repository topics/tags
  license: option<string>,      // SPDX license identifier
  createdAt: string,            // ISO 8601 timestamp
  updatedAt: string,            // ISO 8601 timestamp
  pushedAt: string,             // ISO 8601 last push timestamp
  // Forge presence — which forges have this repo
  gitHub: option<forgeRepoRef>,
  gitLab: option<forgeRepoRef>,
  bitbucket: option<forgeRepoRef>,
}

/// Reference to a repo on a specific forge (ID + URL + status).
type forgeRepoRef = {
  forgeId: forgeId,             // Which forge
  remoteId: string,             // Forge-specific repo ID
  url: string,                  // Clone URL (HTTPS)
  sshUrl: string,               // Clone URL (SSH)
  webUrl: string,               // Browser URL
  isMirror: bool,               // Whether this is a mirror copy
  lastSyncedAt: option<string>, // Last mirror sync time (ISO 8601)
}

// ============================================================================
// Mirror types — dedicated mirroring section
// ============================================================================

/// Mirror sync status between source and target forges.
type mirrorSyncStatus =
  | InSync                      // All refs match
  | Behind(int)                 // Target is N commits behind
  | Ahead(int)                  // Target has N commits source doesn't
  | Diverged(int, int)          // (behind, ahead) — branches diverged
  | SyncFailed(string)          // Last sync failed with error
  | NeverSynced                 // Mirror exists but never successfully synced
  | Syncing                     // Currently syncing

/// A mirror relationship between two forge instances of the same repo.
type mirrorLink = {
  repoName: string,             // Repository name
  source: forgeId,              // Primary/source forge (usually GitHub)
  target: forgeId,              // Mirror target (GitLab or Bitbucket)
  status: mirrorSyncStatus,     // Current sync status
  lastAttempt: option<string>,  // ISO 8601 last sync attempt
  lastSuccess: option<string>,  // ISO 8601 last successful sync
  method: mirrorMethod,         // How mirroring is configured
  autoSync: bool,               // Whether auto-sync is enabled
  error: option<string>,        // Last error message
}

/// How mirroring is implemented.
type mirrorMethod =
  | GitHubAction                // via mirror.yml / instant-sync.yml workflow
  | GitLabPullMirror            // GitLab's built-in pull mirroring
  | GitLabPushMirror            // GitLab's built-in push mirroring
  | BitbucketPipeline           // Bitbucket Pipelines-based mirroring
  | ManualPush                  // Manual git push to remotes
  | WebhookTrigger              // Webhook-triggered sync

// ============================================================================
// Branch protection types — for the Protection tab
// ============================================================================

/// A branch protection rule on a specific forge.
type branchProtection = {
  repoName: string,             // Which repo
  forgeId: forgeId,             // Which forge
  pattern: string,              // Branch pattern (e.g. "main", "release/*")
  requirePullRequest: bool,     // Require PR before merge
  requiredApprovals: int,       // Minimum number of approvals
  requireStatusChecks: bool,    // Require CI status checks to pass
  statusChecks: array<string>,  // Required status check names
  requireSignedCommits: bool,   // Require GPG/SSH signed commits
  requireLinearHistory: bool,   // No merge commits
  allowForcePush: bool,         // Allow force push (should be false on main)
  allowDeletion: bool,          // Allow branch deletion
  enforceAdmins: bool,          // Apply rules to admins too
  enabled: bool,                // Whether the protection rule is active
}

// ============================================================================
// Webhook types
// ============================================================================

/// A webhook on a specific forge.
type forgeWebhook = {
  id: string,                   // Webhook ID
  repoName: string,             // Which repo
  forgeId: forgeId,             // Which forge
  url: string,                  // Delivery URL
  contentType: string,          // "json" or "form"
  events: array<string>,        // Events that trigger delivery
  active: bool,                 // Whether the webhook is active
  insecureSsl: bool,            // Whether SSL verification is disabled (bad!)
  createdAt: string,            // ISO 8601
  lastDelivery: option<string>, // ISO 8601 last delivery attempt
  lastStatus: option<int>,      // HTTP status of last delivery
}

// ============================================================================
// CI/CD types
// ============================================================================

/// CI/CD pipeline/workflow run status.
type ciRunStatus =
  | CiSuccess
  | CiFailure
  | CiPending
  | CiRunning
  | CiCancelled
  | CiSkipped
  | CiUnknown

/// A CI/CD pipeline/workflow for a repo on a specific forge.
type ciPipeline = {
  id: string,                   // Pipeline/workflow ID
  repoName: string,             // Which repo
  forgeId: forgeId,             // Which forge
  name: string,                 // Workflow/pipeline name
  path: string,                 // Config file path (e.g. ".github/workflows/ci.yml")
  lastRun: option<ciRun>,       // Last run details
  enabled: bool,                // Whether the pipeline is enabled
  badge: option<string>,        // Badge URL
}

/// A single CI/CD run.
type ciRun = {
  id: string,                   // Run ID
  status: ciRunStatus,          // Run status
  branch: string,               // Branch that triggered the run
  commit: string,               // Commit SHA (short)
  message: string,              // Commit message (truncated)
  startedAt: string,            // ISO 8601
  finishedAt: option<string>,   // ISO 8601
  duration: option<int>,        // Duration in seconds
  url: string,                  // Web URL to view the run
}

// ============================================================================
// Secret/variable types
// ============================================================================

/// A repository secret or variable on a specific forge.
/// Values are never returned by forge APIs — only metadata is available.
type forgeSecret = {
  name: string,                 // Secret name (e.g. "GITLAB_TOKEN")
  repoName: string,             // Which repo
  forgeId: forgeId,             // Which forge
  secretType: secretType,       // Secret or variable
  environment: option<string>,  // Environment scope (None = repo-level)
  createdAt: string,            // ISO 8601
  updatedAt: string,            // ISO 8601
}

/// Whether an entry is a secret (encrypted, write-only) or a variable (visible).
type secretType =
  | Secret                      // Encrypted, never readable
  | Variable                    // Plaintext, readable

// ============================================================================
// Release types
// ============================================================================

/// A release/tag on a specific forge.
type forgeRelease = {
  id: string,                   // Release ID
  repoName: string,             // Which repo
  forgeId: forgeId,             // Which forge
  tagName: string,              // Git tag (e.g. "v1.0.0")
  name: string,                 // Release title
  body: string,                 // Release notes (markdown)
  draft: bool,                  // Whether this is a draft
  prerelease: bool,             // Whether this is a pre-release
  createdAt: string,            // ISO 8601
  publishedAt: option<string>,  // ISO 8601
  assets: array<releaseAsset>,  // Attached files
}

/// A release artifact/asset.
type releaseAsset = {
  name: string,                 // File name
  size: int,                    // Size in bytes
  downloadCount: int,           // Number of downloads
  url: string,                  // Download URL
}

// ============================================================================
// Security types
// ============================================================================

/// Security alert severity (shared across Dependabot, code scanning, etc.).
type securitySeverity =
  | SevCritical
  | SevHigh
  | SevMedium
  | SevLow
  | SevInfo

/// A security alert/advisory from a forge.
type securityAlert = {
  id: string,                   // Alert ID
  repoName: string,             // Which repo
  forgeId: forgeId,             // Which forge
  alertType: securityAlertType, // What kind of alert
  severity: securitySeverity,   // How severe
  title: string,                // Alert title
  description: string,          // Alert description
  state: string,                // "open" | "fixed" | "dismissed"
  createdAt: string,            // ISO 8601
  fixedAt: option<string>,      // ISO 8601 if fixed
  url: string,                  // Web URL to the alert
}

/// Type of security alert.
type securityAlertType =
  | DependabotAlert             // Vulnerable dependency
  | CodeScanningAlert           // Code analysis finding
  | SecretScanningAlert         // Exposed secret detected
  | AdvisoryAlert               // Security advisory

// ============================================================================
// Deploy key types
// ============================================================================

/// A deploy key on a specific forge.
type deployKey = {
  id: string,                   // Key ID
  repoName: string,             // Which repo
  forgeId: forgeId,             // Which forge
  title: string,                // Key title/label
  fingerprint: string,          // SSH key fingerprint
  readOnly: bool,               // Whether the key has write access
  createdAt: string,            // ISO 8601
}

// ============================================================================
// Audit and compliance types — same pattern as CloudGuard
// ============================================================================

/// Audit severity for findings.
type auditSeverity =
  | Critical
  | High
  | Medium
  | Low
  | Info

/// A single audit finding — one setting that deviates from policy.
type auditFinding = {
  repoName: string,             // Which repo
  settingId: string,            // Setting ID
  category: forgeCategory,      // Which tab group
  forgeId: option<forgeId>,     // Which forge (None = cross-forge)
  severity: auditSeverity,      // How bad
  message: string,              // Human-readable finding
  currentValue: string,         // What the setting currently is
  expectedValue: string,        // What the policy says it should be
  autoFixable: bool,            // Whether ForgeOps can fix this automatically
}

/// Overall audit result for repos.
type auditResult = {
  timestamp: string,            // ISO 8601 when the audit ran
  repos: array<string>,         // Which repos were audited
  findings: array<auditFinding>, // All findings
  passed: int,                  // Settings that matched policy
  failed: int,                  // Settings that deviated
  warnings: int,                // Medium/low findings
  score: float,                 // Compliance score (0.0 - 1.0)
}

// ============================================================================
// Config diff types — cross-forge comparison
// ============================================================================

/// A diff entry comparing a setting across forges.
type forgeDiffEntry = {
  settingId: string,            // Setting ID
  repoName: string,             // Which repo
  category: forgeCategory,      // Which tab group
  gitHubValue: option<string>,  // Value on GitHub (None if absent)
  gitLabValue: option<string>,  // Value on GitLab (None if absent)
  bitbucketValue: option<string>, // Value on Bitbucket (None if absent)
  policyValue: option<string>,  // Value from RSR policy (None if not specified)
  consistent: bool,             // Whether all present forges agree
}

/// Complete cross-forge diff for one or more repos.
type forgeDiff = {
  timestamp: string,            // When the diff was computed
  entries: array<forgeDiffEntry>, // All diff entries
  inconsistentCount: int,       // Settings that differ across forges
  missingCount: int,            // Settings present on some forges but not others
}

// ============================================================================
// Policy constraint types — Panel-L content
// ============================================================================

/// A policy constraint from RSR / Trustfile.
type policyConstraint = {
  id: string,                   // Unique constraint ID
  expression: string,           // Human-readable rule
  category: forgeCategory,      // Which settings group
  enabled: bool,                // Whether active for auditing
  severity: auditSeverity,      // How severe a violation would be
  description: string,          // Explanation of why this matters
  appliesTo: option<forgeId>,   // Which forge (None = all)
}

// ============================================================================
// Per-repo exception types
// ============================================================================

/// An exception override for a specific repo.
type repoException = {
  repoName: string,             // Which repo
  settingId: string,            // Which setting
  overrideValue: settingValue,  // The override value
  reason: string,               // Why this repo differs
  addedOn: string,              // ISO 8601
}

// ============================================================================
// Bulk operation progress
// ============================================================================

/// Progress state for a bulk operation (e.g. "Apply protection to all repos").
type bulkProgress = {
  total: int,                   // Total number of operations
  completed: int,               // Completed so far
  failed: int,                  // Number that failed
  currentRepo: option<string>,  // Currently processing
  currentForge: option<forgeId>, // Currently processing forge
  startedAt: string,            // ISO 8601
  errors: array<(string, string)>, // (repo, error message)
}

// ============================================================================
// Connection state per forge
// ============================================================================

/// API connection status for a single forge.
type forgeConnectionStatus =
  | Disconnected                // No token configured
  | Connecting                  // Token verification in progress
  | Connected(string)           // Connected — parameter is username/email
  | ConnectionError(string)     // Verification failed

/// Connection state for all three forges.
type forgeConnections = {
  gitHub: forgeConnectionStatus,
  gitLab: forgeConnectionStatus,
  bitbucket: forgeConnectionStatus,
}

// ============================================================================
// Root panel state — composed into Model.model (or standalone)
// ============================================================================

/// The complete ForgeOps panel state. Mirrors CloudGuard's cloudguardState.
type forgeOpsState = {
  // Connections (one per forge)
  connections: forgeConnections, // API connection status per forge
  loading: bool,                // Whether an API call is in flight
  error: option<string>,        // Last error message

  // Data
  repos: array<forgeRepo>,     // All repos across forges (merged by name)
  selectedRepoNames: array<string>, // Currently selected repo names
  settings: array<forgeSetting>, // Settings for currently viewed repo(s)
  mirrorLinks: array<mirrorLink>, // Mirror relationships
  protectionRules: array<branchProtection>, // Branch protection rules
  webhooks: array<forgeWebhook>, // Webhooks
  pipelines: array<ciPipeline>, // CI/CD pipelines
  secrets: array<forgeSecret>,  // Secrets/variables
  releases: array<forgeRelease>, // Releases
  securityAlerts: array<securityAlert>, // Security alerts
  deployKeys: array<deployKey>, // Deploy keys

  // Audit and compliance
  auditResult: option<auditResult>, // Latest audit result
  constraints: array<policyConstraint>, // Policy constraints for Panel-L
  exceptions: array<repoException>, // Per-repo exceptions

  // Cross-forge diff
  forgeDiff: option<forgeDiff>, // Cross-forge comparison

  // Bulk operations
  bulkProgress: option<bulkProgress>, // Current bulk operation

  // UI state
  visible: bool,                // Whether the ForgeOps overlay is shown
  activeCategory: forgeCategory, // Currently active tab
  filterText: string,           // Repo filter text in the ribbon
  settingFilter: string,        // Setting filter within the grid
  showDiff: bool,               // Whether the diff viewer side panel is open
  showAudit: bool,              // Whether the audit results side panel is open
  activeForgeFilter: option<forgeId>, // Filter repos by forge (None = all)
  mirrorEditingId: option<string>, // Mirror link being edited
}
