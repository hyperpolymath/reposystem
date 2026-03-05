// SPDX-License-Identifier: PMPL-1.0-or-later

/// ForgeOps Repo List — Horizontal repo selector ribbon.
///
/// Renders a scrollable horizontal ribbon of repo chips at the top of
/// the ForgeOps panel. Each chip shows the repo name plus forge presence
/// badges (GH, GL, BB). Users can select/deselect, filter, and use
/// Select All / None shortcuts.
///
/// Layout:
///   [Select All] [None] [All|GH|GL|BB] [Filter: ________]  2/265 selected
///   [x proven-servers GH+GL+BB] [ ats2-tui GH+GL] [x panll GH+GL+BB] ...

open ForgeOpsModel
open Tea.Html

/// Render a single forge presence badge (small coloured tag).
let renderForgeBadge = (forge: forgeId, present: bool): Tea_Vdom.t<'msg> => {
  if present {
    let (label, colourClass) = switch forge {
    | GitHub => ("GH", "text-gray-200 bg-gray-700/60")
    | GitLab => ("GL", "text-orange-300 bg-orange-900/40")
    | Bitbucket => ("BB", "text-blue-300 bg-blue-900/40")
    }
    span(
      list{Attrs.class_(`text-xs font-mono px-1 py-0.5 rounded ${colourClass}`)},
      list{text(label)},
    )
  } else {
    noNode
  }
}

/// Render a single repo chip in the ribbon.
let renderRepoChip = (
  repo: forgeRepo,
  isSelected: bool,
  onToggle: string => 'msg,
): Tea_Vdom.t<'msg> => {
  let borderClass = isSelected
    ? "border-indigo-500 bg-indigo-950/30"
    : "border-gray-700 bg-gray-800/30"

  let archiveIndicator = if repo.archived {
    span(
      list{Attrs.class_("text-xs text-gray-600 ml-1")},
      list{text("(archived)")},
    )
  } else {
    noNode
  }

  button(
    list{
      Attrs.class_(
        `inline-flex items-center gap-1 px-3 py-1.5 rounded border text-sm font-mono cursor-pointer transition-colors ${borderClass} hover:border-indigo-400`,
      ),
      Attrs.ariaPressed(isSelected),
      Attrs.ariaLabel(`${isSelected ? "Deselect" : "Select"} ${repo.name}`),
      Events.onClick(onToggle(repo.name)),
    },
    list{
      span(list{Attrs.class_("text-gray-200")}, list{text(repo.name)}),
      renderForgeBadge(GitHub, Option.isSome(repo.gitHub)),
      renderForgeBadge(GitLab, Option.isSome(repo.gitLab)),
      renderForgeBadge(Bitbucket, Option.isSome(repo.bitbucket)),
      archiveIndicator,
    },
  )
}

/// Render the forge filter buttons (All | GH | GL | BB).
let renderForgeFilter = (
  activeFilter: option<forgeId>,
  onSetFilter: option<forgeId> => 'msg,
): Tea_Vdom.t<'msg> => {
  let buttonClass = (isActive: bool) =>
    if isActive {
      "text-xs font-medium text-indigo-300 border-b-2 border-indigo-500 px-2 py-1 cursor-pointer"
    } else {
      "text-xs text-gray-500 hover:text-gray-300 px-2 py-1 cursor-pointer"
    }

  div(
    list{Attrs.class_("flex items-center gap-0.5")},
    list{
      button(
        list{
          Attrs.class_(buttonClass(Option.isNone(activeFilter))),
          Events.onClick(onSetFilter(None)),
        },
        list{text("All")},
      ),
      button(
        list{
          Attrs.class_(buttonClass(activeFilter === Some(GitHub))),
          Events.onClick(onSetFilter(Some(GitHub))),
        },
        list{text("GH")},
      ),
      button(
        list{
          Attrs.class_(buttonClass(activeFilter === Some(GitLab))),
          Events.onClick(onSetFilter(Some(GitLab))),
        },
        list{text("GL")},
      ),
      button(
        list{
          Attrs.class_(buttonClass(activeFilter === Some(Bitbucket))),
          Events.onClick(onSetFilter(Some(Bitbucket))),
        },
        list{text("BB")},
      ),
    },
  )
}

