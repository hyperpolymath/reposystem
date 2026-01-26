;; SPDX-License-Identifier: PMPL-1.0-or-later
;; SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
;;
;; Reposystem Meta-Level Information
;; ==================================
;; Philosophy, governance, architectural decisions

(define-module (reposystem meta)
  #:export (meta-info architecture-decisions development-practices))

(define meta-info
  '((media-type . "application/meta+scheme")
    (version . "1.0")
    (project . "reposystem")))

(define architecture-decisions
  '(;; ADR-001: Railway Yard Mental Model
    ((id . "adr-001")
     (title . "Railway Yard Mental Model")
     (status . "accepted")
     (date . "2025-12-31")
     (context . "Need intuitive model for multi-repo component wiring that supports visual representation and switching between providers")
     (decision . "Adopt railway yard metaphor: repos as yards, edges as tracks, switches as points")
     (consequences
      (positive
       ("Intuitive visual representation"
        "Natural fit for switching semantics"
        "Supports contingency/fallback routing"))
      (negative
       ("May need to explain metaphor to new users"))))

    ;; ADR-002: Aspect Tagging as Orthogonal Layer
    ((id . "adr-002")
     (title . "Aspect Tagging as Orthogonal Layer")
     (status . "accepted")
     (date . "2025-12-31")
     (context . "Need to view graph through multiple lenses (security, reliability, etc.) without restructuring")
     (decision . "Implement aspects as annotations on existing graph, not separate graphs")
     (consequences
      (positive
       ("Single source of truth for structure"
        "Flip views without losing context"
        "Composable - multiple aspects per node/edge"))
      (negative
       ("More complex query model"))))

    ;; ADR-003: Scenarios as Deltas, Not Copies
    ((id . "adr-003")
     (title . "Scenarios as Deltas, Not Full Copies")
     (status . "accepted")
     (date . "2025-12-31")
     (context . "Need A/B testing of configurations without duplicating entire graph")
     (decision . "Scenarios are ChangeSets of operations applied to baseline graph")
     (consequences
      (positive
       ("Minimal storage"
        "Clear diff between scenarios"
        "Baseline remains immutable"))
      (negative
       ("Must compute derived graph on demand"))))

    ;; ADR-004: Manual-First, Guarded Automation
    ((id . "adr-004")
     (title . "Manual-First, Guarded Automation")
     (status . "accepted")
     (date . "2025-12-31")
     (context . "Auto-detection of dependencies can create invisible/unexplained edges")
     (decision . "Manual edges are truth; auto-detection only proposes with evidence")
     (consequences
      (positive
       ("Every edge is explainable"
        "User maintains control"
        "No surprise connections"))
      (negative
       ("More initial setup effort"
        "May miss some connections"))))

    ;; ADR-005: Rust Core + Rust CLI
    ((id . "adr-005")
     (title . "Rust Core with Rust CLI")
     (status . "accepted")
     (date . "2025-12-31")
     (context . "Need type-safe core logic with fast cross-platform CLI")
     (decision . "Rust for core data model/logic and CLI, keep web UI static")
     (consequences
      (positive
       ("Type safety from Rust"
        "Fast CLI from Rust"
        "No Node.js/npm dependencies"))
      (negative
       ("Single-language core limits shared browser logic"))))

    ;; ADR-006: DOT + JSON as Primary Export Formats
    ((id . "adr-006")
     (title . "DOT and JSON as Primary Export Formats")
     (status . "accepted")
     (date . "2025-12-31")
     (context . "Need interoperability with visualization tools and other systems")
     (decision . "Export to Graphviz DOT for visualization, JSON for machine consumption")
     (consequences
      (positive
       ("Wide tooling support"
        "Human-readable DOT"
        "Machine-parseable JSON"))
      (negative
       ("Must maintain two exporters"))))))

(define development-practices
  '((code-style
     (languages . (rust guile-scheme javascript css html))
     (formatter . "rustfmt for Rust, prettier for web")
     (linter . "clippy for Rust, eslint for web"))

    (security
     (supply-chain . "pin all dependencies")
     (secrets . "never commit secrets")
     (permissions . "explicit workflow permissions"))

    (testing
     (unit . "per-module tests")
     (integration . "end-to-end CLI tests")
     (property . "consider for graph invariants"))

    (versioning
     (scheme . "semver")
     (breaking-changes . "major version bump")
     (changelog . "keep-a-changelog format"))

    (documentation
     (format . "asciidoc")
     (api-docs . "generated from source")
     (examples . "in docs/examples/"))

    (branching
     (main . "stable, always green")
     (feature . "feature/* branches")
     (release . "tag-based releases"))))

(define design-rationale
  '((why-railway-yard
     "The railway yard metaphor provides intuitive understanding of how repos connect
      and how traffic (data, artifacts, control) flows between them. Switches at
      junctions make the substitution model concrete and visual.")

    (why-aspect-tagging
     "Traditional dependency graphs show structure but not meaning. Aspect tagging
      adds the 'why does this matter' layer, enabling focused views for security
      review, reliability analysis, or supply chain audit.")

    (why-scenarios-not-branches
     "Git branches are for code versions. Scenarios are for configuration variants.
      You want to compare 'what if I used my container runtime vs theirs' without
      creating git branches everywhere.")

    (why-manual-first
     "LLM-assisted detection is powerful but opaque. By requiring manual confirmation
      of all edges, we ensure the graph remains a governance tool, not a guess.")))
