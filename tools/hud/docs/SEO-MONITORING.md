# SEO Widget Monitoring Guide

Monitor SEO widget usage, performance, and user feedback in the git-hud dashboard.

## Metrics to Track

### Usage Metrics
- **Query frequency**: How often users request SEO reports
- **Repository coverage**: Number of unique repos analyzed
- **Refresh rate**: How often users force-refresh reports
- **Trend queries**: Frequency of historical trend requests

### Performance Metrics
- **Analysis time**: Time to complete git-seo CLI analysis
- **Cache hit rate**: Percentage of requests served from cache
- **Error rate**: Failed analyses (API limits, network issues, etc.)
- **Report age**: Average age of cached reports

### Quality Metrics
- **Average scores**: Overall SEO score distribution
- **Common issues**: Most frequent recommendations
- **Score trends**: Improvement/decline over time
- **Category breakdowns**: Which categories need most work

## Monitoring Queries

### GraphQL Introspection

```graphql
# Monitor SEO query usage
query MonitorSEOUsage {
  __type(name: "Query") {
    fields {
      name
      description
      args {
        name
        type {
          name
        }
      }
    }
  }
}
```

### Get Recent SEO Reports

```graphql
query GetRecentReports {
  # Add to schema: recent SEO reports query
  recentSEOReports(limit: 10) {
    repositoryUrl
    overallScore
    status
    analyzedAt
  }
}
```

### Track Score Distribution

```graphql
query ScoreDistribution {
  # Add to schema: aggregated statistics
  seoStatistics {
    totalReports
    averageScore
    scoreDistribution {
      excellent
      good
      needsImprovement
      critical
    }
  }
}
```

## Backend Logging

### Elixir Logger Configuration

Add to `backend/config/config.exs`:

```elixir
config :logger,
  level: :info,
  compile_time_purge_matching: [
    [level_lower_than: :info]
  ]

# SEO-specific logging
config :gitvisor, :seo_logging,
  log_queries: true,
  log_cache_hits: true,
  log_analysis_time: true,
  log_errors: true
```

### Log SEO Events

Update `backend/lib/gitvisor_web/resolvers/seo.ex`:

```elixir
require Logger

def get_seo_report(_parent, %{repository_url: url, force_refresh: force?}, _resolution) do
  Logger.info("[SEO] Query: #{url}, force_refresh: #{force?}")
  start_time = System.monotonic_time(:millisecond)

  result = # ... existing logic ...

  elapsed = System.monotonic_time(:millisecond) - start_time
  Logger.info("[SEO] Query completed in #{elapsed}ms, cache_hit: #{!force?}")

  result
end
```

## Database Tracking (Future)

Consider adding a `seo_query_logs` table:

```elixir
create table(:seo_query_logs) do
  add :repository_url, :string, null: false
  add :score, :float
  add :status, :string
  add :cache_hit, :boolean, default: false
  add :analysis_time_ms, :integer
  add :error, :text

  timestamps()
end

create index(:seo_query_logs, [:repository_url])
create index(:seo_query_logs, [:inserted_at])
```

## CLI Monitoring Script

Create `~/bin/monitor-seo-usage.sh`:

```bash
#!/bin/bash
# Monitor git-hud SEO report cache

CACHE_DIR="/var/lib/gitvisor/seo-reports"

echo "=== Git-HUD SEO Monitoring ==="
echo

# Count cached reports
total_reports=$(find "$CACHE_DIR" -name "*.json" -type f | wc -l)
echo "Total cached reports: $total_reports"

# Recent reports (last 24h)
recent=$(find "$CACHE_DIR" -name "*.json" -type f -mtime -1 | wc -l)
echo "Reports updated in last 24h: $recent"

# Old reports (>7 days)
old=$(find "$CACHE_DIR" -name "*.json" -type f -mtime +7 | wc -l)
echo "Stale reports (>7 days): $old"

# Average score
echo
echo "=== Score Distribution ==="
for json in "$CACHE_DIR"/*.json; do
  jq -r '.scores.percentage' "$json" 2>/dev/null
done | awk '{
  sum += $1
  if ($1 >= 80) excellent++
  else if ($1 >= 60) good++
  else if ($1 >= 40) needs_improvement++
  else critical++
  count++
}
END {
  if (count > 0) {
    printf "Average score: %.1f/100\n", sum/count
    printf "Excellent (80+): %d (%.0f%%)\n", excellent, (excellent/count)*100
    printf "Good (60-79): %d (%.0f%%)\n", good, (good/count)*100
    printf "Needs Improvement (40-59): %d (%.0f%%)\n", needs_improvement, (needs_improvement/count)*100
    printf "Critical (<40): %d (%.0f%%)\n", critical, (critical/count)*100
  }
}'
```

