# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

import Config

# Development endpoint configuration
config :gitvisor, GitvisorWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "dev_secret_key_base_at_least_64_bytes_long_for_development_only_change_in_prod",
  watchers: []

# Development database (CubDB for simplicity)
config :gitvisor, Gitvisor.Repo,
  adapter: Gitvisor.Repo.CubDB,
  data_dir: "priv/data/dev"

# Development cache (in-memory)
config :gitvisor, Gitvisor.Cache,
  adapter: Gitvisor.Cache.ETS

# Logging
config :logger, :console, format: "[$level] $message\n"

# Phoenix dev settings
config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
