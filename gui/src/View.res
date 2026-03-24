// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//
// TEA View - UI rendering

open Tea.Html
open Tea.Html.Attributes
open Tea.Html.Events

// ============================================================================
// Small utilities
// ============================================================================

/// Check whether a string matches the current search query (case-insensitive).
let matchesSearch = (query: string, text: string): bool => {
  if query == "" {
    true
  } else {
    String.toLowerCase(text)->String.includes(String.toLowerCase(query))
  }
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

let forgeToString = (forge: Backend.forge) =>
  switch forge {
  | GitHub => "GitHub"
  | GitLab => "GitLab"
  | Bitbucket => "Bitbucket"
  | Codeberg => "Codeberg"
  | Sourcehut => "Sourcehut"
  | Local => "Local"
  }

let providerTypeToString = (pt: Backend.providerType) =>
  switch pt {
  | Local => "local"
  | Ecosystem => "ecosystem"
  | External => "external"
  | Stub => "stub"
  }

let planStatusToString = (status: Backend.planStatus) =>
  switch status {
  | Draft => "Draft"
  | Ready => "Ready"
  | Applied => "Applied"
  | RolledBack => "Rolled Back"
  | Cancelled => "Cancelled"
  }

// ============================================================================
// Form field helpers — reusable across all creation forms
// ============================================================================

/// Render a labeled text input field.
let formField = (label_: string, fieldName: string, value_: string, ~placeholder as placeholder_: string="") =>
  div(
    list{class("form-field")},
    list{
      label(list{class("form-label")}, list{text(label_)}),
      input'(
        list{
          class("form-input"),
          type'("text"),
          placeholder(placeholder_),
          value(value_),
          onInput(v => Msg.UpdateFormField(fieldName, v)),
        },
        list{},
      ),
    },
  )

/// Render a labeled select dropdown.
let formSelect = (
  label_: string,
  fieldName: string,
  value_: string,
  options: array<(string, string)>,
) =>
  div(
    list{class("form-field")},
    list{
      label(list{class("form-label")}, list{text(label_)}),
      select(
        list{class("form-select"), onInput(v => Msg.UpdateFormField(fieldName, v))},
        Array.concat(
          [{
            let selected = value_ == ""
            option(list{Tea.Html.Attributes.value(""), Tea.Html.Attributes.disabled(true), Tea.Html.Attributes.selected(selected)}, list{text(`Select ${label_}...`)})
          }],
          options->Array.map(((val, lab)) =>
            option(list{Tea.Html.Attributes.value(val), Tea.Html.Attributes.selected(val == value_)}, list{text(lab)})
          ),
        )->Belt.List.fromArray,
      ),
    },
  )

/// Render a labeled checkbox.
let formCheckbox = (label_: string, fieldName: string, checked_: bool) =>
  div(
    list{class("form-field form-field-checkbox")},
    list{
      label(
        list{class("form-label")},
        list{
          input'(
            list{
              type'("checkbox"),
              Tea.Html.Attributes.checked(checked_),
              onClick(Msg.UpdateFormBool(fieldName, !checked_)),
            },
            list{},
          ),
          text(" " ++ label_),
        },
      ),
    },
  )

/// Render Create + Cancel action buttons for forms.
let formActions = () =>
  div(
    list{class("form-actions")},
    list{
      button(list{onClick(Msg.SubmitForm), class("btn-submit")}, list{text("Create")}),
      button(list{onClick(Msg.CloseForm), class("btn-cancel")}, list{text("Cancel")}),
    },
  )

// ============================================================================
// Detail renderers
// ============================================================================

let renderRepoDetail = (repo: Backend.repo) => {
  div(
    list{class("detail")},
    list{
      h3(list{}, list{text(repo.name)}),
      dl(
        list{},
        list{
          dt(list{}, list{text("ID")}),
          dd(list{}, list{text(repo.id)}),
          dt(list{}, list{text("Owner")}),
          dd(list{}, list{text(repo.owner)}),
          dt(list{}, list{text("Forge")}),
          dd(list{}, list{text(forgeToString(repo.forge))}),
          dt(list{}, list{text("Default Branch")}),
          dd(list{}, list{text(repo.default_branch)}),
          dt(list{}, list{text("Tags")}),
          dd(list{}, list{text(repo.tags->Array.joinWith(", "))}),
        },
      ),
      button(list{onClick(Msg.ClearSelection), class("btn-close")}, list{text("Close")}),
    },
  )
}

