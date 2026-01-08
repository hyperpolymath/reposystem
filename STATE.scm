;; SPDX-License-Identifier: AGPL-3.0-or-later
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
     (updated . "2026-01-08")
     (project . "reposystem")
     (repo . "github.com/hyperpolymath/reposystem"))

    (project-context
     (name . "Reposystem")
     (tagline . "Railway yard for your repository ecosystem")
     (description . "Visual wiring layer for multi-repo component management with aspect tagging and scenario comparison")
     (tech-stack . (rust)))

    (current-position
     (phase . "implementation")
     (overall-completion . 70)
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
       (status . "in-progress")
       (completion . 80)
       (notes . "scan, export, edge, group, aspect commands working"))
      ((name . "dot-export")
       (status . "complete")
       (completion . 100)))
     (working-features
      ("Scan 400+ repositories from local clones"
       "DOT and JSON export"
       "Edge add/remove/list"
       "Group create/add/remove/delete/list/show"
       "Aspect tag/remove/list/show/filter"
       "9 unit tests passing"
       "Re-import fidelity verified")))

    (route-to-mvp
     (milestones
      ((id . "f1")
       (name . "MVC Graph + Tagging + Export")
       (status . "in-progress")
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
        ((task . "Documentation warnings")
         (status . "pending"))
        ((task . "Integration tests")
         (status . "pending"))))
      ((id . "i1")
       (name . "Seam Review: Graph invariants")
       (status . "pending")
       (items
        ((task . "Graph determinism check")
         (status . "pending"))
        ((task . "Tag provenance check")
         (status . "pending"))
        ((task . "Export fidelity check")
         (status . "pending"))))
      ((id . "f2")
       (name . "Slots/Providers Registry")
       (status . "pending"))
      ((id . "f3")
       (name . "Plan Generation + Dry-Run")
       (status . "pending"))
      ((id . "hello-yard")
       (name . "Hello Yard milestone")
       (status . "pending")
       (description . "One slot (container.runtime) end-to-end"))))

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
      ((action . "Fix 25 doc warnings")
       (owner . "dev")
       (blocked-by . ()))
      ((action . "Add integration tests for CLI commands")
       (owner . "dev")
       (blocked-by . ())))
     (this-week
      ((action . "Push to GitLab and Bitbucket mirrors")
       (owner . "dev"))
      ((action . "Complete f1 freeze criteria")
       (owner . "dev")))
     (this-month
      ((action . "Start f2 slots/providers registry")
       (owner . "dev"))
      ((action . "Hello Yard milestone")
       (owner . "dev"))))

    (session-history
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
