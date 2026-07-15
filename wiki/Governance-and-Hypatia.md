<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk> -->

# Governance & Hypatia

This page documents how `reposystem` is governed: the **hypatia** neurosymbolic scanner gate, the **language policy** (allowed vs banned), the **CRG governance grade** and its anti-fiction rule, **licensing & security** requirements, and the **CI** of SHA-pinned reusable workflows.

> Governance here is deliberately *external and audited*, not self-asserted. Grades are set only by a formal audit; the scanner gate is a real CI signal; the licence pair and security rules are enforced by shared workflows. See also [Estate / Submodule Layout](Estate-Submodule-Layout) and the [Tool Registry](Tool-Registry).

---

## 1. The hypatia neurosymbolic gate

`hypatia` is the estate's neurosymbolic anti-pattern scanner (Elixir). It runs against `reposystem` in CI as a thin wrapper over the shared estate reusable:

```yaml
# .github/workflows/hypatia-scan.yml
jobs:
  hypatia:
    uses: hyperpolymath/standards/.github/workflows/hypatia-scan-reusable.yml@d135b05bfc647d0c0fbfedc7e80f37ea50f49236
    secrets: inherit
```

How it runs (verified in `.machine_readable/descriptiles/NEUROSYM.a2ml`):

- **Clone-at-HEAD in CI** — the scanner is cloned at its current HEAD rather than pinned, so the gate always reflects the latest rule set.
- **Exits non-zero on `>= medium` findings**, surfacing them as a check.
- Triggered on push to `main`/`master`/`develop`, on pull requests to `main`/`master`, on a weekly `schedule`, and via `workflow_dispatch` (see `hypatia-scan.yml`).
- Report format is `logtalk`; scan depth `standard` (`NEUROSYM.a2ml`).

### Known non-blocking red

The hypatia gate is a **known, pre-existing red** that is **non-blocking** — it does not stop merges. Per `NEUROSYM.a2ml`, PRs #129–#162 all merged through it.

### 222 → 71 reduction (this session)

| Point | Findings |
|-------|----------|
| `baseline-2026-06-20` (pre-consolidation) | **222** |
| `current-2026-06-26` | **71** |

The reduction came from (per `NEUROSYM.a2ml` `reduction-basis`):

