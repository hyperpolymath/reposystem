# SPDX-License-Identifier: PMPL-1.0-or-later
# Elixir Phoenix service template for ecosystem backends

{
  metadata = {
    name = "elixir-phoenix-service",
    description = "Elixir Phoenix service with GraphQL and PostgreSQL",
    version = "1.0.0",
    author = "Jonathan D.A. Jewell",
    license = "PMPL-1.0-or-later",
  },

  structure = {
    directories = [
      "lib",
      "lib/{{name}}",
      "lib/{{name}}_web",
      "lib/{{name}}_web/schema",
      "lib/{{name}}_web/resolvers",
      "test",
      "test/{{name}}",
      "test/{{name}}_web",
      "priv/repo/migrations",
      ".machine_readable",
      ".github/workflows",
      "docs",
    ],

    files = {
      # Mix project file
      "mix.exs" = {
        content = ''
# SPDX-License-Identifier: PMPL-1.0-or-later
defmodule {{module_name}}.MixProject do
  use Mix.Project

  def project do
    [
      app: :{{name}},
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      mod: {{{module_name}}.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.7"},
      {:phoenix_ecto, "~> 4.4"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.1.1"},
      {:bandit, "~> 1.0"},
      {:absinthe, "~> 1.7"},
      {:absinthe_phoenix, "~> 2.0"},
      {:absinthe_plug, "~> 1.5"},
      {:cors_plug, "~> 3.0"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
        '',
      },

      # Application entry point
      "lib/{{name}}/application.ex" = {
        content = ''
# SPDX-License-Identifier: PMPL-1.0-or-later
defmodule {{module_name}}.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {{module_name}}.Repo,
      {DNSCluster, query: Application.get_env(:{{name}}, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: {{module_name}}.PubSub},
      {{module_name}}Web.Endpoint
    ]

    opts = [strategy: :one_for_one, name: {{module_name}}.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    {{module_name}}Web.Endpoint.config_change(changed, removed)
    :ok
  end
end
        '',
      },

      # GraphQL schema
      "lib/{{name}}_web/schema.ex" = {
        content = ''
# SPDX-License-Identifier: PMPL-1.0-or-later
defmodule {{module_name}}Web.Schema do
  use Absinthe.Schema

  import_types({{module_name}}Web.Schema.Types)

  query do
    @desc "Health check"
    field :health, :string do
      resolve(fn _, _, _ -> {:ok, "ok"} end)
    end

    @desc "Get service version"
    field :version, :string do
      resolve(fn _, _, _ ->
        {:ok, Application.spec(:{{name}}, :vsn) |> to_string()}
      end)
    end
  end

  mutation do
    # Add mutations here
  end

  subscription do
    # Add subscriptions here
  end
end
        '',
      },

      # GraphQL types
      "lib/{{name}}_web/schema/types.ex" = {
        content = ''
# SPDX-License-Identifier: PMPL-1.0-or-later
defmodule {{module_name}}Web.Schema.Types do
  use Absinthe.Schema.Notation

  # Define custom types here
end
        '',
      },

      # Phoenix endpoint
      "lib/{{name}}_web/endpoint.ex" = {
        content = ''
# SPDX-License-Identifier: PMPL-1.0-or-later
defmodule {{module_name}}Web.Endpoint do
  use Phoenix.Endpoint, otp_app: :{{name}}

  @session_options [
    store: :cookie,
    key: "_{{name}}_key",
    signing_salt: "{{signing_salt}}",
    same_site: "Lax"
  ]

  socket("/graphql", {{module_name}}Web.GraphQLSocket,
    websocket: true,
    longpoll: false
  )

  plug(Plug.Static,
    at: "/",
    from: :{{name}},
    gzip: false,
    only: ~w(assets fonts images favicon.ico robots.txt)
  )

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)
  plug(Plug.Session, @session_options)
  plug(CORSPlug, origin: ["http://localhost:3000"])
  plug({{module_name}}Web.Router)
end
        '',
      },

      # Router
      "lib/{{name}}_web/router.ex" = {
        content = ''
# SPDX-License-Identifier: PMPL-1.0-or-later
defmodule {{module_name}}Web.Router do
  use {{module_name}}Web, :router

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/" do
    pipe_through(:api)

    forward("/graphql", Absinthe.Plug,
      schema: {{module_name}}Web.Schema
    )

    forward("/graphiql", Absinthe.Plug.GraphiQL,
      schema: {{module_name}}Web.Schema,
      interface: :simple
    )
  end
end
        '',
      },

      # Repo
      "lib/{{name}}/repo.ex" = {
        content = ''
# SPDX-License-Identifier: PMPL-1.0-or-later
defmodule {{module_name}}.Repo do
  use Ecto.Repo,
    otp_app: :{{name}},
    adapter: Ecto.Adapters.Postgres
end
        '',
      },

      # Config
      "config/config.exs" = {
        content = ''
# SPDX-License-Identifier: PMPL-1.0-or-later
import Config

config :{{name}},
  ecto_repos: [{{module_name}}.Repo]

config :{{name}}, {{module_name}}Web.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: {{module_name}}Web.ErrorJSON],
    layout: false
  ],
  pubsub_server: {{module_name}}.PubSub,
  live_view: [signing_salt: "{{signing_salt}}"]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
        '',
      },

      # Dev config
      "config/dev.exs" = {
        content = ''
# SPDX-License-Identifier: PMPL-1.0-or-later
import Config

config :{{name}}, {{module_name}}.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "{{name}}_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :{{name}}, {{module_name}}Web.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "{{secret_key_base}}",
  watchers: []

config :logger, :console, format: "[$level] $message\n"
config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
        '',
      },

      # Test config
      "config/test.exs" = {
        content = ''
# SPDX-License-Identifier: PMPL-1.0-or-later
import Config

config :{{name}}, {{module_name}}.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "{{name}}_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :{{name}}, {{module_name}}Web.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "{{secret_key_base}}",
  server: false

config :logger, level: :warning
config :phoenix, :plug_init_mode, :runtime
        '',
      },

      # Runtime config
      "config/runtime.exs" = {
        content = ''
# SPDX-License-Identifier: PMPL-1.0-or-later
import Config

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  config :{{name}}, {{module_name}}.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: [:inet6]

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :{{name}}, {{module_name}}Web.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base
end
        '',
      },

      # Justfile
      "justfile" = {
        content = ''
# SPDX-License-Identifier: PMPL-1.0-or-later
# justfile - Task runner for {{name}}

default:
    @just --list

setup:
    mix deps.get
    mix ecto.setup

run:
    iex -S mix phx.server

test:
    mix test

fmt:
    mix format

lint:
    mix credo --strict

clean:
    mix clean
    mix deps.clean --all

reset-db:
    mix ecto.reset

migrate:
    mix ecto.migrate

routes:
    mix phx.routes
        '',
      },

      # STATE.scm
      ".machine_readable/STATE.scm" = {
        content = ''
;; SPDX-License-Identifier: PMPL-1.0-or-later
;; STATE.scm - Project state for {{name}}
;; Media-Type: application/vnd.state+scm

(state
  (metadata
    (version "0.1.0")
    (schema-version "1.0")
    (created "{{created_date}}")
    (updated "{{created_date}}")
    (project "{{name}}")
    (repo "github.com/{{github_user}}/{{name}}"))

  (project-context
    (name "{{name}}")
    (tagline "{{description}}")
    (tech-stack ("Elixir" "Phoenix" "GraphQL" "PostgreSQL")))

  (current-position
    (phase "initial")
    (overall-completion 0)
    (components ())
    (working-features ()))

  (integration
    (seo-score . "0")
    (health-score . "0")
    (reposystem-registered . "false")
    (gnosis-enabled . "true"))

  (route-to-mvp
    (milestones ()))

  (blockers-and-issues
    (critical)
    (high)
    (medium)
    (low))

  (critical-next-actions
    (immediate
      ("Implement GraphQL schema")
      ("Add database models")
      ("Write tests")))

  (session-history ()))
        '',
      },

      # README template
      "README.template.adoc" = {
        content = ''
= (:project-context.name)

image:https://img.shields.io/badge/License-PMPL--1.0-blue.svg[License: PMPL-1.0]

// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: {{year}} {{author}}

*(:project-context.tagline)*

== Status

Phase: *(:current-position.phase)* | Progress: *(:current-position.overall-completion)%*

== Tech Stack

* Elixir 1.18+
* Phoenix 1.7+
* GraphQL (Absinthe)
* PostgreSQL

== Installation

[source,bash]
----
git clone https://github.com/{{github_user}}/{{name}}.git
cd {{name}}
just setup
----

== Usage

[source,bash]
----
just run
----

GraphQL endpoint: http://localhost:4000/graphql
GraphiQL IDE: http://localhost:4000/graphiql

== Development

[source,bash]
----
just test     # Run tests
just fmt      # Format code
just lint     # Run credo
just routes   # Show routes
----

== License

PMPL-1.0-or-later - see link:LICENSE.txt[LICENSE.txt]
        '',
      },
    },
  },
}
