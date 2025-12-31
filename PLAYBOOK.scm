;; SPDX-License-Identifier: AGPL-3.0-or-later
;; SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
;;
;; Reposystem Playbook
;; ===================
;; Operational procedures and runbooks

(define-module (reposystem playbook)
  #:export (plays troubleshooting recipes))

(define plays
  '(;; PLAY-001: Import Your Ecosystem
    ((id . "play-001")
     (name . "Import Your Ecosystem")
     (purpose . "Get all your repos into reposystem")
     (steps
      (("step" . 1)
       ("action" . "Clone all repos to a local folder")
       ("command" . "gh repo list hyperpolymath --limit 100 --json nameWithOwner -q '.[].nameWithOwner' | xargs -I{} gh repo clone {}"))
      (("step" . 2)
       ("action" . "Run reposystem scan")
       ("command" . "reposystem scan ~/repos"))
      (("step" . 3)
       ("action" . "Verify import count")
       ("command" . "reposystem status"))
      (("step" . 4)
       ("action" . "Export initial graph")
       ("command" . "reposystem export --format dot > ecosystem.dot")))
     (validation
      ("All repos appear in graph"
       "No import errors"
       "DOT file renders correctly")))

    ;; PLAY-002: Create Logical Groups
    ((id . "play-002")
     (name . "Create Logical Groups")
     (purpose . "Organize repos into meaningful clusters")
     (steps
      (("step" . 1)
       ("action" . "List all repos")
       ("command" . "reposystem list"))
      (("step" . 2)
       ("action" . "Create groups")
       ("command" . "reposystem group create 'docs-stack' --members my-ssg,my-newsroom"))
      (("step" . 3)
       ("action" . "Verify groups")
       ("command" . "reposystem group list")))
     (validation
      ("Groups contain expected members"
       "Repos can be in multiple groups")))

    ;; PLAY-003: Tag for Security Review
    ((id . "play-003")
     (name . "Tag for Security Review")
     (purpose . "Prepare graph for security aspect analysis")
     (steps
      (("step" . 1)
       ("action" . "Tag repos with external dependencies")
       ("command" . "reposystem tag add REPO --aspect security --weight 2 --reason 'External API dependency'"))
      (("step" . 2)
       ("action" . "Tag edges crossing trust boundaries")
       ("command" . "reposystem tag add EDGE_ID --aspect security --weight 3 --polarity risk --reason 'Crosses trust boundary'"))
      (("step" . 3)
       ("action" . "View security aspect")
       ("command" . "reposystem view --aspect security"))
      (("step" . 4)
       ("action" . "Export security-focused graph")
       ("command" . "reposystem export --aspect security --format dot")))
     (validation
      ("High-weight nodes/edges visible"
       "Can flip between views")))

    ;; PLAY-004: Create Provider Switch Scenario
    ((id . "play-004")
     (name . "Create Provider Switch Scenario")
     (purpose . "Set up A/B comparison between local and ecosystem providers")
     (steps
      (("step" . 1)
       ("action" . "Define baseline scenario")
       ("command" . "reposystem scenario create baseline --description 'Default local providers'"))
      (("step" . 2)
       ("action" . "Create ecosystem scenario")
       ("command" . "reposystem scenario create ecosystem-secure --base baseline"))
      (("step" . 3)
       ("action" . "Add provider switch")
       ("command" . "reposystem scenario add-op ecosystem-secure add_edge --from proj-a --to cerro-torre --rel uses --channel runtime"))
      (("step" . 4)
       ("action" . "Compare scenarios")
       ("command" . "reposystem scenario diff baseline ecosystem-secure")))
     (validation
      ("Diff shows expected changes"
       "Rollback possible")))

    ;; PLAY-005: Weekly Ecosystem Health Check
    ((id . "play-005")
     (name . "Weekly Ecosystem Health Check")
     (purpose . "Regular review of ecosystem state")
     (schedule . "weekly")
     (steps
      (("step" . 1)
       ("action" . "Refresh repo scan")
       ("command" . "reposystem scan --update"))
      (("step" . 2)
       ("action" . "Check for orphan repos")
       ("command" . "reposystem lint --check orphans"))
      (("step" . 3)
       ("action" . "Review security aspect")
       ("command" . "reposystem view --aspect security --sort weight"))
      (("step" . 4)
       ("action" . "Export updated graph")
       ("command" . "reposystem export --all-formats"))
      (("step" . 5)
       ("action" . "Update STATE.scm")
       ("command" . "reposystem state update")))
     (validation
      ("No unresolved orphans"
       "Security view reviewed"
       "STATE.scm current")))))

(define troubleshooting
  '(;; TS-001: Import Fails for Repo
    ((id . "ts-001")
     (symptom . "Repo import fails with 'not a git repository'")
     (causes
      ("Shallow clone"
       "Corrupted .git directory"
       "Wrong path"))
     (resolution
      ("Verify path: ls -la REPO/.git"
       "If shallow: git fetch --unshallow"
       "If corrupted: re-clone")))

    ;; TS-002: Export Produces Empty DOT
    ((id . "ts-002")
     (symptom . "DOT export is empty or minimal")
     (causes
      ("No edges defined"
       "Filter too restrictive"
       "Wrong scenario selected"))
     (resolution
      ("Check edge count: reposystem stats"
       "Remove filters: reposystem export --no-filter"
       "Verify scenario: reposystem scenario current")))

    ;; TS-003: Scenario Apply Fails
    ((id . "ts-003")
     (symptom . "Scenario apply fails with validation error")
     (causes
      ("Edge references non-existent node"
       "Incompatible slot/provider"
       "Conflicting operations"))
     (resolution
      ("Validate scenario: reposystem scenario validate SCENARIO"
       "Check node existence: reposystem node exists NODE_ID"
       "Review ops: reposystem scenario show SCENARIO --ops")))))

(define recipes
  '(;; Quick one-liners
    ((name . "Count repos by forge")
     (command . "reposystem list --format json | jq 'group_by(.forge) | map({forge: .[0].forge, count: length})'"))

    ((name . "Find repos with no edges")
     (command . "reposystem lint --check orphans --format plain"))

    ((name . "Export security-critical subgraph")
     (command . "reposystem export --aspect security --min-weight 2 --format dot"))

    ((name . "Render graph to SVG")
     (command . "reposystem export --format dot | dot -Tsvg -o ecosystem.svg"))

    ((name . "Compare two scenarios visually")
     (command . "reposystem scenario diff A B --format dot | dot -Tpng -o diff.png"))))
