;; SPDX-License-Identifier: PMPL-1.0-or-later
;; SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell (hyperpolymath)
;;
;; sustainabot.scm — Dependency update directives for stateful-artefacts

(sustainabot
  (version "1.0")
  (repo "hyperpolymath/stateful-artefacts")

  (dependency-policy
    (auto-merge-patch #t)
    (auto-merge-minor #f)
    (review-major #t))

  (package-managers
    (haskell
      (tool "stack")
      (lockfile "gnosis/stack.yaml.lock")
      (config "gnosis/stack.yaml")))

  (schedule
    (frequency "weekly")
    (day "monday")))
