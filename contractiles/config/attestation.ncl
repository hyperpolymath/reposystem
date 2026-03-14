# SPDX-License-Identifier: PMPL-1.0-or-later
# attestation.ncl — Node attestation configuration for deployment targets.
#
# Defines attestation requirements for nodes that run contractile-managed
# services. Each deployment target must prove its identity and integrity
# before receiving signed artifacts.
#
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)

{
  attestation = {
    # Enable node attestation for deployments
    enabled = true,

    # Attestation method
    method = "tpm2-quote",

    # Required PCR values for boot integrity
    pcr_policy = {
      # PCR 0: BIOS/UEFI firmware
      pcr0 = "required",
      # PCR 7: Secure Boot state
      pcr7 = "required",
      # PCR 4-5: Boot manager
      pcr4 = "advisory",
      pcr5 = "advisory",
    },

    # Node identity verification
    identity = {
      # Require device certificate
      require_cert = true,
      # Certificate authority
      ca = "keys/node-ca.pem",
      # Minimum key strength
      min_key_bits = 256,
    },

    # Deployment constraints
    constraints = {
      # Only deploy to attested nodes
      require_attestation_for_deploy = true,
      # Re-attest on every deployment
      re_attest_on_deploy = true,
      # Maximum time since last attestation (seconds)
      max_attestation_age = 3600,
    },
  },
}
