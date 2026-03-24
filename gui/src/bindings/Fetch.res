// SPDX-License-Identifier: PMPL-1.0-or-later
// Minimal Fetch API bindings for PanLL bridge HTTP calls.

type response

type method = [#GET | #POST | #PUT | #DELETE]

module Body = {
  /// Wrap a string as a fetch body (identity — fetch accepts string bodies).
  let string = (s: string): string => s
}

type requestInit = {
  method: method,
  body?: string,
}

@val external fetch: (string, requestInit) => promise<response> = "fetch"
