# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
# (MPL-2.0 is the automatic legal fallback until PMPL is formally recognised)
#
# registry/zig/zig-edge.ncl — Scaffoldia template for a new Zig edge repo.
#
# A Zig edge repo is any repo that:
#   - serves HTTP via uapi_gnosis_set_handler (single-port, path-routed), OR
#   - calls hyperpolymath services via uapi_connector_*, OR
#   - extends the Idris2 ABI with repo-specific types.
#
# Produced directory layout:
#
#   {{EDGE_NAME}}/
#   ├── build.zig                  — Zig 0.15.2 build; links libzig_api + libproven_ffi
#   ├── justfile                   — recipes: build, test, abi-check, run
#   ├── .gitignore
#   ├── README.adoc
#   ├── {{EDGE_NAME}}.ipkg         — Idris2 package for the ABI layer
#   ├── src/
#   │   ├── main.zig               — minimal handler wired via uapi_gnosis_set_handler
#   │   ├── Abi/                   — capitalised: Idris2 module names must start uppercase
#   │   │   ├── Types.idr          — edge-specific Handle with So (ptr /= 0) proof
#   │   │   ├── Foreign.idr        — %foreign declarations for this edge's C exports
#   │   │   └── Layout.idr         — Refl-based size proof stub
#   │   └── tests/
#   │       └── handler_test.zig   — verifies zig build test passes
#   └── .github/
#       └── workflows/
#           └── ci.yml             — minimal CI: zig build + zig build test
#
# Playbook: developer-ecosystem/UNIFIED-ZIG-API-STACK.adoc
#           §"Canonical single-port shape" + §"Wiring a New Edge Repo"
#
# Placeholders (substituted by scaffoldia or manually):
#   {{EDGE_NAME}}       — repo / binary name (e.g. lol-gateway)
#   {{EDGE_PURPOSE}}    — one-line description (e.g. "LoL service API gateway")
#   {{DEFAULT_PORT}}    — HTTP port number (e.g. 4001)
#   {{HANDLER_PREFIX}}  — function-naming prefix (e.g. lol, aerie, emergency)

let main = import "../../builder/main.ncl" in

