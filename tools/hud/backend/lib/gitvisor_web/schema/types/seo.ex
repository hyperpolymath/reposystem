# SPDX-License-Identifier: PMPL-1.0-or-later
defmodule GitvisorWeb.Schema.Types.SEO do
  @moduledoc """
  GraphQL types for git-seo integration.

  Provides schema definitions for repository SEO scores, categories,
  recommendations, and trending analysis.
  """

  use Absinthe.Schema.Notation

  @desc "SEO category score"
  object :seo_category_score do
    field :name, non_null(:string), description: "Category name (metadata, readme, social, activity, quality)"
    field :score, non_null(:float), description: "Points earned in this category"
    field :max_score, non_null(:float), description: "Maximum possible points"
    field :percentage, non_null(:float), description: "Category score as percentage"
    field :grade, non_null(:string), description: "Letter grade (A-F)"
  end

  @desc "Complete SEO analysis report for a repository"
  object :seo_report do
    field :repository_url, non_null(:string), description: "Full repository URL"
    field :forge, non_null(:string), description: "Git forge (github, gitlab, bitbucket)"
    field :overall_score, non_null(:float), description: "Total SEO score (0-100)"
    field :status, non_null(:string), description: "Status (excellent, good, needs_improvement, critical)"
    field :grade, non_null(:string), description: "Overall letter grade (A+ to F)"
    field :categories, list_of(:seo_category_score), description: "Score breakdown by category"
    field :priority_recommendations, list_of(:string), description: "Top 3 most important recommendations"
    field :total_recommendations, non_null(:integer), description: "Total number of recommendations"
    field :analyzed_at, non_null(:datetime), description: "When this analysis was performed"
  end

  @desc "SEO score trend over time"
  object :seo_trend do
    field :current_score, non_null(:float), description: "Most recent SEO score"
    field :previous_score, :float, description: "Previous SEO score (if available)"
    field :change, non_null(:float), description: "Change from previous to current"
    field :trend_slope, non_null(:float), description: "Trend direction (positive = improving)"
    field :min_score, non_null(:float), description: "Lowest score in history"
    field :max_score, non_null(:float), description: "Highest score in history"
    field :average_score, non_null(:float), description: "Average score across all analyses"
    field :dates, list_of(:datetime), description: "Timestamps of analyses"
    field :scores, list_of(:float), description: "Historical scores"
  end

  @desc "Input for requesting SEO analysis"
  input_object :seo_analysis_input do
    field :repository_url, non_null(:string), description: "Repository URL to analyze"
    field :force_refresh, :boolean, description: "Force new analysis even if cached", default_value: false
  end
end
