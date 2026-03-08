# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

defmodule Echidnabot do
  @moduledoc """
  Echidnabot - Automated formal validation and property-based testing.

  ## Quick Start

      # Verify current directory
      Echidnabot.verify()

      # Generate attestation
      Echidnabot.attest()

  ## Configuration

  Place `.echidnabot.toml` in your repo root to configure behavior.
  """

  alias Echidnabot.{Config, Verifier, Attestation}

  @doc """
  Run all configured verifications.
  """
  def verify(path \\ ".", opts \\ []) do
    config = Config.load(path)

    results =
      config.languages
      |> Enum.flat_map(fn lang ->
        Verifier.run(lang, path, config)
      end)

    summary = summarize(results)

    if opts[:output] do
      File.write!(opts[:output], Jason.encode!(summary, pretty: true))
    end

    {:ok, summary}
  end

  @doc """
  Generate a signed attestation from verification results.
  """
  def attest(path \\ ".", opts \\ []) do
    {:ok, results} = verify(path, opts)

    attestation = Attestation.generate(results, opts)

    if opts[:output] do
      File.write!(opts[:output], Jason.encode!(attestation, pretty: true))
    end

    {:ok, attestation}
  end

  @doc """
  CI-friendly verification that returns appropriate exit codes.
  """
  def ci(path \\ ".") do
    case verify(path) do
      {:ok, %{all_passed: true}} -> :ok
      {:ok, %{all_passed: false}} -> {:error, :verification_failed}
      error -> error
    end
  end

  defp summarize(results) do
    total = length(results)
    passed = Enum.count(results, & &1.passed)

    %{
      total_checks: total,
      passed: passed,
      failed: total - passed,
      all_passed: passed == total,
      components: results |> Enum.map(& &1.component) |> Enum.uniq(),
      results: results,
      timestamp: DateTime.utc_now()
    }
  end
end
