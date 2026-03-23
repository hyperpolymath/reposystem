// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//
// TEA View - UI rendering

open Tea.Html

// Main view function
let view = (model: Model.t): Vdom.t<Msg.t> => {
  div(
    [class("app")],
    [
      renderHeader(model),
      div(
        [class("main-content")],
        [
          renderSidebar(model),
          renderMainPanel(model),
          renderDetailPanel(model),
        ],
      ),
      renderError(model),
    ],
  )
}

// ============================================================================
// Header
// ============================================================================

let renderHeader = (model: Model.t) => {
  header(
    [class("app-header")],
    [
      h1([], [text("Reposystem")]),
      span([class("tagline")], [text("Railway yard for your repository ecosystem")]),
      div(
        [class("header-actions")],
        [
          renderPanllStatus(model),
          button([onClick(Msg.SaveGraph), class("btn-save")], [text("Save")]),
          button([onClick(Msg.LoadAllData), class("btn-refresh")], [text("Refresh")]),
        ],
      ),
    ],
  )
}

// PanLL connection indicator in the header
let renderPanllStatus = (model: Model.t) => {
  let panll = model.panll
  let (statusClass, statusLabel) = switch panll.connection {
  | PanllDisconnected => ("panll-disconnected", "PanLL: Off")
  | PanllConnecting => ("panll-connecting", "PanLL: ...")
  | PanllConnected(_) => ("panll-connected", "PanLL: On")
  | PanllError(_) => ("panll-error", "PanLL: Err")
  }

  div(
    [class("panll-status " ++ statusClass)],
    [
      span([class("panll-indicator")], [text(statusLabel)]),
      switch panll.connection {
      | PanllDisconnected | PanllError(_) =>
        button(
          [onClick(Msg.PanllConnect), class("btn-panll")],
          [text("Connect")],
        )
      | PanllConnected(_) =>
        div(
          [],
          [
            button(
              [onClick(Msg.PanllSyncGraph), class("btn-panll")],
              [text("Sync")],
            ),
            button(
              [onClick(Msg.PanllDisconnect), class("btn-panll-disconnect")],
              [text("X")],
            ),
          ],
        )
      | PanllConnecting => noNode
      },
    ],
  )
}

// ============================================================================
// Sidebar - Tab navigation
// ============================================================================

let renderSidebar = (model: Model.t) => {
  nav(
    [class("sidebar")],
    [
      ul(
        [class("tab-list")],
        Model.allTabs->Array.map(tab => {
          let isActive = model.activeTab == tab
          li(
            [
              class(isActive ? "tab-item active" : "tab-item"),
              onClick(Msg.SetTab(tab)),
            ],
            [
              span([class("tab-icon")], [text(tabIcon(tab))]),
              span([class("tab-label")], [text(Model.tabToString(tab))]),
              span([class("tab-count")], [text(tabCount(model, tab))]),
            ],
          )
        })->Belt.List.fromArray,
      ),
    ],
  )
}

let tabIcon = (tab: Model.tab) =>
  switch tab {
  | Dashboard => "~"
  | Repos => "@"
  | Edges => "->"
  | Groups => "[]"
  | Aspects => "#"
  | Slots => "<>"
  | Plans => "!"
  }

let tabCount = (model: Model.t, tab: Model.tab) =>
  switch tab {
  | Dashboard => ""
  | Repos => Int.toString(Array.length(model.repos))
  | Edges => Int.toString(Array.length(model.edges))
  | Groups => Int.toString(Array.length(model.groups))
  | Aspects => Int.toString(Array.length(model.aspects))
  | Slots => Int.toString(Array.length(model.slots))
  | Plans => Int.toString(Array.length(model.plans))
  }

// ============================================================================
// Main panel - Content based on active tab
// ============================================================================

// ============================================================================
// Form field helpers — reusable across all creation forms
// ============================================================================

/// Render a labeled text input field.
let formField = (label_: string, fieldName: string, value_: string, ~placeholder: string="") =>
  div(
    [class("form-field")],
    [
      label([class("form-label")], [text(label_)]),
      input'(
        [
          class("form-input"),
          type'("text"),
          placeholder(placeholder),
          value(value_),
          onInput(v => Msg.UpdateFormField(fieldName, v)),
        ],
        [],
      ),
    ],
  )

