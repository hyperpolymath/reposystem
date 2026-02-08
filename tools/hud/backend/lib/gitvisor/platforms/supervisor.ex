# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

defmodule Gitvisor.Platforms.Supervisor do
  @moduledoc """
  Supervisor for platform adapters.

  Manages connections to external Git platforms (GitHub, GitLab, etc.)
  with support for rate limiting, caching, and failover.
  """

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # Platform adapter registry
      {Registry, keys: :unique, name: Gitvisor.Platforms.Registry},

      # GitHub adapter
      Gitvisor.Platforms.GitHub,

      # GitLab adapter
      Gitvisor.Platforms.GitLab,

      # Rate limiter for API calls
      Gitvisor.Platforms.RateLimiter,

      # Webhook receiver
      Gitvisor.Platforms.Webhooks
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