let renderEdgeDetail = (edge: Backend.edge) => {
  div(
    list{class("detail")},
    list{
      h3(list{}, list{text(edge.label->Option.getOr("Edge"))}),
      dl(
        list{},
        list{
          dt(list{}, list{text("ID")}),
          dd(list{}, list{text(edge.id)}),
          dt(list{}, list{text("From")}),
          dd(list{}, list{text(edge.from)}),
          dt(list{}, list{text("To")}),
          dd(list{}, list{text(edge.to_)}),
          dt(list{}, list{text("Created By")}),
          dd(list{}, list{text(edge.meta.created_by)}),
        },
      ),
      button(list{onClick(Msg.RemoveEdge(edge.id)), class("btn-danger")}, list{text("Remove")}),
      button(list{onClick(Msg.ClearSelection), class("btn-close")}, list{text("Close")}),
    },
  )
}

let renderGroupDetail = (group: Backend.group) => {
  div(
    list{class("detail")},
    list{
      h3(list{}, list{text(group.name)}),
      dl(
        list{},
        list{
          dt(list{}, list{text("ID")}),
          dd(list{}, list{text(group.id)}),
          dt(list{}, list{text("Description")}),
          dd(list{}, list{text(group.description->Option.getOr("-"))}),
          dt(list{}, list{text("Members")}),
          dd(
            list{},
            group.members
            ->Array.map(m =>
              div(
                list{class("member-row")},
                list{
                  span(list{}, list{text(m)}),
                  button(
                    list{onClick(Msg.RemoveFromGroup(group.id, m)), class("btn-danger btn-sm")},
                    list{text("x")},
                  ),
                },
              )
            )
            ->Belt.List.fromArray,
          ),
        },
      ),
      button(list{onClick(Msg.ClearSelection), class("btn-close")}, list{text("Close")}),
    },
  )
}

let renderAspectDetail = (aspect: Backend.aspectAnnotation) => {
  div(
    list{class("detail")},
    list{
      h3(list{}, list{text(aspect.aspect_id)}),
      dl(
        list{},
        list{
          dt(list{}, list{text("Target")}),
          dd(list{}, list{text(aspect.target)}),
          dt(list{}, list{text("Weight")}),
          dd(list{}, list{text(Int.toString(aspect.weight))}),
          dt(list{}, list{text("Reason")}),
          dd(list{}, list{text(aspect.reason)}),
        },
      ),
      button(list{onClick(Msg.RemoveAspect(aspect.id)), class("btn-danger")}, list{text("Remove")}),
      button(list{onClick(Msg.ClearSelection), class("btn-close")}, list{text("Close")}),
    },
  )
}

let renderSlotDetail = (slot: Backend.slot) => {
  div(
    list{class("detail")},
    list{
      h3(list{}, list{text(slot.name)}),
      dl(
        list{},
        list{
          dt(list{}, list{text("ID")}),
          dd(list{}, list{text(slot.id)}),
          dt(list{}, list{text("Category")}),
          dd(list{}, list{text(slot.category)}),
          dt(list{}, list{text("Interface Version")}),
          dd(list{}, list{text(slot.interface_version->Option.getOr("-"))}),
          dt(list{}, list{text("Description")}),
          dd(list{}, list{text(slot.description)}),
          dt(list{}, list{text("Required Capabilities")}),
          dd(list{}, list{text(slot.required_capabilities->Array.joinWith(", "))}),
        },
      ),
      button(list{onClick(Msg.ClearSelection), class("btn-close")}, list{text("Close")}),
    },
  )
}

let renderProviderDetail = (provider: Backend.provider) => {
  div(
    list{class("detail")},
    list{
      h3(list{}, list{text(provider.name)}),
      dl(
        list{},
        list{
          dt(list{}, list{text("ID")}),
          dd(list{}, list{text(provider.id)}),
          dt(list{}, list{text("Slot")}),
          dd(list{}, list{text(provider.slot_id)}),
          dt(list{}, list{text("Type")}),
          dd(list{}, list{text(providerTypeToString(provider.provider_type))}),
          dt(list{}, list{text("Repo")}),
          dd(list{}, list{text(provider.repo_id->Option.getOr("-"))}),
          dt(list{}, list{text("Priority")}),
          dd(list{}, list{text(Int.toString(provider.priority))}),
          dt(list{}, list{text("Fallback")}),
          dd(list{}, list{text(provider.is_fallback ? "Yes" : "No")}),
        },
      ),
      button(list{onClick(Msg.ClearSelection), class("btn-close")}, list{text("Close")}),
    },
  )
}

