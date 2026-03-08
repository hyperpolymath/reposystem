# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

defmodule Echidnabot.Attestation do
  @moduledoc """
  Attestation generation for verification results.

  Produces machine-verifiable attestations compatible with:
  - in-toto attestation format
  - SLSA provenance
  - OpenTimestamps
  """

  @doc """
  Generate an attestation from verification results.
  """
  def generate(results, opts \\ []) do
    base_attestation = %{
      "_type" => "https://in-toto.io/Statement/v0.1",
      "predicateType" => "https://echidnabot.dev/verification/v1",
      "subject" => [build_subject(opts)],
      "predicate" => %{
        "verification" => %{
          "total_checks" => results.total_checks,
          "passed" => results.passed,
          "failed" => results.failed,
          "all_passed" => results.all_passed,
          "components" => results.components,
          "timestamp" => DateTime.to_iso8601(results.timestamp)
        },
        "details" => Enum.map(results.results, &sanitize_result/1)
      }
    }

    attestation =
      base_attestation
      |> maybe_add_hash(results)
      |> maybe_add_timestamp(opts)
      |> maybe_sign(opts)

    attestation
  end

  defp build_subject(opts) do
    repo = Keyword.get(opts, :repo, get_repo_info())
    commit = Keyword.get(opts, :commit, get_commit_hash())

    %{
      "name" => repo,
      "digest" => %{
        "gitCommit" => commit
      }
    }
  end

  defp get_repo_info do
    case System.cmd("git", ["remote", "get-url", "origin"], stderr_to_stdout: true) do
      {url, 0} -> String.trim(url)
      _ -> "unknown"
    end
  end

  defp get_commit_hash do
    case System.cmd("git", ["rev-parse", "HEAD"], stderr_to_stdout: true) do
      {hash, 0} -> String.trim(hash)
      _ -> "unknown"
    end
  end

  defp sanitize_result(result) do
    %{
      "component" => to_string(result.component),
      "tool" => result.tool,
      "passed" => result.passed,
      "duration_ms" => result.duration_ms
      # Omit full output for brevity
    }
  end

  defp maybe_add_hash(attestation, results) do
    hash =
      results
      |> Jason.encode!()
      |> Blake3.hash()
      |> Base.encode16(case: :lower)

    put_in(attestation, ["predicate", "resultsHash"], %{
      "blake3" => hash
    })
  end

  defp maybe_add_timestamp(attestation, opts) do
    case Keyword.get(opts, :timestamp, "opentimestamps") do
      "opentimestamps" ->
        # Submit to OpenTimestamps (stub)
        put_in(attestation, ["predicate", "timestamp"], %{
          "type" => "opentimestamps",
          "status" => "pending"
        })

      "rfc3161" ->
        put_in(attestation, ["predicate", "timestamp"], %{
          "type" => "rfc3161",
          "status" => "pending"
        })

      _ ->
        attestation
    end
  end

  defp maybe_sign(attestation, opts) do
    if Keyword.get(opts, :sign, false) do
      # Sign with local key or Sigstore (stub)
      Map.put(attestation, "signatures", [
        %{
          "keyid" => "pending",
          "sig" => "pending"
        }
      ])
    else
      attestation
    end
  end
end
