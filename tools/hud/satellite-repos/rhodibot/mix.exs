# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

defmodule Rhodibot.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/hyperpolymath/rhodibot"

  def project do
    [
      app: :rhodibot,
      version: @version,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: escript(),
      name: "Rhodibot",
      source_url: @source_url,
      docs: docs()
    ]
  end

  def application do
    [
      mod: {Rhodibot.Application, []},
      extra_applications: [:logger, :eex]
    ]
  end

  defp deps do
    [
      # CLI
      {:optimus, "~> 0.5"},

      # HTTP (for GitHub/GitLab API)
      {:req, "~> 0.4"},

      # Config
      {:toml, "~> 0.7"},
      {:jason, "~> 1.4"},

      # Templates
      {:eex, "~> 1.0"},

      # Web server (for service mode)
      {:plug_cowboy, "~> 2.7"},

      # Dev
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp escript do
    [main_module: Rhodibot.CLI]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.adoc"]
    ]
  end
end
