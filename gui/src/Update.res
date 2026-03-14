// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//
// TEA Update - State transitions

open Tea

// Update function
let update = (msg: Msg.t, model: Model.t): (Model.t, Cmd.t<Msg.t>) => {
  switch msg {
  // Navigation
  | SetTab(tab) => ({...model, activeTab: tab}, Cmd.none)
  | SetSearchQuery(query) => ({...model, searchQuery: query}, Cmd.none)

  // Selection
  | SelectRepo(repo) => ({...model, selectedItem: SelectedRepo(repo)}, Cmd.none)
  | SelectEdge(edge) => ({...model, selectedItem: SelectedEdge(edge)}, Cmd.none)
  | SelectGroup(group) => ({...model, selectedItem: SelectedGroup(group)}, Cmd.none)
  | SelectAspect(aspect) => ({...model, selectedItem: SelectedAspect(aspect)}, Cmd.none)
  | SelectSlot(slot) => ({...model, selectedItem: SelectedSlot(slot)}, Cmd.none)
  | SelectProvider(provider) => ({...model, selectedItem: SelectedProvider(provider)}, Cmd.none)
  | SelectBinding(binding) => ({...model, selectedItem: SelectedBinding(binding)}, Cmd.none)
  | SelectPlan(plan) => ({...model, selectedItem: SelectedPlan(plan)}, Cmd.none)
  | ClearSelection => ({...model, selectedItem: NoSelection}, Cmd.none)

  // Data loading
  | LoadAllData => (
      {...model, loading: true, error: None},
      Cmd.call(_ => {
        loadAllData()
      }),
    )

  | DataLoaded(Ok(data)) => (
      {
        ...model,
        repos: data.repos,
        edges: data.edges,
        groups: data.groups,
        aspects: data.aspects,
        slots: data.slots,
        providers: data.providers,
        bindings: data.bindings,
        plans: data.plans,
        loading: false,
        error: None,
      }->Model.withGraphData,
      Cmd.none,
    )

  | DataLoaded(Error(err)) => ({...model, loading: false, error: Some(err)}, Cmd.none)

  // Edge operations
  | AddEdge(from, to_, rel) => (
      model,
      Cmd.call(_ => {
        addEdge(from, to_, rel)
      }),
    )

  | EdgeAdded(Ok(edge)) => (
      {
        ...model,
        edges: Array.concat(model.edges, [edge]),
      }->Model.withGraphData,
      Cmd.none,
    )

  | EdgeAdded(Error(err)) => ({...model, error: Some(err)}, Cmd.none)

  | RemoveEdge(edgeId) => (
      model,
      Cmd.call(_ => {
        removeEdge(edgeId)
      }),
    )

  | EdgeRemoved(Ok()) => (model, Cmd.msg(LoadAllData))
  | EdgeRemoved(Error(err)) => ({...model, error: Some(err)}, Cmd.none)

  // Group operations
  | CreateGroup(name, description) => (
      model,
      Cmd.call(_ => {
        createGroup(name, description)
      }),
    )

  | GroupCreated(Ok(group)) => (
      {...model, groups: Array.concat(model.groups, [group])},
      Cmd.none,
    )

  | GroupCreated(Error(err)) => ({...model, error: Some(err)}, Cmd.none)

  | AddToGroup(groupId, repoId) => (
      model,
      Cmd.call(_ => {
        addToGroup(groupId, repoId)
      }),
    )

  | RemoveFromGroup(groupId, repoId) => (
      model,
      Cmd.call(_ => {
        removeFromGroup(groupId, repoId)
      }),
    )

  // Aspect operations
  | TagAspect(target, aspectId, weight, polarity, reason) => (
      model,
      Cmd.call(_ => {
        tagAspect(target, aspectId, weight, polarity, reason)
      }),
    )

  | AspectTagged(Ok(aspect)) => (
      {...model, aspects: Array.concat(model.aspects, [aspect])},
      Cmd.none,
    )

  | AspectTagged(Error(err)) => ({...model, error: Some(err)}, Cmd.none)

  | RemoveAspect(annotationId) => (
      model,
      Cmd.call(_ => {
        removeAspect(annotationId)
      }),
    )

  | AspectRemoved(Ok()) => (model, Cmd.msg(LoadAllData))
  | AspectRemoved(Error(err)) => ({...model, error: Some(err)}, Cmd.none)

  // Slot operations
  | CreateSlot(name, category, description, capabilities) => (
      model,
      Cmd.call(_ => {
        createSlot(name, category, description, capabilities)
      }),
    )

  | SlotCreated(Ok(slot)) => (
      {
        ...model,
        slots: Array.concat(model.slots, [slot]),
      }->Model.withGraphData,
      Cmd.none,
    )

  | SlotCreated(Error(err)) => ({...model, error: Some(err)}, Cmd.none)

  | CreateProvider(args) => (
      model,
      Cmd.call(_ => {
        createProvider(args)
      }),
    )

  | ProviderCreated(Ok(provider)) => (
      {
        ...model,
        providers: Array.concat(model.providers, [provider]),
      }->Model.withGraphData,
      Cmd.none,
    )

  | ProviderCreated(Error(err)) => ({...model, error: Some(err)}, Cmd.none)

  | BindSlot(consumerId, slotId, providerId) => (
      model,
      Cmd.call(_ => {
        bindSlot(consumerId, slotId, providerId)
      }),
    )

  | SlotBound(Ok(binding)) => (
      {
        ...model,
        bindings: Array.concat(model.bindings, [binding]),
      }->Model.withGraphData,
      Cmd.none,
    )

  | SlotBound(Error(err)) => ({...model, error: Some(err)}, Cmd.none)

  | UnbindSlot(bindingId) => (
      model,
      Cmd.call(_ => {
        unbindSlot(bindingId)
      }),
    )

  | SlotUnbound(Ok()) => (model, Cmd.msg(LoadAllData))
  | SlotUnbound(Error(err)) => ({...model, error: Some(err)}, Cmd.none)

  // Persistence
  | SaveGraph => (
      model,
      Cmd.call(_ => {
        saveGraph()
      }),
    )

  | GraphSaved(Ok()) => (model, Cmd.none)
  | GraphSaved(Error(err)) => ({...model, error: Some(err)}, Cmd.none)

  // Graph interaction
  | NodeDragStart(_nodeId) => (model, Cmd.none)
  | NodeDrag(_nodeId, _x, _y) => (model, Cmd.none) // Handled by D3
  | NodeDragEnd(_nodeId) => (model, Cmd.none)
  | GraphZoom(_scale) => (model, Cmd.none) // Handled by D3

  // Error handling
  | DismissError => ({...model, error: None}, Cmd.none)

  // PanLL integration
  | PanllConnect => (
      {...model, panll: {...model.panll, connection: PanllConnecting}},
      Cmd.call(_ => {
        connectToPanll()
      }),
    )

  | PanllDisconnect => (
      {...model, panll: {...model.panll, connection: PanllDisconnected, instanceId: None}},
      Cmd.none,
    )

  | PanllConnectionChanged(status) => (
      {
        ...model,
        panll: {
          ...model.panll,
          connection: status,
          instanceId: switch status {
          | PanllConnected(id) => Some(id)
          | _ => model.panll.instanceId
          },
        },
      },
      Cmd.none,
    )

  | PanllSyncGraph => (
      model,
      Cmd.call(_ => {
        syncGraphToPanll(model)
      }),
    )

  | PanllInbound(request) => (
      model,
      switch request {
      | PanllConstraintRequest => Cmd.none // TODO: send constraints to Panel-L
      | PanllScanRequest => Cmd.msg(Msg.LoadAllData)
      | PanllExportRequest(_format) => Cmd.none // TODO: export in requested format
      | PanllFilterRequest(_filter) => Cmd.none // TODO: apply PanLL-requested filter
      | PanllScenarioRequest(_scenario) => Cmd.none // TODO: run requested scenario
      },
    )

  | PanllToggleAutoSync => (
      {...model, panll: {...model.panll, autoSync: !model.panll.autoSync}},
      Cmd.none,
    )
  }
}

