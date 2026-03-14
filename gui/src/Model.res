// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//
// TEA Model - Application state

open Tauri

// Tab navigation
type tab =
  | Dashboard
  | Repos
  | Edges
  | Groups
  | Aspects
  | Slots
  | Plans

// Selected item for detail panel
type selectedItem =
  | NoSelection
  | SelectedRepo(repo)
  | SelectedEdge(edge)
  | SelectedGroup(group)
  | SelectedAspect(aspectAnnotation)
  | SelectedSlot(slot)
  | SelectedProvider(provider)
  | SelectedBinding(slotBinding)
  | SelectedPlan(plan)

// Graph node for D3 visualization
type graphNode = {
  id: string,
  label: string,
  kind: [#repo | #slot | #provider],
  x: float,
  y: float,
  vx: float,
  vy: float,
  fx: option<float>,
  fy: option<float>,
}

// Graph link for D3 visualization
type graphLink = {
  source: string,
  target: string,
  kind: [#edge | #binding],
  label: option<string>,
}

// Main application model
type t = {
  // Data
  repos: array<repo>,
  edges: array<edge>,
  groups: array<group>,
  aspects: array<aspectAnnotation>,
  slots: array<slot>,
  providers: array<provider>,
  bindings: array<slotBinding>,
  plans: array<plan>,
  // UI state
  activeTab: tab,
  selectedItem: selectedItem,
  searchQuery: string,
  // Graph visualization state
  graphNodes: array<graphNode>,
  graphLinks: array<graphLink>,
  // Loading state
  loading: bool,
  error: option<string>,
  // PanLL integration
  panll: PanllBridge.panllState,
}

// Initial model
let init = () => {
  repos: [],
  edges: [],
  groups: [],
  aspects: [],
  slots: [],
  providers: [],
  bindings: [],
  plans: [],
  activeTab: Dashboard,
  selectedItem: NoSelection,
  searchQuery: "",
  graphNodes: [],
  graphLinks: [],
  loading: true,
  error: None,
  panll: PanllBridge.init,
}

// Tab helpers
let tabToString = tab =>
  switch tab {
  | Dashboard => "Dashboard"
  | Repos => "Repos"
  | Edges => "Edges"
  | Groups => "Groups"
  | Aspects => "Aspects"
  | Slots => "Slots"
  | Plans => "Plans"
  }

let allTabs = [Dashboard, Repos, Edges, Groups, Aspects, Slots, Plans]

// Build graph nodes from model data
let buildGraphNodes = (model: t): array<graphNode> => {
  let repoNodes =
    model.repos->Array.map(r => {
      id: r.id,
      label: r.name,
      kind: #repo,
      x: Math.random() *. 800.0,
      y: Math.random() *. 600.0,
      vx: 0.0,
      vy: 0.0,
      fx: None,
      fy: None,
    })

  let slotNodes =
    model.slots->Array.map(s => {
      id: s.id,
      label: s.name,
      kind: #slot,
      x: Math.random() *. 800.0,
      y: Math.random() *. 600.0,
      vx: 0.0,
      vy: 0.0,
      fx: None,
      fy: None,
    })

  let providerNodes =
    model.providers->Array.map(p => {
      id: p.id,
      label: p.name,
      kind: #provider,
      x: Math.random() *. 800.0,
      y: Math.random() *. 600.0,
      vx: 0.0,
      vy: 0.0,
      fx: None,
      fy: None,
    })

  Array.concatMany([repoNodes, slotNodes, providerNodes])
}

// Build graph links from model data
let buildGraphLinks = (model: t): array<graphLink> => {
  let edgeLinks =
    model.edges->Array.map(e => {
      source: e.from,
      target: e.to_,
      kind: #edge,
      label: e.label,
    })

  let bindingLinks =
    model.bindings->Array.map(b => {
      source: b.consumer_id,
      target: b.provider_id,
      kind: #binding,
      label: Some("uses"),
    })

  Array.concat(edgeLinks, bindingLinks)
}

// Update graph data in model
let withGraphData = (model: t): t => {
  ...model,
  graphNodes: buildGraphNodes(model),
  graphLinks: buildGraphLinks(model),
}
