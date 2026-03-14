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

let renderMainPanel = (model: Model.t) => {
  main(
    [class("main-panel")],
    [
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
  div(
    [class("list-view")],
    [
      div([class("list-header")], [h2([], [text("Repositories")])]),
      ul(
        [class("item-list")],
        model.repos
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
  div(
    [class("list-view")],
    [
      div([class("list-header")], [h2([], [text("Edges")])]),
      ul(
        [class("item-list")],
        model.edges
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
  div(
    [class("list-view")],
    [
      div([class("list-header")], [h2([], [text("Groups")])]),
      ul(
        [class("item-list")],
        model.groups
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
  div(
    [class("list-view")],
    [
      div([class("list-header")], [h2([], [text("Aspect Annotations")])]),
      ul(
        [class("item-list")],
        model.aspects
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
  div(
    [class("list-view")],
    [
      div([class("list-header")], [h2([], [text("Slots")])]),
      ul(
        [class("item-list")],
        model.slots
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
      div([class("list-header")], [h2([], [text("Providers")])]),
      ul(
        [class("item-list")],
        model.providers
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
  div(
    [class("list-view")],
    [
      div([class("list-header")], [h2([], [text("Plans")])]),
      ul(
        [class("item-list")],
        model.plans
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
          dd([], [text(group.members->Array.join(", "))]),
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
