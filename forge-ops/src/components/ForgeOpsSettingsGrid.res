// SPDX-License-Identifier: PMPL-1.0-or-later

/// ForgeOps Settings Grid — Toggle/switch/dropdown grid for forge settings.
///
/// Renders forge settings as an interactive grid of toggles, dropdowns,
/// and number inputs, grouped by category. Settings unavailable on the
/// user's forge tier are greyed out with a "Requires Pro/Team/Enterprise" badge.
/// Forge-only settings show a forge badge (GH/GL/BB).
///
/// Modified settings (different from last-synced state) show an orange dot.
/// Settings that differ from RSR policy show a yellow warning.
///
/// Layout (within a category tab):
///   +-----------------------------------------+
///   | Visibility       [public           v]  |
///   | Issues Enabled   [================ON]  |
///   | Wiki Enabled     [OFF===============]  |
///   | Default Branch   [main             v]  |
///   | License          [PMPL-1.0-or-later v]  |
///   +-----------------------------------------+

open ForgeOpsModel
open Tea.Html

/// Render a toggle switch for on/off settings.
let renderToggle = (
  setting: forgeSetting,
  onToggle: string => 'msg,
): Tea_Vdom.t<'msg> => {
  let isOn = ForgeOpsEngine.isSettingEnabled(setting.value)
  let bgClass = isOn ? "bg-indigo-600" : "bg-gray-600"
  let translateClass = isOn ? "translate-x-5" : "translate-x-0"

  div(
    list{Attrs.class_("flex items-center justify-between py-2 px-3 hover:bg-gray-800/50 rounded")},
    list{
      // Label + description
      div(
        list{Attrs.class_("flex-1 mr-4")},
        list{
          div(
            list{Attrs.class_("text-sm text-gray-200 font-medium flex items-center gap-2")},
            list{
              text(setting.label),
              // Forge badge if forge-specific
              switch setting.forgeId {
              | Some(forge) =>
                span(
                  list{Attrs.class_(`text-xs font-mono px-1 py-0.5 rounded ${ForgeOpsEngine.forgeBadgeColour(forge)}`)},
                  list{text(ForgeOpsCatalog.forgeLabel(forge))},
                )
              | None => noNode
              },
            },
          ),
          div(
            list{Attrs.class_("text-xs text-gray-500 mt-0.5")},
            list{text(setting.description)},
          ),
        },
      ),
      // Toggle switch
      button(
        list{
          Attrs.class_(
            `relative inline-flex h-6 w-11 items-center rounded-full transition-colors cursor-pointer ${bgClass}`,
          ),
          Attrs.role("switch"),
          Attrs.ariaChecked(isOn),
          Attrs.ariaLabel(`Toggle ${setting.label}`),
          Events.onClick(onToggle(setting.id)),
        },
        list{
          span(
            list{
              Attrs.class_(
                `inline-block h-4 w-4 rounded-full bg-white transition-transform ${translateClass}`,
              ),
              Attrs.style("margin-left", "2px"),
            },
            list{},
          ),
        },
      ),
      // Modified indicator
      if setting.modified {
        span(
          list{
            Attrs.class_("w-2 h-2 rounded-full bg-orange-400 ml-2"),
            Attrs.title("Setting has been modified"),
          },
          list{},
        )
      } else {
        noNode
      },
    },
  )
}

/// Render a dropdown select for enum settings.
let renderSelect = (
  setting: forgeSetting,
  options: array<string>,
  onUpdate: (string, string) => 'msg,
): Tea_Vdom.t<'msg> => {
  let currentValue = ForgeOpsEngine.settingValueToString(setting.value)

  div(
    list{Attrs.class_("flex items-center justify-between py-2 px-3 hover:bg-gray-800/50 rounded")},
    list{
      div(
        list{Attrs.class_("flex-1 mr-4")},
        list{
          div(
            list{Attrs.class_("text-sm text-gray-200 font-medium flex items-center gap-2")},
            list{
              text(setting.label),
              switch setting.forgeId {
              | Some(forge) =>
                span(
                  list{Attrs.class_(`text-xs font-mono px-1 py-0.5 rounded ${ForgeOpsEngine.forgeBadgeColour(forge)}`)},
                  list{text(ForgeOpsCatalog.forgeLabel(forge))},
                )
              | None => noNode
              },
            },
          ),
          div(
            list{Attrs.class_("text-xs text-gray-500 mt-0.5")},
            list{text(setting.description)},
          ),
        },
      ),
      select(
        list{
          Attrs.class_(
            "bg-gray-800 border border-gray-600 rounded px-2 py-1 text-sm text-gray-200 cursor-pointer focus:border-indigo-500 focus:outline-none",
          ),
          Attrs.value(currentValue),
          Attrs.ariaLabel(`Select ${setting.label}`),
          Events.onChange(value => onUpdate(setting.id, value)),
        },
        options
        ->Array.map(opt => {
          option'(
            list{
              Attrs.value(opt),
              if opt === currentValue {
                Attrs.selected(true)
              } else {
                Attrs.noProp
              },
            },
            list{text(opt)},
          )
        })
        ->List.fromArray,
      ),
      if setting.modified {
        span(
          list{
            Attrs.class_("w-2 h-2 rounded-full bg-orange-400 ml-2"),
            Attrs.title("Setting has been modified"),
          },
          list{},
        )
      } else {
        noNode
      },
    },
  )
}