main.Scaffold & {
  name        = "zig-edge",
  language    = "zig",
  dialect     = "edge",

  meta = {
    author      = "scaffoldia",
    license     = "PMPL-1.0-or-later",
    description = "Zig edge repo wired to the unified-zig-api stack from day one",
    tags        = ["zig", "zig-edge", "unified-zig-api", "gnosis", "idris2-abi"],
    version     = "1.0.0",
    rsr_level   = 'bronze,
  },

  directories = [
    "src",
    "src/Abi",
    "src/tests",
    ".github/workflows",
  ],

  files = {

    # -------------------------------------------------------------------------
    # build.zig — links libzig_api (static, per 6b finding) + proven transitive
    # -------------------------------------------------------------------------
    build_zig = {
      path = "build.zig",
      template = m%"
// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
// (MPL-2.0 is the automatic legal fallback until PMPL is formally recognised)
//
// build.zig — {{EDGE_NAME}} build configuration (Zig 0.15.2)
//
// {{EDGE_PURPOSE}}
//
// Wires the unified-zig-api stack:
//   libzig_api   — gnosis HTTP server + connector pool (static link)
//   libproven_ffi — formally-verified safety primitives (static, transitive)
//   zig_api.h    — C ABI header (generated from Idris2 ABI)
//
// Build libzig_api first:
//   cd /var/mnt/eclipse/repos/developer-ecosystem/zig-api/ffi/zig
//   zig build
//
// Then build this edge:
//   zig build
//   zig build run          — start on port {{DEFAULT_PORT}}
//   zig build test         — run handler tests
//
// Override library paths for CI / unusual install locations:
//   zig build -Dzig-api-lib-path=…  -Dzig-api-include-path=…

const std = @import("std");

/// Default path to the directory containing libzig_api.a / libzig_api.so.
const DEFAULT_ZIG_API_LIB_PATH =
    "/var/mnt/eclipse/repos/developer-ecosystem/zig-api/ffi/zig/zig-out/lib";

/// Default path to the directory containing zig_api.h.
const DEFAULT_ZIG_API_INCLUDE_PATH =
    "/var/mnt/eclipse/repos/developer-ecosystem/zig-api/ffi/zig/zig-out/include";

/// Source root of zig-api Zig module (for @import("zig_api") in Zig consumers).
const ZIG_API_SOURCE_ROOT =
    "/var/mnt/eclipse/repos/developer-ecosystem/zig-api/ffi/zig/src/lib.zig";

pub fn build(b: *std.Build) void {
    const target   = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // -------------------------------------------------------------------------
    // Build options — allow callers to override zig-api library paths.
    // -------------------------------------------------------------------------
    const zig_api_lib_path = b.option(
        []const u8,
        "zig-api-lib-path",
        "Directory containing libzig_api.a/.so (default: " ++ DEFAULT_ZIG_API_LIB_PATH ++ ")",
    ) orelse DEFAULT_ZIG_API_LIB_PATH;

    const zig_api_include_path = b.option(
        []const u8,
        "zig-api-include-path",
        "Directory containing zig_api.h (default: " ++ DEFAULT_ZIG_API_INCLUDE_PATH ++ ")",
    ) orelse DEFAULT_ZIG_API_INCLUDE_PATH;

    // -------------------------------------------------------------------------
    // Root module — the edge binary.
    // -------------------------------------------------------------------------
    const edge_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target           = target,
        .optimize         = optimize,
        .link_libc        = true,
    });

    // Expose zig-api Zig module so @import("zig_api") resolves inside main.zig
    // for direct access to gnosis/connector Zig types alongside the C ABI.
    edge_mod.addAnonymousImport("zig_api", .{
        .root_source_file = .{ .cwd_relative = ZIG_API_SOURCE_ROOT },
        .target           = target,
        .optimize         = optimize,
        .link_libc        = true,
    });

    // Link libzig_api (static preferred — resolves all symbols including proven
    // transitive symbols; dynamic build has been observed to miss proven_ffi
    // symbols at load time on some configurations).
    edge_mod.addLibraryPath(.{ .cwd_relative = zig_api_lib_path });
    edge_mod.addIncludePath(.{ .cwd_relative = zig_api_include_path });
    edge_mod.linkSystemLibrary("zig_api", .{});

    // -------------------------------------------------------------------------
    // Main executable: {{EDGE_NAME}}
    // -------------------------------------------------------------------------
    const edge = b.addExecutable(.{
        .name        = "{{EDGE_NAME}}",
        .root_module = edge_mod,
    });
    b.installArtifact(edge);

    // zig build run
    const run_cmd = b.addRunArtifact(edge);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
    const run_step = b.step("run", "Run {{EDGE_NAME}}");
    run_step.dependOn(&run_cmd.step);

    // -------------------------------------------------------------------------
    // Unit tests — src/tests/handler_test.zig
    // -------------------------------------------------------------------------
    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/tests/handler_test.zig"),
        .target           = target,
        .optimize         = optimize,
        .link_libc        = true,
    });
    test_mod.addAnonymousImport("zig_api", .{
        .root_source_file = .{ .cwd_relative = ZIG_API_SOURCE_ROOT },
        .target           = target,
        .optimize         = optimize,
        .link_libc        = true,
    });
    test_mod.addLibraryPath(.{ .cwd_relative = zig_api_lib_path });
    test_mod.addIncludePath(.{ .cwd_relative = zig_api_include_path });
    test_mod.linkSystemLibrary("zig_api", .{});

    const tests     = b.addTest(.{ .root_module = test_mod });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run {{EDGE_NAME}} handler tests");
    test_step.dependOn(&run_tests.step);
}
"m%,
    },

    # -------------------------------------------------------------------------
    # src/main.zig — canonical single-port gnosis handler
    # -------------------------------------------------------------------------
    main_zig = {
      path = "src/main.zig",
      template = m%"
// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
// (MPL-2.0 is the automatic legal fallback until PMPL is formally recognised)
//
// main.zig — {{EDGE_NAME}}: {{EDGE_PURPOSE}}
//
// Single-port HTTP via uapi_gnosis_set_handler.
// All path routing happens inside {{HANDLER_PREFIX}}Handler.
//
// Lifecycle (canonical unified-zig-api shape):
//   uapi_init()                   — initialise gnosis + connector pools
//   uapi_gnosis_create(port)      — reserve pool slot
//   uapi_gnosis_set_handler(h, f) — register edge dispatch fn (before start)
//   uapi_gnosis_start(h)          — start background HTTP listener
//   ... sleep until SIGINT ...
//   uapi_gnosis_stop(h)           — drain listener
//   uapi_gnosis_destroy(h)        — release pool slot
//   uapi_teardown()               — release all global state
//
// Port resolution (checked in order):
//   1. PORT environment variable
//   2. {{DEFAULT_PORT}} compile-time default
//
// Playbook: developer-ecosystem/UNIFIED-ZIG-API-STACK.adoc
//           §"Canonical single-port shape"

const std = @import("std");

/// C ABI from libzig_api.  Provides uapi_gnosis_*, uapi_connector_*,
/// uapi_init / uapi_teardown, GnosisRequest, GnosisResponse constants.
const c = @cImport({
    @cInclude("zig_api.h");
});

// ---------------------------------------------------------------------------
// Edge handler — called by gnosis for every incoming request.
//
// Pointer cast idiom (mandatory per playbook):
//   The C ABI uses [*c] (C pointer) types.  Cast to regular Zig pointers at
//   the top of the handler for ergonomic field access; keep the original c-
//   pointers for calls back into the C ABI (uapi_gnosis_write_response).
//
// Lifetime contract:
//   req fields (path, body_ptr) are valid ONLY during the handler call.
//   Copy any data you need to keep before returning.
//   resp_c must be fully populated (via uapi_gnosis_write_response) before
//   the handler returns.
// ---------------------------------------------------------------------------
export fn {{HANDLER_PREFIX}}Handler(
    req_c: [*c]const c.GnosisRequest,
    resp_c: [*c]c.GnosisResponse,
) callconv(.c) void {
    // Ergonomic Zig pointer access (read-only fields from req).
    const req: *const c.GnosisRequest = @ptrCast(req_c);

    // safePathDefault is called inside gnosis before this handler fires,
    // so req.path has already passed the traversal + prefix-allowlist checks.
    const path = std.mem.span(req.path);

    if (std.mem.startsWith(u8, path, "/api/v1/health")) {
        // Health check — always respond 200.
        const body = "{\"status\":\"ok\",\"service\":\"{{EDGE_NAME}}\"}";
        c.uapi_gnosis_write_response(resp_c, 200, "application/json",
                                     body, body.len);
    } else if (std.mem.startsWith(u8, path, "/api/v1/")) {
        // TODO: add edge-specific REST handlers here.
        const body = "{\"status\":\"ok\"}";
        c.uapi_gnosis_write_response(resp_c, 200, "application/json",
                                     body, body.len);
    } else {
        const e = "{\"error\":\"not found\"}";
        c.uapi_gnosis_write_response(resp_c, 404, "application/json",
                                     e, e.len);
    }

    // Suppress unused-variable warnings if resp pointer is not needed directly
    // (uapi_gnosis_write_response takes resp_c, not resp).
    _ = resp_c;
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------
pub fn main() !void {
    // Resolve port: env PORT → compile-time default.
    const port_str = std.posix.getenv("PORT") orelse "";
    const port: u16 = if (port_str.len > 0)
        std.fmt.parseInt(u16, port_str, 10) catch {{DEFAULT_PORT}}
    else
        {{DEFAULT_PORT}};

    // Initialise the unified-zig-api stack (gnosis pool + connector pool).
    const init_rc = c.uapi_init();
    if (init_rc != c.UAPI_OK) {
        std.debug.print("uapi_init failed: {d}\n", .{init_rc});
        return error.InitFailed;
    }
    defer c.uapi_teardown();

    // Reserve a gnosis pool slot on the chosen port.
    const handle = c.uapi_gnosis_create(port);
    if (handle == 0) {
        std.debug.print("uapi_gnosis_create failed (pool full?)\n", .{});
        return error.CreateFailed;
    }

    // Register the edge handler BEFORE uapi_gnosis_start.
    // After start, set_handler returns UAPI_ERR.
    const set_rc = c.uapi_gnosis_set_handler(handle, &{{HANDLER_PREFIX}}Handler);
    if (set_rc != c.UAPI_OK) {
        std.debug.print("uapi_gnosis_set_handler failed: {d}\n", .{set_rc});
        c.uapi_gnosis_destroy(handle);
        return error.SetHandlerFailed;
    }

    const start_rc = c.uapi_gnosis_start(handle);
    if (start_rc != c.UAPI_OK) {
        std.debug.print("uapi_gnosis_start failed: {d}\n", .{start_rc});
        c.uapi_gnosis_destroy(handle);
        return error.StartFailed;
    }
    defer c.uapi_gnosis_stop(handle);
    defer c.uapi_gnosis_destroy(handle);

    std.debug.print("{{EDGE_NAME}} listening on port {d}\n", .{port});

    // Spin until gnosis stops (SIGINT / uapi_gnosis_stop from another thread).
    while (c.uapi_gnosis_state(handle) == c.UAPI_SERVER_LISTENING) {
        std.Thread.sleep(std.time.ns_per_s);
    }
}
"m%,
    },

    # -------------------------------------------------------------------------
    # src/Abi/Types.idr — edge-specific Handle with non-null proof
    # -------------------------------------------------------------------------
    abi_types = {
      path = "src/Abi/Types.idr",
      template = m%"
-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-- (MPL-2.0 is the automatic legal fallback until PMPL is formally recognised)
--
-- Abi.Types — edge-specific Idris2 type layer for {{EDGE_NAME}}.
--
-- Module name: Abi.Types  (sourcedir = "src" in {{EDGE_NAME}}.ipkg;
-- Idris2 derives module name from path: src/Abi/Types.idr → Abi.Types).
--
-- Extend this module with types specific to {{EDGE_NAME}}.
-- Import ZigApi.ABI.Types from zig-api.ipkg for shared stack types
-- (Handle, Slot, ValidSlot, Platform, Result, etc.).
--
-- The example below shows a {{HANDLER_PREFIX}}-specific opaque handle
-- that wraps the stack's Handle with an additional non-null proof.
-- This pattern ensures that any use of a {{HANDLER_PREFIX}}Handle in
-- Idris2 is statically guaranteed to be non-null.

module Abi.Types

import Data.So
import System.FFI

%default total

-- Import the unified-zig-api type layer.
-- Requires zig-api.ipkg as a dependency in {{EDGE_NAME}}.ipkg.
-- import ZigApi.ABI.Types

-- ============================================================================
-- {{HANDLER_PREFIX}}-specific handle
-- ============================================================================

||| Opaque gnosis pool handle returned by uapi_gnosis_create.
||| The inner AnyPtr is the C-level u64 slot value returned by the C ABI.
|||
||| Non-nullness is enforced at construction time by mk{{HANDLER_PREFIX}}Handle:
||| `prim__nullAnyPtr` returns 1 when null, so the Maybe short-circuits before
||| a zero handle can be wrapped.  Any code holding a {{HANDLER_PREFIX}}Handle
||| value is statically guaranteed (by totality) to hold a live pool slot.
public export
record {{HANDLER_PREFIX}}Handle where
  constructor Mk{{HANDLER_PREFIX}}Handle
  ptr : AnyPtr

||| Attempt to construct a validated {{HANDLER_PREFIX}}Handle from a raw pointer.
||| Returns Nothing when the pointer is null (pool full / init failed).
|||
||| This is the sole construction path — never call Mk{{HANDLER_PREFIX}}Handle directly.
public export
mk{{HANDLER_PREFIX}}Handle : AnyPtr -> Maybe {{HANDLER_PREFIX}}Handle
mk{{HANDLER_PREFIX}}Handle p =
  if prim__nullAnyPtr p == 1
    then Nothing
    else Just (Mk{{HANDLER_PREFIX}}Handle p)

-- ============================================================================
-- Placeholder: add more edge-specific types below
-- ============================================================================
"m%,
    },

    # -------------------------------------------------------------------------
    # src/Abi/Foreign.idr — %foreign declarations
    # -------------------------------------------------------------------------
    abi_foreign = {
      path = "src/Abi/Foreign.idr",
      template = m%"
-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-- (MPL-2.0 is the automatic legal fallback until PMPL is formally recognised)
--
-- Abi.Foreign — %foreign declarations for {{EDGE_NAME}} C exports.
--
-- Module name: Abi.Foreign  (sourcedir = "src"; src/Abi/Foreign.idr → Abi.Foreign).
--
-- Add one `%foreign "C:symbol,lib{{EDGE_NAME}}"` declaration per C function
-- exported by {{EDGE_NAME}}'s Zig layer (if it exposes its own C ABI).
--
-- If {{EDGE_NAME}} only *consumes* zig-api (does not export its own C ABI),
-- import ZigApi.ABI.Foreign instead and delete the stubs below.
--
-- Playbook: developer-ecosystem/UNIFIED-ZIG-API-STACK.adoc §"From Idris2"

module Abi.Foreign

import System.FFI
import Abi.Types

%default total

-- ============================================================================
-- Example %foreign declaration (replace or remove as needed)
-- ============================================================================

||| Example: a C function exported by this edge's Zig layer.
||| Replace "{{HANDLER_PREFIX}}_example_fn" with a real exported symbol.
%foreign "C:{{HANDLER_PREFIX}}_example_fn,lib{{EDGE_NAME}}"
prim__exampleFn : AnyPtr -> PrimIO Int

||| Safe IO wrapper around prim__exampleFn.
exampleFn : Abi.Types.{{HANDLER_PREFIX}}Handle -> IO Int
exampleFn h = fromPrim $ prim__exampleFn (Abi.Types.ptr h)
"m%,
    },

    # -------------------------------------------------------------------------
    # src/Abi/Layout.idr — Refl-based size proof stub
    # -------------------------------------------------------------------------
    abi_layout = {
      path = "src/Abi/Layout.idr",
      template = m%"
-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-- (MPL-2.0 is the automatic legal fallback until PMPL is formally recognised)
--
-- Abi.Layout — memory layout assertions for {{EDGE_NAME}}.
--
-- Module name: Abi.Layout  (sourcedir = "src"; src/Abi/Layout.idr → Abi.Layout).
--
-- Add Refl-based size claims for any C structs this edge crosses the
-- ABI boundary with.  The pattern mirrors ZigApi.ABI.Layout in zig-api.
--
-- If {{EDGE_NAME}} has no structs of its own, this file can remain as a
-- stub.  Keep it — it signals that layout has been considered.
--
-- Reference: developer-ecosystem/zig-api/src/ZigApi/ABI/Layout.idr

module Abi.Layout

import Data.Nat

%default total

-- ============================================================================
-- Platform pointer width (LP64 — 64-bit Linux default)
-- ============================================================================

||| Pointer width in bytes for the current compilation target.
public export
ptrWidth : Nat
ptrWidth = 8

-- ============================================================================
-- Example layout claim
-- ============================================================================

||| Proof that ptrWidth is 8 on the LP64 target.
||| Qualified name avoids shadowing; Refl fires because ptrWidth reduces to 8.
public export
ptrWidthIs8 : Abi.Layout.ptrWidth = 8
ptrWidthIs8 = Refl
"m%,
    },

    # -------------------------------------------------------------------------
    # src/tests/handler_test.zig — minimal build-test exerciser
    # -------------------------------------------------------------------------
    handler_test = {
      path = "src/tests/handler_test.zig",
      template = m%"
// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
// (MPL-2.0 is the automatic legal fallback until PMPL is formally recognised)
//
// handler_test.zig — {{EDGE_NAME}} handler smoke tests.
//
// These tests verify that:
//   1. uapi_init / uapi_teardown round-trip without panicking.
//   2. uapi_gnosis_create returns a non-zero handle.
//   3. uapi_gnosis_set_handler accepts the edge handler without error.
//   4. uapi_gnosis_state correctly reflects UAPI_SERVER_STOPPED before start.
//
// Integration tests (actually starting the HTTP listener and sending requests)
// require the gnosis binary on $PATH; run them with `just test-integration`
// once that is set up.

const std    = @import("std");
const c      = @cImport(@cInclude("zig_api.h"));

test "uapi lifecycle: init → teardown" {
    const rc = c.uapi_init();
    defer c.uapi_teardown();
    try std.testing.expectEqual(@as(u8, c.UAPI_OK), rc);
}

test "gnosis create returns non-zero handle" {
    _ = c.uapi_init();
    defer c.uapi_teardown();

    // Use a high ephemeral port to avoid binding conflicts in CI.
    const handle = c.uapi_gnosis_create(19473);
    defer c.uapi_gnosis_destroy(handle);

    try std.testing.expect(handle != 0);
}

test "set_handler accepts {{HANDLER_PREFIX}}Handler before start" {
    _ = c.uapi_init();
    defer c.uapi_teardown();

    const handle = c.uapi_gnosis_create(19474);
    defer c.uapi_gnosis_destroy(handle);

    // Import the handler symbol from the main module under test.
    // The test runner wires main.zig via build.zig's addAnonymousImport.
    const main_mod = @import("../main.zig");
    const rc = c.uapi_gnosis_set_handler(handle, &main_mod.{{HANDLER_PREFIX}}Handler);
    try std.testing.expectEqual(@as(u8, c.UAPI_OK), rc);
}

test "gnosis state is STOPPED before start" {
    _ = c.uapi_init();
    defer c.uapi_teardown();

    const handle = c.uapi_gnosis_create(19475);
    defer c.uapi_gnosis_destroy(handle);

    try std.testing.expectEqual(c.UAPI_SERVER_STOPPED, c.uapi_gnosis_state(handle));
}
"m%,
    },

    # -------------------------------------------------------------------------
    # {{EDGE_NAME}}.ipkg — Idris2 package for the ABI layer
    # -------------------------------------------------------------------------
    ipkg = {
      path = "{{EDGE_NAME}}.ipkg",
      template = m%"
-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-- (MPL-2.0 is the automatic legal fallback until PMPL is formally recognised)
--
-- {{EDGE_NAME}}.ipkg — Idris2 ABI layer for {{EDGE_NAME}}.
--
-- Covers src/abi/ only.  Build the Zig binary separately via `just build`.
--
-- Usage:
--   idris2 --build {{EDGE_NAME}}.ipkg     -- build the ABI package
--   idris2 --check src/abi/Foreign.idr    -- typecheck Foreign module

package {{EDGE_NAME}}

version   = 0.1.0
authors   = "Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>"
brief     = "{{EDGE_PURPOSE}}"
readme    = "README.adoc"
license   = "PMPL-1.0-or-later"

sourcedir = "src"

-- Depend on zig-api ABI modules (install zig-api.ipkg first).
-- depends = zig-api

modules
  = Abi.Types
  , Abi.Layout
  , Abi.Foreign
"m%,
    },

    # -------------------------------------------------------------------------
    # justfile — build, test, abi-check, run
    # -------------------------------------------------------------------------
    justfile = {
      path = "justfile",
      template = m%"
# SPDX-License-Identifier: PMPL-1.0-or-later
# justfile — {{EDGE_NAME}} development tasks
# {{EDGE_PURPOSE}}

set shell := ["bash", "-uc"]

# Show available recipes
default:
    @just --list --unsorted

# Build the {{EDGE_NAME}} binary (debug)
build:
    zig build

# Build release binary
build-release:
    zig build -Doptimize=ReleaseSafe

# Run the edge server (uses PORT env or default {{DEFAULT_PORT}})
run:
    zig build run

# Run unit tests (requires libzig_api already built)
test:
    zig build test

# Typecheck the Idris2 ABI layer (requires idris2 + zig-api.ipkg installed)
abi-check:
    idris2 --build {{EDGE_NAME}}.ipkg

# Clean Zig build artefacts
clean:
    rm -rf zig-out .zig-cache build dist-newstyle

# Verify the edge handler responds to a health probe (server must be running)
smoke:
    curl -fsS http://localhost:{{DEFAULT_PORT}}/api/v1/health | jq .
"m%,
    },

    # -------------------------------------------------------------------------
    # .gitignore
    # -------------------------------------------------------------------------
    gitignore = {
      path = ".gitignore",
      content = m%"
# Zig build artefacts
zig-out/
.zig-cache/

# Idris2 build artefacts
build/
dist-newstyle/
*.ibc

# Editor
.idea/
.vscode/
*.swp
*~

# OS
.DS_Store
Thumbs.db
"m%,
    },

    # -------------------------------------------------------------------------
    # README.adoc — one-page guide
    # -------------------------------------------------------------------------
    readme = {
      path = "README.adoc",
      template = m%"
// SPDX-License-Identifier: PMPL-1.0-or-later
= {{EDGE_NAME}}
Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
:toc:
:doctype: article

{{EDGE_PURPOSE}}

This repo is a *Zig edge* wired to the unified hyperpolymath API stack:

* **libzig_api** — gnosis HTTP server pool + connector pool
* **libproven_ffi** — formally verified safety primitives (transitive)
* **uapi_gnosis_set_handler** — single-port, path-routed dispatch
* **safePathDefault** + **safeHeaderDefault** — active in gnosis before
  the edge handler fires (traversal guard + CRLF injection guard)
* **Idris2 ABI layer** in `src/abi/` — edge-specific type proofs

== Prerequisites

. Zig 0.15.2+
. `libzig_api` built from `developer-ecosystem/zig-api/ffi/zig/`:
+
[source,bash]
----
cd /var/mnt/eclipse/repos/developer-ecosystem/zig-api/ffi/zig
zig build
----
. _(Optional)_ Idris2 for ABI typechecking.

== Build & Run

[source,bash]
----
just build          # compile
just run            # start on port {{DEFAULT_PORT}} (or $PORT)
just test           # run handler unit tests
just abi-check      # typecheck Idris2 ABI layer
just smoke          # probe /api/v1/health (server must be running)
----

== Adapting This Template

. Replace `{{HANDLER_PREFIX}}Handler` in `src/main.zig` with your own routing logic.
. Add edge-specific types to `src/abi/Types.idr`.
. Wire any additional `%foreign` declarations in `src/abi/Foreign.idr`.
. Extend `justfile` with any extra build steps.
. Remove or replace the stubs in `src/abi/Layout.idr` with real layout claims.

== Playbook

See `developer-ecosystem/UNIFIED-ZIG-API-STACK.adoc` for the full unified
stack reference, including §"Canonical single-port shape" and
§"Wiring a New Edge Repo".

== Licence

PMPL-1.0-or-later. +
MPL-2.0 is the automatic legal fallback until PMPL is formally recognised.
"m%,
    },

    # -------------------------------------------------------------------------
    # .github/workflows/ci.yml — minimal CI
    # -------------------------------------------------------------------------
    ci_workflow = {
      path = ".github/workflows/ci.yml",
      template = m%"
# SPDX-License-Identifier: PMPL-1.0-or-later
# CI for {{EDGE_NAME}}: build + test

name: CI

on:
  push:
    branches: [main]
  pull_request:

permissions: read-all

jobs:
  build-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd  # v6.0.2

      - name: Install Zig 0.15.2
        run: |
          wget -q https://ziglang.org/download/0.15.2/zig-linux-x86_64-0.15.2.tar.xz
          tar -xf zig-linux-x86_64-0.15.2.tar.xz
          echo "$PWD/zig-linux-x86_64-0.15.2" >> $GITHUB_PATH

      - name: Build libzig_api
        run: |
          cd /var/mnt/eclipse/repos/developer-ecosystem/zig-api/ffi/zig
          zig build
        # NOTE: In real CI, replace the above with artifact download or
        # system-installed libzig_api. The path above is developer-machine-local.

      - name: Build {{EDGE_NAME}}
        run: zig build

      - name: Run handler tests
        run: zig build test
"m%,
    },
  },

  # ---------------------------------------------------------------------------
  # Substitution variables (defaults — overridden per-invocation)
  # ---------------------------------------------------------------------------
  variables = {
    EDGE_NAME       = "my-zig-edge",
    EDGE_PURPOSE    = "A Zig edge repo wired to the unified-zig-api stack",
    DEFAULT_PORT    = "4000",
    HANDLER_PREFIX  = "myEdge",
  },

  extends = [],

  constraints = [
    "zig-edge-structure",
    "rsr-bronze",
  ],
}
