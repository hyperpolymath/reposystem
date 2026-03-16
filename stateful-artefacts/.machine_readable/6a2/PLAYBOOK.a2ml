;; SPDX-License-Identifier: PMPL-1.0-or-later
;; SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell (hyperpolymath)

;;; PLAYBOOK.scm — Stateful Artefacts for Git Forges
;;; Executable plans and operational procedures

(define-module (stateful-artefacts playbook)
  #:export (playbook))

(define playbook
  '((procedures
      ((name . "hydration-manual")
       (description . "Force a manual re-render of artefacts without committing")
       (role . "developer")
       (steps . (("cd" "gnosis")
                 ("cabal" "run" "gnosis" "--" "../AI.template.djot" "../AI.djot")))
       (on-success . "Artefact updated locally")
       (on-failure . "Check Haskell compilation errors"))

      ((name . "hydration-commit")
       (description . "Standard commit workflow with automatic hydration")
       (role . "developer")
       (steps . (("git" "add" ".")
                 ("git" "commit" "-m" "MESSAGE")))
       (on-success . "Pre-commit hook triggers Gnosis automatically")
       (on-failure . "Gnosis failed - commit aborted"))

      ((name . "resolve-conflict-manual")
       (description . "Manually invoke Paxos resolution on STATE.scm")
       (role . "developer")
       (steps . (("./gnosis/paxos-resolve.sh" ".base" ".local" ".remote")))
       (on-success . "Conflict resolved by timestamp comparison")
       (on-failure . "Missing timestamps - manual merge required"))

      ((name . "audit-languages")
       (description . "Scan repository for banned languages")
       (role . "rhodibot")
       (steps . (("fd" "-e" "ts" "-e" "py" "-e" "go" ".")))
       (on-success . "No banned languages found")
       (on-failure . "Violation detected - alert maintainer"))

      ((name . "install-hook")
       (description . "Install the pre-commit hook for automatic hydration")
       (role . "developer")
       (steps . (("cp" "gnosis/pre-commit" ".git/hooks/pre-commit")
                 ("chmod" "+x" ".git/hooks/pre-commit")))
       (on-success . "Hook installed - Gnosis will run on every commit")
       (on-failure . "Check file permissions"))

      ((name . "build-gnosis")
       (description . "Compile the Gnosis engine from source")
       (role . "developer")
       (steps . (("cd" "gnosis")
                 ("cabal" "build")))
       (on-success . "Engine compiled successfully")
       (on-failure . "Check GHC and dependencies")))

    (alerts
      ((trigger . "on-failure")
       (message . "Do not push. Revert to last known good state."))

      ((trigger . "on-banned-lang")
       (message . "Fail build immediately. Notify maintainer."))

      ((trigger . "on-accessibility-fail")
       (message . "FlexiText missing alt-text. Cannot render.")))

    (contacts
      ((role . "maintainer")
       (name . "hyperpolymath")
       (method . "github-issue")))))
