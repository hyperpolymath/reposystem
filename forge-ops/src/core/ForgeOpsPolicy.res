// SPDX-License-Identifier: PMPL-1.0-or-later

/// ForgeOps Policy — RSR compliance constraint definitions.
///
/// Defines the security and compliance policy that all repos should meet.
/// These represent the RSR (Rhodium Standard Repository) requirements plus
/// hyperpolymath-specific rules (mirroring, Hypatia, workflow standards).
///
/// In the future, constraints will load from Nickel (.k9.ncl) policy files
/// and/or A2ML Trustfile definitions. Currently hardcoded.

open ForgeOpsModel

// ============================================================================
// Default RSR policy constraints
// ============================================================================

let defaultConstraints: array<policyConstraint> = [
  // --- Repos ---
  {
    id: "default_branch",
    expression: "default_branch == \"main\"",
    category: Repos,
    enabled: true,
    severity: High,
    description: "RSR requires 'main' as the default branch name.",
    appliesTo: None,
  },
  {
    id: "has_issues",
    expression: "has_issues == true",
    category: Repos,
    enabled: true,
    severity: Medium,
    description: "Issue tracker should be enabled for bug reports and feature requests.",
    appliesTo: None,
  },
  {
    id: "has_wiki",
    expression: "has_wiki == false",
    category: Repos,
    enabled: true,
    severity: Low,
    description: "RSR prefers docs/ in-repo over wiki. Wiki should be disabled.",
    appliesTo: None,
  },
  {
    id: "license",
    expression: "license == \"PMPL-1.0-or-later\"",
    category: Repos,
    enabled: true,
    severity: Critical,
    description: "All hyperpolymath repos must use PMPL-1.0-or-later (or MPL-2.0 fallback with reason).",
    appliesTo: None,
  },
  {
    id: "delete_branch_on_merge",
    expression: "delete_branch_on_merge == true",
    category: Repos,
    enabled: true,
    severity: Low,
    description: "Auto-delete head branches after merge to keep the repo clean.",
    appliesTo: None,
  },

  // --- Mirroring ---
  {
    id: "mirror_to_gitlab",
    expression: "mirror_to_gitlab == true",
    category: Mirroring,
    enabled: true,
    severity: Critical,
    description: "RSR requires all repos mirrored to GitLab (hyperpolymath account).",
    appliesTo: None,
  },
  {
    id: "mirror_to_bitbucket",
    expression: "mirror_to_bitbucket == true",
    category: Mirroring,
    enabled: true,
    severity: Critical,
    description: "RSR requires all repos mirrored to Bitbucket (hyperpolymath account).",
    appliesTo: None,
  },
  {
    id: "mirror_auto_sync",
    expression: "mirror_auto_sync == true",
    category: Mirroring,
    enabled: true,
    severity: High,
    description: "Mirror sync should be automated, not manual.",
    appliesTo: None,
  },
  {
    id: "mirror_instant_sync",
    expression: "mirror_instant_sync == true",
    category: Mirroring,
    enabled: true,
    severity: Medium,
    description: "Instant-sync.yml workflow provides immediate propagation on every push.",
    appliesTo: Some(GitHub),
  },

  // --- Protection ---
  {
    id: "protect_main",
    expression: "protect_main == true",
    category: Protection,
    enabled: true,
    severity: Critical,
    description: "The default branch must have branch protection enabled.",
    appliesTo: None,
  },
  {
    id: "require_pull_request",
    expression: "require_pull_request == true",
    category: Protection,
    enabled: true,
    severity: High,
    description: "No direct pushes to main — all changes must go through a PR/MR.",
    appliesTo: None,
  },
  {
    id: "allow_force_push",
    expression: "allow_force_push == false",
    category: Protection,
    enabled: true,
    severity: Critical,
    description: "Force push to main must be prohibited. Prevents history rewriting.",
    appliesTo: None,
  },
  {
    id: "allow_deletion",
    expression: "allow_deletion == false",
    category: Protection,
    enabled: true,
    severity: Critical,
    description: "Deleting the main branch must be prohibited.",
    appliesTo: None,
  },

  // --- CI/CD ---
  {
    id: "hypatia_scan",
    expression: "hypatia_scan == true",
    category: CiCd,
    enabled: true,
    severity: Critical,
    description: "RSR requires hypatia-scan.yml workflow for neurosymbolic CI intelligence.",
    appliesTo: Some(GitHub),
  },
  {
    id: "codeql_enabled",
    expression: "codeql_enabled == true",
    category: CiCd,
    enabled: true,
    severity: High,
    description: "RSR requires codeql.yml for code analysis.",
    appliesTo: Some(GitHub),
  },
  {
    id: "scorecard_enabled",
    expression: "scorecard_enabled == true",
    category: CiCd,
    enabled: true,
    severity: High,
    description: "RSR requires scorecard.yml for OpenSSF Scorecard.",
    appliesTo: Some(GitHub),
  },

  // --- Secrets ---
  {
    id: "has_gitlab_token",
    expression: "has_gitlab_token == true",
    category: Secrets,
    enabled: true,
    severity: High,
    description: "GITLAB_TOKEN secret required for mirror.yml workflow.",
    appliesTo: Some(GitHub),
  },
  {
    id: "has_bitbucket_token",
    expression: "has_bitbucket_token == true",
    category: Secrets,
    enabled: true,
    severity: High,
    description: "BITBUCKET_TOKEN secret required for mirror.yml workflow.",
    appliesTo: Some(GitHub),
  },

  // --- Webhooks ---
  {
    id: "webhook_ssl_verify",
    expression: "webhook_ssl_verify == true",
    category: Webhooks,
    enabled: true,
    severity: Critical,
    description: "SSL verification must be enabled for all webhooks. Disabling allows MITM.",
    appliesTo: None,
  },

  // --- Security ---
  {
    id: "dependabot_alerts",
    expression: "dependabot_alerts == true",
    category: Security,
    enabled: true,
    severity: High,
    description: "Dependabot alerts should be enabled for vulnerability notification.",
    appliesTo: Some(GitHub),
  },
  {
    id: "secret_scanning",
    expression: "secret_scanning == true",
    category: Security,
    enabled: true,
    severity: Critical,
    description: "Secret scanning detects accidentally committed credentials.",
    appliesTo: Some(GitHub),
  },
  {
    id: "secret_scanning_push_protection",
    expression: "secret_scanning_push_protection == true",
    category: Security,
    enabled: true,
    severity: Critical,
    description: "Push protection blocks commits containing known secret patterns.",
    appliesTo: Some(GitHub),
  },
  {
    id: "security_policy",
    expression: "security_policy == true",
    category: Security,
    enabled: true,
    severity: High,
    description: "RSR requires SECURITY.md with vulnerability disclosure instructions.",
    appliesTo: None,
  },
]

