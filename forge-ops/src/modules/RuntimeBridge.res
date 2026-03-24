// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell

/// RuntimeBridge — Gossamer IPC bridge for reposystem-forge-ops.
///
/// All command modules use `RuntimeBridge.invoke` to call the Rust backend
/// through Gossamer's `window.__gossamer_invoke` IPC channel.
///
/// Gossamer injects `__gossamer_invoke` via `gossamer_channel_open()` before
/// the frontend loads. If the function is missing, a descriptive error is
/// returned so development builds (browser-only) get a clear message.

// ---------------------------------------------------------------------------
// Gossamer IPC binding
// ---------------------------------------------------------------------------

/// Gossamer IPC: injected by gossamer_channel_open() into the webview.
/// Signature: (commandName: string, payload: object) => Promise<any>
%%raw(`
function isGossamerRuntime() {
  return typeof window !== 'undefined'
    && typeof window.__gossamer_invoke === 'function';
}
`)
@val external isGossamerRuntime: unit => bool = "isGossamerRuntime"

%%raw(`
function gossamerInvoke(cmd, args) {
  return window.__gossamer_invoke(cmd, args);
}
`)
@val external gossamerInvoke: (string, 'a) => promise<'b> = "gossamerInvoke"

// ---------------------------------------------------------------------------
// Runtime type
// ---------------------------------------------------------------------------

/// The runtime currently in use.
type runtime =
  | Gossamer
  | BrowserOnly

/// Detect and return the current runtime.
let detectRuntime = (): runtime => {
  if isGossamerRuntime() {
    Gossamer
  } else {
    BrowserOnly
  }
}

// ---------------------------------------------------------------------------
// Unified invoke — primary API
// ---------------------------------------------------------------------------

/// Invoke a backend command through the Gossamer IPC channel.
///
/// - On Gossamer: calls `window.__gossamer_invoke(cmd, args)`
/// - On browser:  rejects with a descriptive error
///
/// This is the primary function all command modules should use.
let invoke = (cmd: string, args: 'a): promise<'b> => {
  if isGossamerRuntime() {
    gossamerInvoke(cmd, args)
  } else {
    Js.Promise.reject(
      Js.Exn.raiseError(
        `No desktop runtime — "${cmd}" requires Gossamer`,
      ),
    )
  }
}

/// Invoke a backend command with no arguments.
let invokeNoArgs = (cmd: string): promise<'b> => {
  invoke(cmd, ())
}

/// Check whether the Gossamer runtime is available.
let hasDesktopRuntime = (): bool => {
  isGossamerRuntime()
}

/// Get a human-readable name for the current runtime.
let runtimeName = (): string => {
  switch detectRuntime() {
  | Gossamer => "Gossamer"
  | BrowserOnly => "Browser"
  }
}
