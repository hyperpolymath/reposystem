// SPDX-License-Identifier: PMPL-1.0-or-later

/// ForgeOps — Main git forge management panel (Panel-W composition root).
///
/// Full-screen overlay panel that provides the Panel-W dashboard for managing
/// git forges (GitHub, GitLab, Bitbucket). Contains the repo selector ribbon,
/// category tab bar, settings toggle grid / mirror panel / protection editor,
/// audit side panel, and action bar.
///
/// Layout:
///   +-------------------------------------------------------+
///   | ForgeOps — Git Forge Management    [GH:ok GL:ok BB:!] x |
///   +-------------------------------------------------------+
///   | [Repo Ribbon: chips with GH+GL+BB badges]             |
///   | [Select All] [None] [All|GH|GL|BB] [Filter: ___]     |
///   +-------------------------------------------------------+
///   | Repos|Mirror|Protect|CI/CD|Secrets|...|GH|GL|BB       |  <-- Category tabs
///   +---------------------------+---------------------------+
///   | Settings Grid / Mirror    | Compliance Audit /        |
///   | Panel / Protection Editor | Cross-Forge Diff          |
///   | (depends on active tab)   | (side panel)              |
///   +---------------------------+---------------------------+
///   | [Apply All] [Push] [Download] [Audit] [Compare]       |
///   | Progress: 3/265 repos processed                       |
///   +-------------------------------------------------------+

open ForgeOpsModel
open Tea.Html

// ============================================================================
// Message type — ForgeOps-local TEA messages
// ============================================================================

/// All messages the ForgeOps panel can produce.
type msg =
  // Panel visibility
  | TogglePanel
  // Repo selection
  | ToggleRepo(string)
  | SelectAllRepos
  | DeselectAllRepos
  | SetRepoFilter(string)
  | SetForgeFilter(option<forgeId>)
  // Category tabs
  | SetCategory(forgeCategory)
  | SetSettingFilter(string)
  // Settings
  | ToggleSetting(string)
  | UpdateSettingValue(string, string)
  // Mirror operations
  | ForceSync(string, string)
  | ForceSyncAll
  | RefreshMirrors
  // Bulk actions
  | ApplyCompliance
  | PushChanges
  | DownloadConfig
  | RunAudit
  | CompareCrossForge
  // Side panels
  | ToggleAuditPanel
  | ToggleDiffPanel
  // API results
  | ReposLoaded(result<string, string>)
  | SettingsLoaded(result<string, string>)
  | MirrorStatusLoaded(result<string, string>)
  | ProtectionLoaded(result<string, string>)
  | AuditCompleted(result<string, string>)
  | ComplianceApplied(result<string, string>)
  | ConfigDownloaded(result<string, string>)
  | TokensVerified(result<string, string>)

// ============================================================================
// Category tab bar
// ============================================================================

/// All setting categories in display order.
let allCategories: array<forgeCategory> = [
  Repos,
  Mirroring,
  Protection,
  CiCd,
  Secrets,
  Webhooks,
  Releases,
  Security,
  GitHubSpecific,
  GitLabSpecific,
  BitbucketSpecific,
]

/// Render a single category tab button.
let renderCategoryTab = (
  cat: forgeCategory,
  isActive: bool,
  onSetCategory: forgeCategory => msg,
): Tea_Vdom.t<msg> => {
  let activeClass = isActive
    ? "border-indigo-500 text-indigo-300 bg-gray-800/50"
    : "border-transparent text-gray-500 hover:text-gray-300 hover:border-gray-600"

  // Forge-specific tabs get a subtle forge colour accent
  let accentClass = switch cat {
  | GitHubSpecific => if isActive { "" } else { " hover:text-gray-300" }
  | GitLabSpecific => if isActive { "" } else { " hover:text-orange-300" }
  | BitbucketSpecific => if isActive { "" } else { " hover:text-blue-300" }
  | _ => ""
  }

  button(
    list{
      Attrs.class_(
        `px-3 py-2 text-sm font-medium border-b-2 cursor-pointer transition-colors ${activeClass}${accentClass}`,
      ),
      Attrs.ariaSelected(isActive),
      Attrs.role("tab"),
      Events.onClick(onSetCategory(cat)),
    },
    list{text(ForgeOpsCatalog.categoryLabel(cat))},
  )
}

