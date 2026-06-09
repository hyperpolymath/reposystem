# SPDX-License-Identifier: MPL-2.0
# Owner: Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
# Stage 0 Assessment: total-upgrade

## Commands Run
* `ls -R ~/developer/repos/reposystem/total-upgrade`: Confirmed stub state (Justfile, README.adoc).
* `ls -R ~/developer/repos/rsr-template-repo`: Identified RSR directory structure (aspects, bridges, core, etc.).
* `cat ~/developer/repos/odds-and-sods-package-manager/opsm_ex/lib/opsm/cli.ex`: Confirmed rich feature set in `opsm`.
* `find ~/developer/repos -name "Cargo.toml" | xargs grep "ratatui"`: Found `opsm-tui` and `reposystem-tui` as implementation references.

## Existing Relevant Projects
| Path | What it is | Evidence | Reuse recommendation |
| :--- | :--- | :--- | :--- |
| `reposystem/total-upgrade` | Placeholder | Justfile/README only. | **Main Project Root.** |
| `opsm` | Core Backend | Elixir CLI with 101 adapters. | **Backend Provider.** |
| `rsr-template-repo` | Repo Structure | `.a2ml` and RSR dirs. | **Structural Template.** |

## Strategic Decisions
* **Language:** Rust + `ratatui` (standard across your other TUI projects).
* **Architecture:** Meta-manager calling `opsm` CLI and parsing `asdf`/`mise` configs directly.
* **Categorization:** Tiered hierarchy (e.g., Editors -> Basic / IDE / Formatter) instead of flat lists.
* **Platform Visibility:** Clear indicators for **Win, Mac, Linux, Minix, Android, iOS** using Unicode symbols or labels.
* **Context Awareness:** Filter views based on whether a tool is relevant to the current hardware (e.g., skip IDEs on mobile unless requested).

## Proposed Stage 1 Scope
* **Rust Scaffolding:** `cargo init` and directory setup following `rsr-template-repo` (src/core, src/interface, etc.).
* **Basic TUI:** A compiling binary that opens a Ratatui window and exits cleanly.
* **Manifests:** Initial `0-AI-MANIFEST.a2ml` and `Justfile` integration.

## Risks / Unknowns
* **Minix symbols:** Need to decide on a clear, recognizable short-code or icon for Minix in a TUI.
* **Mobile/Termux:** Rust/Ratatui works in Termux, but requires testing for touch-based navigation vs keyboard.

Stage 0 complete. I will not start Stage 1 until you approve or modify this plan.
