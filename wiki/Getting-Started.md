<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->

# Getting Started

This page covers how to **build, run, and use** reposystem — the estate cockpit that holds one canonical representation of the hyperpolymath repo/forge estate and renders it through converged front-ends. For the underlying model (the Rust `types` schema of record, seams, stores), see [Architecture / Representation Model](Architecture-Representation-Model).

All facts below are taken from the repository's `Justfile`, `src/main.rs`, `README.adoc`, and `guix.scm`. Recipe names and CLI subcommands are quoted only where they actually exist in those files.

---

## 1. Prerequisites

| Tool | Why | Notes |
|------|-----|-------|
| **Rust toolchain** (`cargo`) | Builds the CLI / TUI and runs tests | `just doctor` checks for cargo |
| **Deno** | JS runtime / package manager; builds the ReScript core (`just build-rescript` runs `deno task build`) | No Node/npm |
| **just** | Task runner for every recipe on this page | `just --list` to enumerate |
| **Guix** (primary) | Package/build definition lives in `guix.scm` | `guix build -f guix.scm`, `guix shell -f guix.scm` |
| **Graphviz** (`dot`) | Renders DOT exports to SVG (`just render-svg`) | Optional, for visual export |

**Package management is Guix-only at the repo root.** The top-level `flake.nix` was removed (Nix fallback retired). A `flake.nix` still exists *inside* a sub-tool (`tools/hud/`), but there is no root-level Nix flake — use `guix.scm`.

Quick toolchain health check:

```bash
just doctor
```

---

## 2. Build

```bash
# Build everything (ReScript core + Rust CLI)
just build

# Just the Rust CLI (release binary)
just build-rust          # -> cargo build --release

# Debug / development build
just build-dev
```

Under the hood, `build` depends on `build-rescript` (`deno task build`) and `build-rust` (`cargo build --release`). From a clean checkout the `README.adoc` "Installation" path is simply:

```bash
git clone https://github.com/hyperpolymath/reposystem
cd reposystem
just build
```

To build the Guix package directly:

```bash
guix build -f guix.scm
```

---

## 3. Test

```bash
# Run the full suite (ReScript + Rust + integration)
just test

# Rust tests only
just test-rust           # -> cargo test
```

`just test` chains `test-rescript` (`deno test`), `test-rust` (`cargo test`), and `test-integration` (`./tests/integration/run.sh`).

**Current baseline: 113/113** on a fresh run (per `.machine_readable/6a2/STATE.a2ml`). Note that the recorded `tests-passing` figure in STATE carries an explicit staleness note — treat it as a baseline marker, not a live CI assertion.

---

## 4. CLI subcommand reference

The real subcommands are defined by the clap `Commands` enum in `src/main.rs`. These are the ones that actually exist:

| Subcommand | What it does |
|------------|--------------|
| `scan` | Scan repositories under a path and build the dependency graph |
| `import` | Import the estate from a manifest (default source `manifest`, i.e. `repos.toml`) into the graph |
| `view` | Launch the interactive TUI |
| `export` | Export the graph (`--format` dot, json, yaml, toml; `-o`/`--output` to a file; `--aspect` filter) |
| `edge` | Manage edges (relationships) between repos — `action` add/remove/list |
| `group` | Manage repository groups — `action` create/add/remove/delete/list/show |
| `aspect` | Manage aspect annotations — `action` tag/remove/list/show/filter |
| `scenario` | Manage scenarios — `action` create/delete/list/show/compare |
| `slot` | Manage slots (swappable capabilities) — `action` create/delete/list/show |
| `provider` | Manage providers (slot implementations) — `action` create/delete/list/show |
| `binding` | Manage slot bindings (consumer → provider) — `action` bind/unbind/list/show |
| `plan` | Generate and manage plans — `action` create/list/show/diff/rollback/delete |
| `apply` | Apply plans and manage execution — `action` apply/undo/status (`--dry-run`, `--auto-rollback`) |
| `weak-links` | Identify weak links in the ecosystem (`--aspect`, `--severity`) |
| `config` | Get or set a configuration key |
| `completions` | Generate shell completions (bash, zsh, fish, powershell) |

Global flags (defined on the top-level parser) include `-v`/`--verbose`, `-q`/`--quiet`, `--config`, `--data-dir`, `--no-color`, and `--json`. Logs are written to **stderr**, so command output on **stdout** (e.g. `export --format estate-json`) is never contaminated.

Run any subcommand through cargo during development:

```bash
just run <args>          # -> cargo run -- <args>
# e.g.
just run export --format json
```

---

## 5. Visualise the estate: import → export → serve

This is the end-to-end flow that produces the envelope the web HUD consumes. The unified export envelope uses schema `reposystem/estate-export@1`. Every recipe name below exists in the `Justfile`.

```bash
# 1. Import the estate manifest (repos.toml + repos.groups.toml) into the graph store
just import-manifest          # -> cargo run -- import manifest

# 2. Export the unified estate envelope into the web UI folder (web/export.json)
just web-export               # -> cargo run -- export --format estate-json -o web/export.json

# Steps 1+2 in one shot:
just web-refresh              # import-manifest + web-export

# 3. Serve the static web UI
just web-serve                # http://localhost:801, serves ./web/
```

Then open `http://localhost:801` in a browser and load `./export.json` (per `README.adoc`). To serve on a different port:

```bash
just web-serve-port 1803
```

For a Graphviz rendering instead of the web HUD:

```bash
just export-dot               # cargo run -- export --format dot > ecosystem.dot
just render-svg               # dot -Tsvg ecosystem.dot -o ecosystem.svg
```

The web HUD is a static vanilla-JS canvas prototype (grandfathered no-build); the TUI (`reposystem view`), the ReScript desktop GUI, and the forge-ops control surface are the other front-ends rendering the same canonical representation.

---

## 6. Language policy

reposystem follows the hyperpolymath banned-language policy (TypeScript, Node, npm, Go, Python, Java/Kotlin, Swift and others are banned; ReScript is banned in *new* code from 2026-04-30). Enforcement runs through the hypatia neurosymbolic scanner gate in CI. See [Governance and Hypatia](Governance-and-Hypatia) for the full policy, the SPDX/licence requirements (MPL-2.0 code + CC-BY-SA-4.0 docs), and the AffineScript migration.

---

See also: [Home](Home) · [Architecture / Representation Model](Architecture-Representation-Model) · [Estate / Submodule Layout](Estate-Submodule-Layout) · [Tool Registry](Tool-Registry) · [Governance and Hypatia](Governance-and-Hypatia)
