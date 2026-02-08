# SPDX-License-Identifier: PMPL-1.0-or-later
defmodule GitvisorWeb.Resolvers.SEO do
  @moduledoc """
  GraphQL resolvers for SEO analytics.

  Integrates with git-seo CLI tool and Julia analytics module
  to provide comprehensive SEO metrics for repositories.
  """

  alias Gitvisor.Repo

  @doc """
  Get SEO report for a repository.

  Looks for cached git-seo JSON reports or triggers new analysis.
  """
  def get_seo_report(_parent, %{repository_url: url, force_refresh: force?}, _resolution) do
    # Check for cached report first
    cache_path = seo_cache_path(url)

    report = if force? || !File.exists?(cache_path) || cache_expired?(cache_path) do
      # Run git-seo analysis
      case run_git_seo_analysis(url) do
        {:ok, report_path} -> load_seo_report(report_path)
        {:error, reason} -> {:error, "Failed to analyze repository: #{reason}"}
      end
    else
      load_seo_report(cache_path)
    end

    case report do
      {:ok, data} -> {:ok, data}
      {:error, _} = error -> error
      nil -> {:error, "Failed to load SEO report"}
    end
  end

  @doc """
  Get SEO trend for a repository over time.
  """
  def get_seo_trend(_parent, %{repository_url: url}, _resolution) do
    # Load all historical reports for this repository
    reports_dir = seo_reports_dir(url)

    reports = if File.exists?(reports_dir) do
      reports_dir
      |> File.ls!()
      |> Enum.filter(&String.ends_with?(&1, ".json"))
      |> Enum.map(&Path.join(reports_dir, &1))
      |> Enum.map(&load_seo_report/1)
      |> Enum.filter(&(&1 != nil))
    else
      []
    end

    if Enum.empty?(reports) do
      {:error, "No historical SEO data available"}
    else
      # Call Julia analytics module to compute trends
      {:ok, compute_seo_trends(reports)}
    end
  end

  @doc """
  Trigger new SEO analysis for a repository.
  """
  def analyze_repository(_parent, %{repository_url: url}, _resolution) do
    case run_git_seo_analysis(url) do
      {:ok, report_path} ->
        case load_seo_report(report_path) do
          {:ok, report} -> {:ok, report}
          {:error, reason} -> {:error, "Failed to load analysis results: #{reason}"}
        end

      {:error, reason} ->
        {:error, "Analysis failed: #{reason}"}
    end
  end

  # Private helpers

  defp seo_cache_path(url) do
    hash = :crypto.hash(:sha256, url) |> Base.encode16(case: :lower)
    Path.join([seo_cache_dir(), "#{hash}.json"])
  end

  defp seo_reports_dir(url) do
    hash = :crypto.hash(:sha256, url) |> Base.encode16(case: :lower)
    Path.join([seo_cache_dir(), "history", hash])
  end

  defp seo_cache_dir do
    Path.join([Application.get_env(:gitvisor, :data_dir, "/tmp/gitvisor"), "seo-reports"])
  end

  defp cache_expired?(path, max_age_hours \\ 24) do
    case File.stat(path) do
      {:ok, %{mtime: mtime}} ->
        age = System.os_time(:second) - :calendar.datetime_to_gregorian_seconds(mtime) + 62_167_219_200
        age > max_age_hours * 3600

      _ ->
        true
    end
  end

  defp run_git_seo_analysis(url) do
    output_path = seo_cache_path(url)
    File.mkdir_p!(Path.dirname(output_path))

    # Archive old report to history
    if File.exists?(output_path) do
      history_dir = seo_reports_dir(url)
      File.mkdir_p!(history_dir)
      timestamp = DateTime.utc_now() |> DateTime.to_unix()
      File.cp!(output_path, Path.join(history_dir, "#{timestamp}.json"))
    end

    # Run git-seo analyze
    case System.cmd("git-seo", ["analyze", url, "--json"], stderr_to_stdout: true) do
      {output, 0} ->
        File.write!(output_path, output)
        {:ok, output_path}

      {error, _} ->
        {:error, error}
    end
  end

  defp load_seo_report(path) do
    try do
      data = File.read!(path) |> Jason.decode!(keys: :atoms)

      {:ok,
       %{
         repository_url: data.repository.url,
         forge: data.repository.forge,
         overall_score: data.scores.percentage,
         status: score_status(data.scores.percentage),
         grade: score_grade(data.scores.percentage),
         categories:
           Enum.map(data.scores.categories, fn cat ->
             pct = cat.score / cat.max * 100.0

             %{
               name: cat.name,
               score: cat.score,
               max_score: cat.max,
               percentage: pct,
               grade: score_grade(pct)
             }
           end),
         priority_recommendations: Enum.take(data.recommendations, 3),
         total_recommendations: length(data.recommendations),
         analyzed_at: parse_datetime(data.analyzed_at)
       }}
    rescue
      _ -> {:error, "Failed to parse SEO report"}
    end
  end

  defp score_status(percentage) when percentage >= 80.0, do: "excellent"
  defp score_status(percentage) when percentage >= 60.0, do: "good"
  defp score_status(percentage) when percentage >= 40.0, do: "needs_improvement"
  defp score_status(_), do: "critical"

  defp score_grade(percentage) when percentage >= 90.0, do: "A+"
  defp score_grade(percentage) when percentage >= 80.0, do: "A"
  defp score_grade(percentage) when percentage >= 70.0, do: "B"
  defp score_grade(percentage) when percentage >= 60.0, do: "C"
  defp score_grade(percentage) when percentage >= 50.0, do: "D"
  defp score_grade(_), do: "F"

  defp parse_datetime(datetime_str) do
    case DateTime.from_iso8601(datetime_str) do
      {:ok, dt, _} -> dt
      _ -> DateTime.utc_now()
    end
  end

  defp compute_seo_trends(reports) do
    # Simplified trend computation
    # In production, call Julia analytics module via Port
    scores = Enum.map(reports, fn {:ok, r} -> r.overall_score end)
    dates = Enum.map(reports, fn {:ok, r} -> r.analyzed_at end)

    %{
      current_score: List.last(scores),
      previous_score: if(length(scores) >= 2, do: Enum.at(scores, -2), else: nil),
      change: if(length(scores) >= 2, do: List.last(scores) - Enum.at(scores, -2), else: 0.0),
      trend_slope: 0.0,
      # Placeholder
      min_score: Enum.min(scores),
      max_score: Enum.max(scores),
      average_score: Enum.sum(scores) / length(scores),
      dates: dates,
      scores: scores
    }
  end
end
