;; SPDX-License-Identifier: PMPL-1.0-or-later
;; AGENTIC.scm - AI agent interaction patterns for recon-silly-ation

(define agentic-config
  `((version . "1.0.0")
    (claude-code
      ((model . "claude-opus-4-6")
       (tools . ("read" "edit" "write" "bash" "grep" "glob"))
       (permissions . "read-all")
       (session-protocol . "read AI.a2ml first, then SCM files")))
    (gitbot-fleet
      ((rhodibot . ((role . "RSR compliance") (auto-fix . #t)))
       (echidnabot . ((role . "security scanning") (auto-fix . #f)))
       (sustainabot . ((role . "dependency updates") (auto-fix . #t)))
       (glambot . ((role . "documentation quality") (auto-fix . #f)))
       (seambot . ((role . "SEAM protocol validation") (auto-fix . #f)))
       (finishbot . ((role . "completion tracking") (auto-fix . #f)))))
    (patterns
      ((code-review . "thorough")
       (refactoring . "conservative")
       (testing . "comprehensive")
       (commit-style . "conventional-commits")))
    (language-constraints
      ((allowed . ("rescript" "rust" "haskell" "javascript" "bash" "guile-scheme"))
       (banned . ("typescript" "go" "python" "java" "kotlin"))))
    (runtime-constraints
      ((runtime . "deno")
       (package-manager . "deno")
       (container-runtime . "podman")
       (base-images . "cgr.dev/chainguard/wolfi-base")))))
