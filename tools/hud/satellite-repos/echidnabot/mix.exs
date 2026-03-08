# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

defmodule Echidnabot.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/hyperpolymath/echidnabot"

  def project do
    [
      app: :echidnabot,
      version: @version,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: escript(),
      name: "Echidnabot",
      source_url: @source_url,
      docs: docs()
    ]
  end

  def application do
    [
      mod: {Echidnabot.Application, []},
      extra_applications: [:logger, :crypto]
    ]
  end

  defp deps do
    [
      # CLI
      {:optimus, "~> 0.5"},

      # Property testing
      {:stream_data, "~> 0.6"},
      {:propcheck, "~> 1.4", optional: true},

      # Static analysis helpers
      {:credo, "~> 1.7", runtime: false},

      # Crypto for attestations
      {:blake3, "~> 1.0"},
      {:jason, "~> 1.4"},

      # HTTP for timestamps
      {:req, "~> 0.4"},

      # Config parsing
      {:toml, "~> 0.7"},

      # Dev
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp escript do
    [main_module: Echidnabot.CLI]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.adoc"]
    ]
  end
end
