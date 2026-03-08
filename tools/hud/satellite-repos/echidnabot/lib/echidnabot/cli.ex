# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

defmodule Echidnabot.CLI do
  @moduledoc """
  Command-line interface for Echidnabot.
  """

  def main(args) do
    args
    |> parse_args()
    |> run()
    |> handle_result()
  end

  defp parse_args(args) do
    Optimus.new!(
      name: "echidnabot",
      description: "Automated formal validation and property-based testing",
      version: Mix.Project.config()[:version],
      author: "hyperpolymath",
      about: "Validates polyglot codebases and generates attestations",
      subcommands: [
        verify: [
          name: "verify",
          about: "Run all configured verifications",
          options: [
            path: [
              value_name: "PATH",
              short: "-p",
              long: "--path",
              help: "Path to repository",
              default: "."
            ],
            lang: [
              value_name: "LANG",
              short: "-l",
              long: "--lang",
              help: "Specific language to verify",
              required: false
            ],
            output: [
              value_name: "FILE",
              short: "-o",
              long: "--output",
              help: "Output file for results",
              required: false
            ]
          ]
        ],
        attest: [
          name: "attest",
          about: "Generate attestation from verification results",
          options: [
            path: [
              value_name: "PATH",
              short: "-p",
              long: "--path",
              help: "Path to repository",
              default: "."
            ],
            output: [
              value_name: "FILE",
              short: "-o",
              long: "--output",
              help: "Output file for attestation",
              default: "attestation.json"
            ],
            sign: [
              short: "-s",
              long: "--sign",
              help: "Sign the attestation",
              required: false
            ]
          ]
        ],
        ci: [
          name: "ci",
          about: "CI mode - exit code reflects pass/fail",
          options: [
            path: [
              value_name: "PATH",
              short: "-p",
              long: "--path",
              help: "Path to repository",
              default: "."
            ]
          ]
        ]
      ]
    )
    |> Optimus.parse!(args)
  end

  defp run({[:verify], %{options: opts}}) do
    IO.puts("🦔 Echidnabot verifying #{opts.path}...")
    Echidnabot.verify(opts.path, Map.to_list(opts))
  end

  defp run({[:attest], %{options: opts}}) do
    IO.puts("🦔 Echidnabot generating attestation...")
    Echidnabot.attest(opts.path, Map.to_list(opts))
  end

  defp run({[:ci], %{options: opts}}) do
    IO.puts("🦔 Echidnabot CI mode...")
    Echidnabot.ci(opts.path)
  end

  defp run({[], _}) do
    IO.puts("Run 'echidnabot --help' for usage")
    :ok
  end

  defp handle_result(:ok) do
    IO.puts("✅ All checks passed")
    System.halt(0)
  end

  defp handle_result({:ok, %{all_passed: true} = summary}) do
    IO.puts("✅ All #{summary.total_checks} checks passed")
    System.halt(0)
  end

  defp handle_result({:ok, %{all_passed: false} = summary}) do
    IO.puts("❌ #{summary.failed}/#{summary.total_checks} checks failed")
    System.halt(1)
  end

  defp handle_result({:error, reason}) do
    IO.puts("❌ Error: #{inspect(reason)}")
    System.halt(1)
  end
end