// ============================================================================
// Async command helpers
// ============================================================================

let loadAllData = async () => {
  try {
    let repos = await Tauri.Commands.getRepos()
    let edges = await Tauri.Commands.getEdges()
    let groups = await Tauri.Commands.getGroups()
    let aspects = await Tauri.Commands.getAspects()
    let slots = await Tauri.Commands.getSlots()
    let providers = await Tauri.Commands.getProviders()
    let bindings = await Tauri.Commands.getBindings()
    let plans = await Tauri.Commands.getPlans()

    Msg.DataLoaded(
      Ok({
        repos,
        edges,
        groups,
        aspects,
        slots,
        providers,
        bindings,
        plans,
      }),
    )
  } catch {
  | Exn.Error(e) => Msg.DataLoaded(Error(Exn.message(e)->Option.getOr("Unknown error")))
  }
}

let addEdge = async (from, to_, rel) => {
  try {
    let edge = await Tauri.Commands.addEdge(~from, ~to_, ~rel)
    Msg.EdgeAdded(Ok(edge))
  } catch {
  | Exn.Error(e) => Msg.EdgeAdded(Error(Exn.message(e)->Option.getOr("Unknown error")))
  }
}

let removeEdge = async edgeId => {
  try {
    await Tauri.Commands.removeEdge(~edgeId)
    Msg.EdgeRemoved(Ok())
  } catch {
  | Exn.Error(e) => Msg.EdgeRemoved(Error(Exn.message(e)->Option.getOr("Unknown error")))
  }
}

