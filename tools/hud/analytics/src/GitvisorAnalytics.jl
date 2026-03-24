# SPDX-License-Identifier: PMPL-1.0-or-later

"""
    GitvisorAnalytics

High-performance analytics module for Gitvisor dashboard.
Provides statistical analysis, trend detection, and visualization
for Git platform data.
"""
module GitvisorAnalytics

using DataFrames
using Dates
using Statistics
using StatsBase
using HTTP
using JSON3

export analyze_commits, analyze_issues, analyze_prs
export contribution_trends, activity_heatmap
export repository_health_score, team_velocity
export fetch_analytics_data
export load_seo_report, analyze_seo_trends, seo_score_card

# API client
const API_ENDPOINT = Ref("http://localhost:4060/api/graphql")

function set_endpoint!(url::String)
    API_ENDPOINT[] = url
end

# Data structures
struct CommitData
    sha::String
    author::String
    date::DateTime
    message::String
    additions::Int
    deletions::Int
end

struct IssueData
    number::Int
    title::String
    state::String
    created_at::DateTime
    closed_at::Union{DateTime, Nothing}
    labels::Vector{String}
    author::String
end

struct PRData
    number::Int
    title::String
    state::String
    created_at::DateTime
    merged_at::Union{DateTime, Nothing}
    additions::Int
    deletions::Int
    author::String
    reviewers::Vector{String}
end

# SEO analytics structures
struct SEOCategoryScore
    name::String
    score::Float64
    max_score::Float64
end

struct SEOReport
    repository_url::String
    forge::String
    total_score::Float64
    max_possible::Float64
    percentage::Float64
    categories::Vector{SEOCategoryScore}
    recommendations::Vector{String}
    analyzed_at::DateTime
end

# Fetch data from backend
function fetch_analytics_data(query::String, variables::Dict=Dict())
    try
        response = HTTP.post(
            API_ENDPOINT[],
            ["Content-Type" => "application/json"],
            JSON3.write(Dict("query" => query, "variables" => variables))
        )
        data = JSON3.read(String(response.body))
        return get(data, :data, nothing)
    catch e
        @warn "Failed to fetch analytics data" exception=e
        return nothing
    end
end

# Commit analysis
"""
    analyze_commits(commits::Vector{CommitData}; period=Month(1))

Analyze commit patterns over a specified period.
Returns statistics including frequency, size distribution, and author breakdown.
"""
function analyze_commits(commits::Vector{CommitData}; period=Month(1))
    isempty(commits) && return Dict()

    df = DataFrame(commits)

    # Basic statistics
    total_commits = nrow(df)
    total_additions = sum(df.additions)
    total_deletions = sum(df.deletions)

    # Author statistics
    author_counts = countmap(df.author)
    top_contributors = sort(collect(author_counts), by=x->x[2], rev=true)[1:min(10, length(author_counts))]

    # Time-based analysis
    df.date_only = Date.(df.date)
    daily_counts = combine(groupby(df, :date_only), nrow => :count)

    # Commit size distribution
    df.total_changes = df.additions .+ df.deletions
    size_stats = describe(df.total_changes)

    return Dict(
        :total_commits => total_commits,
        :total_additions => total_additions,
        :total_deletions => total_deletions,
        :net_changes => total_additions - total_deletions,
        :top_contributors => top_contributors,
        :daily_average => mean(daily_counts.count),
        :size_stats => size_stats,
        :period_start => minimum(df.date),
        :period_end => maximum(df.date)
    )
end

# Issue analysis
"""
    analyze_issues(issues::Vector{IssueData})

Analyze issue patterns including resolution time, label distribution,
and author activity.
"""
function analyze_issues(issues::Vector{IssueData})
    isempty(issues) && return Dict()

    df = DataFrame(issues)

    # State breakdown
    state_counts = countmap(df.state)

    # Resolution time for closed issues
    closed = filter(row -> row.state == "closed" && !isnothing(row.closed_at), df)
    if nrow(closed) > 0
        closed.resolution_time = Dates.value.(closed.closed_at .- closed.created_at) ./ (1000 * 60 * 60 * 24)  # days
        avg_resolution = mean(closed.resolution_time)
        median_resolution = median(closed.resolution_time)
    else
        avg_resolution = nothing
        median_resolution = nothing
    end

    # Label analysis
    all_labels = reduce(vcat, df.labels)
    label_counts = countmap(all_labels)

    # Author analysis
    author_counts = countmap(df.author)

    return Dict(
        :total_issues => nrow(df),
        :state_breakdown => state_counts,
        :avg_resolution_days => avg_resolution,
        :median_resolution_days => median_resolution,
        :top_labels => sort(collect(label_counts), by=x->x[2], rev=true)[1:min(10, length(label_counts))],
        :top_reporters => sort(collect(author_counts), by=x->x[2], rev=true)[1:min(10, length(author_counts))]
    )
end

