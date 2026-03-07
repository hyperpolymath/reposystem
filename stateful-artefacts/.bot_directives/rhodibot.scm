;; SPDX-License-Identifier: PMPL-1.0-or-later
;; SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell (hyperpolymath)
;;
;; rhodibot.scm — Git operations directives for stateful-artefacts

(rhodibot
  (version "1.0")
  (repo "hyperpolymath/stateful-artefacts")

  (permissions
    (allowed-operations
      "branch-create"
      "branch-delete-merged"
      "pr-create"
      "pr-update"
      "commit-fix")
    (denied-operations
      "force-push"
      "branch-delete-main"
      "tag-delete"))

  (branch-policy
    (protected-branches "main")
    (auto-delete-merged #t)
    (require-pr-review #t))

  (commit-policy
    (require-spdx-header #t)
    (require-signed-commits #f)
    (author "Jonathan D.A. Jewell <jonathan.jewell@open.ac.uk>")))
