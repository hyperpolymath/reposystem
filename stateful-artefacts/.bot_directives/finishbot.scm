;; SPDX-License-Identifier: PMPL-1.0-or-later
;; SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell (hyperpolymath)
;;
;; finishbot.scm — Release preparation directives for stateful-artefacts

(finishbot
  (version "1.0")
  (repo "hyperpolymath/stateful-artefacts")

  (release-policy
    (versioning "semver")
    (changelog "RELEASE-NOTES-v*.md")
    (require-passing-ci #t)
    (require-clean-scan #t))

  (pre-release-checks
    (license-compliance #t)
    (spdx-headers #t)
    (no-agpl #t)
    (topology-current #t)
    (state-scm-updated #t)))
