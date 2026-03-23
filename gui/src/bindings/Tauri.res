// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//
// Backend IPC bindings for ReScript
// Uses RuntimeBridge for Gossamer/Tauri/browser dispatch

/// Invoke a backend command with arguments (delegates to RuntimeBridge).
let invoke = RuntimeBridge.invoke

/// Invoke a backend command with no arguments (delegates to RuntimeBridge).
let invokeNoArgs = RuntimeBridge.invokeNoArgs

// ============================================================================
// Types matching Rust types
// ============================================================================

type forge =
  | @as("gh") GitHub
  | @as("gl") GitLab
  | @as("bb") Bitbucket
  | @as("cb") Codeberg
  | @as("sr") Sourcehut
  | @as("local") Local

type visibility =
  | @as("public") Public
  | @as("private") Private
  | @as("internal") Internal

type importMeta = {
  source: string,
  path_hint: option<string>,
  imported_at: string,
}

type repo = {
  kind: string,
  id: string,
  forge: forge,
  owner: string,
  name: string,
  default_branch: string,
  visibility: visibility,
  tags: array<string>,
  imports: importMeta,
}

type relationType =
  | @as("uses") Uses
  | @as("provides") Provides
  | @as("extends") Extends
  | @as("mirrors") Mirrors
  | @as("replaces") Replaces

type channel =
  | @as("api") Api
  | @as("artifact") Artifact
  | @as("config") Config
  | @as("runtime") Runtime
  | @as("human") Human
  | @as("unknown") Unknown

type edgeMeta = {
  created_by: string,
  created_at: string,
}

type edge = {
  kind: string,
  id: string,
  from: string,
  @as("to") to_: string,
  rel: relationType,
  channel: channel,
  label: option<string>,
  meta: edgeMeta,
}

type group = {
  kind: string,
  id: string,
  name: string,
  description: option<string>,
  members: array<string>,
}

type polarity =
  | @as("risk") Risk
  | @as("strength") Strength
  | @as("neutral") Neutral

type annotationSource = {
  mode: string,
  who: string,
  @as("when") when_: string,
  rule_id: option<string>,
}

type aspectAnnotation = {
  kind: string,
  id: string,
  target: string,
  aspect_id: string,
  weight: int,
  polarity: polarity,
  reason: string,
  source: annotationSource,
}

type slot = {
  kind: string,
  id: string,
  name: string,
  category: string,
  interface_version: option<string>,
  description: string,
  required_capabilities: array<string>,
  created_at: string,
}

type providerType =
  | @as("local") Local
  | @as("ecosystem") Ecosystem
  | @as("external") External
  | @as("stub") Stub

type provider = {
  kind: string,
  id: string,
  name: string,
  slot_id: string,
  provider_type: providerType,
  repo_id: option<string>,
  external_uri: option<string>,
  interface_version: option<string>,
  capabilities: array<string>,
  priority: int,
  is_fallback: bool,
  created_at: string,
}

type bindingMode =
  | @as("manual") Manual
  | @as("auto") Auto
  | @as("scenario") Scenario
  | @as("default") Default

type slotBinding = {
  kind: string,
  id: string,
  consumer_id: string,
  slot_id: string,
  provider_id: string,
  mode: bindingMode,
  created_at: string,
  created_by: string,
}

type riskLevel =
  | @as("low") Low
  | @as("medium") Medium
  | @as("high") High
  | @as("critical") Critical

type planStatus =
  | @as("draft") Draft
  | @as("ready") Ready
  | @as("applied") Applied
  | @as("rolled_back") RolledBack
  | @as("cancelled") Cancelled

/// Plan operation — tagged union matching Rust's PlanOp enum.
/// Represented as generic JSON for display; the GUI doesn't create plans yet.
type planOp = {
  op: string,
}