// ============================================================================
// Policy evaluation helpers
// ============================================================================

/// Get all enabled constraints.
let enabledConstraints = (): array<policyConstraint> => {
  defaultConstraints->Array.filter(c => c.enabled)
}

/// Get constraints for a specific category.
let constraintsByCategory = (cat: forgeCategory): array<policyConstraint> => {
  defaultConstraints->Array.filter(c => c.category === cat)
}

/// Find a constraint by its setting ID.
let findConstraint = (id: string): option<policyConstraint> => {
  defaultConstraints->Array.find(c => c.id === id)
}

/// Run a full audit of settings against the policy for a given repo.
let auditSettings = (
  repoName: string,
  settings: array<forgeSetting>,
): auditResult => {
  let enabledC = enabledConstraints()
  let findings = ref([])

  Array.forEach(settings, setting => {
    switch findConstraint(setting.id) {
    | None => ()
    | Some(rule) =>
      if rule.enabled {
        let currentStr = ForgeOpsEngine.settingValueToString(setting.value)
        let expectedStr = ForgeOpsEngine.settingValueToString(setting.defaultValue)

        let matches = switch (setting.value, setting.defaultValue) {
        | (BoolValue(a), BoolValue(b)) => a === b
        | (StringValue(a), StringValue(b)) => a === b
        | (IntValue(a), IntValue(b)) => a === b
        | _ => currentStr === expectedStr
        }

        if !matches {
          findings := Array.concat(findings.contents, [{
            repoName,
            settingId: setting.id,
            category: setting.category,
            forgeId: setting.forgeId,
            severity: rule.severity,
            message: `${rule.expression}: expected ${expectedStr}, got ${currentStr}`,
            currentValue: currentStr,
            expectedValue: expectedStr,
            autoFixable: setting.editable,
          }])
        }
      }
    }
  })

  let totalConstrained = enabledC->Array.length
  let failedCount = Array.length(findings.contents)
  let passedCount = totalConstrained - failedCount
  let warningCount = findings.contents->Array.filter(f =>
    switch f.severity {
    | Medium | Low => true
    | _ => false
    }
  )->Array.length

  let score = if totalConstrained > 0 {
    Int.toFloat(passedCount) /. Int.toFloat(totalConstrained)
  } else {
    1.0
  }

  {
    timestamp: "now", // TODO: use Date.now() ISO 8601
    repos: [repoName],
    findings: ForgeOpsEngine.sortFindingsBySeverity(findings.contents),
    passed: passedCount,
    failed: failedCount,
    warnings: warningCount,
    score,
  }
}

/// Run audit across multiple repos.
let auditMultipleRepos = (
  repos: array<string>,
  settingsPerRepo: array<(string, array<forgeSetting>)>,
): auditResult => {
  let allFindings = ref([])
  let totalPassed = ref(0)
  let totalFailed = ref(0)

  Array.forEach(settingsPerRepo, ((repoName, settings)) => {
    let result = auditSettings(repoName, settings)
    allFindings := Array.concat(allFindings.contents, result.findings)
    totalPassed := totalPassed.contents + result.passed
    totalFailed := totalFailed.contents + result.failed
  })

  let total = totalPassed.contents + totalFailed.contents
  let score = if total > 0 {
    Int.toFloat(totalPassed.contents) /. Int.toFloat(total)
  } else {
    1.0
  }

  {
    timestamp: "now",
    repos,
    findings: ForgeOpsEngine.sortFindingsBySeverity(allFindings.contents),
    passed: totalPassed.contents,
    failed: totalFailed.contents,
    warnings: allFindings.contents->Array.filter(f =>
      switch f.severity {
      | Medium | Low => true
      | _ => false
      }
    )->Array.length,
    score,
  }
}
