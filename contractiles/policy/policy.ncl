# SPDX-License-Identifier: PMPL-1.0-or-later
# policy.ncl — Contractile system policy configuration.
#
# Defines the policy rules for the contractiles project:
# - Which contractile types are required
# - What checks must pass before deployment
# - Which algorithms are approved for trust operations
# - K9 security level requirements
#
# Evaluated via: nickel export policy/policy.ncl -f json
# Validated via: nickel check policy/policy.ncl
#
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)

{
  # Policy metadata
  policy = {
    name = "contractiles-policy",
    version = "1.0.0",
    description = "Operational policy for the contractiles project",
  },

  # Which contractile types are required in this project
  required_contractiles = {
    mustfile = true,
    trustfile = true,
    dustfile = true,
    intentfile = true,
    k9_validators = true,
  },

  # Must check policy
  must = {
    # All checks with severity: critical must pass
    critical_checks_required = true,
    # Warnings are advisory only
    warnings_block_deploy = false,
    # Minimum checks required
    minimum_checks = 4,
  },

  # Trust verification policy
  trust = {
    # Approved hash algorithms (no MD5, no SHA1)
    approved_hash_algorithms = [
      "SHA-256",
      "SHA-384",
      "SHA-512",
      "SHA3-256",
      "SHA3-512",
      "SHAKE256",
      "BLAKE3",
    ],

    # Approved signature algorithms
    approved_signature_algorithms = [
      "Ed25519",
      "Ed448",
      "Dilithium5",
      "SPHINCS+",
    ],

    # Banned algorithms
    banned_algorithms = [
      "MD5",
      "SHA1",
      "RC4",
      "DES",
      "3DES",
    ],

    # Post-quantum readiness
    require_pq_for_long_term = true,
  },

  # Dust recovery policy
  dust = {
    # Every must check should have a corresponding dust recovery
    require_recovery_coverage = false,
    # Non-idempotent actions must be explicitly marked
    require_idempotent_annotation = true,
    # Cluster/global blast radius requires precondition
    require_precondition_for_wide_blast = true,
  },

  # Intent tracking policy
  intend = {
    # In-progress intents should have an owner
    require_owner_for_active = false,
    # Critical intents must have a target date
    require_target_for_critical = true,
    # All intents should have evidence probes
    require_evidence_probes = false,
  },

  # K9 security policy
  k9 = {
    # Hunt-level components require signatures
    hunt_requires_signature = true,
    # Kennel-level is always safe
    kennel_always_allowed = true,
    # Yard-level recommended but not required to sign
    yard_signature_recommended = true,
  },

  # Deployment gates
  deployment = {
    # All critical must checks must pass
    require_must_check = true,
    # All critical trust verifications must pass
    require_trust_verify = true,
    # Intent progress must be reviewed
    require_intent_review = false,
    # Container images must use pinned digests
    require_pinned_images = true,
    # No Dockerfiles (Containerfile only)
    ban_dockerfile = true,
  },
}
