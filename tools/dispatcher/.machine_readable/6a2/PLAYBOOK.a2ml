;; SPDX-License-Identifier: PMPL-1.0-or-later
;; SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
;;
;; Git Dispatcher Playbook
;; ========================

(define-module (git-dispatcher playbook)
  #:export (plays troubleshooting))

(define plays
  '(;; PLAY-001: Dry-run dispatch
    ((id . "play-001")
     (name . "Dry-run Dispatch")
     (purpose . "Validate a Reposystem plan before execution")
     (steps
      (("step" . 1)
       ("action" . "Generate plan from Reposystem")
       ("command" . "reposystem plan create --scenario baseline"))
      (("step" . 2)
       ("action" . "Export graph")
       ("command" . "reposystem export --format json > export.json"))
      (("step" . 3)
       ("action" . "Run dispatcher dry-run")
       ("command" . "git-dispatcher dry-run --plan plan.json --graph export.json")))
     (validation
      ("No destructive changes applied"
       "Audit log produced")))

    ;; PLAY-002: Dispatch with approvals
    ((id . "play-002")
     (name . "Dispatch with Approvals")
     (purpose . "Execute a plan with explicit approvals")
     (steps
      (("step" . 1)
       ("action" . "Load plan")
       ("command" . "git-dispatcher run --plan plan.json --require-approval"))
      (("step" . 2)
       ("action" . "Approve operations in order")
       ("command" . "Approve per prompt")))
     (validation
      ("All approved operations executed"
       "Audit log recorded")))))

(define troubleshooting
  '((id . "ts-001")
    (symptom . "Plan rejected")
    (causes
     ("Missing graph export"
      "Schema mismatch"
      "Invalid references"))
    (resolution
     ("Re-export graph from Reposystem"
      "Validate schema version"
      "Check plan references"))))
