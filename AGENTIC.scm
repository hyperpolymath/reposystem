;; SPDX-License-Identifier: AGPL-3.0-or-later
;; SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
;;
;; Reposystem Agentic Interface
;; ============================
;; Patterns for AI agent interaction with reposystem

(define-module (reposystem agentic)
  #:export (agent-capabilities agent-boundaries agent-workflows))

(define agent-capabilities
  '((description . "How AI agents can interact with reposystem")

    (read-operations
     ;; Agents can freely perform these
     ((operation . "scan")
      (description . "Import/refresh repos from local folder")
      (autonomy . "full")
      (approval-required . #f))

     ((operation . "list")
      (description . "List repos, groups, edges, scenarios")
      (autonomy . "full")
      (approval-required . #f))

     ((operation . "view")
      (description . "View graph with aspect filters")
      (autonomy . "full")
      (approval-required . #f))

     ((operation . "export")
      (description . "Export graph to DOT/JSON")
      (autonomy . "full")
      (approval-required . #f))

     ((operation . "lint")
      (description . "Check for graph issues")
      (autonomy . "full")
      (approval-required . #f))

     ((operation . "scenario diff")
      (description . "Compare two scenarios")
      (autonomy . "full")
      (approval-required . #f)))

    (propose-operations
     ;; Agents can propose, user must approve
     ((operation . "edge create")
      (description . "Create edge between nodes")
      (autonomy . "propose-only")
      (approval-required . #t)
      (proposal-format . "Show evidence, ask user to confirm"))

     ((operation . "tag add")
      (description . "Add aspect tag to node/edge")
      (autonomy . "propose-only")
      (approval-required . #t)
      (proposal-format . "Show reasoning, ask user to confirm"))

     ((operation . "group create")
      (description . "Create logical group")
      (autonomy . "propose-only")
      (approval-required . #t))

     ((operation . "scenario create")
      (description . "Create new scenario")
      (autonomy . "propose-only")
      (approval-required . #t)))

    (restricted-operations
     ;; Agents must never perform without explicit user request
     ((operation . "scenario apply")
      (description . "Apply scenario changes to repos")
      (autonomy . "user-initiated-only")
      (approval-required . #t)
      (confirmation-level . "explicit-per-change"))

     ((operation . "edge delete")
      (description . "Remove edge from graph")
      (autonomy . "user-initiated-only")
      (approval-required . #t))

     ((operation . "node delete")
      (description . "Remove repo from graph")
      (autonomy . "user-initiated-only")
      (approval-required . #t)))))

(define agent-boundaries
  '((doctrine . "Manual-first, guarded automation")

    (core-principles
     ((principle . "Truth from user, not inference")
      (description . "Agents propose, humans confirm. No silent mutations."))

     ((principle . "Evidence-backed proposals")
      (description . "Every agent proposal must include why and evidence."))

     ((principle . "Reversibility preserved")
      (description . "Agents must never take actions that can't be undone."))

     ((principle . "No hidden channels")
      (description . "Agents must not create connections not visible in graph.")))

    (prohibited-actions
     ("Modify repos without explicit user request"
      "Create edges without showing evidence"
      "Apply scenarios automatically"
      "Delete nodes/edges without confirmation"
      "Bypass aspect tagging requirements"))

    (encouraged-actions
     ("Propose edges with file-based evidence"
      "Suggest aspect tags with reasoning"
      "Identify potential weak links"
      "Generate visualizations"
      "Export for external review"
      "Compare scenarios and explain differences"))))

(define agent-workflows
  '(;; Workflow: Ecosystem Discovery
    ((id . "wf-discovery")
     (name . "Ecosystem Discovery")
     (trigger . "User asks to map their ecosystem")
     (steps
      (("step" . 1)
       ("action" . "Scan local repos folder")
       ("autonomy" . "full"))
      (("step" . 2)
       ("action" . "Analyze for potential connections")
       ("autonomy" . "full"))
      (("step" . 3)
       ("action" . "Propose edges with evidence")
       ("autonomy" . "propose-only")
       ("user-interaction" . "Show each proposal, await confirmation"))
      (("step" . 4)
       ("action" . "Suggest groupings")
       ("autonomy" . "propose-only"))
      (("step" . 5)
       ("action" . "Export initial graph")
       ("autonomy" . "full"))))

    ;; Workflow: Security Audit Prep
    ((id . "wf-security-audit")
     (name . "Security Audit Preparation")
     (trigger . "User asks to prepare for security review")
     (steps
      (("step" . 1)
       ("action" . "Scan for external dependencies")
       ("autonomy" . "full"))
      (("step" . 2)
       ("action" . "Identify trust boundaries")
       ("autonomy" . "full"))
      (("step" . 3)
       ("action" . "Propose security tags with evidence")
       ("autonomy" . "propose-only")
       ("user-interaction" . "Show each proposed tag with risk level"))
      (("step" . 4)
       ("action" . "Generate security-focused graph")
       ("autonomy" . "full"))
      (("step" . 5)
       ("action" . "Highlight weak links")
       ("autonomy" . "full"))))

    ;; Workflow: Provider Comparison
    ((id . "wf-provider-compare")
     (name . "Provider Comparison")
     (trigger . "User asks to compare provider options")
     (steps
      (("step" . 1)
       ("action" . "Identify relevant slot")
       ("autonomy" . "full"))
      (("step" . 2)
       ("action" . "List available providers")
       ("autonomy" . "full"))
      (("step" . 3)
       ("action" . "Create comparison scenarios")
       ("autonomy" . "propose-only")
       ("user-interaction" . "Confirm scenario creation"))
      (("step" . 4)
       ("action" . "Generate diff between scenarios")
       ("autonomy" . "full"))
      (("step" . 5)
       ("action" . "Present comparison with aspect analysis")
       ("autonomy" . "full"))))))

(define evidence-requirements
  '((for-edges
     (required-fields . ("type" "ref" "confidence"))
     (evidence-types
      ((type . "file")
       (description . "Reference to file showing dependency")
       (example . '((type . "file") (ref . "package.json") (excerpt . "\"cerro-torre\": \"^1.0\"") (confidence . 0.9))))
      ((type . "config")
       (description . "Configuration file reference")
       (example . '((type . "config") (ref . ".github/workflows/ci.yml") (excerpt . "uses: cerro-torre") (confidence . 0.8))))
      ((type . "import")
       (description . "Code import statement")
       (example . '((type . "import") (ref . "src/main.rs") (excerpt . "use cerro_torre::*") (confidence . 0.95))))
      ((type . "manual")
       (description . "User-provided knowledge")
       (example . '((type . "manual") (ref . "user-input") (confidence . 1.0))))))

    (for-tags
     (required-fields . ("reason" "source"))
     (source-types
      ((mode . "manual") (rule_id . #f) (who . "user"))
      ((mode . "inferred") (rule_id . "RULE_ID") (evidence . "..."))))))