let renderBindingDetail = (binding: Backend.slotBinding) => {
  div(
    list{class("detail")},
    list{
      h3(list{}, list{text("Binding")}),
      dl(
        list{},
        list{
          dt(list{}, list{text("ID")}),
          dd(list{}, list{text(binding.id)}),
          dt(list{}, list{text("Consumer")}),
          dd(list{}, list{text(binding.consumer_id)}),
          dt(list{}, list{text("Slot")}),
          dd(list{}, list{text(binding.slot_id)}),
          dt(list{}, list{text("Provider")}),
          dd(list{}, list{text(binding.provider_id)}),
        },
      ),
      button(list{onClick(Msg.UnbindSlot(binding.id)), class("btn-danger")}, list{text("Unbind")}),
      button(list{onClick(Msg.ClearSelection), class("btn-close")}, list{text("Close")}),
    },
  )
}

let renderPlanDetail = (plan: Backend.plan) => {
  div(
    list{class("detail")},
    list{
      h3(list{}, list{text(plan.name)}),
      dl(
        list{},
        list{
          dt(list{}, list{text("ID")}),
          dd(list{}, list{text(plan.id)}),
          dt(list{}, list{text("Status")}),
          dd(list{}, list{text(planStatusToString(plan.status))}),
          dt(list{}, list{text("Description")}),
          dd(list{}, list{text(plan.description->Option.getOr("-"))}),
        },
      ),
      button(list{onClick(Msg.ClearSelection), class("btn-close")}, list{text("Close")}),
    },
  )
}

// ============================================================================
// Stat card
// ============================================================================

let renderStatCard = (label: string, count: int) => {
  div(
    list{class("stat-card")},
    list{
      span(list{class("stat-count")}, list{text(Int.toString(count))}),
      span(list{class("stat-label")}, list{text(label)}),
    },
  )
}

// ============================================================================
// List renderers
// ============================================================================

// Dashboard with graph visualization
let renderDashboard = (model: Model.t) => {
  div(
    list{class("dashboard")},
    list{
      div(
        list{class("stats-row")},
        list{
          renderStatCard("Repositories", Array.length(model.repos)),
          renderStatCard("Edges", Array.length(model.edges)),
          renderStatCard("Groups", Array.length(model.groups)),
          renderStatCard("Slots", Array.length(model.slots)),
          renderStatCard("Plans", Array.length(model.plans)),
        },
      ),
      div(list{id("graph-container"), class("graph-container")}, list{}),
    },
  )
}

// Repos list
let renderReposList = (model: Model.t) => {
  let q = model.searchQuery
  let filtered = model.repos->Array.filter(repo =>
    matchesSearch(q, repo.name) || matchesSearch(q, repo.owner)
  )
  div(
    list{class("list-view")},
    list{
      div(list{class("list-header")}, list{h2(list{}, list{text("Repositories")})}),
      ul(
        list{class("item-list")},
        filtered
        ->Array.map(repo =>
          li(
            list{class("item"), onClick(Msg.SelectRepo(repo))},
            list{
              span(list{class("item-name")}, list{text(repo.name)}),
              span(list{class("item-meta")}, list{text(`${repo.owner} | ${forgeToString(repo.forge)}`)}),
            },
          )
        )
        ->Belt.List.fromArray,
      ),
    },
  )
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
    list{class("list-view")},
    list{
      div(
        list{class("list-header")},
        list{
          h2(list{}, list{text("Edges")}),
          button(list{onClick(Msg.OpenEdgeForm), class("btn-add")}, list{text("+")}),
        },
      ),
      switch model.openForm {
      | EdgeForm(f) =>
        div(
          list{class("creation-form")},
          list{
            h3(list{}, list{text("Add Edge")}),
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
          },
        )
      | _ => noNode
      },
      ul(
        list{class("item-list")},
        filtered
        ->Array.map(edge =>
          li(
            list{class("item"), onClick(Msg.SelectEdge(edge))},
            list{
              span(list{class("item-name")}, list{text(edge.label->Option.getOr(edge.id))}),
              span(list{class("item-meta")}, list{text(`${edge.from} -> ${edge.to_}`)}),
            },
          )
        )
        ->Belt.List.fromArray,
      ),
    },
  )
}