- Extracting the vendored standalone trees to gitlink submodules, removing large swathes of vendored-tree noise (see [Estate / Submodule Layout](Estate-Submodule-Layout)).
- Real first-party source fixes (#160: `src/commands/apply.rs` error-handling, `src/verisimdb.rs` blocking-client build).
- Workflow `timeout-minutes` hardening (#162), clearing the `WF013 missing_timeout_minutes` rule.

### Residual classification of the 71

Per `NEUROSYM.a2ml` `residual-classification`, the remaining findings are tracked, not regressions, and none are blocking. They are dominated by:

1. **Epic #93 migration debt** — ReScript→AffineScript. ReScript is banned-in-new-code, and roughly **213 pre-existing `.res` files are baselined** in `.hypatia-ignore` under the `cicd_rules/banned_language_file` rule (grandfathered debt, *not* an endorsement). New `.res` files are deliberately **not** baselined and stay flagged.
2. **Known false positives** — e.g. `web/app.js` SVG `xmlns` attributes and `clippy::pedantic` style noise.
3. **Embedded-tree residue** from `total-upgrade` / `git-morph` / `git-seo`.

`.hypatia-ignore` format note (from the file header): each non-comment line is `${rule}:${path}`, matched as fixed-string whole-line equality (`grep -qxF`). It also exempts `scaffoldia/repo-batcher`'s **ATS2** (`.dats`/`.sats`) sources — ATS2 is an *allowed* language; those entries exist because the central enforce list over-reaches, and they are explicitly marked **NOT migration debt**.

---

## 2. Language policy

The full allowed/banned policy lives in `.claude/CLAUDE.md` (the "Hyperpolymath Standard"). Summary:

### Allowed

| Language / Tool | Use case |
|-----------------|----------|
| **ReScript** | Primary application code (compiles to JS) — *but see ban note below* |
| **Deno** | Runtime & JS package management |
| **Rust** | Performance-critical, systems, WASM, CLI |
| **Tauri 2.0+** | Mobile apps (Rust backend + web UI) |
| **Dioxus** | Mobile apps (pure-Rust native UI) |
| **Gleam** | Backend services (BEAM or JS) |
| **Bash / POSIX shell** | Scripts, automation (kept minimal) |
| **JavaScript** | Only where ReScript cannot (MCP glue, Deno APIs) |
| **Nickel** | Configuration (e.g. the [Tool Registry](Tool-Registry)) |
| **Guile Scheme** | State/meta `.a2ml` files |
| **Julia** | Batch / data processing |
| **OCaml** | AffineScript compiler |
| **Ada** | Safety-critical |

### Banned (with replacement)

| Banned | Replacement |
|--------|-------------|
| TypeScript | AffineScript |
| Node.js / npm / Bun / pnpm / yarn | Deno |
| Go | Rust |
| V (vlang) | Zig / Rust (migration completed 2026-05-28) |
| Python | Julia / Rust / AffineScript |
| Java / Kotlin | Rust / Tauri / Dioxus |
| Swift / React Native / Flutter / Dart | Tauri / Dioxus |

### ReScript banned-in-new-code (2026-04-30)

Although ReScript is allowed for existing application code, **`.claude/CLAUDE.md` bans it in *new* code as of 2026-04-30** — convert TypeScript directly to AffineScript without passing through ReScript. Pre-existing `.res` files are grandfathered while the in-flight migration proceeds; they are baselined in `.hypatia-ignore` (see §1). The migration to **AffineScript is tracked as epic #93**. An empirical run of AffineScript's own `res-to-affine --partial` converter over the first-party `.res` files produced 0 compilable ports (397 TODO holes), confirming the port is human effort, not a mechanical transpile (`.hypatia-ignore` header).

Package management follows the same standard: **Guix primary** (`guix.scm`), **Nix fallback** historically (the `flake.nix` was removed in #144 — Guix-only now), Deno for JS deps.

---

## 3. CRG governance grade

`reposystem`'s Component Readiness Grade is **currently D**.

Critically, the grade is **never self-assessed**. It is set only by the formal **`docs/governance/CRG-AUDIT`** process. The on-disk audit is `docs/governance/CRG-AUDIT-2026-04-18.adoc`, which evaluates the repo against *Component Readiness Grades v2.0 (STRICT)*.

- The repo had **self-declared C** (`STATE.a2ml` `crg-grade = "C"`, `TEST-NEEDS.md` "CRG Grade: C — ACHIEVED 2026-04-04").
- The audit graded the repo **as-is today, not aspirationally**, and set a **demote target of D**, recommending `STATE.a2ml` move C→D citing the audit.
- The one-grade (not two-grade) demote rests on the v2.0 *"honest D > dishonest B"* clause and verified mitigating signals.

### The anti-fiction rule

The demotion to D was driven primarily by **fabrication**, which is why this estate enforces a hard anti-fiction rule. Per `CRG-AUDIT-2026-04-18.adoc`:

- The `EXPLAINME.adoc` **File Map was fabricated** — 10 of 18 listed paths did not exist; 5 claimed source directories (`importers/`, `aspects/`, `scenarios/`, `export/`, `cli/`) were fictional.
- The "Dogfooded Across The Account" table was fabricated — 4 of 4 cross-project dogfood claims unsubstantiated.

The rule for all docs (including this wiki): **state only facts verifiable by reading the named files**, or omit the claim. Prefer "see `<file>`" over guessing. Inventing file paths, CLI flags, recipes, function names, or version numbers is exactly what demoted the grade and must not recur.

---

## 4. Licensing & security

### Licence pair

The canonical pair, with **SPDX headers required on all files**:

| Scope | Licence |
|-------|---------|
| **Code** | `MPL-2.0` |
| **Docs** | `CC-BY-SA-4.0` |

(For example, this page carries the `CC-BY-SA-4.0` SPDX header; `.github/workflows/*.yml` and the Rust sources carry `MPL-2.0`.)

### Security requirements

Per `.claude/CLAUDE.md`:

- **No MD5/SHA1 for security** — use **SHA256+**.
- **HTTPS only** — no HTTP URLs.
- **No hardcoded secrets.**
- **SHA-pinned dependencies.**

Two CI workflows back the secret rule directly: `secret-scanner.yml` (calls `secret-scanner-reusable.yml`) and `scorecard.yml` (OpenSSF Scorecard supply-chain checks).

---

## 5. CI — standards reusable, SHA-pinned workflows

CI is built from **reusable workflows in `hyperpolymath/standards`**, called as thin per-repo wrappers and **SHA-pinned** (the shared reusables all pin `@d135b05bfc647d0c0fbfedc7e80f37ea50f49236`; standalone third-party actions, e.g. in `codeql.yml`, are pinned to full commit SHAs with a version comment). This is "configure once, propagate everywhere."

### Real workflow files in `.github/workflows/`

| File | Role (as documented in the file header) |
|------|------------------------------------------|
| `hypatia-scan.yml` | Neurosymbolic security scan (reusable wrapper) — see §1 |
| `governance.yml` | Single wrapper calling the shared estate governance bundle |
| `rust-ci.yml` | Rust CI (reusable wrapper, `toolchain: stable`) |
| `codeql.yml` | CodeQL analysis (scans `actions`/workflow files; repo source is not JS/TS) |
| `scorecard.yml` | OpenSSF Scorecards supply-chain security (reusable) |
| `secret-scanner.yml` | Secret scanning (reusable) |
| `bridge-gate.yml` | Bridge gate |
| `dogfood-gate.yml` | Dogfood gate |
| `boj-build.yml` | BOJ build |
| `cflite_batch.yml` | ClusterFuzzLite (batch) |
| `cflite_pr.yml` | ClusterFuzzLite (PR) |
| `instant-sync.yml` | Instant sync |
| `k9iser-regen.yml` | k9iser regen |
| `mirror.yml` | Cross-forge mirror |
| `push-email-notify.yml` | Push email notification |

`governance.yml` notes that it *replaces* per-repo governance scaffolding (formerly `quality.yml`, `guix-nix-policy.yml`, `npm-bun-blocker.yml`, `ts-blocker.yml`, `security-policy.yml`, `rsr-antipattern.yml`, `wellknown-enforcement.yml`, `workflow-linter.yml`) by delegating to the shared bundle, while load-bearing build/security workflows stay standalone in the repo.

---

### See also

- [Estate / Submodule Layout](Estate-Submodule-Layout) — the gitlink extraction that drove much of the 222→71 hypatia reduction.
- [Tool Registry](Tool-Registry) — `config/tools.ncl`, including extraction `Status` enums.
- [Home](Home)
