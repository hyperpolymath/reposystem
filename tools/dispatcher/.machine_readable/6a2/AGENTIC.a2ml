;; SPDX-License-Identifier: PMPL-1.0-or-later
;; SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
;;
;; Git Dispatcher Agentic Interface
;; =================================

(define-module (git-dispatcher agentic)
  #:export (agent-capabilities agent-boundaries))

(define agent-capabilities
  '((description . "How AI agents can interact with git-dispatcher")

    (read-operations
     ((operation . "dry-run")
      (description . "Simulate dispatch without making changes")
      (autonomy . "full")
      (approval-required . #f))

     ((operation . "audit")
      (description . "Inspect audit logs and outcomes")
      (autonomy . "full")
      (approval-required . #f)))

    (restricted-operations
     ((operation . "dispatch run")
      (description . "Execute repo changes")
      (autonomy . "user-initiated-only")
      (approval-required . #t)
      (confirmation-level . "explicit-per-change")))))

(define agent-boundaries
  '((doctrine . "Human approval for all mutating actions")

    (prohibited-actions
     ("Run dispatch without explicit user confirmation"
      "Auto-approve steps"
      "Bypass audit logging"))

    (encouraged-actions
     ("Validate plans for consistency"
      "Recommend safer batch sizing"
      "Summarize audit results"))))
