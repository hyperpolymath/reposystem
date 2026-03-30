# PROOF-NEEDS.md
<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->

## Current State

- **LOC**: ~162,000
- **Languages**: Rust, ReScript, Ada, Nickel, Idris2, Zig
- **Existing ABI proofs**: `src/abi/*.idr` (template-level only, per sub-project)
- **Dangerous patterns**: ~20+ `Obj.magic` calls in `gui/lib/rescript-tea/` and `tools/hud/frontend/src/Tea.res`

## What Needs Proving

### Obj.magic elimination (ReScript)
- `gui/lib/rescript-tea/` — DOM event casting, JSON coercion, XHR response type discrimination all use `Obj.magic` for type erasure
- `tools/hud/frontend/src/Tea.res` — event listener attachment uses `Obj.magic` for listener coercion
- These are inherited from the rescript-tea library; type-safe wrappers or phantom-typed bindings should replace them

### Bitfuckit Ada subsystem
- `bitfuckit/src/bitbucket_api.adb` — API interaction code with no SPARK annotations
- Ada code handling Bitbucket API should have pre/post conditions on authentication flows

### Avatar Fabrication Facility
- Template/boilerplate ABI only — needs real domain-specific proofs for avatar generation invariants

## Recommended Prover

- **Idris2** for ABI layer (already in place, needs deepening)
- **SPARK** for Ada subsystems (natural fit for existing Ada code)

## Priority

**MEDIUM** — Large monorepo; `Obj.magic` is a systemic concern but mostly in vendored library code. Ada SPARK annotations would add real safety value.

## Template ABI Cleanup (2026-03-29)

Template ABI removed -- was creating false impression of formal verification.
The removed files (Types.idr, Layout.idr, Foreign.idr) contained only RSR template
scaffolding with unresolved {{PROJECT}}/{{AUTHOR}} placeholders and no domain-specific proofs.