// Groups list
let renderGroupsList = (model: Model.t) => {
  let q = model.searchQuery
  let filtered = model.groups->Array.filter(group => matchesSearch(q, group.name))
  div(
    list{class("list-view")},
    list{
      div(
        list{class("list-header")},
        list{
          h2(list{}, list{text("Groups")}),
          button(list{onClick(Msg.OpenGroupForm), class("btn-add")}, list{text("+")}),
        },
      ),
      switch model.openForm {
      | GroupForm(f) =>
        div(
          list{class("creation-form")},
          list{
            h3(list{}, list{text("Create Group")}),
            formField("Name", "name", f.name, ~placeholder="Group name"),
            formField("Description", "description", f.description, ~placeholder="Optional description"),
            formActions(),
          },
        )
      | _ => noNode
      },
      ul(
        list{class("item-list")},
        filtered
        ->Array.map(group =>
          li(
            list{class("item"), onClick(Msg.SelectGroup(group))},
            list{
              span(list{class("item-name")}, list{text(group.name)}),
              span(
                list{class("item-meta")},
                list{text(`${Int.toString(Array.length(group.members))} members`)},
              ),
            },
          )
        )
        ->Belt.List.fromArray,
      ),
    },
  )
}

// Aspects list
let renderAspectsList = (model: Model.t) => {
  let q = model.searchQuery
  let filtered = model.aspects->Array.filter(aspect =>
    matchesSearch(q, aspect.aspect_id) || matchesSearch(q, aspect.target)
  )
  div(
    list{class("list-view")},
    list{
      div(
        list{class("list-header")},
        list{
          h2(list{}, list{text("Aspect Annotations")}),
          button(list{onClick(Msg.OpenAspectForm), class("btn-add")}, list{text("+")}),
        },
      ),
      switch model.openForm {
      | AspectForm(f) =>
        div(
          list{class("creation-form")},
          list{
            h3(list{}, list{text("Tag Aspect")}),
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
          },
        )
      | _ => noNode
      },
      ul(
        list{class("item-list")},
        filtered
        ->Array.map(aspect =>
          li(
            list{class("item"), onClick(Msg.SelectAspect(aspect))},
            list{
              span(list{class("item-name")}, list{text(aspect.aspect_id)}),
              span(list{class("item-meta")}, list{text(`on ${aspect.target}`)}),
            },
          )
        )
        ->Belt.List.fromArray,
      ),
    },
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
    list{class("list-view")},
    list{
      div(
        list{class("list-header")},
        list{
          h2(list{}, list{text("Slots")}),
          button(list{onClick(Msg.OpenSlotForm), class("btn-add")}, list{text("+")}),
        },
      ),
      switch model.openForm {
      | SlotForm(f) =>
        div(
          list{class("creation-form")},
          list{
            h3(list{}, list{text("Create Slot")}),
            formField("Name", "name", f.name, ~placeholder="Slot name"),
            formField("Category", "category", f.category, ~placeholder="e.g. database, auth, cache"),
            formField("Description", "description", f.description, ~placeholder="What this slot provides"),
            formField("Capabilities", "capabilities", f.capabilities, ~placeholder="cap1, cap2, ..."),
            formActions(),
          },
        )
      | _ => noNode
      },
      ul(
        list{class("item-list")},
        filteredSlots
        ->Array.map(slot =>
          li(
            list{class("item"), onClick(Msg.SelectSlot(slot))},
            list{
              span(list{class("item-name")}, list{text(slot.name)}),
              span(list{class("item-meta")}, list{text(`[${slot.category}]`)}),
            },
          )
        )
        ->Belt.List.fromArray,
      ),
      div(
        list{class("list-header")},
        list{
          h2(list{}, list{text("Providers")}),
          button(list{onClick(Msg.OpenProviderForm), class("btn-add")}, list{text("+")}),
        },
      ),
      switch model.openForm {
      | ProviderForm(f) =>
        div(
          list{class("creation-form")},
          list{
            h3(list{}, list{text("Create Provider")}),
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
          },
        )
      | _ => noNode
      },
      ul(
        list{class("item-list")},
        filteredProviders
        ->Array.map(provider =>
          li(
            list{class("item"), onClick(Msg.SelectProvider(provider))},
            list{
              span(list{class("item-name")}, list{text(provider.name)}),
              span(list{class("item-meta")}, list{text(providerTypeToString(provider.provider_type))}),
            },
          )
        )
        ->Belt.List.fromArray,
      ),
    },
  )
}

// Plans list
let renderPlansList = (model: Model.t) => {
  let q = model.searchQuery
  let filtered = model.plans->Array.filter(plan => matchesSearch(q, plan.name))
  div(
    list{class("list-view")},
    list{
      div(list{class("list-header")}, list{h2(list{}, list{text("Plans")})}),
      ul(
        list{class("item-list")},
        filtered
        ->Array.map(plan =>
          li(
            list{class("item"), onClick(Msg.SelectPlan(plan))},
            list{
              span(list{class("item-name")}, list{text(plan.name)}),
              span(list{class("item-meta")}, list{text(planStatusToString(plan.status))}),
            },
          )
        )
        ->Belt.List.fromArray,
      ),
    },
  )
}

