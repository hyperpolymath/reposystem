# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

defmodule Echidnabot.Verifier do
  @moduledoc """
  Language-specific verification runners.
  """

  require Logger

  @type result :: %{
          component: atom(),
          tool: String.t(),
          passed: boolean(),
          output: String.t(),
          duration_ms: non_neg_integer(),
          timestamp: DateTime.t()
        }

  @doc """
  Run verification for a specific language.
  """
  def run(language, path, config) do
    lang_config = Map.get(config, language, %{})

    case language do
      :elixir -> verify_elixir(path, lang_config)
      :rescript -> verify_rescript(path, lang_config)
      :ada -> verify_ada(path, lang_config)
      :julia -> verify_julia(path, lang_config)
      :rust -> verify_rust(path, lang_config)
      _ -> []
    end
  end

  # Elixir verification
  defp verify_elixir(path, config) do
    results = []

    # Dialyzer
    if Map.get(config, :dialyzer, true) do
      results = [run_tool(:elixir, "dialyzer", path, ["mix", "dialyzer"]) | results]
    end

    # Credo
    if Map.get(config, :credo_strict, true) do
      results = [run_tool(:elixir, "credo", path, ["mix", "credo", "--strict"]) | results]
    end

    # Property tests
    if Map.get(config, :property_tests, true) do
      results = [run_tool(:elixir, "property_tests", path, ["mix", "test", "--only", "property"]) | results]
    end

    results
  end

  # ReScript verification
  defp verify_rescript(path, _config) do
    [run_tool(:rescript, "compiler", path, ["npx", "rescript", "build"])]
  end

  # Ada/SPARK verification
  defp verify_ada(path, config) do
    results = []

    # Find GPR files
    gpr_files = Path.wildcard(Path.join(path, "**/*.gpr"))

    for gpr <- gpr_files do
      # GNAT compile with warnings as errors
      results = [run_tool(:ada, "gnat", path, ["gprbuild", "-P", gpr, "-gnatwe"]) | results]

      # GNATprove if requested
      level = Map.get(config, :gnatprove_level, 2)
      results = [run_tool(:ada, "gnatprove", path, ["gnatprove", "-P", gpr, "--level=#{level}"]) | results]
    end

    results
  end

  # Julia verification
  defp verify_julia(path, _config) do
    [run_tool(:julia, "tests", path, ["julia", "--project=.", "-e", "using Pkg; Pkg.test()"])]
  end

  # Rust verification
  defp verify_rust(path, _config) do
    [
      run_tool(:rust, "clippy", path, ["cargo", "clippy", "--", "-D", "warnings"]),
      run_tool(:rust, "test", path, ["cargo", "test"])
    ]
  end

  # Generic tool runner
  defp run_tool(component, tool, path, command) do
    start_time = System.monotonic_time(:millisecond)

    {output, exit_code} =
      try do
        System.cmd(hd(command), tl(command), cd: path, stderr_to_stdout: true)
      rescue
        e -> {inspect(e), 1}
      end

    duration = System.monotonic_time(:millisecond) - start_time

    %{
      component: component,
      tool: tool,
      passed: exit_code == 0,
      output: output,
      exit_code: exit_code,
      duration_ms: duration,
      timestamp: DateTime.utc_now()
    }
  end
end
