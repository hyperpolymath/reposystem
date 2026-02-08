# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

import Config

if config_env() == :prod do
  # Secret key base from environment
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "gitvisor.dev"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :gitvisor, GitvisorWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # Database configuration
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      """

  config :gitvisor, Gitvisor.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

  # Cache (Dragonfly/Redis)
  cache_url = System.get_env("CACHE_URL") || "redis://localhost:6379"

  config :gitvisor, Gitvisor.Cache,
    adapter: Gitvisor.Cache.Dragonfly,
    url: cache_url

  # Platform credentials (optional, users provide their own tokens)
  if github_app_id = System.get_env("GITHUB_APP_ID") do
    config :gitvisor, :github,
      app_id: github_app_id,
      client_id: System.get_env("GITHUB_CLIENT_ID"),
      client_secret: System.get_env("GITHUB_CLIENT_SECRET")
  end

  if gitlab_app_id = System.get_env("GITLAB_APP_ID") do
    config :gitvisor, :gitlab,
      app_id: gitlab_app_id,
      client_id: System.get_env("GITLAB_CLIENT_ID"),
      client_secret: System.get_env("GITLAB_CLIENT_SECRET")
  end
end
