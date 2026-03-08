# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

import Config

config :gitvisor,
  ecto_repos: [Gitvisor.Repo]

# Endpoint configuration
config :gitvisor, GitvisorWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [json: GitvisorWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Gitvisor.PubSub,
  live_view: [signing_salt: "gitvisor_lv"]

# JSON library
config :phoenix, :json_library, Jason

# Logger configuration
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config
import_config "#{config_env()}.exs"
