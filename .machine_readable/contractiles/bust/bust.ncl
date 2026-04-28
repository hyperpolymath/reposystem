# SPDX-License-Identifier: PMPL-1.0-or-later
# Bust — error-handling / failure-recovery runner
#
# Pairs with: Bustfile.a2ml (same directory)
# Verb:       bust
# Semantics:  every declared failure mode must have a recovery path that has
#             been exercised. Runner injects failures (via declared probes)
#             and verifies the recovery path works. Hard gate on any
#             failure-mode with missing or broken recovery.
# CLI:        `contractile bust check`  → list failure modes + recovery status
#             `contractile bust drill`  → inject declared failures, verify recovery
#
# Anything else in this directory is human-only notes/archive; machines ignore.
#
# Base: ../_base.ncl provides pedigree_schema, run_defaults, probe_schema.
# See: docs/CONTRACTILE-SPEC.adoc

let base = import "../_base.ncl" in

{
  pedigree = base.pedigree_schema & {
    contractile_verb = "bust",
    semantics = "error handling + failure recovery",
    security = {
      leash = 'Kennel,
      trust_level = "controlled failure injection; scoped to system-under-test",
      allow_network = false,
      allow_filesystem_write = true,      # drills may write transient state (tmp dirs, test DBs)
      allow_subprocess = true,
      injection_scope = "system-under-test-only",
    },
    metadata = {
      name = "bust-runner",
      version = "1.0.0",
      description = "Exercises declared failure modes and verifies recovery paths. Hard-gates on any failure mode without working recovery.",
      paired_xfile = "Bustfile.a2ml",
      author = "Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>",
    },
  },

  schema = {
    failure_modes
      | Array {
          id | String,
          description | String,
          class | [| 'network, 'disk_full, 'oom, 'timeout, 'partial_write, 'panic, 'crash, 'rollback, 'concurrency |],
          # TODO: migrate to base.probe_schema (structured probe) when CLI supports it
          injection_probe | String,          # command that deterministically causes this failure
          # TODO: migrate to base.probe_schema (structured probe) when CLI supports it
          recovery_probe | String,           # command that verifies recovery (exit 0 = recovered)
          expected_recovery_time_seconds | Number | default = 30,
          # status_core values: 'declared, 'verified, 'failing; bust adds 'drilled
          status | [| 'declared, 'drilled, 'verified, 'failing |] | default = 'declared,
          notes | String | optional,
        },

    # alert_remediations — discovered (CI/CD/scanner-emitted) failure patterns.
    # Sibling to failure_modes (which is for injected/operational failures).
    # Fix-It-style entries: rich human diagnosis + machine-actionable remediation.
    # Consumed by `contractile bust diagnose <id>` (rendering) and
    # `contractile bust remediate <id>` (apply, --dry-run by default).
    # See EXTENSION-PROPOSAL-2026-04-28.adoc for full motivation and adoption path.
    alert_remediations
      | Array {
          id | String,                       # e.g. "scorecard.token-permissions.no-toplevel"
          title | String,
          severity | [| 'low, 'medium, 'high, 'critical |],
          emitted_by | Array String,         # ["scorecard", "cargo-audit", "dependabot", "codeql", ...]

          fingerprint | {
            source | String,
            rule_id | String,
            message_regex | String | optional,
          },

          diagnosis | {
            short | String,
            root_cause | String,
            why_humans_stuck | String | optional,
            class | [|
              'config_drift, 'dep_advisory, 'unmaintained_dep,
              'missing_workflow, 'missing_policy, 'code_defect,
              'permission_misconfig, 'expected_after_repo_creation
            |],
          },

          remediation | {
            preferred_strategy | [| 'auto_pr, 'cli_command, 'manual_only, 'config_change |],
            human_steps | Array String,
            machine_runner | String | optional,
            auto_safe | Bool | default = false,
            needs_review_when | Array String | optional,
            side_effects | Array String | optional,
          },

          verification | {
            post_fix_check | String,
            expected_state | String,
            ci_check_to_watch | String | optional,
          },

          preemption | {
            template_addition | Array String | optional,
            template_config | Array String | optional,
            prevents_recurrence | Bool | default = false,
            back_ratchet_target | [| 'all_repos, 'rust_only, 'js_only, 'agda_only, 'opt_in |] | optional,
          },

          references | Array String | optional,
          last_seen | String | optional,        # ISO date
          dismissed | Bool | default = false,
          dismissed_until | String | optional,  # ISO date for time-bound dismissals
          notes | String | optional,
        }
      | default = [],
  },

  # Runner behaviour — inherits from base.run_defaults.
  # bust adds record_recovery_times for performance tier feeding.
  run = base.run_defaults & {
    on_any_fail = "exit-nonzero",         # missing or broken recovery blocks merge
    report_format = "a2ml",
    emit_summary = true,
    record_recovery_times = true,         # feeds the performance tier
  },
}
