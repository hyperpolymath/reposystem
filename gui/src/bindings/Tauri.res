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
  when: string,
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
  scenario_id: option<string>,
  created_at: string,
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

type plan = {
  kind: string,
  id: string,
  name: string,
  description: option<string>,
  scenario_id: option<string>,
  status: planStatus,
  risk_level: riskLevel,
  created_at: string,
  applied_at: option<string>,
}

// ============================================================================
// Commands
// ============================================================================

module Commands = {
  // Read operations
  let getRepos = () => invokeNoArgs("get_repos"): promise<array<repo>>
  let getEdges = () => invokeNoArgs("get_edges"): promise<array<edge>>
  let getGroups = () => invokeNoArgs("get_groups"): promise<array<group>>
  let getAspects = () => invokeNoArgs("get_aspects"): promise<array<aspectAnnotation>>
  let getSlots = () => invokeNoArgs("get_slots"): promise<array<slot>>
  let getProviders = () => invokeNoArgs("get_providers"): promise<array<provider>>
  let getBindings = () => invokeNoArgs("get_bindings"): promise<array<slotBinding>>
  let getPlans = () => invokeNoArgs("get_plans"): promise<array<plan>>

  // Edge operations
  let addEdge = (~from: string, ~to_: string, ~rel: string, ~label: option<string>=?) =>
    invoke("add_edge", {"from": from, "to": to_, "rel": rel, "label": label}): promise<edge>

  let removeEdge = (~edgeId: string) =>
    invoke("remove_edge", {"edge_id": edgeId}): promise<unit>

  // Group operations
  let createGroup = (~name: string, ~description: option<string>=?) =>
    invoke("create_group", {"name": name, "description": description}): promise<group>

  let addToGroup = (~groupId: string, ~repoId: string) =>
    invoke("add_to_group", {"group_id": groupId, "repo_id": repoId}): promise<unit>

  let removeFromGroup = (~groupId: string, ~repoId: string) =>
    invoke("remove_from_group", {"group_id": groupId, "repo_id": repoId}): promise<unit>

  // Aspect operations
  let tagAspect = (
    ~target: string,
    ~aspectId: string,
    ~weight: int,
    ~polarity: string,
    ~reason: string,
  ) =>
    invoke("tag_aspect", {
      "target": target,
      "aspect_id": aspectId,
      "weight": weight,
      "polarity": polarity,
      "reason": reason,
    }): promise<aspectAnnotation>

  let removeAspect = (~annotationId: string) =>
    invoke("remove_aspect", {"annotation_id": annotationId}): promise<unit>

  // Slot operations
  let createSlot = (
    ~name: string,
    ~category: string,
    ~interfaceVersion: option<string>=?,
    ~description: string,
    ~capabilities: array<string>,
  ) =>
    invoke("create_slot", {
      "name": name,
      "category": category,
      "interface_version": interfaceVersion,
      "description": description,
      "capabilities": capabilities,
    }): promise<slot>

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
  ) =>
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
    }): promise<provider>

  let bindSlot = (~consumerId: string, ~slotId: string, ~providerId: string) =>
    invoke("bind_slot", {
      "consumer_id": consumerId,
      "slot_id": slotId,
      "provider_id": providerId,
    }): promise<slotBinding>

  let unbindSlot = (~bindingId: string) =>
    invoke("unbind_slot", {"binding_id": bindingId}): promise<unit>

  // Persistence
  let saveGraph = () => invokeNoArgs("save_graph"): promise<unit>
}