/// Render a number input for numeric settings.
let renderNumberInput = (
  setting: forgeSetting,
  onUpdate: (string, string) => 'msg,
): Tea_Vdom.t<'msg> => {
  let currentValue = ForgeOpsEngine.settingValueToString(setting.value)

  div(
    list{Attrs.class_("flex items-center justify-between py-2 px-3 hover:bg-gray-800/50 rounded")},
    list{
      div(
        list{Attrs.class_("flex-1 mr-4")},
        list{
          div(
            list{Attrs.class_("text-sm text-gray-200 font-medium flex items-center gap-2")},
            list{
              text(setting.label),
              switch setting.forgeId {
              | Some(forge) =>
                span(
                  list{Attrs.class_(`text-xs font-mono px-1 py-0.5 rounded ${ForgeOpsEngine.forgeBadgeColour(forge)}`)},
                  list{text(ForgeOpsCatalog.forgeLabel(forge))},
                )
              | None => noNode
              },
            },
          ),
          div(
            list{Attrs.class_("text-xs text-gray-500 mt-0.5")},
            list{text(setting.description)},
          ),
        },
      ),
      input(
        list{
          Attrs.class_(
            "bg-gray-800 border border-gray-600 rounded px-2 py-1 text-sm text-gray-200 w-24 focus:border-indigo-500 focus:outline-none",
          ),
          Attrs.type_("number"),
          Attrs.value(currentValue),
          Attrs.ariaLabel(`Set ${setting.label}`),
          Events.onInput(value => onUpdate(setting.id, value)),
        },
        list{},
      ),
    },
  )
}

/// Render an exception indicator badge for per-repo overrides.
let renderExceptionBadge = (
  exc: repoException,
): Tea_Vdom.t<'msg> => {
  span(
    list{
      Attrs.class_("text-xs text-yellow-400 font-medium px-1.5 py-0.5 border border-yellow-500/30 rounded ml-2"),
      Attrs.title(`Exception: ${exc.reason}`),
    },
    list{text("EXC")},
  )
}

/// Render a single setting row, choosing the appropriate input type.
/// Unavailable settings show a tier badge. Forge-only settings show a forge badge.
let renderSettingRow = (
  setting: forgeSetting,
  repoExc: option<repoException>,
  onToggle: string => 'msg,
  onUpdate: (string, string) => 'msg,
): Tea_Vdom.t<'msg> => {
  let catalogEntry = ForgeOpsCatalog.findById(setting.id)

  let rowContent = switch catalogEntry {
  | None => renderToggle(setting, onToggle)
  | Some(entry) =>
    switch entry.availability {
    | Unavailable(tier) =>
      // Greyed-out setting with tier badge
      div(
        list{Attrs.class_("flex items-center justify-between py-2 px-3 opacity-40 cursor-not-allowed")},
        list{
          div(
            list{Attrs.class_("flex-1 mr-4")},
            list{
              div(
                list{Attrs.class_("text-sm text-gray-400 font-medium")},
                list{text(setting.label)},
              ),
              div(
                list{Attrs.class_("text-xs text-gray-600 mt-0.5")},
                list{text(setting.description)},
              ),
            },
          ),
          span(
            list{Attrs.class_("text-xs text-amber-500/60 font-medium px-2 py-0.5 border border-amber-500/30 rounded")},
            list{text(`Requires ${ForgeOpsCatalog.tierLabel(tier)}`)},
          ),
        },
      )
    | Available | ForgeOnly(_) | Limited(_) =>
      switch entry.valueType {
      | "toggle" => renderToggle(setting, onToggle)
      | "select" =>
        switch entry.options {
        | Some(opts) => renderSelect(setting, opts, onUpdate)
        | None => renderToggle(setting, onToggle)
        }
      | "number" => renderNumberInput(setting, onUpdate)
      | _ => renderToggle(setting, onToggle)
      }
    }
  }

  switch repoExc {
  | None => rowContent
  | Some(exc) =>
    div(
      list{Attrs.class_("relative")},
      list{
        rowContent,
        renderExceptionBadge(exc),
      },
    )
  }
}

/// Render the settings grid for a given category.
/// Shows all settings in the category, filtered by search text.
let view = (
  settings: array<forgeSetting>,
  activeCategory: forgeCategory,
  settingFilter: string,
  exceptions: array<repoException>,
  currentRepoName: option<string>,
  onToggle: string => 'msg,
  onUpdate: (string, string) => 'msg,
): Tea_Vdom.t<'msg> => {
  let categorySettings = settings->Array.filter(s => s.category === activeCategory)

  let filteredSettings = if String.length(settingFilter) > 0 {
    let lower = String.toLowerCase(settingFilter)
    categorySettings->Array.filter(s =>
      String.includes(String.toLowerCase(s.label), lower)
      || String.includes(String.toLowerCase(s.id), lower)
    )
  } else {
    categorySettings
  }

  div(
    list{
      Attrs.class_("flex-1 overflow-y-auto"),
      Attrs.role("list"),
      Attrs.ariaLabel(`${ForgeOpsCatalog.categoryLabel(activeCategory)} settings`),
    },
    list{
      if Array.length(filteredSettings) === 0 {
        div(
          list{Attrs.class_("text-gray-600 text-sm italic py-4 px-3")},
          list{text(`No ${ForgeOpsCatalog.categoryLabel(activeCategory)} settings found`)},
        )
      } else {
        div(
          list{Attrs.class_("divide-y divide-gray-800/50")},
          filteredSettings
          ->Array.map(setting => {
            let repoExc = switch currentRepoName {
            | Some(repo) =>
              ForgeOpsEngine.findException(exceptions, repo, setting.id)
            | None => None
            }
            renderSettingRow(setting, repoExc, onToggle, onUpdate)
          })
          ->List.fromArray,
        )
      },
    },
  )
}
