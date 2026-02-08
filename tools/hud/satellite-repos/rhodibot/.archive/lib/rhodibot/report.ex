# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

defmodule Rhodibot.Report do
  @moduledoc """
  Report formatting for compliance results.
  """

  @doc """
  Format a compliance report.
  """
  def format(report, opts \\ []) do
    format_type = Keyword.get(opts, :format, :text)

    case format_type do
      :text -> text_report(report)
      :json -> Jason.encode!(report, pretty: true)
      :markdown -> markdown_report(report)
    end
  end

  defp text_report(report) do
    """
    RSR Compliance Report
    =====================

    Repository: #{report.path}
    Score: #{report.score}%
    Level: #{report.level |> Atom.to_string() |> String.upcase()}
    Checks: #{report.passed_checks}/#{report.total_checks} passed

    #{format_categories(report.categories)}
    """
  end

  defp markdown_report(report) do
    """
    # RSR Compliance Report

    | Metric | Value |
    |--------|-------|
    | Repository | `#{report.path}` |
    | Score | #{report.score}% |
    | Level | **#{report.level |> Atom.to_string() |> String.upcase()}** |
    | Passed | #{report.passed_checks}/#{report.total_checks} |

    #{format_categories_md(report.categories)}
    """
  end

  defp format_categories(categories) do
    categories
    |> Enum.map(fn {_cat, data} ->
      checks =
        data.checks
        |> Enum.map(fn check ->
          icon = if check.passed, do: "[✓]", else: "[✗]"
          "  #{icon} #{check.name}"
        end)
        |> Enum.join("\n")

      "#{data.name}\n#{checks}"
    end)
    |> Enum.join("\n\n")
  end

  defp format_categories_md(categories) do
    categories
    |> Enum.map(fn {_cat, data} ->
      checks =
        data.checks
        |> Enum.map(fn check ->
          icon = if check.passed, do: ":white_check_mark:", else: ":x:"
          "- #{icon} #{check.name}"
        end)
        |> Enum.join("\n")

      "## #{data.name}\n\n#{checks}"
    end)
    |> Enum.join("\n\n")
  end
end