/// Render a labeled select dropdown.
let formSelect = (
  label_: string,
  fieldName: string,
  value_: string,
  options: array<(string, string)>,
) =>
  div(
    [class("form-field")],
    [
      label([class("form-label")], [text(label_)]),
      select(
        [class("form-select"), onInput(v => Msg.UpdateFormField(fieldName, v))],
        Array.concat(
          [{
            let selected = value_ == ""
            option([Tea.Html.Attributes.value(""), Tea.Html.Attributes.disabled(true), Tea.Html.Attributes.selected(selected)], [text(`Select ${label_}...`)])
          }],
          options->Array.map(((val, lab)) =>
            option([Tea.Html.Attributes.value(val), Tea.Html.Attributes.selected(val == value_)], [text(lab)])
          ),
        )->Belt.List.fromArray,
      ),
    ],
  )

/// Render a labeled checkbox.
let formCheckbox = (label_: string, fieldName: string, checked_: bool) =>
  div(
    [class("form-field form-field-checkbox")],
    [
      label(
        [class("form-label")],
        [
          input'(
            [
              type'("checkbox"),
              Tea.Html.Attributes.checked(checked_),
              onClick(Msg.UpdateFormBool(fieldName, !checked_)),
            ],
            [],
          ),
          text(" " ++ label_),
        ],
      ),
    ],
  )

/// Render Create + Cancel action buttons for forms.
let formActions = () =>
  div(
    [class("form-actions")],
    [
      button([onClick(Msg.SubmitForm), class("btn-submit")], [text("Create")]),
      button([onClick(Msg.CloseForm), class("btn-cancel")], [text("Cancel")]),
    ],
  )

/// Check whether a string matches the current search query (case-insensitive).
let matchesSearch = (query: string, text: string): bool => {
  if query == "" {
    true
  } else {
    String.toLowerCase(text)->String.includes(String.toLowerCase(query))
  }
}

let renderMainPanel = (model: Model.t) => {
  main(
    [class("main-panel")],
    [
      // Search bar — shown on all list tabs (not Dashboard)
      switch model.activeTab {
      | Dashboard => noNode
      | _ =>
        div(
          [class("search-bar")],
          [
            input'(
              [
                class("search-input"),
                type'("text"),
                placeholder("Search..."),
                value(model.searchQuery),
                onInput(value => Msg.SetSearchQuery(value)),
              ],
              [],
            ),
          ],
        )
      },
      if model.loading {
        div([class("loading")], [text("Loading...")])
      } else {
        switch model.activeTab {
        | Dashboard => renderDashboard(model)
        | Repos => renderReposList(model)
        | Edges => renderEdgesList(model)
        | Groups => renderGroupsList(model)
        | Aspects => renderAspectsList(model)
        | Slots => renderSlotsList(model)
        | Plans => renderPlansList(model)
        }
      },
    ],
  )
}

// Dashboard with graph visualization
let renderDashboard = (model: Model.t) => {
  div(
    [class("dashboard")],
    [
      div(
        [class("stats-row")],
        [
          renderStatCard("Repositories", Array.length(model.repos)),
          renderStatCard("Edges", Array.length(model.edges)),
          renderStatCard("Groups", Array.length(model.groups)),
          renderStatCard("Slots", Array.length(model.slots)),
          renderStatCard("Plans", Array.length(model.plans)),
        ],
      ),
      div([id("graph-container"), class("graph-container")], []),
    ],
  )
}

let renderStatCard = (label: string, count: int) => {
  div(
    [class("stat-card")],
    [
      span([class("stat-count")], [text(Int.toString(count))]),
      span([class("stat-label")], [text(label)]),
    ],
  )
}

// Repos list
let renderReposList = (model: Model.t) => {
  let q = model.searchQuery
  let filtered = model.repos->Array.filter(repo =>
    matchesSearch(q, repo.name) || matchesSearch(q, repo.owner)
  )
  div(
    [class("list-view")],
    [
      div([class("list-header")], [h2([], [text("Repositories")])]),
      ul(
        [class("item-list")],
        filtered
        ->Array.map(repo =>
          li(
            [class("item"), onClick(Msg.SelectRepo(repo))],
            [
              span([class("item-name")], [text(repo.name)]),
              span([class("item-meta")], [text(`${repo.owner} | ${forgeToString(repo.forge)}`)]),
            ],
          )
        )
        ->Belt.List.fromArray,
      ),
    ],
  )
}