/// Render the domain filter input.
let renderFilterInput = (
  filterText: string,
  onInput: string => 'msg,
): Tea_Vdom.t<'msg> => {
  div(
    list{Attrs.class_("flex items-center gap-2")},
    list{
      span(
        list{Attrs.class_("text-xs text-gray-500")},
        list{text("Filter:")},
      ),
      input(
        list{
          Attrs.class_("bg-gray-800 border border-gray-700 rounded px-2 py-1 text-sm text-gray-300 w-40 focus:border-indigo-500 focus:outline-none"),
          Attrs.type_("text"),
          Attrs.value(filterText),
          Attrs.placeholder("repo name..."),
          Attrs.ariaLabel("Filter repos"),
          Events.onInput(text => onInput(text)),
        },
        list{},
      ),
    },
  )
}

/// Render the selection control buttons.
let renderSelectionControls = (
  onSelectAll: 'msg,
  onDeselectAll: 'msg,
): Tea_Vdom.t<'msg> => {
  div(
    list{Attrs.class_("flex items-center gap-2")},
    list{
      button(
        list{
          Attrs.class_("text-xs text-indigo-400 hover:text-indigo-300 cursor-pointer font-medium"),
          Events.onClick(onSelectAll),
        },
        list{text("Select All")},
      ),
      span(list{Attrs.class_("text-gray-600")}, list{text("|")}),
      button(
        list{
          Attrs.class_("text-xs text-gray-400 hover:text-gray-300 cursor-pointer font-medium"),
          Events.onClick(onDeselectAll),
        },
        list{text("None")},
      ),
    },
  )
}

/// Render the complete repo ribbon.
let view = (
  repos: array<forgeRepo>,
  selectedRepoNames: array<string>,
  filterText: string,
  activeForgeFilter: option<forgeId>,
  onToggle: string => 'msg,
  onSelectAll: 'msg,
  onDeselectAll: 'msg,
  onSetFilter: string => 'msg,
  onSetForgeFilter: option<forgeId> => 'msg,
): Tea_Vdom.t<'msg> => {
  // Apply forge filter
  let forgeFiltered = switch activeForgeFilter {
  | None => repos
  | Some(forge) => ForgeOpsEngine.filterByForge(repos, forge)
  }

  // Apply text filter
  let filteredRepos = ForgeOpsEngine.filterRepos(forgeFiltered, filterText)

  div(
    list{
      Attrs.class_("border-b border-gray-800 pb-3"),
      Attrs.role("region"),
      Attrs.ariaLabel("Repo selector"),
    },
    list{
      // Controls row
      div(
        list{Attrs.class_("flex items-center justify-between mb-2")},
        list{
          div(
            list{Attrs.class_("flex items-center gap-3")},
            list{
              renderSelectionControls(onSelectAll, onDeselectAll),
              renderForgeFilter(activeForgeFilter, onSetForgeFilter),
            },
          ),
          div(
            list{Attrs.class_("flex items-center gap-3")},
            list{
              span(
                list{Attrs.class_("text-xs text-gray-500")},
                list{
                  text(
                    `${Int.toString(Array.length(selectedRepoNames))}/${Int.toString(Array.length(repos))} selected`,
                  ),
                },
              ),
              renderFilterInput(filterText, onSetFilter),
            },
          ),
        },
      ),
      // Repo chips ribbon (scrollable)
      div(
        list{
          Attrs.class_("flex flex-wrap gap-1.5 max-h-24 overflow-y-auto"),
          Attrs.role("listbox"),
          Attrs.ariaLabel("Repositories"),
        },
        filteredRepos
        ->Array.map(repo => {
          let isSelected = Array.includes(selectedRepoNames, repo.name)
          renderRepoChip(repo, isSelected, onToggle)
        })
        ->List.fromArray,
      ),
    },
  )
}
