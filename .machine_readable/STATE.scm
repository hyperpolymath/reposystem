;; SPDX-License-Identifier: PMPL-1.0-or-later
;; SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
;;
;; Reposystem Project State
;; ========================
;; Machine-readable project status for agent consumption

(define-module (reposystem state)
  #:export (project-state get-completion get-blockers get-next-actions))

(define project-state
  '((metadata
     (version . "0.1.0")
     (schema-version . "1.0")
     (created . "2025-12-31")
     (updated . "2026-01-26")
     (project . "reposystem")
     (repo . "github.com/hyperpolymath/reposystem"))

    (project-context
     (name . "Reposystem")
     (tagline . "Railway yard for your repository ecosystem")
     (description . "Visual wiring layer for multi-repo component management with aspect tagging and scenario comparison")
     (tech-stack . (rust)))

    (current-position
     (phase . "implementation")
     (overall-completion . 100)
     (components
      ((name . "spec/DATA-MODEL.adoc")
       (status . "complete")
       (completion . 100))
      ((name . "spec/CONCEPTS.adoc")
       (status . "complete")
       (completion . 100))
      ((name . "ROADMAP.adoc")
       (status . "complete")
       (completion . 100))
      ((name . "core-importer")
       (status . "complete")
       (completion . 100)
       (notes . "Local clone scanner with gix, language detection"))
      ((name . "graph-store")
       (status . "complete")
       (completion . 100)
       (notes . "JSON persistence with petgraph backing"))
      ((name . "cli")
       (status . "complete")
       (completion . 100)
       (notes . "All f1+f2+f3+f4 commands: scan, export, edge, group, aspect, scenario, weak-links, view, slot, provider, binding, plan, apply"))
      ((name . "dot-export")
       (status . "complete")
       (completion . 100)
       (notes . "Includes slots/providers overlay"))
      ((name . "slots-registry")
       (status . "complete")
       (completion . 100)
       (notes . "Slot, Provider, Binding types with compatibility checking"))
      ((name . "plan-store")
       (status . "complete")
       (completion . 100)
       (notes . "Plan, PlanOp, PlanDiff types with rollback generation and risk assessment"))
      ((name . "audit-store")
       (status . "complete")
       (completion . 100)
       (notes . "AuditEntry, OpResult, ApplyResult types with JSON persistence"))
      ((name . "tui-view")
       (status . "complete")
       (completion . 100)
       (notes . "Ratatui TUI with 4 tabs, navigation, detail view"))
      ((name . "web-ui")
       (status . "complete")
       (completion . 100)
       (notes . "Static HTML/CSS/JS graph explorer with annotations and ER mode")))
     (working-features
      ("Scan 400+ repositories from local clones"
       "DOT and JSON export with slots/providers overlay"
       "Edge add/remove/list"
       "Group create/add/remove/delete/list/show"
       "Aspect tag/remove/list/show/filter"
       "Scenario create/delete/list/show/compare"
       "Weak links detection (risk annotations, SPOFs, missing evidence)"
       "Interactive TUI view with tabs and detail panels"
       "Slot create/delete/list/show"
       "Provider create/delete/list/show with compatibility checking"
       "Binding bind/unbind/list/show"
       "Plan create/list/show/diff/rollback/delete"
       "Risk assessment per plan operation"
       "Rollback plan generation"
       "Apply apply/undo/status commands"
       "Apply execution with operation-level tracking"
       "Auto-rollback on failure"
       "Health checks post-apply"
       "Audit log with full execution history"
       "Web UI prototype (layouts, annotations, ER mode, export)"
       "66 tests passing (9 unit + 4 integration + 3 hello-yard + 50 invariant)"
       "Re-import fidelity verified")))

    (route-to-mvp
     (milestones
      ((id . "f1")
       (name . "MVC Graph + Tagging + Export")
       (status . "complete")
       (items
        ((task . "Repo importer from local clones")
         (status . "complete"))
        ((task . "Graph store (JSON persistence)")
         (status . "complete"))
        ((task . "Manual edges and groups")
         (status . "complete"))
        ((task . "Manual aspect tagging")
         (status . "complete"))
        ((task . "DOT + JSON export")
         (status . "complete"))
        ((task . "Re-import fidelity test")
         (status . "complete"))
        ((task . "Scenario management")
         (status . "complete"))
        ((task . "Weak links detection")
         (status . "complete"))
        ((task . "TUI view")
         (status . "complete"))
        ((task . "Integration tests")
         (status . "complete"))))
      ((id . "i1")
       (name . "Seam Review: Graph invariants")
       (status . "complete")
       (items
        ((task . "Graph determinism check")
         (status . "complete"))
        ((task . "Tag provenance check")
         (status . "complete"))
        ((task . "Export fidelity check")
         (status . "complete"))))
      ((id . "f2")
       (name . "Slots/Providers Registry")
       (status . "complete")
       (items
        ((task . "Slot type definitions")
         (status . "complete"))
        ((task . "Provider type definitions")
         (status . "complete"))
        ((task . "SlotBinding type definitions")
         (status . "complete"))
        ((task . "SlotStore registry with persistence")
         (status . "complete"))
        ((task . "Compatibility checking (version + capabilities)")
         (status . "complete"))
        ((task . "Slot CLI commands (create/delete/list/show)")
         (status . "complete"))
        ((task . "Provider CLI commands (create/delete/list/show)")
         (status . "complete"))
        ((task . "Binding CLI commands (bind/unbind/list/show)")
         (status . "complete"))
        ((task . "Graph overlay in DOT export")
         (status . "complete"))
        ((task . "Invariant tests for f2")
         (status . "complete"))))
      ((id . "f3")
       (name . "Plan Generation + Dry-Run")
       (status . "complete")
       (items
        ((task . "Plan, PlanOp, PlanDiff types")
         (status . "complete"))
        ((task . "Plan generation from scenario")
         (status . "complete"))
        ((task . "Risk assessment per operation")
         (status . "complete"))
        ((task . "Dry-run diff generation")
         (status . "complete"))
        ((task . "Rollback plan generation")
         (status . "complete"))
        ((task . "Plan CLI commands (create/list/show/diff/rollback/delete)")
         (status . "complete"))
        ((task . "PlanStore persistence (plans.json)")
         (status . "complete"))
        ((task . "Invariant tests for f3")
         (status . "complete"))))
      ((id . "f4")
       (name . "Apply + Rollback Execution")
       (status . "complete")
       (items
        ((task . "AuditLog types (OpResult, ApplyResult, AuditEntry, AuditStore)")
         (status . "complete"))
        ((task . "Apply plan execution with operation tracking")
         (status . "complete"))
        ((task . "Rollback execution (manual undo)")
         (status . "complete"))
        ((task . "Auto-rollback on failure")
         (status . "complete"))
        ((task . "Health checks post-apply")
         (status . "complete"))
        ((task . "Apply CLI commands (apply/undo/status)")
         (status . "complete"))
        ((task . "AuditStore persistence (audit.json)")
         (status . "complete"))
        ((task . "Invariant tests for f4")
         (status . "complete"))))
      ((id . "hello-yard")
       (name . "Hello Yard milestone")
       (status . "complete")
       (description . "One slot (container.runtime) end-to-end")
       (items
        ((task . "Create hello-yard integration test")
         (status . "complete"))
        ((task . "container.runtime slot with podman, cerro-torre, docker providers")
         (status . "complete"))
        ((task . "Consumer repo bindings (webapp, api-service, worker)")
         (status . "complete"))
        ((task . "Plan → Apply → Rollback workflow validation")
         (status . "complete"))
        ((task . "Fix --iface-version argument naming to avoid clap conflict")
         (status . "complete"))
        ((task . "Flexible slot lookup in provider/binding commands")
         (status . "complete"))))))

    (blockers-and-issues
     (critical . ())
     (high . ())
     (medium
      ((id . "WARN-001")
       (description . "25 missing documentation warnings")
       (impact . "Code quality")
       (proposed-resolution . "Add doc comments to stub modules")))
     (low . ())
     (resolved
      ((id . "BLOCK-001")
       (description . "git-dispatcher merge decision")
       (resolution . "Keep separate - git-dispatcher is documentation/methodology only, not code")
       (resolved-date . "2026-01-08"))))

    (critical-next-actions
     (immediate
      ((action . "Push hello-yard changes to GitHub")
       (owner . "dev")
       (blocked-by . ())))
     (this-week
      ((action . "Push to GitLab and Bitbucket mirrors")
       (owner . "dev"))
      ((action . "Begin f5 milestone (Remote Operations)")
       (owner . "dev")))
     (this-month
      ((action . "f5 Remote Operations milestone")
       (owner . "dev"))
      ((action . "Documentation improvements")
       (owner . "dev"))))

    (session-history
     ((date . "2026-01-09")
      (accomplishments
       ("Implemented scenario create/delete/list/show/compare commands"
        "Implemented weak links detection (risk annotations, SPOFs, missing evidence)"
        "Implemented TUI view with ratatui (4 tabs, navigation, detail panels)"
        "Added 4 integration tests for CLI commands"
        "Completed f1 milestone to 100%"
        "Implemented i1 seam review with 22 invariant tests"
        "Graph determinism: repo/edge ID generation, idempotent operations"
        "Tag provenance: valid source metadata, aspect validation, weight bounds"
        "Export fidelity: JSON/DOT round-trip, empty graph handling, scenarios"
        "Completed f2 slots/providers registry milestone"
        "Slot, Provider, SlotBinding types with deterministic IDs"
        "SlotStore with JSON persistence (slots.json)"
        "Compatibility checking (version + capabilities)"
        "Slot/Provider/Binding CLI commands"
        "DOT export with slots/providers overlay (diamonds, hexagons, bindings)"
        "Completed f3 Plan Generation + Dry-Run milestone"
        "Plan, PlanOp, PlanDiff, PlanStore types"
        "Plan generation from scenarios"
        "Risk assessment per operation (Low/Medium/High/Critical)"
        "Rollback plan generation"
        "Plan CLI commands (create/list/show/diff/rollback/delete)"
        "PlanStore with JSON persistence (plans.json)"
        "Added 8 new f3 invariant tests"
        "Completed f4 Apply + Rollback Execution milestone"
        "AuditEntry, OpResult, ApplyResult, AuditStore types"
        "Apply plan execution with operation-level tracking"
        "Rollback execution for undoing applied plans"
        "Auto-rollback on failure with rollback plan generation"
        "Health checks post-apply (binding validation, version checks)"
        "Apply CLI commands (apply/undo/status)"
        "AuditStore with JSON persistence (audit.json)"
        "Added 8 new f4 invariant tests"
        "Completed hello-yard milestone - one slot end-to-end"
        "Created hello_yard.rs integration test (3 tests)"
        "container.runtime slot with podman, cerro-torre, docker providers"
        "Consumer repo bindings for webapp, api-service, worker"
        "Fixed --iface-version argument to avoid clap --version conflict"
        "Flexible slot lookup in provider/binding commands (name, suffix, exact)"
        "All 66 tests passing (9 unit + 4 integration + 3 hello-yard + 50 invariant)")))
     ((date . "2026-01-08")
      (accomplishments
       ("Implemented full scanner with gix and walkdir"
        "Implemented graph store with petgraph and JSON persistence"
        "Implemented edge add/remove/list commands"
        "Implemented group create/add/remove/delete/list/show commands"
        "Implemented aspect tag/remove/list/show/filter commands"
        "Added re-import fidelity test"
        "Resolved BLOCK-001: keep git-dispatcher separate"
        "All 9 unit tests passing"
        "Tested scan on 428 repositories")))
     ((date . "2025-12-31")
      (accomplishments
       ("Created spec/DATA-MODEL.adoc"
        "Created spec/CONCEPTS.adoc"
        "Created ROADMAP.adoc with f/i staging"
        "Defined core entity types"
        "Established railway yard mental model"))))))

;; Helper functions
(define (get-completion state)
  (assoc-ref (assoc-ref state 'current-position) 'overall-completion))

(define (get-blockers state)
  (assoc-ref state 'blockers-and-issues))

(define (get-next-actions state)
  (assoc-ref state 'critical-next-actions))