# PR analysis
"""
    analyze_prs(prs::Vector{PRData})

Analyze pull request patterns including merge rate, review patterns,
and code churn.
"""
function analyze_prs(prs::Vector{PRData})
    isempty(prs) && return Dict()

    df = DataFrame(prs)

    # State and merge statistics
    state_counts = countmap(df.state)
    merged = filter(row -> !isnothing(row.merged_at), df)
    merge_rate = nrow(merged) / nrow(df)

    # Time to merge
    if nrow(merged) > 0
        merged.time_to_merge = Dates.value.(merged.merged_at .- merged.created_at) ./ (1000 * 60 * 60 * 24)
        avg_merge_time = mean(merged.time_to_merge)
    else
        avg_merge_time = nothing
    end

    # Code churn
    total_additions = sum(df.additions)
    total_deletions = sum(df.deletions)

    # Review patterns
    all_reviewers = reduce(vcat, df.reviewers)
    reviewer_counts = countmap(all_reviewers)

    return Dict(
        :total_prs => nrow(df),
        :state_breakdown => state_counts,
        :merge_rate => merge_rate,
        :avg_merge_time_days => avg_merge_time,
        :total_additions => total_additions,
        :total_deletions => total_deletions,
        :top_reviewers => sort(collect(reviewer_counts), by=x->x[2], rev=true)[1:min(10, length(reviewer_counts))]
    )
end

# Contribution trends
"""
    contribution_trends(commits::Vector{CommitData}; granularity=:weekly)

Calculate contribution trends over time.
Returns time series data suitable for plotting.
"""
function contribution_trends(commits::Vector{CommitData}; granularity=:weekly)
    isempty(commits) && return DataFrame()

    df = DataFrame(commits)
    df.date_only = Date.(df.date)

    # Group by time period
    if granularity == :daily
        df.period = df.date_only
    elseif granularity == :weekly
        df.period = firstdayofweek.(df.date_only)
    elseif granularity == :monthly
        df.period = firstdayofmonth.(df.date_only)
    end

    trends = combine(
        groupby(df, :period),
        nrow => :commits,
        :additions => sum => :additions,
        :deletions => sum => :deletions,
        :author => (x -> length(unique(x))) => :unique_authors
    )

    sort!(trends, :period)
    return trends
end

# Activity heatmap
"""
    activity_heatmap(commits::Vector{CommitData})

Generate data for an activity heatmap (day of week × hour of day).
"""
function activity_heatmap(commits::Vector{CommitData})
    isempty(commits) && return zeros(7, 24)

    heatmap = zeros(Int, 7, 24)  # 7 days × 24 hours

    for commit in commits
        dow = dayofweek(commit.date)  # 1 = Monday
        hour = Dates.hour(commit.date)
        heatmap[dow, hour + 1] += 1
    end

    return heatmap
end

# Repository health score
"""
    repository_health_score(commits, issues, prs; weights=nothing)

Calculate a composite health score for a repository based on
various metrics.
"""
function repository_health_score(
    commits::Vector{CommitData},
    issues::Vector{IssueData},
    prs::Vector{PRData};
    weights=Dict(
        :activity => 0.3,
        :issue_resolution => 0.25,
        :pr_velocity => 0.25,
        :contributor_diversity => 0.2
    )
)
    scores = Dict{Symbol, Float64}()

    # Activity score (commits in last 30 days)
    recent_cutoff = now() - Day(30)
    recent_commits = filter(c -> c.date > recent_cutoff, commits)
    scores[:activity] = min(1.0, length(recent_commits) / 100)  # 100 commits = perfect score

    # Issue resolution score
    issue_analysis = analyze_issues(issues)
    if !isempty(issue_analysis)
        open_issues = get(issue_analysis[:state_breakdown], "open", 0)
        closed_issues = get(issue_analysis[:state_breakdown], "closed", 0)
        total = open_issues + closed_issues
        scores[:issue_resolution] = total > 0 ? closed_issues / total : 0.5
    else
        scores[:issue_resolution] = 0.5
    end

    # PR velocity score
    pr_analysis = analyze_prs(prs)
    if !isempty(pr_analysis)
        scores[:pr_velocity] = get(pr_analysis, :merge_rate, 0.5)
    else
        scores[:pr_velocity] = 0.5
    end

    # Contributor diversity
    if !isempty(commits)
        unique_authors = length(unique(c.author for c in commits))
        scores[:contributor_diversity] = min(1.0, unique_authors / 10)  # 10+ contributors = perfect
    else
        scores[:contributor_diversity] = 0.0
    end

    # Weighted average
    total_score = sum(weights[k] * scores[k] for k in keys(weights))

    return Dict(
        :overall => total_score,
        :components => scores,
        :grade => total_score >= 0.8 ? "A" :
                  total_score >= 0.6 ? "B" :
                  total_score >= 0.4 ? "C" :
                  total_score >= 0.2 ? "D" : "F"
    )
end