// ============================================================================
// Panel renderers
// ============================================================================

let renderMainPanel = (model: Model.t) => {
  main(
    list{class("main-panel")},
    list{
      // Search bar — shown on all list tabs (not Dashboard)
      switch model.activeTab {
      | Dashboard => noNode
      | _ =>
        div(
          list{class("search-bar")},
          list{
            input'(
              list{
                class("search-input"),
                type'("text"),
                placeholder("Search..."),
                value(model.searchQuery),
                onInput(value => Msg.SetSearchQuery(value)),
              },
              list{},
            ),
          },
        )
      },
      if model.loading {
        div(list{class("loading")}, list{text("Loading...")})
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
    },
  )
}

// ============================================================================
// Detail panel - Shows selected item
// ============================================================================

let renderDetailPanel = (model: Model.t) => {
  aside(
    list{class("detail-panel")},
    list{
      switch model.selectedItem {
      | NoSelection => div(list{class("no-selection")}, list{text("Select an item to view details")})
      | SelectedRepo(repo) => renderRepoDetail(repo)
      | SelectedEdge(edge) => renderEdgeDetail(edge)
      | SelectedGroup(group) => renderGroupDetail(group)
      | SelectedAspect(aspect) => renderAspectDetail(aspect)
      | SelectedSlot(slot) => renderSlotDetail(slot)
      | SelectedProvider(provider) => renderProviderDetail(provider)
      | SelectedBinding(binding) => renderBindingDetail(binding)
      | SelectedPlan(plan) => renderPlanDetail(plan)
      },
    },
  )
}

// ============================================================================
// Header
// ============================================================================

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
    list{class("panll-status " ++ statusClass)},
    list{
      span(list{class("panll-indicator")}, list{text(statusLabel)}),
      switch panll.connection {
      | PanllDisconnected | PanllError(_) =>
        button(
          list{onClick(Msg.PanllConnect), class("btn-panll")},
          list{text("Connect")},
        )
      | PanllConnected(_) =>
        div(
          list{},
          list{
            button(
              list{onClick(Msg.PanllSyncGraph), class("btn-panll")},
              list{text("Sync")},
            ),
            button(
              list{onClick(Msg.PanllDisconnect), class("btn-panll-disconnect")},
              list{text("X")},
            ),
          },
        )
      | PanllConnecting => noNode
      },
    },
  )
}

let renderHeader = (model: Model.t) => {
  header(
    list{class("app-header")},
    list{
      h1(list{}, list{text("Reposystem")}),
      span(list{class("tagline")}, list{text("Railway yard for your repository ecosystem")}),
      div(
        list{class("header-actions")},
        list{
          renderPanllStatus(model),
          button(list{onClick(Msg.SaveGraph), class("btn-save")}, list{text("Save")}),
          button(list{onClick(Msg.LoadAllData), class("btn-refresh")}, list{text("Refresh")}),
        },
      ),
    },
  )
}

// ============================================================================
// Sidebar - Tab navigation
// ============================================================================

let renderSidebar = (model: Model.t) => {
  nav(
    list{class("sidebar")},
    list{
      ul(
        list{class("tab-list")},
        Model.allTabs->Array.map(tab => {
          let isActive = model.activeTab == tab
          li(
            list{
              class(isActive ? "tab-item active" : "tab-item"),
              onClick(Msg.SetTab(tab)),
            },
            list{
              span(list{class("tab-icon")}, list{text(tabIcon(tab))}),
              span(list{class("tab-label")}, list{text(Model.tabToString(tab))}),
              span(list{class("tab-count")}, list{text(tabCount(model, tab))}),
            },
          )
        })->Belt.List.fromArray,
      ),
    },
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
      list{class("error-toast")},
      list{
        span(list{}, list{text(err)}),
        button(list{onClick(Msg.DismissError), class("btn-dismiss")}, list{text("X")}),
      },
    )
  }
}

// ============================================================================
// Main view function (at end — references all renderers above)
// ============================================================================

let view = (model: Model.t): Vdom.t<Msg.t> => {
  div(
    list{class("app")},
    list{
      renderHeader(model),
      div(
        list{class("main-content")},
        list{
          renderSidebar(model),
          renderMainPanel(model),
          renderDetailPanel(model),
        },
      ),
      renderError(model),
    },
  )
}
