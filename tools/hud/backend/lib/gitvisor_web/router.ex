# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

defmodule GitvisorWeb.Router do
  use GitvisorWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :graphql do
    plug :accepts, ["json"]
    plug GitvisorWeb.Plugs.Context
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  # GraphQL API
  scope "/api" do
    pipe_through :graphql

    forward "/graphql", Absinthe.Plug,
      schema: GitvisorWeb.Schema

    # GraphQL Playground (dev only)
    if Mix.env() == :dev do
      forward "/graphiql", Absinthe.Plug.GraphiQL,
        schema: GitvisorWeb.Schema,
        interface: :playground,
        socket: GitvisorWeb.UserSocket
    end
  end

  # REST fallback endpoints (for compatibility)
  scope "/api/v1", GitvisorWeb.Api.V1 do
    pipe_through :api

    # Health check
    get "/health", HealthController, :check

    # OAuth callbacks
    get "/auth/:provider/callback", AuthController, :callback
  end

  # .well-known endpoints
  scope "/.well-known", GitvisorWeb do
    get "/security.txt", WellKnownController, :security
    get "/humans.txt", WellKnownController, :humans
  end
end
