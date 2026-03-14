K9!
# SPDX-License-Identifier: PMPL-1.0-or-later
# Yard-level K9 validator for Mustfile.a2ml structural correctness.
# Validates that a Mustfile follows the must-spec: every check has a
# description and a run command, severity is a recognised value, and
# the required sections (Parameters, Checks) are present.
#
# Usage: nickel eval contractiles/k9/validators/mustfile-validator.k9.ncl
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
      name = "mustfile-validator",
      version = "0.1.0",
      description = "Validates Mustfile.a2ml structural correctness per must-spec.adoc",
      author = "Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>",
    },
  },

  # The Mustfile structure to validate (consumers override this).
  mustfile = {
    # Checks must be an array of records with required fields.
    checks
      | Array {
          name | String | std.string.NonEmpty,
          description | String | std.string.NonEmpty,
          run | String | std.string.NonEmpty,
          severity | optional | [| 'critical, 'warning |],
        }
      = [],
  },

  # Validation rules per must-spec.adoc.
  validation = {
    # Every check must have a non-empty description.
    all_checks_have_descriptions =
      std.array.all (fun c => std.string.length c.description > 0) mustfile.checks,

    # Every check must have a non-empty run command.
    all_checks_have_commands =
      std.array.all (fun c => std.string.length c.run > 0) mustfile.checks,

    # At least one check must be defined.
    has_checks = std.array.length mustfile.checks > 0,
  },
}
