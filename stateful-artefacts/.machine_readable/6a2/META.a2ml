;; SPDX-License-Identifier: PMPL-1.0-or-later
;; SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell (hyperpolymath)

;;; META.scm — Stateful Artefacts for Git Forges
;;; Architecture decisions and development practices

(define-module (stateful-artefacts meta)
  #:export (architecture-decisions development-practices))

;;; Architecture Decisions Record (ADR)

(define architecture-decisions
  '((adr-001
     (title . "Dual-Layer Architecture: Guile Data + Haskell Engine")
     (status . "accepted")
     (date . "2026-01-16")
     (context . "Need a system that can transform template documents with
                 dynamic placeholders into rendered output, while maintaining
                 type safety and accessibility guarantees.")
     (decision . "Use Guile Scheme for the data layer (.scm metadata files)
                  and Haskell for the rendering engine (Gnosis). Guile provides
                  homoiconic S-expressions for easy data storage; Haskell
                  provides parser combinators and type safety for transformation.")
     (consequences . ("S-expressions are human-readable and VCS-friendly"
                      "Haskell guarantees no runtime errors in rendering"
                      "Two languages require both ecosystems installed"
                      "Natural fit with existing Hyperpolymath standards")))

    (adr-002
     (title . "Paxos-Lite Conflict Resolution")
     (status . "accepted")
     (date . "2026-01-16")
     (context . "When two users edit STATE.scm simultaneously and merge,
                 Git's default textual merge creates conflict markers that
                 break the S-expression parser.")
     (decision . "Implement a custom Git merge driver that compares Unix
                  timestamps in the metadata.last-updated field. The newer
                  timestamp wins automatically (Last Writer Wins semantics).")
     (consequences . ("No manual conflict resolution for STATE.scm"
                      "Potential silent data loss if timestamps collide"
                      "Requires all editors to update timestamp on save"
                      "Git history remains clean and readable")))

    (adr-003
     (title . "Tri-Guard Safety System")
     (status . "accepted")
     (date . "2026-01-16")
     (context . "Dynamic document rendering can introduce instability
                 (broken formatting), ambiguity (unknown what is dynamic),
                 and accessibility failures (screen readers see garbage).")
     (decision . "Implement three guards: (1) Sanitizer - prevents syntax-breaking
                  characters in context-specific locations; (2) Explicit Boundaries -
                  HTML comments mark mutable regions; (3) FlexiText - all visual
                  elements require accompanying alt-text.")
     (consequences . ("Documents pass WCAG accessibility standards"
                      "Git diffs clearly show bot-touched regions"
                      "Slightly more verbose data structures"
                      "Compile-time guarantees via Haskell types")))

    (adr-004
     (title . "Static Hydration Rendering Strategy")
     (status . "accepted")
     (date . "2026-01-16")
     (context . "Git forges (GitHub, Codeberg) strip JavaScript and custom CSS
                 from rendered markdown for security. We cannot use AJAX or
                 dynamic client-side rendering.")
     (decision . "Use 'Static Hydration': render templates to plain Markdown/Djot
                  at commit time via git pre-commit hook. Output uses Shields.io
                  badges for color/visuals within forge constraints.")
     (consequences . ("Works on all Git forges without modification"
                      "No network calls during rendering (offline-safe)"
                      "Follows the 'No CI Loop' treaty (local hooks only)"
                      "Dynamic feel achieved through commit-time updates")))))

;;; Development Practices

(define development-practices
  '((code-style
      (indentation . "2 spaces")
      (naming . "kebab-case for Scheme, camelCase for Haskell")
      (comments . "Document 'why', not 'what'"))

    (security
      (hashing . "SHA256+")
      (network . "HTTPS only")
      (secrets . "Never hardcoded")
      (dependencies . "SHA-pinned"))

    (testing
      (strategy . "Property-based for Haskell, REPL-driven for Scheme")
      (coverage . "Focus on parser edge cases"))

    (versioning
      (scheme . "SemVer 2.0")
      (branching . "trunk-based"))

    (documentation
      (primary-format . "AsciiDoc")
      (api-docs . "Haddock for Haskell"))))
