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
     (updated . "2025-12-31")
     (project . "reposystem")
     (repo . "github.com/hyperpolymath/reposystem"))

    (project-context
     (name . "Reposystem")
     (tagline . "Railway yard for your repository ecosystem")
     (description . "Visual wiring layer for multi-repo component management with aspect tagging and scenario comparison")
     (tech-stack . (rescript deno rust nickel guile-scheme)))

    (current-position
     (phase . "specification")
     (overall-completion . 5)
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
       (status . "not-started")
       (completion . 0))
      ((name . "graph-store")
       (status . "not-started")
       (completion . 0))
      ((name . "cli")
       (status . "not-started")
       (completion . 0))
      ((name . "dot-export")
       (status . "not-started")
       (completion . 0)))
     (working-features . ()))

    (route-to-mvp
     (milestones
      ((id . "f1")
       (name . "MVC Graph + Tagging + Export")
       (status . "in-progress")
       (items
        ((task . "Repo importer from local clones")
         (status . "pending"))
        ((task . "Graph store (JSON persistence)")
         (status . "pending"))
        ((task . "Manual edges and groups")
         (status . "pending"))
        ((task . "Manual aspect tagging")
         (status . "pending"))
        ((task . "DOT + JSON export")
         (status . "pending"))
        ((task . "Re-import fidelity test")
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
     (high
      ((id . "BLOCK-001")
       (description . "Need to decide: merge git-dispatcher into reposystem or keep separate")
       (impact . "Affects repo structure and naming")
       (proposed-resolution . "Consolidate into reposystem, archive git-dispatcher")))
     (medium . ())
     (low . ()))

    (critical-next-actions
     (immediate
      ((action . "Set up ReScript project structure in src/")
       (owner . "dev")
       (blocked-by . ()))
      ((action . "Create Rust CLI skeleton")
       (owner . "dev")
       (blocked-by . ())))
     (this-week
      ((action . "Implement local folder scanner")
       (owner . "dev"))
      ((action . "Implement graph JSON persistence")
       (owner . "dev")))
     (this-month
      ((action . "Complete f1 freeze criteria")
       (owner . "dev"))
      ((action . "Hello Yard milestone")
       (owner . "dev"))))

    (session-history
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