let forgeToString = (forge: Tauri.forge) =>
  switch forge {
  | GitHub => "GitHub"
  | GitLab => "GitLab"
  | Bitbucket => "Bitbucket"
  | Codeberg => "Codeberg"
  | Sourcehut => "Sourcehut"
  | Local => "Local"
  }

// Edges list
let renderEdgesList = (model: Model.t) => {
  let q = model.searchQuery
  let filtered = model.edges->Array.filter(edge =>
    matchesSearch(q, edge.label->Option.getOr("")) ||
    matchesSearch(q, edge.from) ||
    matchesSearch(q, edge.to_)
  )
  div(
    [class("list-view")],
    [
      div(
        [class("list-header")],
        [
          h2([], [text("Edges")]),
          button([onClick(Msg.OpenEdgeForm), class("btn-add")], [text("+")]),
        ],
      ),
      switch model.openForm {
      | EdgeForm(f) =>
        div(
          [class("creation-form")],
          [
            h3([], [text("Add Edge")]),
            formSelect("From", "from", f.from, model.repos->Array.map(r => (r.id, r.name))),
            formSelect("To", "to", f.to_, model.repos->Array.map(r => (r.id, r.name))),
            formSelect(
              "Relation",
              "rel",
              f.rel,
              [
                ("uses", "Uses"),
                ("provides", "Provides"),
                ("extends", "Extends"),
                ("mirrors", "Mirrors"),
                ("replaces", "Replaces"),
              ],
            ),
            formActions(),
          ],
        )
      | _ => noNode
      },
      ul(
        [class("item-list")],
        filtered
        ->Array.map(edge =>
          li(
            [class("item"), onClick(Msg.SelectEdge(edge))],
            [
              span([class("item-name")], [text(edge.label->Option.getOr(edge.id))]),
              span([class("item-meta")], [text(`${edge.from} -> ${edge.to_}`)]),
            ],
          )
        )
        ->Belt.List.fromArray,
      ),
    ],
  )
}

// Groups list
let renderGroupsList = (model: Model.t) => {
  let q = model.searchQuery
  let filtered = model.groups->Array.filter(group => matchesSearch(q, group.name))
  div(
    [class("list-view")],
    [
      div(
        [class("list-header")],
        [
          h2([], [text("Groups")]),
          button([onClick(Msg.OpenGroupForm), class("btn-add")], [text("+")]),
        ],
      ),
      switch model.openForm {
      | GroupForm(f) =>
        div(
          [class("creation-form")],
          [
            h3([], [text("Create Group")]),
            formField("Name", "name", f.name, ~placeholder="Group name"),
            formField("Description", "description", f.description, ~placeholder="Optional description"),
            formActions(),
          ],
        )
      | _ => noNode
      },
      ul(
        [class("item-list")],
        filtered
        ->Array.map(group =>
          li(
            [class("item"), onClick(Msg.SelectGroup(group))],
            [
              span([class("item-name")], [text(group.name)]),
              span(
                [class("item-meta")],
                [text(`${Int.toString(Array.length(group.members))} members`)],
              ),
            ],
          )
        )
        ->Belt.List.fromArray,
      ),
    ],
  )
}

