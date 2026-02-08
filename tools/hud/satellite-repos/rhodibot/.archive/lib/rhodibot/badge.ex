# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

defmodule Rhodibot.Badge do
  @moduledoc """
  RSR compliance badge generation.
  """

  @colors %{
    gold: "#FFD700",
    silver: "#C0C0C0",
    bronze: "#CD7F32",
    non_compliant: "#DC3545"
  }

  @doc """
  Generate a badge for a compliance report.
  """
  def generate(report, opts \\ []) do
    format = Keyword.get(opts, :format, :svg)

    case format do
      :svg -> svg_badge(report)
      :markdown -> markdown_badge(report)
      :html -> html_badge(report)
    end
  end

  defp svg_badge(report) do
    level = report.level
    color = Map.get(@colors, level, "#666")
    label = level |> Atom.to_string() |> String.capitalize()

    """
    <svg xmlns="http://www.w3.org/2000/svg" width="110" height="20">
      <linearGradient id="b" x2="0" y2="100%">
        <stop offset="0" stop-color="#bbb" stop-opacity=".1"/>
        <stop offset="1" stop-opacity=".1"/>
      </linearGradient>
      <mask id="a">
        <rect width="110" height="20" rx="3" fill="#fff"/>
      </mask>
      <g mask="url(#a)">
        <path fill="#555" d="M0 0h43v20H0z"/>
        <path fill="#{color}" d="M43 0h67v20H43z"/>
        <path fill="url(#b)" d="M0 0h110v20H0z"/>
      </g>
      <g fill="#fff" text-anchor="middle" font-family="DejaVu Sans,Verdana,Geneva,sans-serif" font-size="11">
        <text x="21.5" y="15" fill="#010101" fill-opacity=".3">RSR</text>
        <text x="21.5" y="14">RSR</text>
        <text x="75.5" y="15" fill="#010101" fill-opacity=".3">#{label}</text>
        <text x="75.5" y="14">#{label}</text>
      </g>
    </svg>
    """
  end

  defp markdown_badge(report) do
    level = report.level |> Atom.to_string() |> String.capitalize()
    color = Map.get(@colors, report.level, "grey") |> String.trim_leading("#")

    "![RSR #{level}](https://img.shields.io/badge/RSR-#{level}-#{color})"
  end

  defp html_badge(report) do
    level = report.level |> Atom.to_string() |> String.capitalize()
    color = Map.get(@colors, report.level, "#666")

    """
    <span style="display:inline-block;padding:2px 8px;background:#{color};color:#fff;border-radius:3px;font-family:sans-serif;font-size:12px;">
      RSR #{level}
    </span>
    """
  end
end
