// SPDX-License-Identifier: PMPL-1.0-or-later

/// ForgeOps Protection Editor — Branch protection rule viewer/editor.
///
/// Shows branch protection rules for the selected repo across all three
/// forges side by side. Each rule displays its configuration as a grid
/// of toggles, with indicators for which forges have the rule and whether
/// they agree.
///
/// Layout:
///   +------------------------------------------------------------+
///   | Branch: main                                  [Add Rule]   |
///   +------------------------------------------------------------+
///   |                     | GitHub | GitLab | Bitbucket          |
///   +------------------------------------------------------------+
///   | Require PR          | ON     | ON     | ON        | Match  |
///   | Required Approvals  | 1      | 1      | 0         | DRIFT  |
///   | Require Status Chk  | ON     | ON     | --        | PARTIAL|
///   | Signed Commits      | OFF    | --     | --        | OK     |
///   | Force Push          | OFF    | OFF    | OFF       | Match  |
///   | Allow Deletion      | OFF    | OFF    | OFF       | Match  |
///   +------------------------------------------------------------+

open ForgeOpsModel
open Tea.Html

// ============================================================================
// Protection rule comparison row
// ============================================================================

/// Render the value of a protection field for a specific forge.
let renderProtectionValue = (
  rules: array<branchProtection>,
  forgeId: forgeId,
  getter: branchProtection => string,
): Tea_Vdom.t<'msg> => {
  let rule = rules->Array.find(r => r.forgeId === forgeId)
  switch rule {
  | Some(r) =>
    let value = getter(r)
    let colourClass = if value === "ON" || value === "true" {
      "text-green-400"
    } else if value === "OFF" || value === "false" {
      "text-gray-400"
    } else {
      "text-gray-200"
    }
    span(
      list{Attrs.class_(`text-sm font-mono ${colourClass}`)},
      list{text(value)},
    )
  | None =>
    span(
      list{Attrs.class_("text-sm font-mono text-gray-600 italic")},
      list{text("--")},
    )
  }
}

/// Check if a protection field is consistent across all present forges.
let fieldConsistent = (
  rules: array<branchProtection>,
  getter: branchProtection => string,
): bool => {
  let values = rules->Array.map(getter)
  switch Array.get(values, 0) {
  | Some(first) => values->Array.every(v => v === first)
  | None => true
  }
}

/// Render a single protection comparison row.
let renderComparisonRow = (
  label: string,
  rules: array<branchProtection>,
  getter: branchProtection => string,
): Tea_Vdom.t<'msg> => {
  let consistent = fieldConsistent(rules, getter)
  let allPresent = Array.length(rules) === 3

  div(
    list{
      Attrs.class_(
        `flex items-center py-1.5 px-3 hover:bg-gray-800/30${if !consistent { " bg-yellow-950/20" } else { "" }}`,
      ),
    },
    list{
      // Field label
      div(
        list{Attrs.class_("text-sm text-gray-300 flex-1")},
        list{text(label)},
      ),
      // GitHub value
      div(
        list{Attrs.class_("w-24 text-center")},
        list{renderProtectionValue(rules, GitHub, getter)},
      ),
      // GitLab value
      div(
        list{Attrs.class_("w-24 text-center")},
        list{renderProtectionValue(rules, GitLab, getter)},
      ),
      // Bitbucket value
      div(
        list{Attrs.class_("w-24 text-center")},
        list{renderProtectionValue(rules, Bitbucket, getter)},
      ),
      // Status
      div(
        list{Attrs.class_("w-20 text-center")},
        list{
          if !consistent {
            span(
              list{Attrs.class_("text-xs text-yellow-400 font-medium")},
              list{text("DRIFT")},
            )
          } else if !allPresent {
            span(
              list{Attrs.class_("text-xs text-gray-500")},
              list{text("PARTIAL")},
            )
          } else {
            span(
              list{Attrs.class_("text-xs text-green-400")},
              list{text("Match")},
            )
          },
        },
      ),
    },
  )
}

// ============================================================================
// Table header
// ============================================================================

/// Render the protection comparison table header.
let renderHeader = (): Tea_Vdom.t<'msg> => {
  let headerCell = (label: string, extraClass: string) =>
    div(
      list{Attrs.class_(`text-xs text-gray-500 font-medium py-2 px-2 ${extraClass}`)},
      list{text(label)},
    )

  div(
    list{Attrs.class_("flex border-b border-gray-700")},
    list{
      headerCell("Rule", "flex-1 text-left"),
      headerCell("GitHub", "w-24 text-center"),
      headerCell("GitLab", "w-24 text-center"),
      headerCell("Bitbucket", "w-24 text-center"),
      headerCell("Status", "w-20 text-center"),
    },
  )
}

