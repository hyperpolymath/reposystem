// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//
// TEA Update - State transitions

open Tea

// ============================================================================
// Raw JS helpers (must be defined before use)
// ============================================================================

/// Post a message to the parent window (for PanLL embedded mode).
%%raw(`
function postMessageToParent(payload) {
  if (typeof window !== 'undefined' && window.parent !== window) {
    window.parent.postMessage(JSON.parse(payload), '*');
  }
}
`)
@val external postMessageToParent: string => unit = "postMessageToParent"

// ============================================================================
// Async command helpers
// ============================================================================

let loadAllData = async () => {
  try {
    let repos = await Backend.Commands.getRepos()
    let edges = await Backend.Commands.getEdges()
    let groups = await Backend.Commands.getGroups()
    let aspects = await Backend.Commands.getAspects()
    let slots = await Backend.Commands.getSlots()
    let providers = await Backend.Commands.getProviders()
    let bindings = await Backend.Commands.getBindings()
    let plans = await Backend.Commands.getPlans()

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
    let edge = await Backend.Commands.addEdge(~from, ~to_, ~rel)
    Msg.EdgeAdded(Ok(edge))
  } catch {
  | Exn.Error(e) => Msg.EdgeAdded(Error(Exn.message(e)->Option.getOr("Unknown error")))
  }
}

let removeEdge = async edgeId => {
  try {
    await Backend.Commands.removeEdge(~edgeId)
    Msg.EdgeRemoved(Ok())
  } catch {
  | Exn.Error(e) => Msg.EdgeRemoved(Error(Exn.message(e)->Option.getOr("Unknown error")))
  }
}

let createGroup = async (name, description) => {
  try {
    let group = await Backend.Commands.createGroup(~name, ~description?)
    Msg.GroupCreated(Ok(group))
  } catch {
  | Exn.Error(e) => Msg.GroupCreated(Error(Exn.message(e)->Option.getOr("Unknown error")))
  }
}

let addToGroup = async (groupId, repoId) => {
  try {
    await Backend.Commands.addToGroup(~groupId, ~repoId)
    Msg.LoadAllData
  } catch {
  | Exn.Error(_) => Msg.LoadAllData
  }
}

let removeFromGroup = async (groupId, repoId) => {
  try {
    await Backend.Commands.removeFromGroup(~groupId, ~repoId)
    Msg.LoadAllData
  } catch {
  | Exn.Error(_) => Msg.LoadAllData
  }
}

let tagAspect = async (target, aspectId, weight, polarity, reason) => {
  try {
    let aspect = await Backend.Commands.tagAspect(~target, ~aspectId, ~weight, ~polarity, ~reason)
    Msg.AspectTagged(Ok(aspect))
  } catch {
  | Exn.Error(e) => Msg.AspectTagged(Error(Exn.message(e)->Option.getOr("Unknown error")))
  }
}

let removeAspect = async annotationId => {
  try {
    await Backend.Commands.removeAspect(~annotationId)
    Msg.AspectRemoved(Ok())
  } catch {
  | Exn.Error(e) => Msg.AspectRemoved(Error(Exn.message(e)->Option.getOr("Unknown error")))
  }
}

let createSlot = async (name, category, description, capabilities) => {
  try {
    let slot = await Backend.Commands.createSlot(~name, ~category, ~description, ~capabilities)
    Msg.SlotCreated(Ok(slot))
  } catch {
  | Exn.Error(e) => Msg.SlotCreated(Error(Exn.message(e)->Option.getOr("Unknown error")))
  }
}

