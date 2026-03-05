// SPDX-License-Identifier: PMPL-1.0-or-later

/// ForgeOps Diff Viewer — Cross-forge settings comparison display.
///
/// Shows differences between GitHub, GitLab, Bitbucket, and RSR policy
/// values for shared repo settings. Each diff entry displays the four
/// values side by side with colour-coded consistency indicators.
///
/// Layout:
///   +-------------+--------+--------+--------+--------+----------+
///   | Setting     | GitHub | GitLab | BB     | Policy | Status   |
///   +-------------+--------+--------+--------+--------+----------+
///   | visibility  | public | public | public | public | OK       |
///   | has_issues  | true   | true   | false  | true   | DRIFT    |
///   | has_wiki    | false  | --     | false  | false  | OK       |
///   +-------------+--------+--------+--------+--------+----------+
///   | 2 inconsistent | 3 missing | 42 settings match             |
///   +------------------------------------------------------------+

open ForgeOpsModel
open Tea.Html

// ============================================================================
// Diff entry rendering
// ============================================================================

/// CSS class for a value based on whether it matches the policy.
let valueClass = (value: option<string>, policyValue: option<string>): string => {
  switch (value, policyValue) {
  | (Some(v), Some(p)) =>
    if v === p { "text-green-400" } else { "text-red-400" }
  | (None, _) => "text-gray-600 italic"
  | (_, None) => "text-gray-400"
  }
}