// ============================================================================
// Branch group
// ============================================================================

/// Render all protection rules for a single branch pattern, compared across forges.
let renderBranchGroup = (
  pattern: string,
  rules: array<branchProtection>,
): Tea_Vdom.t<'msg> => {
  div(
    list{Attrs.class_("mb-4")},
    list{
      // Branch header
      div(
        list{Attrs.class_("flex items-center gap-2 px-3 py-1.5 bg-gray-800/50 rounded-t")},
        list{
          span(
            list{Attrs.class_("text-sm font-mono text-indigo-300")},
            list{text(pattern)},
          ),
          span(
            list{Attrs.class_("text-xs text-gray-500")},
            list{text(`(${Int.toString(Array.length(rules))} forges)`)},
          ),
        },
      ),
      // Comparison table
      renderHeader(),
      div(
        list{Attrs.class_("divide-y divide-gray-800/30")},
        list{
          renderComparisonRow("Require PR", rules, r =>
            if r.requirePullRequest { "ON" } else { "OFF" }
          ),
          renderComparisonRow("Required Approvals", rules, r =>
            Int.toString(r.requiredApprovals)
          ),
          renderComparisonRow("Require Status Checks", rules, r =>
            if r.requireStatusChecks { "ON" } else { "OFF" }
          ),
          renderComparisonRow("Signed Commits", rules, r =>
            if r.requireSignedCommits { "ON" } else { "OFF" }
          ),
          renderComparisonRow("Linear History", rules, r =>
            if r.requireLinearHistory { "ON" } else { "OFF" }
          ),
          renderComparisonRow("Allow Force Push", rules, r =>
            if r.allowForcePush { "ON" } else { "OFF" }
          ),
          renderComparisonRow("Allow Deletion", rules, r =>
            if r.allowDeletion { "ON" } else { "OFF" }
          ),
          renderComparisonRow("Enforce Admins", rules, r =>
            if r.enforceAdmins { "ON" } else { "OFF" }
          ),
        },
      ),
    },
  )
}

// ============================================================================
// Main view
// ============================================================================

/// Render the complete branch protection editor for a repo.
/// Groups protection rules by branch pattern and compares across forges.
let view = (
  protectionRules: array<branchProtection>,
  selectedRepoName: option<string>,
  _loading: bool,
): Tea_Vdom.t<'msg> => {
  // Filter to selected repo
  let repoRules = switch selectedRepoName {
  | Some(name) => protectionRules->Array.filter(r => r.repoName === name)
  | None => protectionRules
  }

  // Group by branch pattern
  let patterns: Dict.t<array<branchProtection>> = Dict.make()
  Array.forEach(repoRules, rule => {
    let existing = switch Dict.get(patterns, rule.pattern) {
    | Some(arr) => arr
    | None => []
    }
    Dict.set(patterns, rule.pattern, Array.concat(existing, [rule]))
  })

  div(
    list{
      Attrs.class_("flex-1 overflow-y-auto"),
      Attrs.role("region"),
      Attrs.ariaLabel("Branch Protection Editor"),
    },
    list{
      // Header
      div(
        list{Attrs.class_("flex items-center justify-between px-3 py-2 mb-2")},
        list{
          div(
            list{Attrs.class_("text-xs text-gray-500 font-medium")},
            list{text("BRANCH PROTECTION RULES")},
          ),
          switch selectedRepoName {
          | Some(name) =>
            span(
              list{Attrs.class_("text-xs text-gray-400 font-mono")},
              list{text(name)},
            )
          | None =>
            span(
              list{Attrs.class_("text-xs text-gray-600 italic")},
              list{text("Select a repo")},
            )
          },
        },
      ),
      // Branch groups
      if Array.length(repoRules) === 0 {
        div(
          list{Attrs.class_("text-sm text-gray-600 italic py-4 px-3")},
          list{
            text(
              switch selectedRepoName {
              | Some(_) => "No branch protection rules found for this repo."
              | None => "Select a repo to view branch protection rules."
              },
            ),
          },
        )
      } else {
        div(
          list{Attrs.class_("space-y-4")},
          Dict.keysToArray(patterns)
          ->Array.map(pattern => {
            let rules = switch Dict.get(patterns, pattern) {
            | Some(arr) => arr
            | None => []
            }
            renderBranchGroup(pattern, rules)
          })
          ->List.fromArray,
        )
      },
    },
  )
}
