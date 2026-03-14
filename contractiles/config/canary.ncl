# SPDX-License-Identifier: PMPL-1.0-or-later
# canary.ncl — Canary and staged rollout configuration.
#
# Defines canary deployment parameters for the contractile system.
# Used by the control plane to gradually roll out policy changes.
#
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)

{
  canary = {
    # Enable canary deployments
    enabled = true,

    # Percentage of traffic to route to canary
    initial_weight = 10,

    # Step size for traffic increase
    step_weight = 10,

    # Time between steps (seconds)
    step_interval = 300,

    # Maximum weight before full promotion
    max_weight = 50,

    # Metrics to evaluate canary health
    analysis = {
      # Maximum acceptable error rate (percentage)
      max_error_rate = 1.0,

      # Maximum acceptable latency p99 (milliseconds)
      max_latency_p99 = 500,

      # Minimum evaluation period (seconds)
      min_evaluation_period = 600,
    },

    # Automatic rollback on failure
    rollback = {
      enabled = true,
      # Rollback if error rate exceeds threshold
      on_error_rate = true,
      # Rollback if latency exceeds threshold
      on_latency = true,
      # Notify on rollback
      notify = true,
    },
  },

  # Staged rollout phases
  phases = [
    {
      name = "canary",
      weight = 10,
      duration = "10m",
      checks = ["must check", "trust verify"],
    },
    {
      name = "expansion",
      weight = 50,
      duration = "30m",
      checks = ["must check"],
    },
    {
      name = "full",
      weight = 100,
      duration = "0",
      checks = ["must check", "trust verify"],
    },
  ],
}