/// Render a single diff entry row.
let renderDiffEntry = (entry: forgeDiffEntry): Tea_Vdom.t<'msg> => {
  let ghDisplay = switch entry.gitHubValue {
  | Some(v) => v
  | None => "--"
  }
  let glDisplay = switch entry.gitLabValue {
  | Some(v) => v
  | None => "--"
  }
  let bbDisplay = switch entry.bitbucketValue {
  | Some(v) => v
  | None => "--"
  }
  let policyDisplay = switch entry.policyValue {
  | Some(v) => v
  | None => "--"
  }

  let hasMissing =
    Option.isNone(entry.gitHubValue)
    || Option.isNone(entry.gitLabValue)
    || Option.isNone(entry.bitbucketValue)

  let rowBg = if !entry.consistent && hasMissing {
    " bg-red-950/20"
  } else if !entry.consistent {
    " bg-yellow-950/20"
  } else {
    ""
  }

  div(
    list{Attrs.class_(`flex hover:bg-gray-800/30${rowBg}`)},
    list{
      // Setting ID
      div(
        list{Attrs.class_("py-1.5 px-2 text-sm text-gray-300 font-mono flex-1")},
        list{text(entry.settingId)},
      ),
      // GitHub value
      div(
        list{Attrs.class_(`py-1.5 px-2 text-sm font-mono w-24 ${valueClass(entry.gitHubValue, entry.policyValue)}`)},
        list{text(ghDisplay)},
      ),
      // GitLab value
      div(
        list{Attrs.class_(`py-1.5 px-2 text-sm font-mono w-24 ${valueClass(entry.gitLabValue, entry.policyValue)}`)},
        list{text(glDisplay)},
      ),
      // Bitbucket value
      div(
        list{Attrs.class_(`py-1.5 px-2 text-sm font-mono w-24 ${valueClass(entry.bitbucketValue, entry.policyValue)}`)},
        list{text(bbDisplay)},
      ),
      // Policy value
      div(
        list{Attrs.class_("py-1.5 px-2 text-sm font-mono w-24 text-gray-500")},
        list{text(policyDisplay)},
      ),
      // Status indicator
      div(
        list{Attrs.class_("py-1.5 px-2 w-24")},
        list{
          if !entry.consistent {
            span(
              list{Attrs.class_("text-xs text-yellow-400 font-medium")},
              list{text("DRIFT")},
            )
          } else if hasMissing {
            span(
              list{Attrs.class_("text-xs text-gray-500 font-medium")},
              list{text("PARTIAL")},
            )
          } else {
            span(
              list{Attrs.class_("text-xs text-green-400")},
              list{text("OK")},
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

/// Render the diff table header.
let renderDiffHeader = (): Tea_Vdom.t<'msg> => {
  let headerCell = (label: string, extraClass: string) =>
    div(
      list{Attrs.class_(`text-left text-xs text-gray-500 font-medium py-2 px-2 ${extraClass}`)},
      list{text(label)},
    )

  div(
    list{Attrs.class_("flex border-b border-gray-800")},
    list{
      headerCell("Setting", "flex-1"),
      headerCell("GitHub", "w-24"),
      headerCell("GitLab", "w-24"),
      headerCell("Bitbucket", "w-24"),
      headerCell("Policy", "w-24"),
      headerCell("Status", "w-24"),
    },
  )
}

// ============================================================================
// Compact side-panel view
// ============================================================================

/// Render the diff viewer as a compact side panel.
/// Shows only inconsistent entries with a summary bar.
let view = (
  forgeDiff: option<forgeDiff>,
  _loading: bool,
): Tea_Vdom.t<'msg> => {
  div(
    list{
      Attrs.class_("w-72 border-l border-gray-800 p-3 overflow-y-auto"),
      Attrs.role("region"),
      Attrs.ariaLabel("Cross-Forge Diff Viewer"),
    },
    list{
      div(
        list{Attrs.class_("text-xs text-gray-500 mb-3 font-medium")},
        list{text("CROSS-FORGE DIFF")},
      ),
      switch forgeDiff {
      | None =>
        div(
          list{Attrs.class_("text-sm text-gray-600 italic")},
          list{text("Select repos and click 'Compare' to see cross-forge differences.")},
        )
      | Some(diff) =>
        div(
          list{},
          list{
            // Summary bar
            div(
              list{Attrs.class_("flex items-center gap-3 mb-3 text-xs")},
              list{
                span(
                  list{Attrs.class_("text-yellow-400")},
                  list{text(`${Int.toString(diff.inconsistentCount)} inconsistent`)},
                ),
                span(
                  list{Attrs.class_("text-gray-500")},
                  list{text(`${Int.toString(diff.missingCount)} missing`)},
                ),
                span(
                  list{Attrs.class_("text-green-400")},
                  list{
                    text(
                      `${Int.toString(
                        Array.length(diff.entries) - diff.inconsistentCount,
                      )} OK`,
                    ),
                  },
                ),
              },
            ),
            // Inconsistent entries only (compact for side panel)
            div(
              list{Attrs.class_("space-y-1")},
              diff.entries
              ->Array.filter(e => !e.consistent)
              ->Array.map(entry => {
                let ghDisplay = switch entry.gitHubValue {
                | Some(v) => v
                | None => "--"
                }
                let glDisplay = switch entry.gitLabValue {
                | Some(v) => v
                | None => "--"
                }
                let bbDisplay = switch entry.bitbucketValue {
                | Some(v) => v
                | None => "--"
                }
                div(
                  list{Attrs.class_("text-xs p-2 bg-gray-800/50 rounded")},
                  list{
                    div(
                      list{Attrs.class_("font-mono text-gray-300 mb-1")},
                      list{text(entry.settingId)},
                    ),
                    div(
                      list{Attrs.class_("flex items-center gap-1 flex-wrap")},
                      list{
                        span(
                          list{Attrs.class_("text-gray-400")},
                          list{text(`GH:${ghDisplay}`)},
                        ),
                        span(
                          list{Attrs.class_("text-orange-400")},
                          list{text(`GL:${glDisplay}`)},
                        ),
                        span(
                          list{Attrs.class_("text-blue-400")},
                          list{text(`BB:${bbDisplay}`)},
                        ),
                      },
                    ),
                  },
                )
              })
              ->List.fromArray,
            ),
          },
        )
      },
    },
  )
}

/// Render the diff viewer as a full-width table (for main content area).
let viewExpanded = (
  forgeDiff: option<forgeDiff>,
): Tea_Vdom.t<'msg> => {
  switch forgeDiff {
  | None =>
    div(
      list{Attrs.class_("text-sm text-gray-600 italic px-3 py-4")},
      list{text("No cross-forge diff available. Select repos and compare.")},
    )
  | Some(diff) =>
    div(
      list{Attrs.class_("flex-1 overflow-y-auto")},
      list{
        div(
          list{Attrs.class_("w-full text-left")},
          list{
            renderDiffHeader(),
            div(
              list{},
              diff.entries
              ->Array.map(renderDiffEntry)
              ->List.fromArray,
            ),
          },
        ),
      },
    )
  }
}