let createGroup = async (name, description) => {
  try {
    let group = await Tauri.Commands.createGroup(~name, ~description?)
    Msg.GroupCreated(Ok(group))
  } catch {
  | Exn.Error(e) => Msg.GroupCreated(Error(Exn.message(e)->Option.getOr("Unknown error")))
  }
}

let addToGroup = async (groupId, repoId) => {
  try {
    await Tauri.Commands.addToGroup(~groupId, ~repoId)
    Msg.LoadAllData
  } catch {
  | Exn.Error(_) => Msg.LoadAllData
  }
}

let removeFromGroup = async (groupId, repoId) => {
  try {
    await Tauri.Commands.removeFromGroup(~groupId, ~repoId)
    Msg.LoadAllData
  } catch {
  | Exn.Error(_) => Msg.LoadAllData
  }
}

let tagAspect = async (target, aspectId, weight, polarity, reason) => {
  try {
    let aspect = await Tauri.Commands.tagAspect(~target, ~aspectId, ~weight, ~polarity, ~reason)
    Msg.AspectTagged(Ok(aspect))
  } catch {
  | Exn.Error(e) => Msg.AspectTagged(Error(Exn.message(e)->Option.getOr("Unknown error")))
  }
}

let removeAspect = async annotationId => {
  try {
    await Tauri.Commands.removeAspect(~annotationId)
    Msg.AspectRemoved(Ok())
  } catch {
  | Exn.Error(e) => Msg.AspectRemoved(Error(Exn.message(e)->Option.getOr("Unknown error")))
  }
}

let createSlot = async (name, category, description, capabilities) => {
  try {
    let slot = await Tauri.Commands.createSlot(~name, ~category, ~description, ~capabilities)
    Msg.SlotCreated(Ok(slot))
  } catch {
  | Exn.Error(e) => Msg.SlotCreated(Error(Exn.message(e)->Option.getOr("Unknown error")))
  }
}

let createProvider = async (args: Msg.createProviderArgs) => {
  try {
    let provider = await Tauri.Commands.createProvider(
      ~name=args.name,
      ~slotId=args.slotId,
      ~providerType=args.providerType,
      ~repoId=?args.repoId,
      ~capabilities=args.capabilities,
      ~priority=args.priority,
      ~isFallback=args.isFallback,
    )
    Msg.ProviderCreated(Ok(provider))
  } catch {
  | Exn.Error(e) => Msg.ProviderCreated(Error(Exn.message(e)->Option.getOr("Unknown error")))
  }
}

let bindSlot = async (consumerId, slotId, providerId) => {
  try {
    let binding = await Tauri.Commands.bindSlot(~consumerId, ~slotId, ~providerId)
    Msg.SlotBound(Ok(binding))
  } catch {
  | Exn.Error(e) => Msg.SlotBound(Error(Exn.message(e)->Option.getOr("Unknown error")))
  }
}

let unbindSlot = async bindingId => {
  try {
    await Tauri.Commands.unbindSlot(~bindingId)
    Msg.SlotUnbound(Ok())
  } catch {
  | Exn.Error(e) => Msg.SlotUnbound(Error(Exn.message(e)->Option.getOr("Unknown error")))
  }
}

let saveGraph = async () => {
  try {
    await Tauri.Commands.saveGraph()
    Msg.GraphSaved(Ok())
  } catch {
  | Exn.Error(e) => Msg.GraphSaved(Error(Exn.message(e)->Option.getOr("Unknown error")))
  }
}

// ============================================================================
// PanLL bridge helpers
// ============================================================================

/// Attempt to connect to a running PanLL instance.
let connectToPanll = async () => {
  if PanllBridge.isPanllHost() {
    // Running inside PanLL — direct connection via shared internals
    Msg.PanllConnectionChanged(PanllConnected("embedded"))
  } else {
    // Standalone — attempt HTTP handshake with PanLL service
    try {
      let _response = await Fetch.fetch(
        PanllBridge.defaultEndpoint ++ "/api/v1/health",
        {method: #GET},
      )
      Msg.PanllConnectionChanged(PanllConnected("standalone"))
    } catch {
    | Exn.Error(e) =>
      Msg.PanllConnectionChanged(
        PanllError(Exn.message(e)->Option.getOr("Failed to reach PanLL")),
      )
    }
  }
}

/// Push the current ecosystem graph to PanLL for Panel-W rendering.
let syncGraphToPanll = async (model: Model.t) => {
  if !(model.panll->PanllBridge.isConnected) {
    Msg.DismissError
  } else {
    let graphJson = {
      "repos": model.repos,
      "edges": model.edges,
      "groups": model.groups,
      "aspects": model.aspects,
      "slots": model.slots,
      "providers": model.providers,
      "bindings": model.bindings,
      "plans": model.plans,
    }
    let payload = JSON.stringifyAny(graphJson)->Option.getOr("{}")
    ignore(payload)
    // TODO: send via postMessage (embedded) or HTTP POST (standalone)
    Msg.DismissError
  }
}