Make executable:
```bash
chmod +x ~/bin/monitor-seo-usage.sh
```

## Feedback Collection

### User Feedback Widget

Add to `frontend/src/SEOWidget.res`:

```rescript
module FeedbackButton = {
  @react.component
  let make = (~repositoryUrl: string) => {
    <button
      className="feedback-btn"
      onClick={_ => {
        // Open feedback modal or redirect to feedback form
        Console.log("Feedback for: " ++ repositoryUrl)
      }}>
      {React.string("📝 Report Issue")}
    </button>
  }
}
```

### GitHub Issue Template

Create `.github/ISSUE_TEMPLATE/seo-feedback.yml`:

```yaml
name: SEO Widget Feedback
description: Report issues or suggest improvements for the SEO dashboard widget
labels: ["seo", "feedback"]
body:
  - type: input
    id: repository_url
    attributes:
      label: Repository URL
      description: URL of the repository you analyzed
      placeholder: https://github.com/user/repo
    validations:
      required: true

  - type: input
    id: reported_score
    attributes:
      label: Reported Score
      description: SEO score shown in dashboard
      placeholder: "78.5"

  - type: textarea
    id: issue
    attributes:
      label: Issue or Suggestion
      description: Describe the problem or improvement
    validations:
      required: true

  - type: dropdown
    id: category
    attributes:
      label: Category
      options:
        - Incorrect score
        - Missing recommendations
        - UI/UX issue
        - Performance issue
        - Feature request
    validations:
      required: true
```

## Alerts and Notifications

### Set up alerts for:
1. **High error rate** (>10% failed analyses)
2. **Stale cache** (>50% reports older than 7 days)
3. **API rate limits** (approaching GitHub API limit)
4. **Low scores** (>30% repos with critical scores)

### Example alert script (`~/bin/seo-alert-check.sh`):

```bash
#!/bin/bash
# Check for SEO issues and alert

ERROR_THRESHOLD=0.10  # 10%
STALE_THRESHOLD=0.50  # 50%

# Check error rate from logs
error_rate=$(journalctl -u gitvisor --since "24 hours ago" | \
  grep "\[SEO\]" | \
  awk '/error/{err++} END{print err/NR}')

if (( $(echo "$error_rate > $ERROR_THRESHOLD" | bc -l) )); then
  echo "ALERT: High SEO error rate: $error_rate"
fi

# Check stale cache
total=$(find /var/lib/gitvisor/seo-reports -name "*.json" | wc -l)
stale=$(find /var/lib/gitvisor/seo-reports -name "*.json" -mtime +7 | wc -l)
stale_rate=$(echo "scale=2; $stale/$total" | bc)

if (( $(echo "$stale_rate > $STALE_THRESHOLD" | bc -l) )); then
  echo "ALERT: High stale cache rate: $stale_rate"
fi
```

## Dashboard Analytics (Future Enhancement)

Add analytics tracking to frontend:

```rescript
// Track widget interactions
let trackSEOWidgetView = (repositoryUrl: string) => {
  // Send to analytics service
  Analytics.track("seo_widget_viewed", {
    "repository_url": repositoryUrl,
    "timestamp": Date.now(),
  })
}

let trackSEORefresh = (repositoryUrl: string) => {
  Analytics.track("seo_refresh_clicked", {
    "repository_url": repositoryUrl,
    "timestamp": Date.now(),
  })
}
```

## Regular Review Schedule

1. **Daily**: Check error logs, cache status
2. **Weekly**: Review score distribution, common recommendations
3. **Monthly**: Analyze trends, gather user feedback, plan improvements

## Useful Commands

```bash
# Watch SEO logs live
journalctl -u gitvisor -f | grep "\[SEO\]"

# Count cache hits vs misses
grep "\[SEO\]" /var/log/gitvisor.log | \
  grep "cache_hit" | \
  awk '{if($0~"true") hits++; else misses++} END{print "Hits:", hits, "Misses:", misses}'

# Find slowest analyses
grep "\[SEO\] Query completed" /var/log/gitvisor.log | \
  sed 's/.*in \([0-9]*\)ms.*/\1/' | \
  sort -n | tail -10

# Most analyzed repositories
find /var/lib/gitvisor/seo-reports/history -type d | \
  xargs -I {} sh -c 'ls {} | wc -l' | \
  sort -rn | head -10
```

## Next Steps

1. Implement database tracking for query logs
2. Add real-time dashboard analytics
3. Create automated weekly reports
4. Set up Grafana/Prometheus integration
5. Build admin panel for SEO statistics
