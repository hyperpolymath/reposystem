// SPDX-License-Identifier: PMPL-1.0-or-later

/// ForgeOps Mirror Panel — Dedicated mirror management dashboard.
///
/// Shows mirror relationships between forges as a status table with
/// sync indicators, force-sync buttons, and mirror configuration.
/// This is a dedicated panel (not the settings grid) that appears when
/// the Mirroring tab is active.
///
/// Layout:
///   +-------------------------------------------------------------+
///   | MIRROR STATUS               [Force Sync All] [Refresh]      |
///   +-------------------------------------------------------------+
///   | Repo               | GH->GL  | GH->BB  | Method   | Action |
///   +-------------------------------------------------------------+
///   | proven-servers      | In Sync | In Sync | Actions  | [Sync] |
///   | panll               | 2 behind| In Sync | Actions  | [Sync] |
///   | ats2-tui            | Failed! | --      | Manual   | [Sync] |
///   +-------------------------------------------------------------+
///   | Summary: 245/265 fully mirrored | 15 behind | 5 failed     |
///   +-------------------------------------------------------------+

open ForgeOpsModel
open Tea.Html

// ============================================================================
// Mirror status badge
// ============================================================================

/// Render a coloured status badge for a mirror sync status.
let renderStatusBadge = (status: mirrorSyncStatus): Tea_Vdom.t<'msg> => {
  let colourClass = ForgeOpsEngine.mirrorStatusColour(status)
  let label = ForgeOpsEngine.mirrorStatusLabel(status)

  span(
    list{Attrs.class_(`text-xs font-mono ${colourClass}`)},
    list{text(label)},
  )
}

/// Render the mirror method badge.
let renderMethodBadge = (method: mirrorMethod): Tea_Vdom.t<'msg> => {
  let (label, colourClass) = switch method {
  | GitHubAction => ("Actions", "text-gray-200 bg-gray-700/60")
  | GitLabPullMirror => ("GL Pull", "text-orange-300 bg-orange-900/40")
  | GitLabPushMirror => ("GL Push", "text-orange-300 bg-orange-900/40")
  | BitbucketPipeline => ("BB Pipe", "text-blue-300 bg-blue-900/40")
  | ManualPush => ("Manual", "text-yellow-300 bg-yellow-900/40")
  | WebhookTrigger => ("Webhook", "text-purple-300 bg-purple-900/40")
  }

  span(
    list{Attrs.class_(`text-xs font-mono px-1.5 py-0.5 rounded ${colourClass}`)},
    list{text(label)},
  )
}

// ============================================================================
// Mirror table row
// ============================================================================

/// Render a single mirror link row in the table.
let renderMirrorRow = (
  link: mirrorLink,
  onForceSync: (string, string) => 'msg,
): Tea_Vdom.t<'msg> => {
  let targetLabel = ForgeOpsCatalog.forgeLabel(link.target)

  div(
    list{Attrs.class_("flex items-center hover:bg-gray-800/30 py-2 px-3 border-b border-gray-800/50")},
    list{
      // Repo name
      div(
        list{Attrs.class_("text-sm text-gray-200 font-mono flex-1")},
        list{text(link.repoName)},
      ),
      // Source -> Target label
      div(
        list{Attrs.class_("text-xs text-gray-500 w-24")},
        list{
          text(`${ForgeOpsCatalog.forgeLabel(link.source)}->${switch link.target {
          | GitHub => "GH"
          | GitLab => "GL"
          | Bitbucket => "BB"
          }}`),
        },
      ),
      // Status
      div(
        list{Attrs.class_("w-28")},
        list{renderStatusBadge(link.status)},
      ),
      // Method
      div(
        list{Attrs.class_("w-24")},
        list{renderMethodBadge(link.method)},
      ),
      // Auto-sync indicator
      div(
        list{Attrs.class_("w-16 text-center")},
        list{
          if link.autoSync {
            span(
              list{Attrs.class_("text-xs text-green-400"), Attrs.title("Auto-sync enabled")},
              list{text("Auto")},
            )
          } else {
            span(
              list{Attrs.class_("text-xs text-gray-600"), Attrs.title("Manual sync only")},
              list{text("Manual")},
            )
          },
        },
      ),
      // Last sync time
      div(
        list{Attrs.class_("text-xs text-gray-500 w-28")},
        list{
          text(switch link.lastSuccess {
          | Some(ts) => ts
          | None => "Never"
          }),
        },
      ),
      // Force sync button
      div(
        list{Attrs.class_("w-16")},
        list{
          button(
            list{
              Attrs.class_("text-xs text-indigo-400 hover:text-indigo-300 cursor-pointer font-medium"),
              Attrs.ariaLabel(`Force sync ${link.repoName} to ${targetLabel}`),
              Events.onClick(onForceSync(link.repoName, targetLabel)),
            },
            list{text("Sync")},
          ),
        },
      ),
    },
  )
}

