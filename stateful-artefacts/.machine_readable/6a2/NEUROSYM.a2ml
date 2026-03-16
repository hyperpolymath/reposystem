;; SPDX-License-Identifier: PMPL-1.0-or-later
;; SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell (hyperpolymath)

;;; NEUROSYM.scm — Stateful Artefacts for Git Forges
;;; Symbolic operation semantics and proof obligations

(define-module (stateful-artefacts neurosym)
  #:export (neurosym))

(define neurosym
  '((claims
      ;; The rendering engine guarantees these properties
      ((name . "render-deterministic")
       (type . "verified")
       (statement . "Given identical STATE.scm and AI.template.djot,
                     Gnosis always produces identical AI.djot output")
       (method . "pure-functional-implementation")
       (prover . "Gnosis.Render.render"))

      ((name . "accessibility-complete")
       (type . "verified")
       (statement . "Every visual element in output has corresponding alt-text")
       (method . "type-enforcement")
       (prover . "Gnosis.Types.FlexiText"))

      ((name . "syntax-preserving")
       (type . "verified")
       (statement . "Output is always valid Markdown/Djot syntax")
       (method . "sanitization-pass")
       (prover . "Gnosis.Render.sanitize"))

      ((name . "paxos-convergent")
       (type . "assumed")
       (statement . "All replicas eventually converge to same STATE.scm
                     given sufficient time and no network partition")
       (method . "timestamp-comparison")
       (prover . "gnosis/paxos-resolve.sh"))

      ((name . "compliance-verifiable")
       (type . "derived")
       (statement . "Language compliance status can be computed from filesystem")
       (method . "extension-scan")
       (prover . "Gnosis.Engine.Scanner [future]")))

    (proof-obligations
      ;; These must hold for the system to be correct
      ((rule . "timestamps-monotonic")
       (description . "Paxos ballot numbers must increase over time")
       (enforcement . "Editor must update last-updated on every save")
       (violation-action . "Paxos resolver falls back to manual merge"))

      ((rule . "alt-text-non-empty")
       (description . "FlexiText altText field cannot be empty string")
       (enforcement . "Haskell type: newtype AltText = AltText NonEmptyString")
       (violation-action . "Compilation fails"))

      ((rule . "template-boundary-integrity")
       (description . "(:placeholder) tags must have matching closing parens")
       (enforcement . "Parser rejects malformed tags")
       (violation-action . "Render halts with error"))

      ((rule . "no-ci-loop")
       (description . "Gnosis must never trigger itself via CI webhook")
       (enforcement . "Pre-commit hook only, no push-triggered workflows")
       (violation-action . "API rate limit breach, potential ban")))

    (semantic-operations
      ;; Formal semantics for placeholder evaluation
      ((operation . "lookup")
       (signature . "Context -> Key -> Maybe Value")
       (semantics . "Pure dictionary lookup, no side effects"))

      ((operation . "render")
       (signature . "Context -> Template -> Output")
       (semantics . "Recursive descent, replacing (:key) with lookup result"))

      ((operation . "sanitize")
       (signature . "Context -> String -> String")
       (semantics . "Context-aware character filtering"))

      ((operation . "resolve")
       (signature . "State -> State -> State")
       (semantics . "max(timestamp_a, timestamp_b) wins")))))
