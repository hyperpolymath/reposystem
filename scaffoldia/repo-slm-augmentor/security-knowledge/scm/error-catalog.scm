; SPDX-License-Identifier: MPL-2.0-or-later
; Security Error Catalog for GitHub Workflows
; Designed for Datalog reasoning and Qwen3 SLM augmentation

(define-module (security error-catalog)
  #:export (errors
            pinned-actions
            codeql-languages
            severity-levels
            get-error
            get-fix
            get-sha))

;; =============================================================================
;; Severity Definitions
;; =============================================================================

(define severity-levels
  '((critical . "Must fix immediately - blocks CI or exposes vulnerabilities")
    (high . "Should fix soon - security risk or OpenSSF compliance issue")
    (medium . "Should fix - code quality or maintainability issue")
    (low . "Nice to fix - minor improvements")))

;; =============================================================================
;; Error Catalog
;; Each error: (id category severity description auto-fixable)
;; =============================================================================

(define errors
  '(
    ;; Workflow errors
    (ERR-WF-001 workflow medium
     "Duplicate CodeQL workflows (codeql.yml AND codeql-analysis.yml)"
     #t)

    (ERR-WF-002 workflow high
     "CodeQL language matrix mismatch - scanning languages not present in repo"
     #t)

    (ERR-WF-003 workflow medium
     "Broken comprehensive-quality.yml workflow - references missing services"
     #t)

    (ERR-WF-004 workflow low
     "Mirror workflow missing SSH key secrets (GITLAB_SSH_KEY, BITBUCKET_SSH_KEY)"
     #f)

    (ERR-WF-005 workflow low
     "Datadog workflow without DATADOG_API_KEY/DATADOG_APP_KEY configured"
     #t)

    (ERR-WF-006 workflow high
     "Invalid action SHA - action tarball not found at pinned commit"
     #t)

    (ERR-WF-007 workflow medium
     "Composite action uses unpinned internal dependencies (cannot fix externally)"
     #f)

    ;; Security errors
    (ERR-SEC-001 security high
     "Unpinned GitHub Actions - using version tags (@v4) instead of SHA pins"
     #t)

    (ERR-SEC-002 security high
     "Missing workflow permissions declaration - Token-Permissions check fails"
     #t)

    (ERR-SEC-003 security medium
     "Secrets referenced without conditional guards"
     #t)

    ;; License errors
    (ERR-LIC-001 license medium
     "Missing SPDX-License-Identifier header in workflow file"
     #t)))

;; =============================================================================
;; SHA Pinning Reference (December 2025)
;; Each entry: (action version sha)
;; =============================================================================

(define pinned-actions
  '(
    ("actions/checkout" "v4.2.2"
     "11bd71901bbe5b1630ceea73d27597364c9af683")

    ("github/codeql-action/init" "v3"
     "662472033e021d55d94146f66f6058822b0b39fd")

    ("github/codeql-action/analyze" "v3"
     "662472033e021d55d94146f66f6058822b0b39fd")

    ("ossf/scorecard-action" "v2.4.0"
     "62b2cac7ed8198b15735ed49ab1e5cf35480ba46")

    ("trufflesecurity/trufflehog" "v3"
     "05cccb53bc9e13bc6d17997db5a6bcc3df44bf2f")

    ("webfactory/ssh-agent" "v0.9.1"
     "a6f90b1f127823b31d4d4a8d96047790581349bd")

    ("editorconfig-checker/action-editorconfig-checker" "main"
     "8d9ca9cf96953707b7299eaec419c6cfcd3a65ac")

    ("dtolnay/rust-toolchain" "stable"
     "6d9817901c499d6b02debbb57edb38d33daa680b")

    ("Swatinem/rust-cache" "v2"
     "ad397744b0d591a723ab90405b7247fac0e6b8db")

    ("codecov/codecov-action" "v5"
     "671740ac38dd9b0130fbe1cec585b89eea48d3de")

    ("actions/configure-pages" "v5"
     "983d7736d9b0ae728b81ab479565c72886d7745b")

    ("actions/jekyll-build-pages" "v1"
     "44a6e6beabd48582f863aeeb6cb2151cc1716697")

    ("actions/upload-pages-artifact" "v3"
     "56afc609e74202658d3ffba0e8f6dda462b719fa")

    ("actions/deploy-pages" "v4"
     "d6db90164ac5ed86f2b6aed7e0febac5b3c0c03e")

    ("ruby/setup-ruby" "v1.207.0"
     "4a9ddd6f338a97768b8006bf671dfbad383215f4")

    ("ocaml/setup-ocaml" "v3"
     "4c1df9105efb7a8b996c21e052e4fb8b64a8f2fc")

    ("softprops/action-gh-release" "v2"
     "da05d552573ad5aba039eaac05058a918a7bf631")))

;; =============================================================================
;; CodeQL Language Detection
;; Each entry: (extensions codeql-language)
;; =============================================================================

(define codeql-languages
  '(
    ((".js" ".jsx" ".ts" ".tsx" ".mjs") "javascript-typescript")
    ((".py") "python")
    ((".go") "go")
    ((".java" ".kt") "java-kotlin")
    ((".rb") "ruby")
    ((".cs") "csharp")
    ((".cpp" ".c" ".h") "cpp")
    ((".swift") "swift")))

;; Languages NOT supported by CodeQL - use 'actions' instead
(define codeql-unsupported
  '(rust ocaml haskell elixir nickel rescript))

;; =============================================================================
;; Helper Functions
;; =============================================================================

(define (get-error id)
  "Get error definition by ID"
  (assq id errors))

(define (get-sha action version)
  "Get SHA for a pinned action"
  (let ((entry (find (lambda (e)
                       (and (string=? (car e) action)
                            (string=? (cadr e) version)))
                     pinned-actions)))
    (if entry (caddr entry) #f)))

(define (auto-fixable? id)
  "Check if error is auto-fixable"
  (let ((err (get-error id)))
    (if err (list-ref err 4) #f)))

(define (high-severity-errors)
  "Get all high severity errors"
  (filter (lambda (e) (eq? (caddr e) 'high)) errors))

;; =============================================================================
;; Fix Patterns (for SLM prompting)
;; =============================================================================

(define fix-patterns
  '(
    (ERR-SEC-001
     pattern: "uses: ACTION@VERSION"
     replacement: "uses: ACTION@SHA # VERSION"
     example: "uses: actions/checkout@v4 -> uses: actions/checkout@11bd71... # v4.2.2")

    (ERR-SEC-002
     pattern: "(workflow without permissions)"
     replacement: "permissions: read-all"
     position: "after 'on:' trigger block")

    (ERR-LIC-001
     pattern: "(first line of file)"
     replacement: "# SPDX-License-Identifier: PMPL-1.0-or-later"
     position: "line 1")))