// Aspects list
let renderAspectsList = (model: Model.t) => {
  let q = model.searchQuery
  let filtered = model.aspects->Array.filter(aspect =>
    matchesSearch(q, aspect.aspect_id) || matchesSearch(q, aspect.target)
  )
  div(
    [class("list-view")],
    [
      div(
        [class("list-header")],
        [
          h2([], [text("Aspect Annotations")]),
          button([onClick(Msg.OpenAspectForm), class("btn-add")], [text("+")]),
        ],
      ),
      switch model.openForm {
      | AspectForm(f) =>
        div(
          [class("creation-form")],
          [
            h3([], [text("Tag Aspect")]),
            formSelect("Target", "target", f.target, model.repos->Array.map(r => (r.id, r.name))),
            formSelect(
              "Aspect",
              "aspectId",
              f.aspectId,
              [
                ("security", "Security"),
                ("reliability", "Reliability"),
                ("maintainability", "Maintainability"),
                ("performance", "Performance"),
                ("supply-chain", "Supply Chain"),
                ("observability", "Observability"),
              ],
            ),
            formSelect(
              "Weight",
              "weight",
              f.weight,
              [("0", "0 - None"), ("1", "1 - Low"), ("2", "2 - Medium"), ("3", "3 - High")],
            ),
            formSelect(
              "Polarity",
              "polarity",
              f.polarity,
              [("risk", "Risk"), ("strength", "Strength"), ("neutral", "Neutral")],
            ),
            formField("Reason", "reason", f.reason, ~placeholder="Why this annotation?"),
            formActions(),
          ],
        )
      | _ => noNode
      },
      ul(
        [class("item-list")],
        filtered
        ->Array.map(aspect =>
          li(
            [class("item"), onClick(Msg.SelectAspect(aspect))],
            [
              span([class("item-name")], [text(aspect.aspect_id)]),
              span([class("item-meta")], [text(`on ${aspect.target}`)]),
            ],
          )
        )
        ->Belt.List.fromArray,
      ),
    ],
  )
}

// Slots list
let renderSlotsList = (model: Model.t) => {
  let q = model.searchQuery
  let filteredSlots = model.slots->Array.filter(slot =>
    matchesSearch(q, slot.name) || matchesSearch(q, slot.category)
  )
  let filteredProviders = model.providers->Array.filter(provider =>
    matchesSearch(q, provider.name)
  )
  div(
    [class("list-view")],
    [
      div(
        [class("list-header")],
        [
          h2([], [text("Slots")]),
          button([onClick(Msg.OpenSlotForm), class("btn-add")], [text("+")]),
        ],
      ),
      switch model.openForm {
      | SlotForm(f) =>
        div(
          [class("creation-form")],
          [
            h3([], [text("Create Slot")]),
            formField("Name", "name", f.name, ~placeholder="Slot name"),
            formField("Category", "category", f.category, ~placeholder="e.g. database, auth, cache"),
            formField("Description", "description", f.description, ~placeholder="What this slot provides"),
            formField("Capabilities", "capabilities", f.capabilities, ~placeholder="cap1, cap2, ..."),
            formActions(),
          ],
        )
      | _ => noNode
      },
      ul(
        [class("item-list")],
        filteredSlots
        ->Array.map(slot =>
          li(
            [class("item"), onClick(Msg.SelectSlot(slot))],
            [
              span([class("item-name")], [text(slot.name)]),
              span([class("item-meta")], [text(`[${slot.category}]`)]),
            ],
          )
        )
        ->Belt.List.fromArray,
      ),
      div(
        [class("list-header")],
        [
          h2([], [text("Providers")]),
          button([onClick(Msg.OpenProviderForm), class("btn-add")], [text("+")]),
        ],
      ),
      switch model.openForm {
      | ProviderForm(f) =>
        div(
          [class("creation-form")],
          [
            h3([], [text("Create Provider")]),
            formField("Name", "name", f.name, ~placeholder="Provider name"),
            formSelect("Slot", "slotId", f.slotId, model.slots->Array.map(s => (s.id, s.name))),
            formSelect(
              "Type",
              "providerType",
              f.providerType,
              [("local", "Local"), ("ecosystem", "Ecosystem"), ("external", "External"), ("stub", "Stub")],
            ),
            formSelect("Repository", "repoId", f.repoId, model.repos->Array.map(r => (r.id, r.name))),
            formField("Capabilities", "capabilities", f.capabilities, ~placeholder="cap1, cap2, ..."),
            formField("Priority", "priority", f.priority, ~placeholder="100"),
            formCheckbox("Fallback provider", "isFallback", f.isFallback),
            formActions(),
          ],
        )
      | _ => noNode
      },
      ul(
        [class("item-list")],
        filteredProviders
        ->Array.map(provider =>
          li(
            [class("item"), onClick(Msg.SelectProvider(provider))],
            [
              span([class("item-name")], [text(provider.name)]),
              span([class("item-meta")], [text(providerTypeToString(provider.provider_type))]),
            ],
          )
        )
        ->Belt.List.fromArray,
      ),
    ],
  )
}

