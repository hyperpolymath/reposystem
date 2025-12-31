;; SPDX-License-Identifier: AGPL-3.0-or-later
;; SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
;;
;; Reposystem Neurosymbolic Integration
;; =====================================
;; Patterns for combining neural (LLM) and symbolic (graph) reasoning

(define-module (reposystem neurosym)
  #:export (integration-model boundaries verification))

(define integration-model
  '((philosophy . "LLM helps design the rule, never is the rule")

    (layers
     ;; Layer 1: Symbolic Graph (ground truth)
     ((layer . "symbolic")
      (role . "source of truth")
      (components . ("repos" "edges" "groups" "aspects" "scenarios"))
      (properties
       ("Deterministic"
        "Verifiable"
        "Auditable"
        "Reversible"))
      (mutations . "Only through explicit operations"))

     ;; Layer 2: Neural Analysis (proposals)
     ((layer . "neural")
      (role . "pattern recognition and proposal")
      (capabilities
       ("Detect likely dependencies from code"
        "Suggest aspect tags from context"
        "Identify similar patterns across repos"
        "Natural language query interface"
        "Explain graph in human terms"))
      (properties
       ("Probabilistic"
        "Context-dependent"
        "Explainable (with effort)"))
      (outputs . "Proposals, never direct mutations"))

     ;; Layer 3: Verification Bridge
     ((layer . "verification")
      (role . "validate neural proposals before symbolic commit")
      (mechanisms
       ("Evidence requirement for proposals"
        "Confidence thresholds"
        "Human-in-the-loop confirmation"
        "Consistency checks against graph"))
      (properties
       ("All proposals must pass"
        "Failed proposals logged for review"))))

    (data-flow
     ;; Neural → Symbolic (controlled)
     ((direction . "neural-to-symbolic")
      (pattern . "propose-verify-commit")
      (steps
       (("step" . 1) ("action" . "Neural generates proposal"))
       (("step" . 2) ("action" . "Verification checks evidence"))
       (("step" . 3) ("action" . "Human confirms"))
       (("step" . 4) ("action" . "Symbolic graph updated"))))

     ;; Symbolic → Neural (free)
     ((direction . "symbolic-to-neural")
      (pattern . "read-analyze-explain")
      (description . "Neural can freely read graph for analysis/explanation")))))

(define boundaries
  '((what-neural-can-do
     ;; Analysis and explanation
     ("Query graph state"
      "Explain relationships in natural language"
      "Identify patterns across repos"
      "Suggest potential connections"
      "Highlight anomalies or weak links"
      "Compare scenarios in prose"
      "Generate documentation from graph"))

    (what-neural-cannot-do
     ;; Direct mutations
     ("Create edges without evidence and confirmation"
      "Delete nodes or edges"
      "Apply scenarios"
      "Modify aspect weights authoritatively"
      "Bypass verification layer"
      "Claim certainty about inferred connections"))

    (confidence-thresholds
     ;; When neural proposals can proceed to human review
     ((threshold . 0.9)
      (action . "Auto-propose to user with evidence"))
     ((threshold . 0.7)
      (action . "Propose with explicit uncertainty warning"))
     ((threshold . 0.5)
      (action . "Suggest as possibility, require extra confirmation"))
     ((threshold . "<0.5")
      (action . "Log for analysis but do not propose")))))

(define verification
  '((evidence-validation
     (required-for . ("edge creation" "aspect tagging" "provider assignment"))
     (evidence-types
      ((type . "file-reference")
       (validation . "File must exist at path")
       (confidence-boost . 0.2))
      ((type . "code-analysis")
       (validation . "AST parse confirms dependency")
       (confidence-boost . 0.3))
      ((type . "config-presence")
       (validation . "Config file contains reference")
       (confidence-boost . 0.25))
      ((type . "user-assertion")
       (validation . "User explicitly confirmed")
       (confidence-boost . 1.0))))

    (consistency-checks
     ;; Before committing neural proposals
     ((check . "node-exists")
      (description . "All referenced nodes must exist in graph")
      (failure-action . "reject proposal"))
     ((check . "no-duplicate-edge")
      (description . "Edge must not already exist")
      (failure-action . "warn and skip"))
     ((check . "slot-compatibility")
      (description . "Provider must match slot interface")
      (failure-action . "reject with explanation"))
     ((check . "acyclicity-optional")
      (description . "Check for cycles if requested")
      (failure-action . "warn but allow")))

    (audit-trail
     (log-format . "structured-json")
     (logged-events
      ("proposal generated"
       "verification passed/failed"
       "user confirmation requested"
       "user response"
       "commit executed"
       "rollback executed"))
     (retention . "indefinite"))))

(define query-patterns
  '((natural-language-queries
     ;; Examples of neural query capabilities
     ((query . "What are my container runtime options?")
      (interpretation . "List providers for slot:container.runtime")
      (graph-operation . "(filter providers (= slot 'container.runtime'))"))

     ((query . "What depends on cerro-torre?")
      (interpretation . "Find edges where cerro-torre is target")
      (graph-operation . "(filter edges (= to 'repo:cerro-torre'))"))

     ((query . "What's the security risk in my docs stack?")
      (interpretation . "Filter group:docs-stack by aspect:security, sort by weight")
      (graph-operation . "(-> (group-members 'docs-stack') (filter-by-aspect 'security') (sort-by-weight))"))

     ((query . "Compare local vs ecosystem for this project")
      (interpretation . "Generate scenario diff")
      (graph-operation . "(scenario-diff 'baseline' 'ecosystem-provision')")))

    (explanation-patterns
     ;; How neural explains graph state
     ((pattern . "edge-explanation")
      (template . "{{from}} uses {{to}} for {{channel}} because {{evidence.excerpt}}"))

     ((pattern . "aspect-summary")
      (template . "The {{aspect}} view shows {{count}} high-risk items, primarily {{top-3-nodes}}"))

     ((pattern . "scenario-comparison")
      (template . "Switching from {{scenario-a}} to {{scenario-b}} would change {{change-count}} edges, mainly affecting {{affected-groups}}")))))

(define hybrid-reasoning
  '((pattern . "symbolic-grounded-neural")
   (description . "Neural reasoning grounded in symbolic graph facts")

   (example-workflow
    (("context" . "User asks: 'Is my container setup secure?'")
     ("steps"
      (("step" . 1)
       ("actor" . "neural")
       ("action" . "Parse query into graph operations"))
      (("step" . 2)
       ("actor" . "symbolic")
       ("action" . "Execute: find all container.runtime edges"))
      (("step" . 3)
       ("actor" . "symbolic")
       ("action" . "Execute: get security aspects for those edges"))
      (("step" . 4)
       ("actor" . "neural")
       ("action" . "Synthesize findings into natural language"))
      (("step" . 5)
       ("actor" . "neural")
       ("action" . "Suggest improvements with evidence"))
      (("step" . 6)
       ("actor" . "human")
       ("action" . "Review and confirm/reject suggestions")))))))