/// Render the full category tab bar.
let renderCategoryTabBar = (
  activeCategory: forgeCategory,
  onSetCategory: forgeCategory => msg,
): Tea_Vdom.t<msg> => {
  div(
    list{
      Attrs.class_("flex border-b border-gray-800 overflow-x-auto"),
      Attrs.role("tablist"),
      Attrs.ariaLabel("Setting categories"),
    },
    allCategories
    ->Array.map(cat => renderCategoryTab(cat, cat === activeCategory, onSetCategory))
    ->List.fromArray,
  )
}

// ============================================================================
// Connection status bar — shows status for all three forges
// ============================================================================

/// Render a single forge connection indicator dot + label.
let renderForgeConnection = (
  forge: forgeId,
  status: forgeConnectionStatus,
): Tea_Vdom.t<msg> => {
  let label = switch forge {
  | GitHub => "GH"
  | GitLab => "GL"
  | Bitbucket => "BB"
  }

  let (dotClass, statusText) = switch status {
  | Disconnected => ("bg-gray-500", "off")
  | Connecting => ("bg-yellow-400 animate-pulse", "...")
  | Connected(_info) => ("bg-green-400", "ok")
  | ConnectionError(_err) => ("bg-red-400", "err")
  }

  div(
    list{Attrs.class_("flex items-center gap-1")},
    list{
      span(
        list{Attrs.class_(`w-2 h-2 rounded-full ${dotClass}`)},
        list{},
      ),
      span(
        list{Attrs.class_("text-xs text-gray-400")},
        list{text(`${label}:${statusText}`)},
      ),
    },
  )
}

/// Render the connection status for all three forges.
let renderConnectionBar = (connections: forgeConnections): Tea_Vdom.t<msg> => {
  div(
    list{Attrs.class_("flex items-center gap-3 px-3 py-1.5")},
    list{
      renderForgeConnection(GitHub, connections.gitHub),
      renderForgeConnection(GitLab, connections.gitLab),
      renderForgeConnection(Bitbucket, connections.bitbucket),
    },
  )
}

// ============================================================================
// Audit side panel
// ============================================================================

/// Render the audit results summary in the right side panel.
let renderAuditPanel = (
  auditResult: option<auditResult>,
  loading: bool,
): Tea_Vdom.t<msg> => {
  div(
    list{Attrs.class_("w-72 border-l border-gray-800 p-3 overflow-y-auto")},
    list{
      div(
        list{Attrs.class_("text-xs text-gray-500 mb-3 font-medium")},
        list{text("RSR COMPLIANCE AUDIT")},
      ),
      switch auditResult {
      | None =>
        if loading {
          div(
            list{Attrs.class_("text-sm text-gray-500 italic")},
            list{text("Running audit...")},
          )
        } else {
          div(
            list{Attrs.class_("text-sm text-gray-600 italic")},
            list{text("Click 'Audit' to check RSR compliance")},
          )
        }
      | Some(result) =>
        div(
          list{},
          list{
            // Score summary
            div(
              list{Attrs.class_("flex items-center gap-3 mb-3")},
              list{
                div(
                  list{Attrs.class_("text-2xl font-bold text-indigo-300")},
                  list{text(`${Float.toFixed(result.score *. 100.0, ~digits=0)}%`)},
                ),
                div(
                  list{},
                  list{
                    div(
                      list{Attrs.class_("text-xs text-green-400")},
                      list{text(`${Int.toString(result.passed)} passed`)},
                    ),
                    div(
                      list{Attrs.class_("text-xs text-red-400")},
                      list{text(`${Int.toString(result.failed)} failed`)},
                    ),
                    div(
                      list{Attrs.class_("text-xs text-yellow-400")},
                      list{text(`${Int.toString(result.warnings)} warnings`)},
                    ),
                  },
                ),
              },
            ),
            // Repos audited
            div(
              list{Attrs.class_("text-xs text-gray-500 mb-2")},
              list{text(`${Int.toString(Array.length(result.repos))} repos audited`)},
            ),
            // Findings list
            div(
              list{Attrs.class_("space-y-2")},
              result.findings
              ->ForgeOpsEngine.sortFindingsBySeverity
              ->Array.map(finding =>
                div(
                  list{Attrs.class_("text-xs p-2 bg-gray-800/50 rounded")},
                  list{
                    div(
                      list{Attrs.class_("flex items-center gap-1.5 mb-1")},
                      list{
                        span(
                          list{Attrs.class_(`font-bold ${ForgeOpsEngine.severityColour(finding.severity)}`)},
                          list{text(ForgeOpsEngine.severityLabel(finding.severity))},
                        ),
                        span(
                          list{Attrs.class_("text-gray-300 font-mono")},
                          list{text(finding.settingId)},
                        ),
                      },
                    ),
                    div(
                      list{Attrs.class_("text-gray-500 mb-0.5")},
                      list{text(finding.repoName)},
                    ),
                    div(
                      list{Attrs.class_("text-gray-400")},
                      list{text(finding.message)},
                    ),
                    if finding.autoFixable {
                      span(
                        list{Attrs.class_("text-xs text-indigo-400 mt-1")},
                        list{text("Auto-fixable")},
                      )
                    } else {
                      noNode
                    },
                  },
                )
              )
              ->List.fromArray,
            ),
          },
        )
      },
    },
  )
}