let createProvider = async (args: Msg.createProviderArgs) => {
  try {
    let provider = await Backend.Commands.createProvider(
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
    let binding = await Backend.Commands.bindSlot(~consumerId, ~slotId, ~providerId)
    Msg.SlotBound(Ok(binding))
  } catch {
  | Exn.Error(e) => Msg.SlotBound(Error(Exn.message(e)->Option.getOr("Unknown error")))
  }
}

let unbindSlot = async bindingId => {
  try {
    await Backend.Commands.unbindSlot(~bindingId)
    Msg.SlotUnbound(Ok())
  } catch {
  | Exn.Error(e) => Msg.SlotUnbound(Error(Exn.message(e)->Option.getOr("Unknown error")))
  }
}

let saveGraph = async () => {
  try {
    await Backend.Commands.saveGraph()
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
///
/// Two modes:
///   Embedded (PanLL iframe): window.parent.postMessage
///   Standalone: HTTP POST to PanLL service API
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
    let message = {
      "type": "reposystem:graph-snapshot",
      "source": "reposystem-gui",
      "timestamp": Date.make()->Date.toISOString,
      "data": graphJson,
    }
    let payload = JSON.stringifyAny(message)->Option.getOr("{}")

    if PanllBridge.isPanllHost() {
      // Embedded — postMessage to parent PanLL window
      postMessageToParent(payload)
      Msg.DismissError
    } else {
      // Standalone — POST to PanLL Panel-W API
      try {
        let _response = await Fetch.fetch(
          PanllBridge.defaultEndpoint ++ "/api/v1/panel-w/graph",
          {method: #POST, body: Fetch.Body.string(payload)},
        )
        Msg.DismissError
      } catch {
      | Exn.Error(e) =>
        Msg.PanllConnectionChanged(
          PanllError(Exn.message(e)->Option.getOr("PanLL sync failed")),
        )
      }
    }
  }
}

// ============================================================================
// Update function
// ============================================================================

let update = (model: Model.t, msg: Msg.t): (Model.t, Cmd.t<Msg.t>) => {
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
        loadAllData()->ignore
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
        addEdge(from, to_, rel)->ignore
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
        removeEdge(edgeId)->ignore
      }),
    )

  | EdgeRemoved(Ok()) => (model, Cmd.msg(Msg.LoadAllData))
  | EdgeRemoved(Error(err)) => ({...model, error: Some(err)}, Cmd.none)

  // Group operations
  | CreateGroup(name, description) => (
      model,
      Cmd.call(_ => {
        createGroup(name, description)->ignore
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
        addToGroup(groupId, repoId)->ignore
      }),
    )

  | RemoveFromGroup(groupId, repoId) => (
      model,
      Cmd.call(_ => {
        removeFromGroup(groupId, repoId)->ignore
      }),
    )

  // Aspect operations
  | TagAspect(target, aspectId, weight, polarity, reason) => (
      model,
      Cmd.call(_ => {
        tagAspect(target, aspectId, weight, polarity, reason)->ignore
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
        removeAspect(annotationId)->ignore
      }),
    )

  | AspectRemoved(Ok()) => (model, Cmd.msg(Msg.LoadAllData))
  | AspectRemoved(Error(err)) => ({...model, error: Some(err)}, Cmd.none)

  // Slot operations
  | CreateSlot(name, category, description, capabilities) => (
      model,
      Cmd.call(_ => {
        createSlot(name, category, description, capabilities)->ignore
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
        createProvider(args)->ignore
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
        bindSlot(consumerId, slotId, providerId)->ignore
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
        unbindSlot(bindingId)->ignore
      }),
    )

  | SlotUnbound(Ok()) => (model, Cmd.msg(Msg.LoadAllData))
  | SlotUnbound(Error(err)) => ({...model, error: Some(err)}, Cmd.none)

  // Persistence
  | SaveGraph => (
      model,
      Cmd.call(_ => {
        saveGraph()->ignore
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

  // Creation forms — open with empty defaults
  | OpenEdgeForm => ({...model, openForm: EdgeForm({from: "", to_: "", rel: "uses"})}, Cmd.none)
  | OpenGroupForm => ({...model, openForm: GroupForm({name: "", description: ""})}, Cmd.none)
  | OpenAspectForm => ({...model, openForm: AspectForm({target: "", aspectId: "security", weight: "1", polarity: "risk", reason: ""})}, Cmd.none)
  | OpenSlotForm => ({...model, openForm: SlotForm({name: "", category: "", description: "", capabilities: ""})}, Cmd.none)
  | OpenProviderForm => ({...model, openForm: ProviderForm({name: "", slotId: "", providerType: "local", repoId: "", capabilities: "", priority: "100", isFallback: false})}, Cmd.none)
  | OpenBindingForm => ({...model, openForm: BindingForm({consumerId: "", slotId: "", providerId: ""})}, Cmd.none)
  | CloseForm => ({...model, openForm: NoForm}, Cmd.none)

  // Form field updates
  | UpdateFormField(field, value) => (
      {
        ...model,
        openForm: switch model.openForm {
        | EdgeForm(f) =>
          EdgeForm(
            switch field {
            | "from" => {...f, from: value}
            | "to" => {...f, to_: value}
            | "rel" => {...f, rel: value}
            | _ => f
            },
          )
        | GroupForm(f) =>
          GroupForm(
            switch field {
            | "name" => {...f, name: value}
            | "description" => {...f, description: value}
            | _ => f
            },
          )
        | AspectForm(f) =>
          AspectForm(
            switch field {
            | "target" => {...f, target: value}
            | "aspectId" => {...f, aspectId: value}
            | "weight" => {...f, weight: value}
            | "polarity" => {...f, polarity: value}
            | "reason" => {...f, reason: value}
            | _ => f
            },
          )
        | SlotForm(f) =>
          SlotForm(
            switch field {
            | "name" => {...f, name: value}
            | "category" => {...f, category: value}
            | "description" => {...f, description: value}
            | "capabilities" => {...f, capabilities: value}
            | _ => f
            },
          )
        | ProviderForm(f) =>
          ProviderForm(
            switch field {
            | "name" => {...f, name: value}
            | "slotId" => {...f, slotId: value}
            | "providerType" => {...f, providerType: value}
            | "repoId" => {...f, repoId: value}
            | "capabilities" => {...f, capabilities: value}
            | "priority" => {...f, priority: value}
            | _ => f
            },
          )
        | BindingForm(f) =>
          BindingForm(
            switch field {
            | "consumerId" => {...f, consumerId: value}
            | "slotId" => {...f, slotId: value}
            | "providerId" => {...f, providerId: value}
            | _ => f
            },
          )
        | NoForm => NoForm
        },
      },
      Cmd.none,
    )

  | UpdateFormBool(field, value) => (
      {
        ...model,
        openForm: switch model.openForm {
        | ProviderForm(f) =>
          ProviderForm(
            switch field {
            | "isFallback" => {...f, isFallback: value}
            | _ => f
            },
          )
        | other => other
        },
      },
      Cmd.none,
    )

  // Submit current form — dispatch to existing creation messages
  | SubmitForm =>
    switch model.openForm {
    | EdgeForm(f) => (
        {...model, openForm: NoForm},
        Cmd.msg(Msg.AddEdge(f.from, f.to_, f.rel)),
      )
    | GroupForm(f) => (
        {...model, openForm: NoForm},
        Cmd.msg(Msg.CreateGroup(f.name, f.description == "" ? None : Some(f.description))),
      )
    | AspectForm(f) => (
        {...model, openForm: NoForm},
        Cmd.msg(
          Msg.TagAspect(
            f.target,
            f.aspectId,
            Int.fromString(f.weight)->Option.getOr(1),
            f.polarity,
            f.reason,
          ),
        ),
      )
    | SlotForm(f) => (
        {...model, openForm: NoForm},
        Cmd.msg(
          Msg.CreateSlot(
            f.name,
            f.category,
            f.description,
            f.capabilities->String.split(",")->Array.map(String.trim)->Array.filter(s => s != ""),
          ),
        ),
      )
    | ProviderForm(f) => (
        {...model, openForm: NoForm},
        Cmd.msg(
          Msg.CreateProvider({
            name: f.name,
            slotId: f.slotId,
            providerType: f.providerType,
            repoId: f.repoId == "" ? None : Some(f.repoId),
            capabilities: f.capabilities
              ->String.split(",")
              ->Array.map(String.trim)
              ->Array.filter(s => s != ""),
            priority: Int.fromString(f.priority)->Option.getOr(100),
            isFallback: f.isFallback,
          }),
        ),
      )
    | BindingForm(f) => (
        {...model, openForm: NoForm},
        Cmd.msg(Msg.BindSlot(f.consumerId, f.slotId, f.providerId)),
      )
    | NoForm => (model, Cmd.none)
    }

  // PanLL integration
  | PanllConnect => (
      {...model, panll: {...model.panll, connection: PanllConnecting}},
      Cmd.call(_ => {
        connectToPanll()->ignore
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
        syncGraphToPanll(model)->ignore
      }),
    )

  | PanllInbound(request) => (
      model,
      switch request {
      | PanllConstraintRequest => Cmd.msg(Msg.PanllSyncGraph)
      | PanllScanRequest => Cmd.msg(Msg.LoadAllData)
      | PanllExportRequest(_format) => Cmd.msg(Msg.PanllSyncGraph)
      | PanllFilterRequest(filter) => Cmd.msg(Msg.SetSearchQuery(filter))
      | PanllScenarioRequest(_scenario) => Cmd.none // Requires scenario planning UI (P2)
      },
    )

  | PanllToggleAutoSync => (
      {...model, panll: {...model.panll, autoSync: !model.panll.autoSync}},
      Cmd.none,
    )
  }
}
