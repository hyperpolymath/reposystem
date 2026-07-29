# SPDX-License-Identifier: MPL-2.0

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
