K9!
# SPDX-License-Identifier: PMPL-1.0-or-later
# Yard-level K9 validator for Dustfile.a2ml structural correctness.
# Validates that a Dustfile follows dust-spec: every recovery action has
# exactly one executable field (handler/rollback/undo/transform), a
# description, and recognised blast_radius and idempotent values.
#
# Usage: nickel eval contractiles/k9/validators/dustfile-validator.k9.ncl
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
      name = "dustfile-validator",
      version = "0.1.0",
      description = "Validates Dustfile.a2ml structural correctness per dust-spec.adoc",
      author = "Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>",
    },
  },

  # The Dustfile structure to validate (consumers override this).
  dustfile = {
    actions
      | Array {
          name | String | std.string.NonEmpty,
          description | optional | String,
          action_type | [| 'handler, 'rollback, 'undo, 'transform |],
          command | String | std.string.NonEmpty,
          blast_radius | optional | [| 'file, 'service, 'cluster, 'global |],
          idempotent | optional | Bool,
          preserves_audit | optional | Bool,
        }
      = [],
  },

  # Validation rules per dust-spec.adoc.
  validation = {
    # Every action must have a non-empty command.
    all_have_commands =
      std.array.all (fun a => std.string.length a.command > 0) dustfile.actions,

    # At least one recovery action must be defined.
    has_actions = std.array.length dustfile.actions > 0,
  },
}