# Team velocity
"""
    team_velocity(prs::Vector{PRData}; sprints=4, sprint_length=Day(14))

Calculate team velocity based on merged PRs per sprint.
"""
function team_velocity(prs::Vector{PRData}; sprints=4, sprint_length=Day(14))
    merged = filter(pr -> !isnothing(pr.merged_at), prs)
    isempty(merged) && return Dict(:velocities => Float64[], :average => 0.0)

    # Sort by merge date
    sort!(merged, by=pr -> pr.merged_at)

    # Calculate sprint boundaries
    end_date = maximum(pr.merged_at for pr in merged)
    start_date = end_date - sprints * sprint_length

    velocities = Float64[]
    for i in 1:sprints
        sprint_start = start_date + (i-1) * sprint_length
        sprint_end = sprint_start + sprint_length

        sprint_prs = filter(pr -> sprint_start <= pr.merged_at < sprint_end, merged)
        push!(velocities, length(sprint_prs))
    end

    return Dict(
        :velocities => velocities,
        :average => mean(velocities),
        :trend => length(velocities) >= 2 ? velocities[end] - velocities[1] : 0.0
    )
end

# SEO Analytics

"""
    load_seo_report(json_path::String) -> SEOReport

Load a git-seo JSON report from disk.
"""
function load_seo_report(json_path::String)::Union{SEOReport, Nothing}
    try
        data = JSON3.read(read(json_path, String))

        # Parse categories
        categories = SEOCategoryScore[]
        for cat in data[:scores][:categories]
            push!(categories, SEOCategoryScore(
                String(cat[:name]),
                Float64(cat[:score]),
                Float64(cat[:max])
            ))
        end

        # Parse date
        analyzed_at = DateTime(data[:analyzed_at][1:19], "yyyy-mm-ddTHH:MM:SS")

        return SEOReport(
            String(data[:repository][:url]),
            String(data[:repository][:forge]),
            Float64(data[:scores][:total]),
            Float64(data[:scores][:max]),
            Float64(data[:scores][:percentage]),
            categories,
            String[String(r) for r in data[:recommendations]],
            analyzed_at
        )
    catch e
        @warn "Failed to load SEO report" path=json_path exception=e
        return nothing
    end
end

"""
    analyze_seo_trends(reports::Vector{SEOReport}) -> Dict

Analyze SEO score trends over time.
Returns trend statistics and category breakdowns.
"""
function analyze_seo_trends(reports::Vector{SEOReport})
    isempty(reports) && return Dict()

    # Sort by date
    sorted = sort(reports, by=r -> r.analyzed_at)

    # Overall score trend
    scores = [r.percentage for r in sorted]
    dates = [r.analyzed_at for r in sorted]

    # Calculate trend (linear regression slope)
    n = length(scores)
    if n >= 2
        x = 1:n
        trend = (n * sum(x .* scores) - sum(x) * sum(scores)) /
                (n * sum(x .^ 2) - sum(x)^2)
    else
        trend = 0.0
    end

    # Category analysis
    category_trends = Dict{String, Vector{Float64}}()
    for report in sorted
        for cat in report.categories
            if !haskey(category_trends, cat.name)
                category_trends[cat.name] = Float64[]
            end
            push!(category_trends[cat.name],
                  (cat.score / cat.max_score) * 100.0)
        end
    end

    return Dict(
        :current_score => sorted[end].percentage,
        :previous_score => length(sorted) >= 2 ? sorted[end-1].percentage : nothing,
        :change => length(sorted) >= 2 ? sorted[end].percentage - sorted[end-1].percentage : 0.0,
        :trend_slope => trend,
        :min_score => minimum(scores),
        :max_score => maximum(scores),
        :average_score => mean(scores),
        :category_trends => category_trends,
        :dates => dates,
        :scores => scores
    )
end

"""
    seo_score_card(report::SEOReport) -> Dict

Generate a dashboard scorecard for SEO metrics.
"""
function seo_score_card(report::SEOReport)
    # Determine status based on percentage
    status = if report.percentage >= 80.0
        "excellent"
    elseif report.percentage >= 60.0
        "good"
    elseif report.percentage >= 40.0
        "needs_improvement"
    else
        "critical"
    end

    # Category breakdown with grades
    categories = Dict{String, Any}()
    for cat in report.categories
        pct = (cat.score / cat.max_score) * 100.0
        categories[cat.name] = Dict(
            :score => cat.score,
            :max => cat.max_score,
            :percentage => pct,
            :grade => if pct >= 80.0
                "A"
            elseif pct >= 70.0
                "B"
            elseif pct >= 60.0
                "C"
            elseif pct >= 50.0
                "D"
            else
                "F"
            end
        )
    end

    # Priority recommendations (top 3)
    priority_recs = report.recommendations[1:min(3, length(report.recommendations))]

    return Dict(
        :repository => report.repository_url,
        :forge => report.forge,
        :overall_score => report.percentage,
        :status => status,
        :grade => if report.percentage >= 90.0
            "A+"
        elseif report.percentage >= 80.0
            "A"
        elseif report.percentage >= 70.0
            "B"
        elseif report.percentage >= 60.0
            "C"
        else
            "F"
        end,
        :categories => categories,
        :priority_recommendations => priority_recs,
        :total_recommendations => length(report.recommendations),
        :analyzed_at => report.analyzed_at
    )
end

end # module
