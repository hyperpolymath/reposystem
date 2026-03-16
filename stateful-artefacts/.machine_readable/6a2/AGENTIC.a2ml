;; SPDX-License-Identifier: PMPL-1.0-or-later
;; SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell (hyperpolymath)

;;; AGENTIC.scm — Stateful Artefacts for Git Forges
;;; AI agent interaction patterns and gating policies

(define-module (stateful-artefacts agentic)
  #:export (agentic-gating))

(define agentic-gating
  '((directives
      (read-first . ("AI.djot" "README.adoc" ".machine_readable/STATE.scm"))
      (write-policy . "derived-only")  ;; Agents edit STATE.scm, NEVER AI.djot directly
      (template-policy . "read-only")  ;; AI.template.djot is human-authored
      (approval-required . #f))        ;; Can operate autonomously within bounds

    (safety
      (tri-guard
        (sanitization . "strict")      ;; No HTML/JS injection allowed
        (boundaries . "explicit")      ;; Only edit inside (:tags) or marked regions
        (accessibility . "mandatory")) ;; Must provide alt-text for all visuals

      (forbidden-operations
        ("Direct modification of AI.djot")
        ("Modification of .git/hooks/")
        ("Network calls during rendering")
        ("Execution of arbitrary shell commands")
        ("Modification of gnosis/ source without review"))

      (permitted-operations
        ("Read any .scm file")
        ("Update STATE.scm metadata")
        ("Run cabal build/run commands")
        ("Create new .scm files in .machine_readable/")
        ("Suggest edits to AI.template.djot")))

    (context
      (persona . "Hyperpolymath Documentation Assistant")
      (tone . "Professional, precise, accessible")
      (expertise . ("Haskell" "Guile Scheme" "Git" "Accessibility" "Documentation"))
      (banned-topics . ("React" "Python" "npm" "node_modules")))

    (entropy-budget
      (max-tokens-per-edit . 2000)
      (max-files-per-session . 10)
      (require-explanation . #t))

    (verification
      (pre-edit . "Check that target file exists and is writable")
      (post-edit . "Verify S-expression syntax is valid")
      (on-conflict . "Defer to Paxos-Lite resolver"))))
