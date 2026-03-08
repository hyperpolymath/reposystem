// SPDX-License-Identifier: PMPL-1.0-or-later

/**
 * SEO Widget Component
 *
 * Displays repository SEO scores with visual indicators and recommendations.
 */

type categoryScore = {
  name: string,
  score: float,
  maxScore: float,
  percentage: float,
  grade: string,
}

type seoReport = {
  repositoryUrl: string,
  overallScore: float,
  status: string,
  grade: string,
  categories: array<categoryScore>,
  priorityRecommendations: array<string>,
  totalRecommendations: int,
  analyzedAt: string,
}

type seoTrend = {
  currentScore: float,
  previousScore: option<float>,
  change: float,
  trendSlope: float,
  minScore: float,
  maxScore: float,
  averageScore: float,
  dates: array<string>,
  scores: array<float>,
}

let statusColor = status =>
  switch status {
  | "excellent" => "status-excellent"
  | "good" => "status-good"
  | "needs_improvement" => "status-needs-improvement"
  | "critical" => "status-critical"
  | _ => "status-unknown"
  }

let gradeColor = grade =>
  switch grade {
  | "A+" | "A" => "grade-a"
  | "B" | "C" => "grade-b"
  | "D" | "F" => "grade-f"
  | _ => "grade-unknown"
  }

module ScoreBar = {
  @react.component
  let make = (~category: categoryScore) => {
    let widthPercent = Float.toString(category.percentage)

    <div className="score-bar-container">
      <div className="score-bar-label">
        <span> {React.string(category.name)} </span>
        <span className={`grade ${gradeColor(category.grade)}`}>
          {React.string(category.grade)}
        </span>
      </div>
      <div className="score-bar-track">
        <div
          className={`score-bar-fill ${gradeColor(category.grade)}`}
          style={ReactDOM.Style.make(~width=`${widthPercent}%`, ())}>
          <span className="score-bar-text">
            {React.string(
              `${Float.toString(category.score)}/${Float.toString(category.maxScore)}`,
            )}
          </span>
        </div>
      </div>
    </div>
  }
}

module RecommendationList = {
  @react.component
  let make = (~recommendations: array<string>) => {
    <div className="recommendations">
      <h4> {React.string("Priority Recommendations")} </h4>
      <ul>
        {recommendations
        ->Array.map((rec, i) =>
          <li key={Int.toString(i)}> <span> {React.string("•")} </span> {React.string(rec)} </li>
        )
        ->React.array}
      </ul>
    </div>
  }
}

module TrendIndicator = {
  @react.component
  let make = (~trend: option<seoTrend>) => {
    switch trend {
    | None => React.null
    | Some(t) =>
      let changeIcon =
        t.change > 0.0 ? "↑" : t.change < 0.0 ? "↓" : "→"
      let changeClass =
        t.change > 0.0 ? "trend-up" : t.change < 0.0 ? "trend-down" : "trend-neutral"

      <div className={`trend-indicator ${changeClass}`}>
        <span className="trend-icon"> {React.string(changeIcon)} </span>
        <span className="trend-change">
          {React.string(`${Float.toString(Float.abs(t.change))} pts`)}
        </span>
        {switch t.previousScore {
        | Some(prev) =>
          <span className="trend-previous"> {React.string(`(from ${Float.toString(prev)})`)} </span>
        | None => React.null
        }}
      </div>
    }
  }
}

@react.component
let make = (~report: option<seoReport>, ~trend: option<seoTrend>, ~onAnalyze: string => unit) => {
  switch report {
  | None =>
    <div className="seo-widget empty">
      <h3> {React.string("Repository SEO")} </h3>
      <p> {React.string("No SEO data available. Analyze a repository to see its score.")} </p>
    </div>

  | Some(r) =>
    <div className="seo-widget">
      <div className="seo-header">
        <h3> {React.string("Repository SEO")} </h3>
        <button className="analyze-btn" onClick={_ => onAnalyze(r.repositoryUrl)}>
          {React.string("Refresh")}
        </button>
      </div>
      <div className={`seo-score ${statusColor(r.status)}`}>
        <div className="score-display">
          <span className="score-value"> {React.string(Float.toString(r.overallScore))} </span>
          <span className="score-max"> {React.string("/100")} </span>
        </div>
        <div className={`score-grade ${gradeColor(r.grade)}`}> {React.string(r.grade)} </div>
        <div className={`score-status ${statusColor(r.status)}`}>
          {React.string(
            switch r.status {
            | "excellent" => "Excellent"
            | "good" => "Good"
            | "needs_improvement" => "Needs Improvement"
            | "critical" => "Critical"
            | _ => r.status
            },
          )}
        </div>
      </div>
      <TrendIndicator trend />
      <div className="score-categories">
        {r.categories
        ->Array.map((cat, i) => <ScoreBar key={Int.toString(i)} category=cat />)
        ->React.array}
      </div>
      {Array.length(r.priorityRecommendations) > 0
        ? <RecommendationList recommendations={r.priorityRecommendations} />
        : React.null}
      <div className="seo-footer">
        <span className="analyzed-at">
          {React.string(`Analyzed: ${r.analyzedAt}`)}
        </span>
        {r.totalRecommendations > Array.length(r.priorityRecommendations)
          ? <span className="more-recommendations">
              {React.string(
                `+${Int.toString(r.totalRecommendations - Array.length(r.priorityRecommendations))} more recommendations`,
              )}
            </span>
          : React.null}
      </div>
    </div>
  }
}