// ============================================================================
// Table header
// ============================================================================

/// Render the mirror table header.
let renderTableHeader = (): Tea_Vdom.t<'msg> => {
  let headerCell = (label: string, extraClass: string) =>
    div(
      list{Attrs.class_(`text-left text-xs text-gray-500 font-medium py-2 px-3 ${extraClass}`)},
      list{text(label)},
    )

  div(
    list{Attrs.class_("flex border-b border-gray-700")},
    list{
      headerCell("Repository", "flex-1"),
      headerCell("Direction", "w-24"),
      headerCell("Status", "w-28"),
      headerCell("Method", "w-24"),
      headerCell("Sync", "w-16 text-center"),
      headerCell("Last Sync", "w-28"),
      headerCell("Action", "w-16"),
    },
  )
}

// ============================================================================
// Summary bar
// ============================================================================

/// Render the mirror status summary bar.
let renderSummary = (links: array<mirrorLink>): Tea_Vdom.t<'msg> => {
  let total = Array.length(links)
  let inSync = links->Array.filter(l => l.status === InSync)->Array.length
  let behind = links->Array.filter(l =>
    switch l.status {
    | Behind(_) => true
    | _ => false
    }
  )->Array.length
  let failed = links->Array.filter(l =>
    switch l.status {
    | SyncFailed(_) => true
    | _ => false
    }
  )->Array.length
  let neverSynced = links->Array.filter(l => l.status === NeverSynced)->Array.length

  div(
    list{Attrs.class_("flex items-center gap-4 px-3 py-2 border-t border-gray-800 text-xs")},
    list{
      span(
        list{Attrs.class_("text-green-400")},
        list{text(`${Int.toString(inSync)}/${Int.toString(total)} in sync`)},
      ),
      if behind > 0 {
        span(
          list{Attrs.class_("text-yellow-400")},
          list{text(`${Int.toString(behind)} behind`)},
        )
      } else {
        noNode
      },
      if failed > 0 {
        span(
          list{Attrs.class_("text-red-400")},
          list{text(`${Int.toString(failed)} failed`)},
        )
      } else {
        noNode
      },
      if neverSynced > 0 {
        span(
          list{Attrs.class_("text-gray-500")},
          list{text(`${Int.toString(neverSynced)} never synced`)},
        )
      } else {
        noNode
      },
    },
  )
}

// ============================================================================
// Unmirrored repos section
// ============================================================================

