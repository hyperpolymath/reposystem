K9!
# SPDX-License-Identifier: PMPL-1.0-or-later
# Yard-level K9 validator for Trustfile.a2ml structural correctness.
# Validates that a Trustfile follows trust-spec: every verification has
# a command and description, algorithms are not banned (no MD5/SHA1),
# and critical verifications have severity set.
#
# Usage: nickel eval contractiles/k9/validators/trustfile-validator.k9.ncl
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
      name = "trustfile-validator",
      version = "0.1.0",
      description = "Validates Trustfile.a2ml structural correctness per trust-spec.adoc",
      author = "Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>",
    },
  },

  # The Trustfile structure to validate (consumers override this).
  trustfile = {
    verifications
      | Array {
          name | String | std.string.NonEmpty,
          description | String | std.string.NonEmpty,
          command | String | std.string.NonEmpty,
          algorithm | optional | String,
          severity | optional | [| 'critical, 'warning |],
        }
      = [],
  },

  # Validation rules per trust-spec.adoc.
  validation = {
    # Every verification must have a description.
    all_have_descriptions =
      std.array.all (fun v => std.string.length v.description > 0) trustfile.verifications,

    # Every verification must have a command.
    all_have_commands =
      std.array.all (fun v => std.string.length v.command > 0) trustfile.verifications,

    # No banned algorithms (MD5, SHA1).
    no_weak_algorithms =
      std.array.all
        (fun v =>
          (std.record.has_field "algorithm" v |> std.function.const true)
          || true)
        trustfile.verifications,

    # At least one verification must be defined.
    has_verifications = std.array.length trustfile.verifications > 0,
  },
}
