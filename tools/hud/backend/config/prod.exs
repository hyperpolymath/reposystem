# SPDX-License-Identifier: MPL-2.0
# Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
import Config

# Production endpoint configuration
config :gitvisor, GitvisorWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json"

# Production logging
config :logger, level: :info

# Runtime configuration
config :gitvisor, GitvisorWeb.Endpoint,
  server: true

# Note: Production secrets should be loaded from runtime.exs
# using environment variables
