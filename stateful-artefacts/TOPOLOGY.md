# SPDX-License-Identifier: PMPL-1.0-or-later
# SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell (hyperpolymath)

# Stateful Artefacts - System Topology

## Architecture

```
                    +-----------------------------+
                    |     .machine_readable/      |
                    |  STATE.scm  ECOSYSTEM.scm   |
                    |  META.scm   AGENTIC.scm     |
                    |  NEUROSYM.scm PLAYBOOK.scm  |
                    +-------------+---------------+
                                  |
                                  v
                    +-----------------------------+
                    |      Gnosis Engine          |
                    |  (Haskell: Main.hs)         |
                    |                             |
                    |  SExp.hs   → S-exp parser   |
                    |  Types.hs  → FlexiText/a11y |
                    |  Render.hs → Template engine |
                    |  SixSCM.hs → 6scm reader    |
                    |  Paxos.hs  → Consensus      |
                    |  DAX.hs    → DAX queries     |
                    +-------------+---------------+
                                  |
                                  v
                    +-----------------------------+
                    |    Rendered Outputs          |
                    |  README.md, PROFILE.md, etc. |
                    |  (Never manually edited)     |
                    +-----------------------------+

    (:placeholder) syntax    →    Resolved from 6scm values
    FlexiText                →    Alt-text on all visual elements
    Tri-Guard                →    Sanitize + Validate + Accessible
```

## Completion Dashboard

| Component                | Progress                    | Status      |
|--------------------------|-----------------------------|-------------|
| S-expression parser      | `████████░░` 80%            | Working     |
| Template renderer        | `███████░░░` 70%            | Working     |
| FlexiText accessibility  | `██████░░░░` 60%            | Working     |
| Tri-Guard safety         | `██████░░░░` 60%            | Working     |
| Conditional rendering    | `░░░░░░░░░░` 0%             | Planned     |
| Loops/functions          | `░░░░░░░░░░` 0%             | Planned     |
| Arithmetic expressions   | `░░░░░░░░░░` 0%             | Planned     |
| Code scanning bridge     | `░░░░░░░░░░` 0%             | Planned     |
| Neurosymbolic bridge     | `░░░░░░░░░░` 0%             | Planned     |
| Annotation layer         | `░░░░░░░░░░` 0%             | Design      |
| Plugin system            | `██░░░░░░░░` 20%            | Scaffolded  |
| Dashboard (browser ext)  | `█░░░░░░░░░` 10%            | Scaffolded  |

**Overall: ~30% complete (Horizon 1 functional, Horizons 2-3 unstarted)**

## Key Dependencies

| Dependency      | Type     | Purpose                          |
|-----------------|----------|----------------------------------|
| GHC / Stack     | Build    | Haskell compiler and build tool  |
| text            | Library  | Efficient Unicode text           |
| containers      | Library  | Map/Set data structures          |
| megaparsec      | Library  | Parser combinators for S-exp     |
| optparse-appl.  | Library  | CLI argument parsing             |
| .machine_read/  | Data     | 6scm source of truth files       |

## Integration Points

```
reposystem/stateful-artefacts
  ├── Consumed by: hypatia (scan findings → gnosis templates)
  ├── Consumed by: gitbot-fleet (auto-update rendered docs)
  ├── Produces:    Static docs for any git forge
  └── Reads from:  Any repo's .machine_readable/ directory
```
