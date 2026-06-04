<!--
SPDX-License-Identifier: MPL-2.0
Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-->
# OpenSSF Best Practices — Submission Runbook (Issue #9)

> Status of prerequisites (verified 2026-05-15):
> - **Scorecard checks:** GREEN — `.github/workflows/scorecard.yml` and
>   `scorecard-enforcer.yml` run on push + schedule, `publish_results: true`,
>   SARIF uploaded to code scanning.
> - **Security policy:** GREEN — `SECURITY.md` present (GitHub Security
>   Advisories + encrypted email fallback, response timeline, safe harbour).
> - **Branch protection:** GREEN — `main` is protected (GitHub API
>   `protected: true`).
>
> The remaining work for Issue #9 is a **one-time authenticated browser
> action** on https://www.bestpractices.dev that requires the repo owner's
> GitHub login. It cannot be automated by CI or by an agent. This runbook
> reduces that action to copy/paste so it never has to be researched again.

## Why this stays manual

bestpractices.dev authenticates submitters via GitHub OAuth and ties each
project entry to the submitting account. There is no API token flow suitable
for unattended submission, and the self-assessment questionnaire requires a
human to attest. "Sorted for all time" therefore means: keep the technical
prerequisites permanently green (already automated) and keep this answer
sheet in-repo so any maintainer can complete a submission in minutes.

## Repos in scope

The owner submits the ecosystem repos. `reposystem` is the reference entry;
the answer sheet below is reusable for sibling repos that share the same
governance, CI, and security model. Track per-repo status in the table:

| Repo | bestpractices.dev project ID | Tier reached | Submitted |
|------|------------------------------|--------------|-----------|
| hyperpolymath/reposystem | _(fill after submission)_ | passing (target) | no |

## One-time submission steps

1. Sign in at https://www.bestpractices.dev with the GitHub account that owns
   the repos.
2. Click **Get Your Badge / Add Project**, enter the repo URL
   (`https://github.com/hyperpolymath/reposystem`).
3. Work top-to-bottom through the questionnaire using the **Answer sheet**
   below — each criterion is pre-mapped to in-repo evidence.
4. Save. Record the assigned numeric project ID in the table above and commit
   that change.
5. Swap the README badge to the live, ID-pinned form (see "README badge"
   below) and commit.
6. Repeat steps 2–5 for each sibling repo, reusing the answer sheet.

## README badge

Pre-award (current state) the badge in `README.adoc` links to the "new
project" page. Post-award, replace it with the ID-pinned live badge so it
self-updates as the tier changes:

```
image:https://www.bestpractices.dev/projects/<ID>/badge[OpenSSF Best Practices,link="https://www.bestpractices.dev/projects/<ID>"]
```

No further maintenance is needed: the badge image is rendered live by
bestpractices.dev from the project's current passing percentage.

## Answer sheet — "passing" level (copy/paste)

Evidence paths are relative to the repo root.

### Basics
- **Project description / homepage:** see `README.adoc`.
- **Interaction / contribution:** `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`,
  `MAINTAINERS.adoc`. → MET.
- **`contribution_requirements`:** documented in `CONTRIBUTING.md`. → MET.
- **`floss_license`:** `LICENSE` + SPDX `PMPL-1.0-or-later` headers across
  sources (`Cargo.toml` `license = "PMPL-1.0-or-later"`). FLOSS. → MET.
- **`floss_license_osi`:** PMPL is **not** an OSI-approved license. Answer
  **N/A with justification** (project uses a published FLOSS license that is
  not on the OSI list) — this is the one criterion requiring a maintainer
  attestation, not a code change.
- **`documentation_basics` / `documentation_interface`:** `README.adoc`,
  `QUICKSTART-*.adoc`, `docs/`, `EXPLAINME.adoc`. → MET.

### Change control
- **`repo_public` / `repo_track` / `repo_distributed`:** public Git repo on
  GitHub. → MET.
- **`version_unique` / `version_semver`:** `VERSION-ROADMAP.adoc`,
  release notes in `stateful-artefacts/RELEASE-NOTES-*.md`. → MET.
- **`release_notes`:** `stateful-artefacts/RELEASE-NOTES-v1.0.0.md`. → MET.

### Reporting
- **`report_process` / `report_tracker` / `report_responses`:** GitHub
  Issues + issue templates in `.github/ISSUE_TEMPLATE/`. → MET.
- **`vulnerability_report_process` / `_private` / `_response`:** `SECURITY.md`
  (GitHub Security Advisories preferred, encrypted email
  `security@hyperpolymath.org` fallback, documented response timeline). → MET.

### Quality
- **`build` / `build_common_tools` / `build_reproducible`:** `Justfile`,
  `Cargo.toml`/`Cargo.lock`, `flake.nix`/`flake.lock`, `guix.scm`. → MET.
- **`test` / `test_invocation` / `test_most`:** `tests/` (Rust integration,
  property, e2e, invariants), CI in `.github/workflows/rust-ci.yml`,
  `quality.yml`, `e2e.yml`. → MET.
- **`test_policy` / `tests_are_added`:** `TEST-NEEDS.md`, `CONTRIBUTING.md`.
  → MET.
- **`warnings` / `warnings_fixed`:** lint/quality CI (`quality.yml`,
  `workflow-linter.yml`, `rsr-antipattern.yml`). → MET.

### Security
- **`know_secure_design` / `know_common_errors`:** `SECURITY.md`
  ("Security Best Practices"), `.claude/CLAUDE.md` security requirements
  (SHA256+, HTTPS-only, no hardcoded secrets, SHA-pinned deps). → MET.
- **`crypto_*`:** project policy mandates SHA256+ and HTTPS only; no MD5/SHA1
  for security. → MET / N/A as applicable.
- **`vulnerabilities_fixed_60_days` / `vulnerabilities_critical_fixed`:**
  Dependabot (`.github/dependabot.yml`), CodeQL (`codeql.yml`), secret
  scanning (`secret-scanner.yml`), ClusterFuzzLite (`.clusterfuzzlite/`,
  `cflite_*.yml`). → MET.
- **`static_analysis`:** CodeQL + Scorecard + `hypatia-scan.yml`. → MET.
- **`dynamic_analysis`:** fuzzing via ClusterFuzzLite (`fuzz/`). → MET.

### Analysis / delivery
- **`dependency_monitoring`:** `.github/dependabot.yml`. → MET.
- **`automated_integration_testing`:** CI on PR (`e2e.yml`, `quality.yml`,
  `rust-ci.yml`). → MET.
- **`signed_releases`:** confirm release signing at submission time; if not
  yet signed, answer honestly and add as a follow-up (not a blocker for the
  passing tier's MUSTs).

## Keeping it green forever

These already run unattended; no recurring manual work:
- `scorecard.yml` (push + daily cron) and `scorecard-enforcer.yml` (weekly,
  fails CI below score 5) keep Scorecard healthy and republish results.
- `security-policy.yml` / `wellknown-enforcement.yml` enforce policy files.
- Branch protection on `main` is a one-time GitHub setting (already on).

If a sibling repo is added, copy this directory into it and run the
one-time submission steps.
