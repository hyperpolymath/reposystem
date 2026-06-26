<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->

# Tool Registry

The **tool registry** is reposystem's "super power collection": one typed record per tool, declaring what each tool does, whether it lives **inside** the cockpit (curated core) or has been **extracted** to a standalone repo, and where it sits in the priority stack. The registry is `config/tools.ncl` (Nickel), the single declarative source of truth for tools-as-nodes.

See also: [Architecture / Representation Model](Architecture-Representation-Model), [Estate Submodule Layout](Estate-Submodule-Layout).

## 1. What it is and how it feeds the cockpit

reposystem renders one canonical representation of the estate, and tools are part of that representation. The registry exists so the estate is not just *repos and edges* but also *capabilities* — the things you can actually do.

Per `config/tools.ncl`, the registry is *"Consumed by the importer to stamp `metadata.tool_role` / `metadata.actions` onto tool nodes (feeds the cockpit view)."* In other words, each tool record carries a list of `actions`, and those actions become the actionable affordances on a node in the cockpit. This is the **tools-as-interface** vision: a tool is not documentation prose, it is a node in the railway-yard graph that you can act on. The priority stack the registry encodes is:

```
representation → visualisation → tools_as_interface → control_surface → interop → utility
```

The file ships its own validation and export commands in the header comment:

```sh
nickel typecheck config/tools.ncl
nickel export config/tools.ncl --format json
```

## 2. The Embed / Role / Status enums

These three enums are defined at the top of `config/tools.ncl` and constrain every record.

**Embed** — where the tool's code lives:

| Value | Meaning |
|-------|---------|
| `'core` | Embedded in the cockpit (curated core component) |
| `'standalone` | Extracted to its own repo, referenced via `repos.toml` |

**Role** — position in the priority stack:

| Value |
|-------|
| `'representation` |
| `'visualisation` |
| `'tools_as_interface` |
| `'control_surface` |
| `'interop` |
| `'utility` |

**Status** — extraction / wiring state (quoting the inline comments in the file):

| Value | Meaning |
|-------|---------|
| `'active` | embedded core component, in use |
| `'extracting` | declared standalone but still vendored as an embedded tree; gitlink extraction pending |
| `'extracted` | now a real gitlink submodule (declared in `.gitmodules`) |
| `'broken` | declared a submodule but committed as a tree (wiring mismatch) |
| `'orphan` | gitlink with no `.gitmodules` URL and no forge repo |

A `Tool` record is `{ id, name, role, embed, repo_ref?, summary, actions = [], status = 'active }`. The `repo_ref` (manifest id) is present only for standalone tools.

## 3. Curated core tools

Embedded in the cockpit (`embed = 'core`, `status = 'active`). These are the front-ends and engines that *are* the cockpit.

| id | name | role | actions | summary |
|----|------|------|---------|---------|
| `forge-ops` | ForgeOps | `control_surface` | `list-repos`, `protect-branch`, `create-webhook`, `sync-mirror`, `compliance-check` | Multi-forge desktop control surface (Tauri): tokens, repos, branch protection, webhooks, mirrors, compliance. |
| `dispatcher` | Git Dispatcher | `control_surface` | `dispatch-plan`, `status` | Execution engine that runs reposystem plans across the estate. |
| `web` | Web HUD | `visualisation` | `render`, `annotate`, `export-svg` | Static estate canvas: railway-yard graph, estate scoping, external seams, annotations, ER mode. |
| `tui` | TUI | `visualisation` | `explore`, `filter` | Terminal explorer for the estate graph (ratatui). |
| `gui` | Desktop GUI | `visualisation` | `render`, `act-on-node` | ReScript + Gossamer desktop cockpit consuming the estate-export envelope. |

### ForgeOps control surface

ForgeOps is the cross-forge control surface. Its Tauri backend (`forge-ops/src-tauri/src/forgeops/commands.rs`) exposes real `#[tauri::command]` functions that wrap a forge API client and return `Result<String, String>` (JSON) to a ReScript frontend. Verified commands include:

- token verification (`forgeops_verify_tokens`, `forgeops_verify_forge_token`)
- repo listing per-forge and unified (`forgeops_list_repos`, `forgeops_list_all_repos`)
- repo settings get/update (`forgeops_get_repo_settings`, `forgeops_update_setting`)
- mirror status and force-sync (`forgeops_get_mirror_status`, `forgeops_force_sync_mirror`)
- branch protection get/update (`forgeops_get_protection`, `forgeops_update_protection`)
- webhooks list/delete (`forgeops_list_webhooks`, `forgeops_delete_webhook`)
- pipelines (`forgeops_list_pipelines`), security alerts (`forgeops_get_security_alerts`)
- compliance apply (`forgeops_apply_compliance`) and config download (`forgeops_download_config`)

This is the concrete realisation of the registry's `actions` list as live, callable affordances.

## 4. Extracted / extracting utility & interop tools

These are `embed = 'standalone`, each with a `repo_ref` (manifest id). Be precise about status: most are now **`extracted` (real gitlink submodule)**, but two are still **`extracting` (vendored embedded tree; gitlink extraction pending)** — `git-morph` and `git-seo`.

| id | name | role | status | repo_ref | summary |
|----|------|------|--------|----------|---------|
| `git-morph` | git-morph | `utility` | **`extracting`** (embedded tree) | `git-morph` | Inflate/deflate components between standalone repos and the monorepo. Still vendored as an embedded tree; gitlink extraction pending. |
| `git-seo` | git-seo | `utility` | **`extracting`** (embedded tree) | `git-seo` | Repository discoverability / SEO scoring (Julia). Still vendored as an embedded tree; gitlink extraction pending. |
| `git-reticulator` | git-reticulator | `utility` | `extracted` (gitlink) | `git-reticulator` | Submodule / gitlink reticulation across the estate. |
| `scaffoldia` | scaffoldia | `utility` | `extracted` (gitlink) | `scaffoldia` | Repository generator / customiser (trainyard topology). |
| `bitfuckit` | bitfuckit | `utility` | `extracted` (gitlink) | `bitfuckit` | Ada/SPARK repository auditor (health, compliance, security posture). |
| `contractiles` | contractiles | `utility` | `extracted` (gitlink) | `contractiles` | Declarative build/task contracts (ADJUST/INTENT/MUST/TRUST). |
| `recon-silly-ation` | recon-silly-ation | `interop` | `extracted` (gitlink) | `recon-silly-ation` | WASM document reconciliation (ReconForth VM). |
| `stateful-artefacts` | stateful-artefacts | `interop` | `extracted` (gitlink) | `stateful-artefacts` | Forge artefact hydration / consensus state (Paxos, DAX). |
| `rpa-elysium` | rpa-elysium | `utility` | `extracted` (gitlink) | `rpa-elysium` | Robotic process automation engine (workflows, scheduler, plugins). |

The seven `extracted` tools above are precisely the gitlink submodules that also appear in `.gitmodules` — see [Estate Submodule Layout](Estate-Submodule-Layout) for how `extracted` status corresponds to the declared gitlink submodules (and where the still-embedded trees like `git-morph` / `git-seo` sit by design).

## 5. Removed orphan records

Two records that were previously **`orphan`** gitlinks — `avatar-fabrication-facility` and `claim-forge` — had no `.gitmodules` URL and no backing forge repo. Per the closing note in `config/tools.ncl`, those orphan gitlinks *"were removed in PR #130 (f0586e8); their registry records are dropped accordingly."* They are therefore **not** present in the current registry; the `'orphan` enum value remains defined only to describe the wiring state these once held.
