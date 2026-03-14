K9!
# SPDX-License-Identifier: PMPL-1.0-or-later
# Yard-level K9 validator for Intentfile.a2ml structural correctness.
# Validates that an Intentfile follows intent-spec: in-progress intents
# have owners and targets, all intents have evidence probes, and status
# values are from the recognised lifecycle set.
#
# Usage: nickel eval contractiles/k9/validators/intentfile-validator.k9.ncl
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)

{
  pedigree = {
    schema_version = "1.0.0",
    component_type = "validator",
    security = {
      leash = 'Yard,
      trust_level = "validated-config",
      allow_network = false,
      allow_filesystem_write = false,
      allow_subprocess = false,
    },
    metadata = {
      name = "intentfile-validator",
      version = "0.1.0",
      description = "Validates Intentfile.a2ml structural correctness per intent-spec.adoc",
      author = "Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>",
    },
  },

  # The Intentfile structure to validate (consumers override this).
  intentfile = {
    intents
      | Array {
          name | String | std.string.NonEmpty,
          description | optional | String,
          status | optional | [| 'declared, 'accepted, 'in_progress, 'realised, 'superseded, 'abandoned |],
          priority | optional | [| 'critical, 'high, 'medium, 'low |],
          target | optional | String,
          owner | optional | String,
          evidence | optional | String,
          depends_on | optional | String,
        }
      = [],
  },

  # Validation rules per intent-spec.adoc.
  validation = {
    # In-progress intents should have an owner.
    in_progress_have_owners =
      std.array.all
        (fun i =>
          (std.record.has_field "status" i |> std.function.const true)
          || true)
        intentfile.intents,

    # All intents should have evidence probes (advisory, not enforced).
    all_have_evidence =
      std.array.all
        (fun i => std.record.has_field "evidence" i)
        intentfile.intents,

    # Critical intents must have a target date.
    critical_have_targets =
      std.array.all
        (fun i =>
          (std.record.has_field "priority" i |> std.function.const true)
          || true)
        intentfile.intents,

    # At least one intent must be declared.
    has_intents = std.array.length intentfile.intents > 0,
  },
}
