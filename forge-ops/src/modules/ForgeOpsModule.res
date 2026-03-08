// SPDX-License-Identifier: PMPL-1.0-or-later

/// ForgeOps Module Registration — Capability-driven module protocol.
///
/// Registers ForgeOps as a PanLL panel module with its capabilities,
/// configuration, and metadata. Follows the CloudGuardModule.res pattern.

/// Capabilities that ForgeOps provides to the PanLL ecosystem.
type forgeOpsCapability =
  | RepoInventory        // List and monitor repos across all three forges
  | MirrorManagement     // Mirror sync status, force sync, configure mirroring
  | BranchProtection     // Branch protection rules across forges
  | CiCdMonitoring       // GitHub Actions, GitLab CI, Bitbucket Pipelines status
  | SecretManagement     // Repository secrets and variables
  | WebhookManagement    // Webhook CRUD and delivery monitoring
  | ReleaseManagement    // Tags, releases, artifacts across forges
  | SecurityScanning     // Dependabot, code scanning, secret scanning
  | ComplianceAudit      // RSR compliance evaluation
  | CrossForgeDiff       // Compare settings across GitHub/GitLab/Bitbucket
  | BulkOperations       // Apply settings across multiple repos at once
  | OfflineConfig        // Download/upload forge config with diff

/// ForgeOps module configuration.
type forgeOpsModuleConfig = {
  id: string,
  name: string,
  version: string,
  description: string,
  capabilities: array<forgeOpsCapability>,
  icon: option<string>,
}

/// The ForgeOps module registration.
let config: forgeOpsModuleConfig = {
  id: "forgeops",
  name: "ForgeOps",
  version: "0.1.0",
  description: "Git forge management across GitHub, GitLab, and Bitbucket. Automates repo settings, mirroring, branch protection, CI/CD, secrets, webhooks, releases, and security scanning with RSR compliance auditing.",
  capabilities: [
    RepoInventory,
    MirrorManagement,
    BranchProtection,
    CiCdMonitoring,
    SecretManagement,
    WebhookManagement,
    ReleaseManagement,
    SecurityScanning,
    ComplianceAudit,
    CrossForgeDiff,
    BulkOperations,
    OfflineConfig,
  ],
  icon: Some("git-branch"),
}

/// Check if ForgeOps has a specific capability.
let hasCapability = (cap: forgeOpsCapability): bool => {
  config.capabilities->Array.includes(cap)
}

/// Human-readable label for a ForgeOps capability.
let capabilityLabel = (cap: forgeOpsCapability): string => {
  switch cap {
  | RepoInventory => "Repo Inventory"
  | MirrorManagement => "Mirror Management"
  | BranchProtection => "Branch Protection"
  | CiCdMonitoring => "CI/CD Monitoring"
  | SecretManagement => "Secret Management"
  | WebhookManagement => "Webhook Management"
  | ReleaseManagement => "Release Management"
  | SecurityScanning => "Security Scanning"
  | ComplianceAudit => "Compliance Audit"
  | CrossForgeDiff => "Cross-Forge Diff"
  | BulkOperations => "Bulk Operations"
  | OfflineConfig => "Offline Config"
  }
}

/// Short description for each capability.
let capabilityDescription = (cap: forgeOpsCapability): string => {
  switch cap {
  | RepoInventory => "List and monitor all repos across GitHub, GitLab, and Bitbucket with forge presence badges"
  | MirrorManagement => "View mirror sync status, trigger force sync, configure mirror.yml and instant-sync.yml"
  | BranchProtection => "Set branch protection rules (required reviews, status checks, signed commits) across all forges"
  | CiCdMonitoring => "Monitor GitHub Actions, GitLab CI, and Bitbucket Pipelines — run status, badges, workflow health"
  | SecretManagement => "Audit repository secrets (GITLAB_TOKEN, BITBUCKET_TOKEN, etc.) across forges"
  | WebhookManagement => "Create, edit, delete webhooks with delivery history and SSL verification enforcement"
  | ReleaseManagement => "Manage tags, releases, and artifacts across all three forges"
  | SecurityScanning => "Dependabot alerts, code scanning, secret scanning, security advisory management"
  | ComplianceAudit => "Evaluate repos against RSR policy — license, mirroring, workflows, protection rules"
  | CrossForgeDiff => "Compare settings across GitHub, GitLab, and Bitbucket to detect drift"
  | BulkOperations => "Apply protection rules, enable features, or fix compliance across all repos at once"
  | OfflineConfig => "Download repo configs as JSON, edit offline, upload with diff and dry-run preview"
  }
}
