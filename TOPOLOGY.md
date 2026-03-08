<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->
<!-- TOPOLOGY.md — Project architecture map and completion dashboard -->
<!-- Last updated: 2026-02-19 -->

# Reposystem — Project Topology

## System Architecture

```
                        ┌─────────────────────────────────────────┐
                        │              OPERATOR / AGENT           │
                        │        (CLI, TUI, Web HUD, 6SCM)        │
                        └───────────────────┬─────────────────────┘
                                            │ Scan / Command
                                            ▼
                        ┌─────────────────────────────────────────┐
                        │           REPOSYSTEM CORE (RUST)        │
                        │    (Railway Yard View, Graph Engine)    │
                        └──────────┬───────────────────┬──────────┘
                                   │                   │
                                   ▼                   ▼
                        ┌───────────────────────┐  ┌────────────────────────────────┐
                        │ DATA MODEL (RESCRIPT) │  │ ASPECT & SCENARIO ENGINE       │
                        │ - Entity Specs        │  │ - Security/Reliability Tags    │
                        │ - Slot/Provider Reg   │  │ - Scenario Diff & Plan         │
                        │ - Graph Invariants    │  │ - Weak Link Detection          │
                        └──────────┬────────────┘  └──────────┬─────────────────────┘
                                   │                          │
                                   └────────────┬─────────────┘
                                                ▼
                        ┌─────────────────────────────────────────┐
                        │           INTERFACE LAYER               │
                        │  ┌───────────┐  ┌───────────────────┐  │
                        │  │ Static    │  │  TUI (Ratatui)    │  │
                        │  │ Web HUD   │  │  CLI (Rust)       │  │
                        │  └─────┬─────┘  └────────┬──────────┘  │
                        └────────│─────────────────│──────────────┘
                                 │                 │
                                 ▼                 ▼
                        ┌─────────────────────────────────────────┐
                        │          TARGET ECOSYSTEM               │
                        │      (All Hyperpolymath Repos)          │
                        └─────────────────────────────────────────┘

                        ┌─────────────────────────────────────────┐
                        │          REPO INFRASTRUCTURE            │
                        │  Justfile Automation  .machine_readable/  │
                        │  OPSM Integration     0-AI-MANIFEST.a2ml  │
                        └─────────────────────────────────────────┘
```

## Completion Dashboard

```
COMPONENT                          STATUS              NOTES
─────────────────────────────────  ──────────────────  ─────────────────────────────────
CORE ENGINE
  Graph Engine (Rust)               ██████████ 100%    Railway yard view stable
  ReScript Data Model               ██████████ 100%    Type-safe entity specs verified
  Scenario Management               ██████████ 100%    Diff & Plan logic stable
  Weak Link Detection               ██████████ 100%    Centrality analysis active

USER INTERFACES
  Rust CLI (reposystem)             ██████████ 100%    Full command set active
  Terminal UI (TUI)                 ██████████ 100%    Baseline/Aspect views stable
  Indigo Web HUD                    ████████░░  80%    Accessibility polish refining
  DOT/JSON Exporters                ██████████ 100%    Interoperability verified

REPO INFRASTRUCTURE
  Justfile Automation               ██████████ 100%    Standard build/web-serve
  .machine_readable/ (6SCM)         ██████████ 100%    Full metadata suite active
  OPSM Stack Integration            ██████████ 100%    Context source for OPSM verified

─────────────────────────────────────────────────────────────────────────────
OVERALL:                            █████████░  ~95%   Implementation phase complete
```

## Key Dependencies

```
Local Clones ─────► Importers ──────► Graph Engine ──────► Scenario Diff
     │                 │                 │                   │
     ▼                 ▼                 ▼                   ▼
6SCM Metadata ───► Aspect Tags ─────► Web / TUI ────────► OPSM Stack
```

## Update Protocol

This file is maintained by both humans and AI agents. When updating:

1. **After completing a component**: Change its bar and percentage
2. **After adding a component**: Add a new row in the appropriate section
3. **After architectural changes**: Update the ASCII diagram
4. **Date**: Update the `Last updated` comment at the top of this file

Progress bars use: `█` (filled) and `░` (empty), 10 characters wide.
Percentages: 0%, 10%, 20%, ... 100% (in 10% increments).
