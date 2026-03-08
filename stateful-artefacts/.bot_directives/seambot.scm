;; SPDX-License-Identifier: PMPL-1.0-or-later
;; SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell (hyperpolymath)
;;
;; seambot.scm — Integration testing directives for stateful-artefacts

(seambot
  (version "1.0")
  (repo "hyperpolymath/stateful-artefacts")

  (integration-tests
    (build-command "cd gnosis && stack build")
    (test-command "cd gnosis && stack test")
    (render-smoke-test "gnosis examples/STATE-production.scm /dev/null"))

  (integration-points
    (consumes
      ("hypatia" "scan findings for template data")
      ("gitbot-fleet" "bot orchestration for auto-updates"))
    (produces
      ("rendered-docs" "Static documentation for git forges"))))
