// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//
// TEA Messages - All application events

open Tauri

// Message types
type t =
  // Navigation
  | SetTab(Model.tab)
  | SetSearchQuery(string)
  // Selection
  | SelectRepo(repo)
  | SelectEdge(edge)
  | SelectGroup(group)
  | SelectAspect(aspectAnnotation)
  | SelectSlot(slot)
  | SelectProvider(provider)
  | SelectBinding(slotBinding)
  | SelectPlan(plan)
  | ClearSelection
  // Data loading
  | LoadAllData
  | DataLoaded(result<loadedData, string>)
  // Edge operations
  | AddEdge(string, string, string) // from, to, rel
  | EdgeAdded(result<edge, string>)
  | RemoveEdge(string)
  | EdgeRemoved(result<unit, string>)
  // Group operations
  | CreateGroup(string, option<string>) // name, description
  | GroupCreated(result<group, string>)
  | AddToGroup(string, string) // groupId, repoId
  | RemoveFromGroup(string, string)
  // Aspect operations
  | TagAspect(string, string, int, string, string) // target, aspectId, weight, polarity, reason
  | AspectTagged(result<aspectAnnotation, string>)
  | RemoveAspect(string)
  | AspectRemoved(result<unit, string>)
  // Slot operations
  | CreateSlot(string, string, string, array<string>) // name, category, description, capabilities
  | SlotCreated(result<slot, string>)
  | CreateProvider(createProviderArgs)
  | ProviderCreated(result<provider, string>)
  | BindSlot(string, string, string) // consumerId, slotId, providerId
  | SlotBound(result<slotBinding, string>)
  | UnbindSlot(string)
  | SlotUnbound(result<unit, string>)
  // Persistence
  | SaveGraph
  | GraphSaved(result<unit, string>)
  // Graph interaction
  | NodeDragStart(string)
  | NodeDrag(string, float, float)
  | NodeDragEnd(string)
  | GraphZoom(float)
  // Error handling
  | DismissError
  // Creation forms
  | OpenEdgeForm
  | OpenGroupForm
  | OpenAspectForm
  | OpenSlotForm
  | OpenProviderForm
  | OpenBindingForm
  | CloseForm
  | UpdateFormField(string, string)
  | UpdateFormBool(string, bool)
  | SubmitForm
  // PanLL integration
  | PanllConnect
  | PanllDisconnect
  | PanllConnectionChanged(PanllBridge.panllConnectionStatus)
  | PanllSyncGraph
  | PanllInbound(PanllBridge.panllInbound)
  | PanllToggleAutoSync

// Helper types for complex messages
and loadedData = {
  repos: array<repo>,
  edges: array<edge>,
  groups: array<group>,
  aspects: array<aspectAnnotation>,
  slots: array<slot>,
  providers: array<provider>,
  bindings: array<slotBinding>,
  plans: array<plan>,
}

and createProviderArgs = {
  name: string,
  slotId: string,
  providerType: string,
  repoId: option<string>,
  capabilities: array<string>,
  priority: int,
  isFallback: bool,
}
