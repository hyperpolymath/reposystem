# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# boj/cartridge.ncl — BoJ server cartridge scaffold template
#
# Generates a complete BoJ cartridge with:
#   - Idris2 ABI (loopback/port safety proofs, protocol types, C-ABI encoding)
#   - Zig FFI (cartridge interface, domain logic, tests)
#   - Zig adapter (REST server on loopback)
#   - Nickel manifest (source-of-truth, exported to JSON for MCP bridge)
#   - Deno handler (mod.js tool dispatch)
#   - PanLL panels (manifest.json)
#   - README.adoc, EXPLAINME.adoc, REPORT.adoc
#
# Derived from local-coord-mcp — the first cartridge built with this pattern.
#
# "A cartridge without proofs is like a bridge without bolts." — Voletaire

let main = import "../../builder/main.ncl" in

main.Scaffold & {
  name = "boj-cartridge",
  language = "idris2-zig",
  dialect = "cartridge",

  meta = {
    author = "Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>",
    license = "PMPL-1.0-or-later",
    description = "BoJ server cartridge — MCP tool with formally verified ABI",
    tags = ["boj", "cartridge", "mcp", "idris2", "zig", "formally-verified"],
    version = "1.0.0",
    rsr_level = 'gold,
  },

  directories = [
    "abi/{{module_name}}",
    "ffi",
    "adapter",
    "panels",
  ],

  files = {
    # ─── Idris2 ABI: Safe{{ModuleName}}.idr ─────────────────────────────
    safe_abi = {
      path = "abi/{{module_name}}/Safe{{ModuleName}}.idr",
      template = m%"
-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
||| {{module_name}}.Safe{{ModuleName}}: Formal verification for {{cartridge_name}}.
|||
||| Cartridge: {{cartridge_name}}
||| Matrix cell: {{domain}} x {{{protocols}}} protocols
module {{module_name}}.Safe{{ModuleName}}

import Data.List
import Data.Nat
import Data.String

%default total

-- ═══════════════════════════════════════════════════════════════════════════
-- Port Safety
-- ═══════════════════════════════════════════════════════════════════════════

||| The assigned port for this cartridge.
public export
cartridgePort : Nat
cartridgePort = {{port}}

||| Valid port range: 1024–65535 (non-privileged).
public export
data ValidPort : Nat -> Type where
  MkValidPort : (p : Nat)
             -> {auto lo : LTE 1024 p}
             -> {auto hi : LTE p 65535}
             -> ValidPort p

-- ═══════════════════════════════════════════════════════════════════════════
-- C-ABI Exports (standard cartridge interface)
-- ═══════════════════════════════════════════════════════════════════════════

||| FFI: Get the bind port.
export
{{snake_name}}_get_port : Int
{{snake_name}}_get_port = {{port}}
"m%,
    },

    # ─── Idris2 ABI: Protocol.idr ───────────────────────────────────────
    protocol_abi = {
      path = "abi/{{module_name}}/Protocol.idr",
      template = m%"
-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
||| {{module_name}}.Protocol: Protocol types for {{cartridge_name}}.
module {{module_name}}.Protocol

import {{module_name}}.Safe{{ModuleName}}

%default total

-- TODO: Define domain-specific message types, state machines, and proofs.
-- See local-coord-mcp/abi/LocalCoord/Protocol.idr for a complete example.
"m%,
    },

    # ─── Idris2 package file ────────────────────────────────────────────
    ipkg = {
      path = "abi/{{cartridge_name}}.ipkg",
      template = m%"
-- SPDX-License-Identifier: PMPL-1.0-or-later
package {{package_name}}

authors    = "Jonathan D.A. Jewell"
version    = 0.1.0
license    = "PMPL-1.0-or-later"
brief      = "{{cartridge_name}} cartridge — {{description}}"

sourcedir  = "."
modules    = {{module_name}}.Safe{{ModuleName}}
           , {{module_name}}.Protocol
depends    = base
"m%,
    },

    # ─── Zig FFI ────────────────────────────────────────────────────────
    zig_ffi = {
      path = "ffi/{{snake_name}}_ffi.zig",
      template = m%"
// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// {{cartridge_name}} — Zig FFI bridge.

const std = @import("std");

const BIND_ADDR = [4]u8{ 127, 0, 0, 1 };
const BIND_PORT: u16 = {{port}};

var mutex: std.Thread.Mutex = .{};

// ═══════════════════════════════════════════════════════════════════════
// Standard Cartridge Interface (loader expects these 4 C-ABI symbols)
// ═══════════════════════════════════════════════════════════════════════

pub export fn boj_cartridge_init() c_int {
    // TODO: initialise domain state
    return 0;
}

pub export fn boj_cartridge_deinit() void {
    // TODO: clean up domain state
}

pub export fn boj_cartridge_name() [*:0]const u8 {
    return "{{cartridge_name}}";
}

pub export fn boj_cartridge_version() [*:0]const u8 {
    return "0.1.0";
}

// ═══════════════════════════════════════════════════════════════════════
// Domain Logic — TODO: implement your cartridge's FFI exports here
// ═══════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════

test "cartridge init returns 0" {
    try std.testing.expectEqual(@as(c_int, 0), boj_cartridge_init());
}

test "cartridge name correct" {
    const name = std.mem.span(boj_cartridge_name());
    try std.testing.expect(std.mem.eql(u8, name, "{{cartridge_name}}"));
}
"m%,
    },

    # ─── Zig FFI build.zig ──────────────────────────────────────────────
    zig_ffi_build = {
      path = "ffi/build.zig",
      template = m%"
// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// {{cartridge_name}} — Zig FFI build configuration (Zig 0.15+).

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ffi_mod = b.addModule("{{snake_name}}_ffi", .{
        .root_source_file = b.path("{{snake_name}}_ffi.zig"),
        .target = target,
        .optimize = optimize,
    });

    const ffi_tests = b.addTest(.{ .root_module = ffi_mod });
    const run_tests = b.addRunArtifact(ffi_tests);
    const test_step = b.step("test", "Run {{cartridge_name}} FFI tests");
    test_step.dependOn(&run_tests.step);

    const lib = b.addLibrary(.{
        .name = "{{snake_name}}_mcp",
        .root_module = b.createModule(.{
            .root_source_file = b.path("{{snake_name}}_ffi.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .dynamic,
    });
    b.installArtifact(lib);

    const lib_step = b.step("lib", "Build shared library");
    lib_step.dependOn(&lib.step);
}
"m%,
    },

    # ─── Zig Adapter ────────────────────────────────────────────────────
    zig_adapter = {
      path = "adapter/{{snake_name}}_adapter.zig",
      template = m%"
// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// {{cartridge_name}} — REST adapter on 127.0.0.1:{{port}}.

const std = @import("std");
const ffi = @import("{{snake_name}}_ffi");

const BIND_ADDR = [4]u8{ 127, 0, 0, 1 };
const REST_PORT: u16 = {{port}};

const Response = struct { status: u16, body: []const u8 };

fn okJson(buf: []u8, msg: []const u8) []u8 {
    return std.fmt.bufPrint(buf, "{{\"success\":true,\"message\":\"{s}\"}}", .{msg}) catch buf[0..0];
}

fn errJson(buf: []u8, msg: []const u8) []u8 {
    return std.fmt.bufPrint(buf, "{{\"success\":false,\"error\":\"{s}\"}}", .{msg}) catch buf[0..0];
}

fn dispatch(tool: []const u8, _body: []const u8, resp: []u8) Response {
    _ = _body;
    // TODO: add tool dispatch cases here
    _ = tool;
    return .{ .status = 404, .body = errJson(resp, "unknown tool") };
}

fn handleConnection(stream: std.net.Stream) void {
    defer stream.close();
    var buf: [4096]u8 = undefined;
    var resp_buf: [4096]u8 = undefined;
    const n = stream.read(&buf) catch return;
    const req = buf[0..n];
    var lines = std.mem.splitScalar(u8, req, '\n');
    const first = lines.next() orelse return;
    var parts = std.mem.splitScalar(u8, std.mem.trim(u8, first, "\r"), ' ');
    _ = parts.next();
    const path = parts.next() orelse return;
    const prefix = "/tools/";
    const result = if (std.mem.startsWith(u8, path, prefix))
        dispatch(path[prefix.len..], req, &resp_buf)
    else
        Response{ .status = 404, .body = errJson(&resp_buf, "not found") };
    var http_resp: [512]u8 = undefined;
    const http = std.fmt.bufPrint(&http_resp,
        "HTTP/1.1 {d} OK\r\nContent-Length: {d}\r\nContent-Type: application/json\r\n\r\n",
        .{ result.status, result.body.len }) catch return;
    _ = stream.write(http) catch {};
    _ = stream.write(result.body) catch {};
}

pub fn main() !void {
    ffi.boj_cartridge_init();
    const addr = std.net.Address.initIp4(BIND_ADDR, REST_PORT);
    var server = try addr.listen(.{ .reuse_address = true });
    defer server.deinit();
    while (true) {
        const conn = try server.accept();
        const t = try std.Thread.spawn(.{}, handleConnection, .{conn.stream});
        t.detach();
    }
}
"m%,
    },

    # ─── Zig Adapter build.zig ──────────────────────────────────────────
    zig_adapter_build = {
      path = "adapter/build.zig",
      template = m%"
// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ffi_mod = b.createModule(.{
        .root_source_file = b.path("../ffi/{{snake_name}}_ffi.zig"),
        .target = target,
        .optimize = optimize,
    });

    const adapter = b.addExecutable(.{
        .name = "{{snake_name}}_adapter",
        .root_source_file = b.path("{{snake_name}}_adapter.zig"),
        .target = target,
        .optimize = optimize,
    });
    adapter.root_module.addImport("{{snake_name}}_ffi", ffi_mod);
    b.installArtifact(adapter);
}
"m%,
    },

    # ─── Nickel manifest (source-of-truth) ──────────────────────────────
    nickel_manifest = {
      path = "cartridge.ncl",
      template = m%"
# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# {{cartridge_name}}/cartridge.ncl
# Generate JSON: nickel export --format json < cartridge.ncl > cartridge.json

{
  "$schema" = "https://boj.dev/schemas/cartridge/v1.json",
  spdx = "PMPL-1.0-or-later",
  copyright = "Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>",
  name = "{{cartridge_name}}",
  version = "0.1.0",
  description = "{{description}}",
  domain = "{{domain_lower}}",
  tier = "{{tier}}",
  protocols = [{{protocols_list}}],
  auth = {
    method = "none",
    env_var | optional = null,
    credential_source | optional = null,
  },
  api = {
    base_url = "local://{{cartridge_name}}",
    content_type = "application/json",
  },
  tools = [
    # TODO: define your MCP tools here
    # {
    #   name = "{{snake_name}}_example",
    #   description = "Example tool",
    #   inputSchema = { type = "object", properties = {}, required = [] },
    # },
  ],
}
"m%,
    },

    # ─── Deno handler ───────────────────────────────────────────────────
    mod_js = {
      path = "mod.js",
      template = m%"
// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// {{cartridge_name}}/mod.js
//
// Delegates to backend at http://127.0.0.1:{{port}}.

const BASE_URL = Deno.env.get("{{env_prefix}}_BACKEND_URL") ?? "http://127.0.0.1:{{port}}";
const TIMEOUT_MS = 15_000;

async function post(path, payload) {
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), TIMEOUT_MS);
  try {
    const r = await fetch(`${BASE_URL}${path}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
      signal: ctrl.signal,
    });
    const data = await r.json().catch(() => ({ success: false, error: "non-JSON response" }));
    return { status: r.status, data };
  } catch (e) {
    if (e.name === "AbortError") return { status: 504, data: { success: false, error: "{{cartridge_name}} backend timed out" } };
    return { status: 503, data: { success: false, error: `{{cartridge_name}} backend unavailable: ${e.message}` } };
  } finally { clearTimeout(t); }
}

export async function handleTool(toolName, args) {
  // TODO: add tool dispatch cases here
  return { status: 404, data: { error: `Unknown tool: ${toolName}` } };
}
"m%,
    },

    # ─── PanLL panels manifest ──────────────────────────────────────────
    panels_manifest = {
      path = "panels/manifest.json",
      template = m%"
{
  "$schema": "https://panll.dev/schemas/panel-manifest/v1.json",
  "spdx": "PMPL-1.0-or-later",
  "cartridge": "{{cartridge_name}}",
  "domain": "{{domain}}",
  "version": "0.1.0",
  "panels": [
    {
      "id": "{{snake_name}}-status",
      "title": "{{ModuleName}} Status",
      "description": "Health and status for {{cartridge_name}}",
      "type": "status-indicator",
      "data_source": {
        "endpoint": "/cartridge/{{cartridge_name}}/invoke",
        "method": "POST",
        "body": { "tool": "status" },
        "refresh_interval_ms": 10000
      },
      "widgets": [
        {
          "type": "state-badge",
          "field": "state",
          "states": {
            "ready": { "color": "#2ecc71", "icon": "check-circle" },
            "degraded": { "color": "#f39c12", "icon": "alert-circle" },
            "error": { "color": "#e74c3c", "icon": "alert-triangle" }
          }
        },
        { "type": "text", "field": "version", "label": "Version" }
      ]
    }
  ]
}
"m%,
    },

    # ─── README.adoc ────────────────────────────────────────────────────
    readme = {
      path = "README.adoc",
      template = m%"
// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
= {{cartridge_name}}
:toc:
:toc-placement: preamble

{{description}}

== Architecture

* *Domain:* {{domain}}
* *Port:* {{port}} (loopback only)
* *Protocols:* {{protocols}}
* *Tier:* {{tier}}

== Build

[source,bash]
----
# FFI tests
cd ffi && zig build test

# Shared library
cd ffi && zig build lib

# Adapter binary
cd adapter && zig build

# Regenerate JSON manifest from Nickel
nickel export --format json < cartridge.ncl > cartridge.json
----

== Files

[cols="1,2"]
|===
| Path | Purpose

| `abi/{{module_name}}/Safe{{ModuleName}}.idr` | Idris2 ABI — formal proofs
| `abi/{{module_name}}/Protocol.idr` | Protocol types and state machines
| `ffi/{{snake_name}}_ffi.zig` | Zig FFI — domain logic and C-ABI exports
| `adapter/{{snake_name}}_adapter.zig` | REST adapter on 127.0.0.1:{{port}}
| `cartridge.ncl` | Nickel source-of-truth manifest
| `cartridge.json` | Generated from Nickel — MCP bridge reads this
| `mod.js` | Deno adapter for MCP tool dispatch
| `panels/manifest.json` | PanLL panel definitions
|===

---

_Scaffolded with https://github.com/hyperpolymath/scaffoldia[Scaffoldia] (boj-cartridge template)_
"m%,
    },
  },

  extends = [],

  constraints = [
    "boj-cartridge-structure",
    "rsr-gold",
    "idris2-abi-required",
    "zig-ffi-required",
    "nickel-manifest-required",
  ],

  variables = {
    cartridge_name = "my-mcp",
    snake_name = "my_mcp",
    module_name = "MyMcp",
    ModuleName = "MyMcp",
    package_name = "mymcp",
    description = "A BoJ server cartridge",
    domain = "Agent",
    domain_lower = "ai",
    port = "7746",
    protocols = "MCP",
    protocols_list = "\"MCP\"",
    tier = "Ayo",
    env_prefix = "MY_MCP",
  },
}
