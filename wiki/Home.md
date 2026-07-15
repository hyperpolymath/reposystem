<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk> -->

# reposystem

**reposystem is the "estate cockpit"** — one canonical representation of a repo/forge estate (the hyperpolymath org, "estate #1"), rendered by converged front-ends. It treats your repository ecosystem as a **railway yard**: repos are *yards*, the things a repo needs are *slots*, the things a repo offers are *providers*, dependencies are *tracks* (edges), provider choices are *switches* (points), and *aspect overlays* let you flip the whole view to a single concern (security, reliability, supply-chain). The Rust `types` module in `src/lib.rs` is the single schema of record for all of it.

## Priority stack

The project builds outward in this order:

1. **Representation** — one canonical model of the estate.
2. **Visualisation** — render that model in the front-ends.
3. **Tools built into the visualisation** — interact with the estate from inside the view.
4. **Cross-forge control surface** — act across forges (GitHub, GitLab, etc.).
5. **Cross-forge interop** — backup mirrors and portability between forges.
6. **Orgs / enterprise / education** — broader deployment (later).

## What's built now

Per `.machine_readable/descriptiles/STATE.a2ml` (2026-06-26), the project is in the **"Testing & stabilization"** phase (completion estimated ~68%, a coarse non-rubric figure), with the estate-representation foundation landed:

- **Representation foundation** — the Rust `types` module is the single schema of record: `Estate`, `ExternalSeam` + `SeamDomain`, `RelationType` (including `RefersTo`), and the five stores (Graph/Slot/Aspect/Plan/Audit). Seams are edge sinks (`aerie` → Network, `ambientops` → Machine).
- **Manifest import** — `src/importers/manifest.rs` bridges `repos.toml` (declared 297 repos) + `repos.groups.toml` into the `GraphStore` via `reposystem import manifest`.
- **Unified export** — the `reposystem/estate-export@1` envelope (`reposystem export`, estate-json) is consumed by the web HUD; DOT export is available too.
- **Core pipeline** — scan → slot/provider registry → scenario diff → plan + apply with rollback, with an audited Plan → Apply → Rollback flow (`PlanStore` + `AuditStore`) and the VeriSimDB persistence client (`src/verisimdb.rs`).
- **Front-ends** — web HUD (static vanilla-JS canvas prototype, grandfathered no-build), TUI (ratatui), desktop GUI (ReScript), and forge-ops (Tauri control surface).

`ROADMAP.adoc` confirms staged freezes **f1–f5** are checked off (graph + tagging + export, slots/providers, plan + dry-run diff, apply + rollback execution, interactive TUI + web).

## Roadmap

The remaining work is the **f6 — GUI Railway Yard (Polish)** freeze in `ROADMAP.adoc`, still open:

- [ ] Drag-and-drop canvas
- [ ] Point-switches with visual feedback
- [ ] Animated routing preview
- [ ] Contingency-paths visualisation
- [ ] Multi-user collaboration

Documentation and OPSM-alignment work is also tracked there, and the ReScript → AffineScript migration is epic #93. Always read `.machine_readable/descriptiles/STATE.a2ml` for the live status, blockers, and next actions before relying on this summary.

## Navigation

- **[Architecture / Representation Model](Architecture-Representation-Model)** — the canonical `types` schema (Estate, seams, relations, channels) and the export envelope.
- **[Estate / Submodule Layout](Estate-Submodule-Layout)** — how the estate is laid out: the eight gitlink submodules, the by-design embedded trees, and the archived vendored snapshots.
- **[Getting Started](Getting-Started)** — build, scan/import a manifest, export the estate, and view it in a front-end.
- **[Tool Registry](Tool-Registry)** — the `config/tools.ncl` (Nickel) registry: Embed, Role, and Status enums for every estate tool.
- **[Governance and Hypatia](Governance-and-Hypatia)** — the hypatia neurosymbolic scanner gate, the banned-language policy, SPDX/licence requirements, and the anti-fiction rule.

## Machine-readable artefacts

Structured project metadata lives under `.machine_readable/descriptiles/`. Agents should read these before mutating the graph or relying on summaries:

- `STATE.a2ml` — current project state, blockers, and next actions
- `META.a2ml` — architecture decisions and development practices
- `ECOSYSTEM.a2ml` — position in the ecosystem and related projects
- `AGENTIC.a2ml` — AI agent interaction patterns
- `NEUROSYM.a2ml` — neurosymbolic integration config
- `PLAYBOOK.a2ml` — operational runbook
