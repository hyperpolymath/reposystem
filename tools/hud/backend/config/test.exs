# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

import Config

# Test endpoint configuration
config :gitvisor, GitvisorWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_secret_key_base_at_least_64_bytes_long_for_testing_only_change_in_prod",
  server: false

# Test database (in-memory)
config :gitvisor, Gitvisor.Repo,
  adapter: Gitvisor.Repo.InMemory

# Test cache (in-memory)
config :gitvisor, Gitvisor.Cache,
  adapter: Gitvisor.Cache.ETS

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