let providerTypeToString = (pt: Tauri.providerType) =>
  switch pt {
  | Local => "local"
  | Ecosystem => "ecosystem"
  | External => "external"
  | Stub => "stub"
  }

// Plans list
let renderPlansList = (model: Model.t) => {
  let q = model.searchQuery
  let filtered = model.plans->Array.filter(plan => matchesSearch(q, plan.name))
  div(
    [class("list-view")],
    [
      div([class("list-header")], [h2([], [text("Plans")])]),
      ul(
        [class("item-list")],
        filtered
        ->Array.map(plan =>
          li(
            [class("item"), onClick(Msg.SelectPlan(plan))],
            [
              span([class("item-name")], [text(plan.name)]),
              span([class("item-meta")], [text(planStatusToString(plan.status))]),
            ],
          )
        )
        ->Belt.List.fromArray,
      ),
    ],
  )
}

let planStatusToString = (status: Tauri.planStatus) =>
  switch status {
  | Draft => "Draft"
  | Ready => "Ready"
  | Applied => "Applied"
  | RolledBack => "Rolled Back"
  | Cancelled => "Cancelled"
  }

// ============================================================================
// Detail panel - Shows selected item
// ============================================================================

let renderDetailPanel = (model: Model.t) => {
  aside(
    [class("detail-panel")],
    [
      switch model.selectedItem {
      | NoSelection => div([class("no-selection")], [text("Select an item to view details")])
      | SelectedRepo(repo) => renderRepoDetail(repo)
      | SelectedEdge(edge) => renderEdgeDetail(edge)
      | SelectedGroup(group) => renderGroupDetail(group)
      | SelectedAspect(aspect) => renderAspectDetail(aspect)
      | SelectedSlot(slot) => renderSlotDetail(slot)
      | SelectedProvider(provider) => renderProviderDetail(provider)
      | SelectedBinding(binding) => renderBindingDetail(binding)
      | SelectedPlan(plan) => renderPlanDetail(plan)
      },
    ],
  )
}

let renderRepoDetail = (repo: Tauri.repo) => {
  div(
    [class("detail")],
    [
      h3([], [text(repo.name)]),
      dl(
        [],
        [
          dt([], [text("ID")]),
          dd([], [text(repo.id)]),
          dt([], [text("Owner")]),
          dd([], [text(repo.owner)]),
          dt([], [text("Forge")]),
          dd([], [text(forgeToString(repo.forge))]),
          dt([], [text("Default Branch")]),
          dd([], [text(repo.default_branch)]),
          dt([], [text("Tags")]),
          dd([], [text(repo.tags->Array.join(", "))]),
        ],
      ),
      button([onClick(Msg.ClearSelection), class("btn-close")], [text("Close")]),
    ],
  )
}

let renderEdgeDetail = (edge: Tauri.edge) => {
  div(
    [class("detail")],
    [
      h3([], [text(edge.label->Option.getOr("Edge"))]),
      dl(
        [],
        [
          dt([], [text("ID")]),
          dd([], [text(edge.id)]),
          dt([], [text("From")]),
          dd([], [text(edge.from)]),
          dt([], [text("To")]),
          dd([], [text(edge.to_)]),
          dt([], [text("Created By")]),
          dd([], [text(edge.meta.created_by)]),
        ],
      ),
      button([onClick(Msg.RemoveEdge(edge.id)), class("btn-danger")], [text("Remove")]),
      button([onClick(Msg.ClearSelection), class("btn-close")], [text("Close")]),
    ],
  )
}

let renderGroupDetail = (group: Tauri.group) => {
  div(
    [class("detail")],
    [
      h3([], [text(group.name)]),
      dl(
        [],
        [
          dt([], [text("ID")]),
          dd([], [text(group.id)]),
          dt([], [text("Description")]),
          dd([], [text(group.description->Option.getOr("-"))]),
          dt([], [text("Members")]),
          dd(
            [],
            group.members
            ->Array.map(m =>
              div(
                [class("member-row")],
                [
                  span([], [text(m)]),
                  button(
                    [onClick(Msg.RemoveFromGroup(group.id, m)), class("btn-danger btn-sm")],
                    [text("x")],
                  ),
                ],
              )
            )
            ->Belt.List.fromArray,
          ),
        ],
      ),
      button([onClick(Msg.ClearSelection), class("btn-close")], [text("Close")]),
    ],
  )
}

