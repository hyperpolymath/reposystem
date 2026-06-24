<!--
SPDX-License-Identifier: CC-BY-SA-4.0
SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath)
-->

# Changelog

All notable changes to `reposystem` will be documented in this file.

This file is generated from conventional commits by the
[`changelog-reusable.yml`](https://github.com/hyperpolymath/standards/blob/main/.github/workflows/changelog-reusable.yml)
workflow (`hyperpolymath/standards#206`). Adopt the workflow in this repo's CI to keep this file in sync automatically — see
[`templates/cliff.toml`](https://github.com/hyperpolymath/standards/blob/main/templates/cliff.toml)
for the canonical config.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
this project aims to follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- feat(aggregator): estate organization — manifest, thread runner, generated superproject (#63)
- feat(repo-batcher): from-scratch verified build-out (#59)
- feat(bust): extend schema with alert_remediations + seed 11 entries (#15)
- feat(scaffoldia): add zig-edge template for unified-zig-api stack
- feat: add rpa-elysium, total-upgrade, and total-recall as submodules
- feat(scaffoldia): wire RepoKind taxonomy into CLI — new + kinds commands
- feat(scaffoldia): add boj-cartridge template and fix RepoKind build
- feat(scaffoldia): add repo-kind taxonomy, trainyard connection graph, and provisioner
- feat(crg): add crg-grade and crg-badge justfile recipes
- feat: wire conflow config validation pipeline

### Fixed

- fix(licence): rb56-work — clear scaffold-placeholder leak (superproject) (#64)
- fix(ci): canonicalise all 12 hypatia-scan.yml (kill templater regeneration drift) (#51)
- fix(ci): bump a2ml/k9-validate-action pins off broken/stale SHAs (standards#85) (#50)
- fix(ci): CodeQL language-aware detection (#42)
- fix(ci): hypatia-scan Comment step must not gate the scan (12 copies) (#41)
- fix(security): replace placeholder crypto with audited crate implementations (#39)
- fix(recon-wasm): restore missing builtins.rs (E0583 build blocker) (#40)
- fix(ci): Phase-2 fleet submission must not fail the security gate (#38)
- fix(ci): hypatia-scan.yml -- --exit-zero + GITHUB_TOKEN (hyperpolymath/hypatia#213) (#26)
- fix(ci): rsr-antipattern duplicate heredoc + setup-beam ubuntu24 (#28)

### Documentation

- docs: verify standalone-vs-local status of the 7 Phase-2 sub-projects + flag submodule-wiring drift
- docs: record tech-debt audit findings (2026-05-26) (#74)
- docs(repo-batcher): correct status to verified L1–L8 build-out (post #59) (#61)
- docs(repo-batcher): correct to verified-accurate state (no V ever; Zig stub unimplemented) (#58)
- docs(repo-batcher): mark V layer legacy/transitional pending Zig port (#57)
- docs: Item 11 Group A — promote stub .adoc from canonical .md (#47)
- docs(readme): add SPDX header and standard badges
- docs(readme): add SPDX header and/or standard badges
- docs: add per-directory READMEs and fix EXPLAINME file map (CRG D→C)
- docs(governance): CRG v2.0 STRICT audit — C (declared) -> D (honest)
- docs: track unresolved mirror and compliance tasks

### CI

- ci(governance): baseline pre-existing ReScript + exempt allowed ATS2 for banned_language_file via .hypatia-ignore (#91)
- ci(rust): convert rust-ci.yml to thin wrapper (standards#174) (#70)
- ci(gitignore): ignore generated/* artefacts (Refs standards#93) (#67)
- ci: redistribute concurrency-cancel guard to read-only check workflows (#60)
- ci: add templated k9iser-regen trigger (mirrors boj-build.yml) (#52)
- ci(hypatia): adopt canonical SARIF code-scanning integration + report truth-fix (#49)

## Pre-history

Prior commits to this file's introduction are recorded in git history but not formally classified into Keep-a-Changelog sections. To backfill, run `git cliff -o CHANGELOG.md` locally using the canonical [`cliff.toml`](https://github.com/hyperpolymath/standards/blob/main/templates/cliff.toml) — this is one-shot mechanical work.

---

<!-- This file was seeded by the 2026-05-26 estate tech-debt audit follow-up (Row-2 Phase 3); see [`hyperpolymath/standards/docs/audits/2026-05-26-estate-documentation-debt.md`](https://github.com/hyperpolymath/standards/blob/main/docs/audits/2026-05-26-estate-documentation-debt.md). -->
