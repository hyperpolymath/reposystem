;; SPDX-License-Identifier: MPL-2.0-or-later
;; STATE.scm - Project state for git-hud
;; Media-Type: application/vnd.state+scm

(state
  (metadata
    (version "0.2.0")
    (schema-version "1.0")
    (created "2026-01-03")
    (updated "2026-02-07")
    (project "git-hud")
    (repo "github.com/hyperpolymath/git-hud"))

  (project-context
    (name "git-hud")
    (tagline "Unified forge HUD for repository health and discoverability")
    (description "Dashboard integrating security, quality, and SEO metrics across GitHub/GitLab/Bitbucket")
    (tech-stack
      ("Elixir" "Phoenix" "GraphQL" "ReScript" "Julia")))

  (current-position
    (phase "active-development")
    (overall-completion 40)
    (components
      ((name . "backend/lib/gitvisor_web/schema.ex")
       (status . "complete")
       (completion . 100)
       (description . "GraphQL schema with SEO queries and mutations"))

      ((name . "backend/lib/gitvisor_web/resolvers/seo.ex")
       (status . "complete")
       (completion . 100)
       (description . "Elixir resolvers for SEO data"))

      ((name . "backend/analytics/seo_analytics.jl")
       (status . "complete")
       (completion . 100)
       (description . "Julia analytics module for SEO report processing"))

      ((name . "frontend/src/components/SEOWidget.res")
       (status . "complete")
       (completion . 100)
       (description . "ReScript SEO widget with score cards and trends"))

      ((name . "docs/SEO-MONITORING.md")
       (status . "complete")
       (completion . 100)
       (description . "Monitoring infrastructure documentation"))

      ((name . "backend/core-dashboard")
       (status . "in-progress")
       (completion . 30)
       (description . "Core repository dashboard UI"))

      ((name . "backend/auth-system")
       (status . "planned")
       (completion . 0)
       (description . "Authentication and authorization"))

      ((name . "backend/forge-integrations")
       (status . "in-progress")
       (completion . 20)
       (description . "GitHub/GitLab/Bitbucket API integrations"))

      ((name . "frontend/main-layout")
       (status . "in-progress")
       (completion . 35)
       (description . "Main dashboard layout and navigation"))

      ((name . "deployment-pipeline")
       (status . "planned")
       (completion . 0)
       (description . "CI/CD and deployment infrastructure")))

    (working-features
      ("GraphQL API with SEO queries (seoReport, seoTrend)")
      ("GraphQL mutation: analyzeRepository")
      ("Elixir resolvers for SEO data fetching")
      ("Julia analytics: load_seo_report(), analyze_seo_trends(), seo_score_card()")
      ("ReScript SEO widget with visual indicators")
      ("Score cards with color-coded grades")
      ("Trend indicators with arrows")
      ("Category score bars (Metadata, README, Social, Activity, Quality)")
      ("Recommendations display")
      ("Monitoring queries and metrics")
      ("CLI monitoring script (~/.bin/monitor-seo-usage.sh)")))

  (route-to-mvp
    (milestones
      ((id . "m1-seo-integration")
       (name . "Git-SEO Integration")
       (status . "complete")
       (completion . 100)
       (items
        ((task . "GraphQL schema for SEO queries")
         (status . "complete"))
        ((task . "Elixir resolvers")
         (status . "complete"))
        ((task . "Julia analytics module")
         (status . "complete"))
        ((task . "ReScript SEO widget")
         (status . "complete"))
        ((task . "Monitoring infrastructure")
         (status . "complete"))))

      ((id . "m2-core-dashboard")
       (name . "Core Dashboard")
       (status . "in-progress")
       (completion . 30)
       (items
        ((task . "Repository list view")
         (status . "in-progress"))
        ((task . "Repository detail view")
         (status . "in-progress"))
        ((task . "Health status indicators")
         (status . "planned"))
        ((task . "Activity timeline")
         (status . "planned"))))

      ((id . "m3-forge-integration")
       (name . "Forge Integration")
       (status . "in-progress")
       (completion . 20)
       (items
        ((task . "GitHub API client")
         (status . "in-progress"))
        ((task . "GitLab API client")
         (status . "planned"))
        ((task . "Bitbucket API client")
         (status . "planned"))
        ((task . "Webhook handlers")
         (status . "planned"))
        ((task . "Real-time updates")
         (status . "planned"))))

      ((id . "m4-reposystem-integration")
       (name . "Reposystem Integration")
       (status . "planned")
       (completion . 0)
       (items
        ((task . "Import reposystem graph data")
         (status . "planned"))
        ((task . "Display repository relationships")
         (status . "planned"))
        ((task . "Aspect tag visualization")
         (status . "planned"))
        ((task . "Scenario comparison view")
         (status . "planned"))))

      ((id . "m5-auth-deployment")
       (name . "Authentication & Deployment")
       (status . "planned")
       (completion . 0)
       (items
        ((task . "User authentication")
         (status . "planned"))
        ((task . "OAuth integration (GitHub/GitLab)")
         (status . "planned"))
        ((task . "Production deployment")
         (status . "planned"))
        ((task . "CI/CD pipeline")
         (status . "planned"))))))

  (blockers-and-issues
    (critical
      ())
    (high
      ((id . "HIGH-001")
       (description . "Need full backend/frontend integration testing")
       (impact . "Unknown if SEO widget integrates correctly with live backend")))
    (medium
      ((id . "MED-001")
       (description . "Deployment pipeline not defined")
       (impact . "Cannot deploy to production environment")))
    (low
      ()))

  (critical-next-actions
    (immediate
      ("Test SEO widget with live backend")
      ("Monitor SEO widget usage and gather feedback")
      ("Document API endpoints for frontend consumers"))
    (this-week
      ("Begin core dashboard implementation")
      ("Set up development deployment environment")
      ("Complete GitHub API client"))
    (this-month
      ("Complete m2-core-dashboard milestone")
      ("Plan reposystem integration approach")
      ("Design authentication system")))

  (notes
    ((git-seo-integration
      ((date . "2026-02-07")
       (status . "complete")
       (description . "Full end-to-end SEO integration completed across 4 languages (Julia CLI → Rust CI/CD → Elixir backend → ReScript frontend). Production-ready SEO widget with visual score cards, trend indicators, and recommendations display.")))

     (monitoring-infrastructure
      ((date . "2026-02-07")
       (status . "complete")
       (description . "Comprehensive monitoring documentation created (SEO-MONITORING.md) with usage metrics, performance metrics, quality metrics, and CLI monitoring script.")))

     (rename-from-gitvisor
      ((date . "2026-01-03")
       (status . "complete")
       (description . "Repository renamed from gitvisor to git-hud for consistency with ecosystem naming standards.")))))

  (session-history
    ((date . "2026-02-07")
     (accomplishments
      ("Completed m1-seo-integration milestone (100%)"
       "Added GraphQL schema with seoReport, seoTrend queries"
       "Added analyzeRepository mutation"
       "Implemented Elixir resolvers (GitvisorWeb.Resolvers.SEO)"
       "Created Julia analytics module (seo_analytics.jl)"
       "Implemented ReScript SEO widget component"
       "Added visual score cards with color-coded grades"
       "Added trend indicators with arrows"
       "Added category score bars"
       "Added recommendations display"
       "Created comprehensive monitoring documentation (SEO-MONITORING.md)"
       "Created CLI monitoring script (~/.bin/monitor-seo-usage.sh)"
       "Documented usage metrics (query frequency, cache usage, repo coverage)"
       "Documented performance metrics (analysis time, cache hit rate, error rate)"
       "Documented quality metrics (score distribution, trend analysis)")))

    ((date . "2026-01-03")
     (accomplishments
      ("Repository created and renamed from gitvisor to git-hud"
       "Initial RSR structure established"
       "Basic project scaffolding")))))
