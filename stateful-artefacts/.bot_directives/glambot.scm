;; SPDX-License-Identifier: PMPL-1.0-or-later
;; SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell (hyperpolymath)
;;
;; glambot.scm — Documentation formatting directives for stateful-artefacts

(glambot
  (version "1.0")
  (repo "hyperpolymath/stateful-artefacts")

  (formatting-policy
    (markup-format "markdown")
    (preferred-format "asciidoc")
    (line-length 80)
    (trailing-newline #t))

  (auto-render
    ;; Gnosis templates that glambot may trigger re-rendering for
    (templates
      ("README.template.md" "README.md"))
    (trigger-on-scm-change #t))

  (documentation-checks
    (require-topology #t)
    (require-readme #t)
    (require-security-md #t)
    (require-contributing #t)))