// ============================================================================
// Action bar
// ============================================================================

/// Render the bottom action bar with Apply, Push, Download, Audit, Compare buttons.
let renderActionBar = (
  selectedCount: int,
  totalCount: int,
  loading: bool,
  bulkProgress: option<bulkProgress>,
): Tea_Vdom.t<msg> => {
  let buttonClass = "px-3 py-1.5 text-sm font-medium rounded cursor-pointer transition-colors"
  let primaryClass = `${buttonClass} bg-indigo-600 hover:bg-indigo-500 text-white`
  let secondaryClass = `${buttonClass} bg-gray-700 hover:bg-gray-600 text-gray-200`
  let disabledClass = `${buttonClass} bg-gray-800 text-gray-600 cursor-not-allowed`

  div(
    list{Attrs.class_("border-t border-gray-800 px-4 py-3 flex items-center justify-between")},
    list{
      // Action buttons
      div(
        list{Attrs.class_("flex items-center gap-2")},
        list{
          button(
            list{
              Attrs.class_(if selectedCount > 0 && !loading { primaryClass } else { disabledClass }),
              Attrs.ariaLabel("Apply RSR compliance to selected repos"),
              if selectedCount > 0 && !loading {
                Events.onClick(ApplyCompliance)
              } else {
                Attrs.noProp
              },
            },
            list{text("Apply RSR")},
          ),
          button(
            list{
              Attrs.class_(if !loading { secondaryClass } else { disabledClass }),
              Attrs.ariaLabel("Push local changes to forges"),
              if !loading {
                Events.onClick(PushChanges)
              } else {
                Attrs.noProp
              },
            },
            list{text("Push Changes")},
          ),
          button(
            list{
              Attrs.class_(if !loading { secondaryClass } else { disabledClass }),
              Attrs.ariaLabel("Download offline config"),
              if !loading {
                Events.onClick(DownloadConfig)
              } else {
                Attrs.noProp
              },
            },
            list{text("Download")},
          ),
          button(
            list{
              Attrs.class_(if selectedCount > 0 && !loading { secondaryClass } else { disabledClass }),
              Attrs.ariaLabel("Run RSR compliance audit"),
              if selectedCount > 0 && !loading {
                Events.onClick(RunAudit)
              } else {
                Attrs.noProp
              },
            },
            list{text("Audit")},
          ),
          button(
            list{
              Attrs.class_(if selectedCount > 0 && !loading { secondaryClass } else { disabledClass }),
              Attrs.ariaLabel("Compare settings across forges"),
              if selectedCount > 0 && !loading {
                Events.onClick(CompareCrossForge)
              } else {
                Attrs.noProp
              },
            },
            list{text("Compare")},
          ),
        },
      ),
      // Progress indicator
      switch bulkProgress {
      | None =>
        div(
          list{Attrs.class_("text-xs text-gray-500")},
          list{
            text(`${Int.toString(selectedCount)}/${Int.toString(totalCount)} repos selected`),
          },
        )
      | Some(progress) =>
        div(
          list{Attrs.class_("flex items-center gap-2")},
          list{
            // Progress bar
            div(
              list{Attrs.class_("w-40 h-2 bg-gray-800 rounded-full overflow-hidden")},
              list{
                div(
                  list{
                    Attrs.class_("h-full bg-indigo-500 transition-all"),
                    Attrs.style(
                      "width",
                      `${Float.toFixed(
                        Int.toFloat(progress.completed) /. Int.toFloat(if progress.total > 0 { progress.total } else { 1 }) *. 100.0,
                        ~digits=0,
                      )}%`,
                    ),
                  },
                  list{},
                ),
              },
            ),
            div(
              list{Attrs.class_("text-xs text-gray-400")},
              list{
                text(
                  `${Int.toString(progress.completed)}/${Int.toString(progress.total)} repos`,
                ),
              },
            ),
            switch progress.currentRepo {
            | Some(repo) =>
              span(
                list{Attrs.class_("text-xs text-gray-500 font-mono")},
                list{text(repo)},
              )
            | None => noNode
            },
            if progress.failed > 0 {
              span(
                list{Attrs.class_("text-xs text-red-400")},
                list{text(`${Int.toString(progress.failed)} failed`)},
              )
            } else {
              noNode
            },
          },
        )
      },
    },
  )
}

