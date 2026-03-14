;; SPDX-License-Identifier: PMPL-1.0-or-later
;; STATE.scm - Project state for contractiles
;; Media-Type: application/vnd.state+scm

(state
  (metadata
    (version "1.1.0")
    (schema-version "1.0")
    (created "2026-01-03")
    (updated "2026-03-14")
    (project "contractiles")
    (repo "github.com/hyperpolymath/reposystem"))

  (project-context
    (name "contractiles")
    (tagline "File-first contract system for operating, verifying, recovering, and evolving repositories")
    (tech-stack
      ("Rust" "A2ML" "Nickel" "Just" "Ada")))

  (current-position
    (phase "active-development")
    (overall-completion 65)
    (components
      ("contractile-cli" "complete" "Unified Rust CLI with must/trust/dust/intend/k9/gen-just")
      ("contractile-core" "complete" "A2ML parser, K9 Nickel bridge, Just recipe emitter")
      ("must-spec" "complete" "Physical State specification with 5 golden examples")
      ("trust-spec" "complete" "Provenance State specification with 5 golden examples")
      ("dust-spec" "complete" "Reversibility State specification with 5 golden examples")
      ("intent-spec" "complete" "Intent State specification with 5 golden examples")
      ("a2ml-files" "complete" "All 4 canonical A2ML files expanded with full field coverage")
      ("k9-validators" "complete" "4 Yard-level K9 validators for structural correctness")
      ("just-integration" "complete" "contractile.just generated with 35 recipes, imported in Justfile")
      ("ada-must-runner" "legacy" "Reference Ada implementation preserved in runners/must/")
      ("legacy-shims" "deprecated" "YAML Mustfile/Dustfile/Intentfile retained for compatibility"))
    (working-features
      ("must check/fix/enforce/list/run" "Runs Mustfile.a2ml checks")
      ("trust verify/hash/sign/list" "Runs Trustfile.a2ml verifications")
      ("dust status/rollback/replay/run" "Executes Dustfile.a2ml recovery actions")
      ("intend list/check/progress" "Displays and probes Intentfile.a2ml intents")
      ("k9 eval/run/typecheck/info" "Evaluates K9 Nickel components")
      ("contractile gen-just" "Generates Just recipes from A2ML + K9 sources")
      ("symlink dispatch" "must/trust/dust/intend/k9 as standalone commands")
      ("evidence probes" "intend check verifies intent realisation")))

  (route-to-mvp
    (milestones
      ("specs-complete" "done" "All 4 specs written (must/trust/dust/intent)")
      ("cli-complete" "done" "Rust CLI built, tested, installed")
      ("k9-validators" "done" "Yard-level validators for all contractile types")
      ("just-integration" "done" "contractile.just generated and imported")
      ("ci-cd-workflow" "done" "contractile.yml workflow: build CLI, run checks, show progress")
      ("lifecycle-commands" "done" "intend accept/start/realise/abandon/supersede with guard rails")
      ("toml-compat" "todo" "must CLI reads mustfile.toml as fallback format")
      ("dust-preconditions" "todo" "dust run --check-precondition support")
      ("k9-hunt-signatures" "todo" "Actual signature verification for Hunt-level K9")))

  (blockers-and-issues
    (critical)
    (high)
    (medium
      ("Bitbucket push fails" "Atlassian API token auth issue, pre-existing"))
    (low
      ("~/.local/bin not on PATH in some shells" "User may need to add to profile")))

  (critical-next-actions
    (immediate
      ("Add contractile check/verify to CI workflow"))
    (this-week
      ("Implement intend lifecycle commands (accept/start/realise/abandon)")
      ("Add mustfile.toml fallback parsing"))
    (this-month
      ("Remove legacy YAML contractile files")
      ("Implement dust precondition checking")
      ("Add K9 Hunt-level signature verification")))

  (session-history
    ("2026-03-14" "Built unified Rust CLI, wrote 3 specs (trust/dust/intent), expanded A2ML files, K9 validators, Just integration, installed CLI, intend lifecycle commands, CI workflow, 6 A2ML parser tests")))