type plan = {
  kind: string,
  id: string,
  name: string,
  scenario_id: string,
  description: option<string>,
  operations: array<planOp>,
  overall_risk: riskLevel,
  status: planStatus,
  created_at: string,
  created_by: string,
  applied_at: option<string>,
  rollback_plan_id: option<string>,
}

// ============================================================================
// Commands
// ============================================================================

module Commands = {
  // Read operations
  let getRepos = (): promise<array<repo>> => invokeNoArgs("get_repos")
  let getEdges = (): promise<array<edge>> => invokeNoArgs("get_edges")
  let getGroups = (): promise<array<group>> => invokeNoArgs("get_groups")
  let getAspects = (): promise<array<aspectAnnotation>> => invokeNoArgs("get_aspects")
  let getSlots = (): promise<array<slot>> => invokeNoArgs("get_slots")
  let getProviders = (): promise<array<provider>> => invokeNoArgs("get_providers")
  let getBindings = (): promise<array<slotBinding>> => invokeNoArgs("get_bindings")
  let getPlans = (): promise<array<plan>> => invokeNoArgs("get_plans")

  // Edge operations
  let addEdge = (~from: string, ~to_: string, ~rel: string, ~label: option<string>=?): promise<edge> =>
    invoke("add_edge", {"from": from, "to": to_, "rel": rel, "label": label})

  let removeEdge = (~edgeId: string): promise<unit> =>
    invoke("remove_edge", {"edge_id": edgeId})

  // Group operations
  let createGroup = (~name: string, ~description: option<string>=?): promise<group> =>
    invoke("create_group", {"name": name, "description": description})

  let addToGroup = (~groupId: string, ~repoId: string): promise<unit> =>
    invoke("add_to_group", {"group_id": groupId, "repo_id": repoId})

  let removeFromGroup = (~groupId: string, ~repoId: string): promise<unit> =>
    invoke("remove_from_group", {"group_id": groupId, "repo_id": repoId})

  // Aspect operations
  let tagAspect = (
    ~target: string,
    ~aspectId: string,
    ~weight: int,
    ~polarity: string,
    ~reason: string,
  ): promise<aspectAnnotation> =>
    invoke("tag_aspect", {
      "target": target,
      "aspect_id": aspectId,
      "weight": weight,
      "polarity": polarity,
      "reason": reason,
    })

  let removeAspect = (~annotationId: string): promise<unit> =>
    invoke("remove_aspect", {"annotation_id": annotationId})

  // Slot operations
  let createSlot = (
    ~name: string,
    ~category: string,
    ~interfaceVersion: option<string>=?,
    ~description: string,
    ~capabilities: array<string>,
  ): promise<slot> =>
    invoke("create_slot", {
      "name": name,
      "category": category,
      "interface_version": interfaceVersion,
      "description": description,
      "capabilities": capabilities,
    })

  let createProvider = (
    ~name: string,
    ~slotId: string,
    ~providerType: string,
    ~repoId: option<string>=?,
    ~externalUri: option<string>=?,
    ~interfaceVersion: option<string>=?,
    ~capabilities: array<string>,
    ~priority: int,
    ~isFallback: bool,
  ): promise<provider> =>
    invoke("create_provider", {
      "name": name,
      "slot_id": slotId,
      "provider_type": providerType,
      "repo_id": repoId,
      "external_uri": externalUri,
      "interface_version": interfaceVersion,
      "capabilities": capabilities,
      "priority": priority,
      "is_fallback": isFallback,
    })

  let bindSlot = (~consumerId: string, ~slotId: string, ~providerId: string): promise<slotBinding> =>
    invoke("bind_slot", {
      "consumer_id": consumerId,
      "slot_id": slotId,
      "provider_id": providerId,
    })

  let unbindSlot = (~bindingId: string): promise<unit> =>
    invoke("unbind_slot", {"binding_id": bindingId})

  // Persistence
  let saveGraph = (): promise<unit> => invokeNoArgs("save_graph")
}