// ============================================================================
// Main panel view
// ============================================================================

/// Render the complete ForgeOps panel as a full-screen overlay.
/// This is the Panel-W component for the ForgeOps module.
let view = (state: forgeOpsState): Tea_Vdom.t<msg> => {
  div(
    list{
      Attrs.class_("fixed inset-0 z-50 bg-gray-950 flex flex-col"),
      Attrs.role("dialog"),
      Attrs.ariaLabel("ForgeOps — Git Forge Management"),
    },
    list{
      // Header bar with title, connection status, and close button
      div(
        list{Attrs.class_("flex items-center justify-between px-4 py-2 border-b border-gray-800 bg-gray-900/80")},
        list{
          div(
            list{Attrs.class_("flex items-center gap-3")},
            list{
              div(
                list{Attrs.class_("text-lg font-semibold text-gray-200")},
                list{text("ForgeOps")},
              ),
              div(
                list{Attrs.class_("text-xs text-gray-500")},
                list{text("Git Forge Management")},
              ),
            },
          ),
          div(
            list{Attrs.class_("flex items-center gap-3")},
            list{
              renderConnectionBar(state.connections),
              button(
                list{
                  Attrs.class_("text-gray-500 hover:text-gray-300 cursor-pointer text-lg px-2"),
                  Attrs.ariaLabel("Close ForgeOps"),
                  Events.onClick(TogglePanel),
                },
                list{text("x")},
              ),
            },
          ),
        },
      ),

      // Repo selector ribbon
      div(
        list{Attrs.class_("px-4 py-2")},
        list{
          ForgeOpsRepoList.view(
            state.repos,
            state.selectedRepoNames,
            state.filterText,
            state.activeForgeFilter,
            name => ToggleRepo(name),
            SelectAllRepos,
            DeselectAllRepos,
            text => SetRepoFilter(text),
            forge => SetForgeFilter(forge),
          ),
        },
      ),

      // Category tab bar
      div(
        list{Attrs.class_("px-4")},
        list{renderCategoryTabBar(state.activeCategory, cat => SetCategory(cat))},
      ),

      // Main content area: content (left) + optional side panel (right)
      div(
        list{Attrs.class_("flex-1 flex overflow-hidden")},
        list{
          // Main content (left) — depends on active category
          div(
            list{Attrs.class_("flex-1 overflow-y-auto px-4 py-2")},
            list{
              {
                let currentRepoName = Array.get(state.selectedRepoNames, 0)
                switch state.activeCategory {
                | Mirroring =>
                  // Mirror tab shows the dedicated mirror management panel
                  ForgeOpsMirrorPanel.view(
                    state.mirrorLinks,
                    state.repos,
                    state.loading,
                    (repo, target) => ForceSync(repo, target),
                    ForceSyncAll,
                    RefreshMirrors,
                  )
                | Protection =>
                  // Protection tab shows the branch protection comparison editor
                  ForgeOpsProtectionEditor.view(
                    state.protectionRules,
                    currentRepoName,
                    state.loading,
                  )
                | _ =>
                  // All other tabs show the settings toggle grid
                  ForgeOpsSettingsGrid.view(
                    state.settings,
                    state.activeCategory,
                    state.settingFilter,
                    state.exceptions,
                    currentRepoName,
                    id => ToggleSetting(id),
                    (id, value) => UpdateSettingValue(id, value),
                  )
                }
              },
            },
          ),
          // Side panel (right) — audit results or diff viewer
          if state.showAudit {
            renderAuditPanel(state.auditResult, state.loading)
          } else if state.showDiff {
            ForgeOpsDiffViewer.view(state.forgeDiff, state.loading)
          } else {
            noNode
          },
        },
      ),

      // Action bar (bottom)
      renderActionBar(
        Array.length(state.selectedRepoNames),
        Array.length(state.repos),
        state.loading,
        state.bulkProgress,
      ),
    },
  )
}
