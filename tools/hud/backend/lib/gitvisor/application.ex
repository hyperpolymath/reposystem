# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

defmodule Gitvisor.Application do
  @moduledoc """
  The Gitvisor OTP Application.

  Starts supervision tree for the dashboard backend including:
  - Phoenix endpoint
  - Database connections (multi-database support)
  - PubSub for real-time features
  - Platform adapters (GitHub, GitLab)
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Telemetry supervisor
      GitvisorWeb.Telemetry,

      # PubSub for real-time updates
      {Phoenix.PubSub, name: Gitvisor.PubSub},

      # Database connections
      Gitvisor.Repo,
      Gitvisor.Cache,

      # HTTP connection pools
      {Finch, name: Gitvisor.Finch},

      # Platform adapters
      Gitvisor.Platforms.Supervisor,

      # GraphQL subscriptions
      {Absinthe.Subscription, GitvisorWeb.Endpoint},

      # Phoenix endpoint (must be last)
      GitvisorWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Gitvisor.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    GitvisorWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
