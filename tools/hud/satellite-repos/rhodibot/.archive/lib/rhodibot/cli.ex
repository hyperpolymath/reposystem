# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

defmodule Rhodibot.CLI do
  @moduledoc """
  Command-line interface for Rhodibot.
  """

  def main(args) do
    args
    |> parse_args()
    |> run()
    |> handle_result()
  end

  defp parse_args(args) do
    Optimus.new!(
      name: "rhodibot",
      description: "RSR compliance checker and enforcer",
      version: "0.1.0",
      author: "hyperpolymath",
      subcommands: [
        check: [
          name: "check",
          about: "Check repository for RSR compliance",
          options: [
            path: [short: "-p", long: "--path", default: ".", help: "Repository path"],
            format: [short: "-f", long: "--format", default: "text", help: "Output format"],
            fail_on: [long: "--fail-on", help: "Fail if below this level"]
          ]
        ],
        fix: [
          name: "fix",
          about: "Generate missing RSR files",
          options: [
            path: [short: "-p", long: "--path", default: ".", help: "Repository path"],
            only: [long: "--only", help: "Only fix specific files"]
          ],
          flags: [
            auto: [short: "-a", long: "--auto", help: "Auto-generate without prompts"]
          ]
        ],
        badge: [
          name: "badge",
          about: "Generate compliance badge",
          options: [
            path: [short: "-p", long: "--path", default: ".", help: "Repository path"],
            format: [short: "-f", long: "--format", default: "svg", help: "Badge format"]
          ]
        ]
      ]
    )
    |> Optimus.parse!(args)
  end

  defp run({[:check], %{options: opts}}) do
    IO.puts("🦏 Checking RSR compliance...")
    {:ok, report} = Rhodibot.check(opts.path)

    case opts.format do
      "json" ->
        IO.puts(Jason.encode!(report, pretty: true))

      _ ->
        print_report(report)
    end

    # Check fail condition
    if fail_level = opts[:fail_on] do
      level_order = [:non_compliant, :bronze, :silver, :gold]
      min_index = Enum.find_index(level_order, &(&1 == String.to_atom(fail_level)))
      actual_index = Enum.find_index(level_order, &(&1 == report.level))

      if actual_index < min_index do
        {:error, :below_threshold}
      else
        :ok
      end
    else
      :ok
    end
  end

  defp run({[:fix], %{options: opts, flags: flags}}) do
    IO.puts("🦏 Fixing RSR compliance issues...")
    {:ok, result} = Rhodibot.fix(opts.path, auto: flags.auto, only: opts[:only])

    if result[:message] do
      IO.puts(result.message)
    end

    for item <- result[:fixed] || [] do
      IO.puts("  ✅ Created #{item.file}")
    end

    for item <- result[:skipped] || [] do
      IO.puts("  ⏭️  Skipped #{item}")
    end

    :ok
  end

  defp run({[:badge], %{options: opts}}) do
    badge = Rhodibot.badge(opts.path, format: String.to_atom(opts.format))
    IO.puts(badge)
    :ok
  end

  defp run({[], _}) do
    IO.puts("Run 'rhodibot --help' for usage")
    :ok
  end

  defp print_report(report) do
    IO.puts("")
    IO.puts("═══════════════════════════════════════")
    IO.puts("  RSR Compliance Report")
    IO.puts("═══════════════════════════════════════")
    IO.puts("")
    IO.puts("  Score: #{report.score}%")
    IO.puts("  Level: #{report.level |> Atom.to_string() |> String.upcase()}")
    IO.puts("  Checks: #{report.passed_checks}/#{report.total_checks} passed")
    IO.puts("")

    for {_cat, data} <- report.categories do
      IO.puts("  #{data.name}")

      for check <- data.checks do
        icon = if check.passed, do: "✅", else: "❌"
        IO.puts("    #{icon} #{check.name}")
      end

      IO.puts("")
    end
  end

  defp handle_result(:ok), do: System.halt(0)
  defp handle_result({:error, _}), do: System.halt(1)
end
