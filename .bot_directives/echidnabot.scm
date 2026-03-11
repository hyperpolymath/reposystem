;; SPDX-License-Identifier: PMPL-1.0-or-later
;; SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell (hyperpolymath)
;;
;; echidnabot.scm — Code quality enforcement for reposystem (Rust)
(bot-directive
  (bot "echidnabot")
  (version "1.0")
  (repo "hyperpolymath/reposystem")
  (scope "code quality, unsafe audit, and fuzzing for Rust codebase")

  (languages
    (primary "rust")
    (allowed ("rust" "bash" "guile-scheme" "ada" "rescript" "zig"))
    (banned ("python" "typescript" "go")))

  (quality
    (enforce-spdx-headers #t)
    (allowed-licenses ("PMPL-1.0-or-later" "MPL-2.0"))
    (banned-licenses ("AGPL-3.0-or-later" "AGPL-3.0")))

  (critical-patterns
    (rust-banned
      ("unsafe" . "require // SAFETY: comment")
      ("transmute" . "banned unless FFI with justification")
      ("std::mem::forget" . "potential resource leak")
      ("Box::leak" . "intentional leak must be justified")
      ("unwrap()" . "prefer expect() or proper error handling in non-test code"))
    (rust-warn
      ("todo!()" . "incomplete implementation")
      ("unimplemented!()" . "incomplete implementation")
      ("println!" . "prefer tracing macros in library code")))

  (allow ("analysis" "fuzzing" "clippy-audit" "unsafe-audit" "dependency-audit"))
  (deny ("write to core modules" "write to bindings"))
  (notes "May open findings; code changes require explicit approval"))