/// Render a compact list of repos missing from one or more forges.
let renderUnmirroredRepos = (repos: array<forgeRepo>): Tea_Vdom.t<'msg> => {
  let unmirrored = ForgeOpsEngine.unmirroredRepos(repos)

  if Array.length(unmirrored) === 0 {
    noNode
  } else {
    div(
      list{Attrs.class_("mt-3 border-t border-gray-800 pt-3")},
      list{
        div(
          list{Attrs.class_("text-xs text-gray-500 font-medium mb-2")},
          list{text(`MISSING MIRRORS (${Int.toString(Array.length(unmirrored))})`)},
        ),
        div(
          list{Attrs.class_("space-y-1 max-h-32 overflow-y-auto")},
          unmirrored
          ->Array.map(repo => {
            let badge = ForgeOpsEngine.forgePresenceBadge(repo)
            div(
              list{Attrs.class_("text-xs flex items-center gap-2 px-3 py-1 bg-red-950/20 rounded")},
              list{
                span(
                  list{Attrs.class_("text-gray-300 font-mono")},
                  list{text(repo.name)},
                ),
                span(
                  list{Attrs.class_("text-gray-500")},
                  list{text(`(${badge})`)},
                ),
                if Option.isNone(repo.gitLab) {
                  span(
                    list{Attrs.class_("text-red-400")},
                    list{text("Missing GL")},
                  )
                } else {
                  noNode
                },
                if Option.isNone(repo.bitbucket) {
                  span(
                    list{Attrs.class_("text-red-400")},
                    list{text("Missing BB")},
                  )
                } else {
                  noNode
                },
              },
            )
          })
          ->List.fromArray,
        ),
      },
    )
  }
}

// ============================================================================
// Main mirror panel view
// ============================================================================

/// Render the complete mirror management panel.
let view = (
  mirrorLinks: array<mirrorLink>,
  repos: array<forgeRepo>,
  loading: bool,
  onForceSync: (string, string) => 'msg,
  onForceSyncAll: 'msg,
  onRefresh: 'msg,
): Tea_Vdom.t<'msg> => {
  let buttonClass = "text-xs font-medium px-2.5 py-1 rounded cursor-pointer transition-colors"
  let primaryClass = `${buttonClass} bg-indigo-600 hover:bg-indigo-500 text-white`
  let secondaryClass = `${buttonClass} bg-gray-700 hover:bg-gray-600 text-gray-200`
  let disabledClass = `${buttonClass} bg-gray-800 text-gray-600 cursor-not-allowed`

  div(
    list{
      Attrs.class_("flex-1 overflow-y-auto"),
      Attrs.role("region"),
      Attrs.ariaLabel("Mirror Management"),
    },
    list{
      // Header with action buttons
      div(
        list{Attrs.class_("flex items-center justify-between px-3 py-2 border-b border-gray-800")},
        list{
          div(
            list{Attrs.class_("text-xs text-gray-500 font-medium")},
            list{text("MIRROR STATUS")},
          ),
          div(
            list{Attrs.class_("flex items-center gap-2")},
            list{
              button(
                list{
                  Attrs.class_(if !loading { primaryClass } else { disabledClass }),
                  Attrs.ariaLabel("Force sync all mirrors"),
                  if !loading {
                    Events.onClick(onForceSyncAll)
                  } else {
                    Attrs.noProp
                  },
                },
                list{text("Force Sync All")},
              ),
              button(
                list{
                  Attrs.class_(if !loading { secondaryClass } else { disabledClass }),
                  Attrs.ariaLabel("Refresh mirror status"),
                  if !loading {
                    Events.onClick(onRefresh)
                  } else {
                    Attrs.noProp
                  },
                },
                list{text("Refresh")},
              ),
            },
          ),
        },
      ),
      // Mirror table
      if Array.length(mirrorLinks) === 0 {
        div(
          list{Attrs.class_("text-sm text-gray-600 italic py-4 px-3")},
          list{text(if loading { "Loading mirror status..." } else { "No mirror links found. Set up mirroring in the settings." })},
        )
      } else {
        div(
          list{},
          list{
            renderTableHeader(),
            div(
              list{},
              mirrorLinks
              ->Array.map(link => renderMirrorRow(link, onForceSync))
              ->List.fromArray,
            ),
            renderSummary(mirrorLinks),
          },
        )
      },
      // Unmirrored repos section
      renderUnmirroredRepos(repos),
    },
  )
}
