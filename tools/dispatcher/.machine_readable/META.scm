;; SPDX-License-Identifier: PMPL-1.0-or-later
;; SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
;;
;; Git Dispatcher Meta
;; ====================

(define-module (git-dispatcher meta)
  #:export (meta-info architecture-decisions development-practices))

(define meta-info
  '((media-type . "application/meta+scheme")
    (version . "1.0")
    (project . "git-dispatcher")))

(define architecture-decisions
  '(;; ADR-001: Dispatcher, Not Executor
    ((id . "adr-001")
     (title . "Dispatcher, Not Executor")
     (status . "accepted")
     (date . "2026-01-26")
     (context . "Need scalable operations across many repos")
     (decision . "Git Dispatcher coordinates work; execution is delegated to gitbot-fleet or local runners")
     (consequences
      (positive
       ("Separation of concerns"
        "Flexible execution backends"))
      (negative
       ("More moving parts to integrate"))))

    ;; ADR-002: Reposystem as Source of Truth
    ((id . "adr-002")
     (title . "Reposystem as Source of Truth")
     (status . "accepted")
     (date . "2026-01-26")
     (context . "Need deterministic inputs for dispatch")
     (decision . "Ingest Reposystem graph exports and scenario plans")
     (consequences
      (positive
       ("Deterministic dispatch"
        "Aligned with ecosystem graph"))
      (negative
       ("Requires contract stability"))))))

(define development-practices
  '((code-style
     (languages . (rust))
     (formatter . "rustfmt")
     (linter . "clippy"))

    (security
     (supply-chain . "pin dependencies")
     (secrets . "never commit secrets")
     (permissions . "explicit workflow permissions"))

    (documentation
     (format . "asciidoc")
     (examples . "docs/examples/"))

    (versioning
     (scheme . "semver")
     (changelog . "keep-a-changelog format"))))

(define opsm-link "OPSM link: multi-repo dispatch for OPSM rollouts.")
