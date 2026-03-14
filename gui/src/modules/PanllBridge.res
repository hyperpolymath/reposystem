// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell

/// PanLL Bridge — Communication layer between Reposystem GUI and PanLL.
///
/// Reposystem can operate standalone (Tauri desktop, browser) or as an
/// embedded panel inside PanLL. This bridge handles both modes:
///
///   Standalone mode: Reposystem runs its own TEA loop; PanLL bridge is
///   dormant. Graph data stays local.
///
///   Embedded mode: Reposystem pushes ecosystem state to PanLL panels:
///     Panel-L receives governance constraints and slot policies
///     Panel-N receives health events for AI reasoning
///     Panel-W receives graph snapshots for barycentre rendering
///
/// Communication uses window.postMessage when in-browser (PanLL iframe or
/// same-origin embed) or Tauri invoke when running as a Tauri sub-window.

/// PanLL connection state.
type panllConnectionStatus =
  | PanllDisconnected      // Not connected to any PanLL instance
  | PanllConnecting        // Handshake in progress
  | PanllConnected(string) // Connected — parameter is PanLL instance ID
  | PanllError(string)     // Connection failed

/// Messages sent TO PanLL (outbound).
type panllOutbound =
  | PanllGraphSnapshot(string)     // JSON-serialised ecosystem graph
  | PanllConstraintUpdate(string)  // Governance constraint changes
  | PanllHealthEvent(string)       // Ecosystem health event
  | PanllSlotCoverage(string)      // Slot binding coverage report
  | PanllAspectSummary(string)     // Aggregated aspect scores
  | PanllScenarioResult(string)    // Scenario planning output

/// Messages received FROM PanLL (inbound).
type panllInbound =
  | PanllConstraintRequest         // Panel-L wants current constraints
  | PanllScanRequest               // Panel-N wants a fresh scan
  | PanllExportRequest(string)     // Panel-W wants export in given format
  | PanllFilterRequest(string)     // Panel-W wants to filter by aspect/group
  | PanllScenarioRequest(string)   // Panel-N wants to run a scenario

/// PanLL bridge state, composed into the main model.
type panllState = {
  connection: panllConnectionStatus,
  lastSentAt: option<string>,      // ISO 8601 timestamp of last outbound message
  lastReceivedAt: option<string>,  // ISO 8601 timestamp of last inbound message
  autoSync: bool,                  // Whether to push graph changes automatically
  instanceId: option<string>,      // PanLL instance we're connected to
}

/// Initial PanLL bridge state.
let init: panllState = {
  connection: PanllDisconnected,
  lastSentAt: None,
  lastReceivedAt: None,
  autoSync: false,
  instanceId: None,
}

/// PanLL service endpoint (default, overridable via Tauri config).
let defaultEndpoint = "http://localhost:1430"

/// Detect whether we're running inside a PanLL host.
/// Checks for PanLL's presence marker on the window object.
@val @scope("window")
external panllInternals: Nullable.t<{..}> = "__PANLL_INTERNALS__"

let isPanllHost = (): bool => {
  panllInternals->Nullable.toOption->Option.isSome
}

/// Connection status as a human-readable label.
let connectionLabel = (status: panllConnectionStatus): string => {
  switch status {
  | PanllDisconnected => "Disconnected"
  | PanllConnecting => "Connecting..."
  | PanllConnected(id) => `Connected (${id})`
  | PanllError(err) => `Error: ${err}`
  }
}

/// Whether the bridge is in a connected state.
let isConnected = (state: panllState): bool => {
  switch state.connection {
  | PanllConnected(_) => true
  | _ => false
  }
}
