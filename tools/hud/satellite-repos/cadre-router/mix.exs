# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

defmodule Cadre.Router.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/hyperpolymath/cadre-router"

  def project do
    [
      app: :cadre_router,
      version: @version,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "CADRE Router",
      source_url: @source_url,
      docs: docs()
    ]
  end

  def application do
    [
      mod: {Cadre.Router.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      # Core
      {:plug, "~> 1.15"},
      {:plug_cowboy, "~> 2.7"},

      # HTTP client for proxy
      {:req, "~> 0.4"},
      {:finch, "~> 0.18"},

      # Distributed consensus
      {:ra, "~> 2.7", optional: true},  # Raft
      {:delta_crdt, "~> 0.6", optional: true},  # CRDTs

      # Static site generators
      {:serum, "~> 1.5", optional: true},

      # Utils
      {:jason, "~> 1.4"},

      # Dev/test
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.adoc"]
    ]
  end
end
