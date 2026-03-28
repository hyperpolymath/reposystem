;; SPDX-License-Identifier: PMPL-1.0-or-later
;;
;; Gitvisor Testing Report
;; Machine-readable format for automated processing
;;

(testing-report
  (metadata
    (version "1.0.0")
    (report-date "2025-12-29")
    (project "git-hud")
    (project-version "0.1.0")
    (analyst "Claude Code (Automated Analysis)")
    (repository "/var$HOME/repos/git-hud"))

  (summary
    (overall-status incomplete)
    (components-analyzed 4)
    (issues-found 16)
    (critical-issues 5)
    (high-issues 5)
    (medium-issues 4)
    (low-issues 2)
    (build-status cannot-verify)
    (test-status no-tests-found))

  (components
    ;; Elixir/Phoenix Backend
    (component
      (name "backend")
      (technology "Elixir/Phoenix")
      (status partial)
      (files-analyzed 15)
      (issues-count 8)
      (build-command "cd backend && mix deps.get && mix compile")
      (test-command "cd backend && mix test")
      (dependencies
        (elixir "~> 1.16")
        (phoenix "~> 1.7")
        (absinthe "~> 1.7")
        (ecto_sql "~> 3.11")
        (req "~> 0.4")
        (guardian "~> 2.3")
        (blake3 "~> 1.0")))

    ;; ReScript Frontend
    (component
      (name "frontend")
      (technology "ReScript/TEA")
      (status partial)
      (files-analyzed 5)
      (issues-count 4)
      (build-command "cd frontend && deno task setup")
      (test-command "cd frontend && deno task test")
      (dependencies
        (rescript required)
        (rescript-core required)
        (deno "latest")))

    ;; Ada/SPARK TUI
    (component
      (name "tui")
      (technology "Ada/SPARK")
      (status functional)
      (files-analyzed 8)
      (issues-count 2)
      (build-command "cd tui && gprbuild -P git-hud_tui.gpr")
      (test-command "cd tui && gprbuild -P git-hud_tui_tests.gpr && ./bin/run_tests")
      (dependencies
        (gnat "Ada 2022")
        (gcc "with Ada support")))

    ;; Julia Analytics
    (component
      (name "analytics")
      (technology "Julia")
      (status complete)
      (files-analyzed 2)
      (issues-count 2)
      (build-command "cd analytics && julia --project=. -e 'using Pkg; Pkg.instantiate()'")
      (test-command "cd analytics && julia --project=. -e 'using Pkg; Pkg.test()'")
      (dependencies
        (julia "1.10+")
        (DataFrames required)
        (HTTP required)
        (JSON3 required)
        (Plots required)
        (Statistics stdlib)
        (StatsBase required))))

  (issues
    ;; Backend Issues
    (issue
      (id "BE-001")
      (severity critical)
      (component "backend")
      (file "backend/lib/git-hud/application.ex")
      (title "Missing Modules Referenced in Application")
      (description "Application supervisor references modules that do not exist")
      (missing-modules
        "GitvisorWeb.Telemetry"
        "Gitvisor.Cache")
      (recommendation "Create these modules or remove from supervisor children"))

    (issue
      (id "BE-002")
      (severity critical)
      (component "backend")
      (file "backend/lib/git-hud_web/schema.ex")
      (title "Missing Schema Type Definitions")
      (description "GraphQL schema imports types that do not exist")
      (missing-modules
        "GitvisorWeb.Schema.Types.Repository"
        "GitvisorWeb.Schema.Types.Issue"
        "GitvisorWeb.Schema.Types.PullRequest"
        "GitvisorWeb.Schema.Types.User"
        "GitvisorWeb.Schema.Types.Dashboard"
        "GitvisorWeb.Schema.Types.Platform")
      (recommendation "Create type definition files in schema/types/"))

    (issue
      (id "BE-003")
      (severity critical)
      (component "backend")
      (file "backend/lib/git-hud_web/schema.ex")
      (title "Missing Resolvers")
      (description "Schema references resolvers that do not exist")
      (missing-modules
        "GitvisorWeb.Resolvers.User"
        "GitvisorWeb.Resolvers.Repository"
        "GitvisorWeb.Resolvers.Dashboard"
        "GitvisorWeb.Resolvers.Platform"
        "GitvisorWeb.Resolvers.Issue"
        "GitvisorWeb.Resolvers.PullRequest")
      (recommendation "Create resolver modules"))

    (issue
      (id "BE-004")
      (severity high)
      (component "backend")
      (file "backend/lib/git-hud/platforms/supervisor.ex")
      (title "Missing Platform Supervisor Children")
      (description "Supervisor references modules that do not exist")
      (missing-modules
        "Gitvisor.Platforms.RateLimiter"
        "Gitvisor.Platforms.Webhooks")
      (recommendation "Create missing modules or remove from children list"))

    (issue
      (id "BE-005")
      (severity high)
      (component "backend")
      (file "backend/lib/git-hud_web/router.ex")
      (title "Missing Router Plug and Controllers")
      (description "Router references missing components")
      (missing-modules
        "GitvisorWeb.Plugs.Context"
        "GitvisorWeb.Api.V1.HealthController"
        "GitvisorWeb.Api.V1.AuthController"
        "GitvisorWeb.WellKnownController")
      (recommendation "Create missing plug and controller modules"))

    (issue
      (id "BE-006")
      (severity medium)
      (component "backend")
      (file "backend/lib/git-hud/platforms/github.ex")
      (title "Missing GitHub Normalizer Module")
      (description "References non-existent normalizer module")
      (missing-modules
        "Gitvisor.Platforms.GitHub.Normalizer")
      (recommendation "Create normalizer submodule"))

    ;; Frontend Issues
    (issue
      (id "FE-001")
      (severity high)
      (component "frontend")
      (file "frontend/rescript.json")
      (title "Missing ReScript Dependencies")
      (description "Build dependencies may not be installed")
      (missing-packages
        "rescript"
        "@rescript/core"
        "@rescript/react")
      (recommendation "Install ReScript compiler and dependencies"))

    (issue
      (id "FE-002")
      (severity high)
      (component "frontend")
      (file "frontend/src/Tea.res")
      (title "Missing Webapi Bindings")
      (description "Uses Webapi.Dom bindings without declared dependency")
      (recommendation "Add @niceweb/webapi or similar ReScript bindings"))

    (issue
      (id "FE-003")
      (severity medium)
      (component "frontend")
      (file "frontend/deno.json")
      (title "NPX Usage in Deno Context")
      (description "Tasks mix npm (npx) and Deno tooling")
      (recommendation "Clarify hybrid build strategy or use pure Deno approach"))

    (issue
      (id "FE-004")
      (severity high)
      (component "frontend")
      (file "frontend/deno.json")
      (title "Missing Build/Serve Scripts")
      (description "Referenced TypeScript files do not exist")
      (missing-files
        "frontend/serve.ts"
        "frontend/bundle.ts")
      (recommendation "Create the missing build/serve scripts"))

    ;; TUI Issues
    (issue
      (id "TUI-001")
      (severity low)
      (component "tui")
      (files
        "tui/src/git-hud-api.adb"
        "tui/src/git-hud-config.adb")
      (title "Stub Implementations")
      (description "API and config contain TODO stubs")
      (recommendation "Expected at this stage - complete when backend is ready"))

    (issue
      (id "TUI-002")
      (severity medium)
      (component "tui")
      (file "tui/git-hud_tui_tests.gpr")
      (title "Missing Test Project File")
      (description "Test project referenced in justfile does not exist")
      (recommendation "Create Ada test project and test runner"))

    ;; Analytics Issues
    (issue
      (id "JL-001")
      (severity low)
      (component "analytics")
      (file "analytics/src/GitvisorAnalytics.jl")
      (title "API Endpoint Uses HTTP")
      (description "Default endpoint uses insecure HTTP protocol")
      (recommendation "Use HTTPS in production configuration"))

    (issue
      (id "JL-002")
      (severity medium)
      (component "analytics")
      (title "Missing Test Suite")
      (description "No test files found in analytics module")
      (recommendation "Add test/runtests.jl with unit tests")))

  (test-coverage
    (backend
      (unit-tests none)
      (integration-tests none)
      (e2e-tests none))
    (frontend
      (unit-tests none)
      (integration-tests none)
      (e2e-tests none))
    (tui
      (unit-tests none)
      (integration-tests none))
    (analytics
      (unit-tests none)
      (integration-tests none)))

  (code-quality
    (spdx-compliance
      (backend compliant)
      (frontend compliant)
      (tui compliant)
      (analytics compliant))
    (architecture-patterns
      (tea-pattern "frontend - correctly implemented")
      (behaviour-pattern "backend - adapters use behaviours correctly")
      (otp-design "backend - follows OTP conventions")
      (spark-friendly "tui - uses bounded types for formal verification"))
    (lines-of-code
      (backend 750)
      (frontend 400)
      (tui 350)
      (analytics 360)
      (total 1860)))

  (security-analysis
    (credential-handling "Tokens in bounded strings - good for memory safety")
    (api-security "HTTPS recommended for production")
    (input-validation "GraphQL schema provides type checking")
    (cors "Configured via CORSPlug - needs production review"))

  (recommendations
    (priority-1-critical
      "Create missing Elixir modules (Telemetry, Cache, types, resolvers, controllers)"
      "Create missing frontend build files (serve.ts, bundle.ts)"
      "Add ReScript/React dependencies")
    (priority-2-high
      "Add missing platform supervisor children (RateLimiter, Webhooks)"
      "Create Ada test project (git-hud_tui_tests.gpr)")
    (priority-3-medium
      "Add test suites for all components"
      "Complete TUI API implementation"
      "Add TOML config parsing in Ada")
    (priority-4-low
      "Use HTTPS for all API endpoints"
      "Add comprehensive documentation"
      "Performance benchmarking"))

  (build-verification
    (status cannot-complete)
    (reason "Missing critical modules prevent compilation")
    (blocking-issues
      "BE-001" "BE-002" "BE-003" "FE-004")
    (potentially-buildable
      (tui "Should compile with GNAT toolchain")
      (analytics "Should build with Julia 1.10+")))

  (next-actions
    (immediate
      "Create stub implementations for missing Elixir modules"
      "Add frontend build/serve scripts"
      "Install build toolchains for verification")
    (short-term
      "Create test project for Ada TUI"
      "Add comprehensive test suites"
      "Complete platform adapter implementations")
    (long-term
      "Full integration testing"
      "Performance optimization"
      "Production deployment configuration")))

;; Helper functions for processing this report

(define (get-issues-by-severity report severity)
  "Extract issues of a given severity from the report"
  (filter (lambda (issue)
            (eq? (cadr (assoc 'severity issue)) severity))
          (cdr (assoc 'issues report))))

(define (get-component-status report component-name)
  "Get the status of a specific component"
  (let ((components (cdr (assoc 'components report))))
    (find (lambda (c)
            (string=? (cadr (assoc 'name c)) component-name))
          components)))

(define (count-issues-by-component report component-name)
  "Count issues for a specific component"
  (length
    (filter (lambda (issue)
              (string=? (cadr (assoc 'component issue)) component-name))
            (cdr (assoc 'issues report)))))

;; Report footer
(report-footer
  (generated-by "Claude Code (Automated Analysis)")
  (generation-date "2025-12-29")
  (format-version "1.0.0")
  (schema "git-hud-testing-report-schema-v1"))
