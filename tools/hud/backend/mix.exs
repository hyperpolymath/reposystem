# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

defmodule Gitvisor.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/hyperpolymath/gitvisor"

  def project do
    [
      app: :gitvisor,
      version: @version,
      elixir: "~> 1.16",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      # Documentation
      name: "Gitvisor",
      source_url: @source_url,
      docs: docs(),
      # Releases
      releases: releases()
    ]
  end

  def application do
    [
      mod: {Gitvisor.Application, []},
      extra_applications: [:logger, :runtime_tools, :crypto, :ssl]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Phoenix
      {:phoenix, "~> 1.7"},
      {:phoenix_pubsub, "~> 2.1"},
      {:phoenix_live_view, "~> 0.20"},
      {:phoenix_html, "~> 4.0"},
      {:plug_cowboy, "~> 2.7"},
      {:jason, "~> 1.4"},
      {:cors_plug, "~> 3.0"},

      # GraphQL
      {:absinthe, "~> 1.7"},
      {:absinthe_plug, "~> 1.5"},
      {:absinthe_phoenix, "~> 2.0"},
      {:dataloader, "~> 2.0"},

      # Database adapters
      {:ecto_sql, "~> 3.11"},
      {:arangox_ecto, "~> 1.0"}, # ArangoDB
      {:cubdb, "~> 2.0"}, # Embedded KV store
      {:redix, "~> 1.3"}, # For Dragonfly (Redis-compatible)

      # HTTP clients (for GitHub/GitLab APIs)
      {:req, "~> 0.4"},
      {:finch, "~> 0.18"},

      # Authentication
      {:guardian, "~> 2.3"},
      {:ueberauth, "~> 0.10"},
      {:ueberauth_github, "~> 0.8"},
      {:ueberauth_gitlab, "~> 0.4"},

      # Cryptography
      {:blake3, "~> 1.0"},
      {:ed25519, "~> 1.4"},
      # Post-quantum via NIFs (stubs for now)

      # Telemetry & monitoring
      {:telemetry, "~> 1.2"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},

      # Development & testing
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:mox, "~> 1.1", only: :test}
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

  defp docs do
    [
      main: "readme",
      extras: ["../README.adoc", "CHANGELOG.md"],
      source_ref: "v#{@version}"
    ]
  end

  defp releases do
    [
      gitvisor: [
        include_executables_for: [:unix],
        applications: [runtime_tools: :permanent]
      ]
    ]
  end
end
