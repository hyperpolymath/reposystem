# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

defmodule Rhodibot do
  @moduledoc """
  Rhodibot - RSR (Rhodium Standard Repository) enforcement bot.

  ## Quick Start

      # Check compliance
      Rhodibot.check("/path/to/repo")

      # Generate missing files
      Rhodibot.fix("/path/to/repo")

      # Get compliance badge
      Rhodibot.badge("/path/to/repo")
  """

  alias Rhodibot.{Checker, Fixer, Badge, Report}

  @doc """
  Check a repository for RSR compliance.

  Returns a detailed compliance report.
  """
  def check(path \\ ".", opts \\ []) do
    Checker.run(path, opts)
  end

  @doc """
  Fix missing RSR requirements in a repository.

  Generates missing files from templates.
  """
  def fix(path \\ ".", opts \\ []) do
    Fixer.run(path, opts)
  end

  @doc """
  Generate a compliance badge.
  """
  def badge(path \\ ".", opts \\ []) do
    {:ok, report} = check(path, opts)
    Badge.generate(report, opts)
  end

  @doc """
  Generate a human-readable report.
  """
  def report(path \\ ".", opts \\ []) do
    {:ok, result} = check(path, opts)
    Report.format(result, opts)
  end

  @doc """
  Get the compliance level for a score.
  """
  def level(score) when score == 100, do: :gold
  def level(score) when score >= 90, do: :silver
  def level(score) when score >= 75, do: :bronze
  def level(_score), do: :non_compliant
end