let renderAspectDetail = (aspect: Tauri.aspectAnnotation) => {
  div(
    [class("detail")],
    [
      h3([], [text(aspect.aspect_id)]),
      dl(
        [],
        [
          dt([], [text("Target")]),
          dd([], [text(aspect.target)]),
          dt([], [text("Weight")]),
          dd([], [text(Int.toString(aspect.weight))]),
          dt([], [text("Reason")]),
          dd([], [text(aspect.reason)]),
        ],
      ),
      button([onClick(Msg.RemoveAspect(aspect.id)), class("btn-danger")], [text("Remove")]),
      button([onClick(Msg.ClearSelection), class("btn-close")], [text("Close")]),
    ],
  )
}

let renderSlotDetail = (slot: Tauri.slot) => {
  div(
    [class("detail")],
    [
      h3([], [text(slot.name)]),
      dl(
        [],
        [
          dt([], [text("ID")]),
          dd([], [text(slot.id)]),
          dt([], [text("Category")]),
          dd([], [text(slot.category)]),
          dt([], [text("Interface Version")]),
          dd([], [text(slot.interface_version->Option.getOr("-"))]),
          dt([], [text("Description")]),
          dd([], [text(slot.description)]),
          dt([], [text("Required Capabilities")]),
          dd([], [text(slot.required_capabilities->Array.join(", "))]),
        ],
      ),
      button([onClick(Msg.ClearSelection), class("btn-close")], [text("Close")]),
    ],
  )
}

let renderProviderDetail = (provider: Tauri.provider) => {
  div(
    [class("detail")],
    [
      h3([], [text(provider.name)]),
      dl(
        [],
        [
          dt([], [text("ID")]),
          dd([], [text(provider.id)]),
          dt([], [text("Slot")]),
          dd([], [text(provider.slot_id)]),
          dt([], [text("Type")]),
          dd([], [text(providerTypeToString(provider.provider_type))]),
          dt([], [text("Repo")]),
          dd([], [text(provider.repo_id->Option.getOr("-"))]),
          dt([], [text("Priority")]),
          dd([], [text(Int.toString(provider.priority))]),
          dt([], [text("Fallback")]),
          dd([], [text(provider.is_fallback ? "Yes" : "No")]),
        ],
      ),
      button([onClick(Msg.ClearSelection), class("btn-close")], [text("Close")]),
    ],
  )
}

let renderBindingDetail = (binding: Tauri.slotBinding) => {
  div(
    [class("detail")],
    [
      h3([], [text("Binding")]),
      dl(
        [],
        [
          dt([], [text("ID")]),
          dd([], [text(binding.id)]),
          dt([], [text("Consumer")]),
          dd([], [text(binding.consumer_id)]),
          dt([], [text("Slot")]),
          dd([], [text(binding.slot_id)]),
          dt([], [text("Provider")]),
          dd([], [text(binding.provider_id)]),
        ],
      ),
      button([onClick(Msg.UnbindSlot(binding.id)), class("btn-danger")], [text("Unbind")]),
      button([onClick(Msg.ClearSelection), class("btn-close")], [text("Close")]),
    ],
  )
}

let renderPlanDetail = (plan: Tauri.plan) => {
  div(
    [class("detail")],
    [
      h3([], [text(plan.name)]),
      dl(
        [],
        [
          dt([], [text("ID")]),
          dd([], [text(plan.id)]),
          dt([], [text("Status")]),
          dd([], [text(planStatusToString(plan.status))]),
          dt([], [text("Description")]),
          dd([], [text(plan.description->Option.getOr("-"))]),
        ],
      ),
      button([onClick(Msg.ClearSelection), class("btn-close")], [text("Close")]),
    ],
  )
}

// ============================================================================
// Error display
// ============================================================================

let renderError = (model: Model.t) => {
  switch model.error {
  | None => noNode
  | Some(err) =>
    div(
      [class("error-toast")],
      [
        span([], [text(err)]),
        button([onClick(Msg.DismissError), class("btn-dismiss")], [text("X")]),
      ],
    )
  }
}
