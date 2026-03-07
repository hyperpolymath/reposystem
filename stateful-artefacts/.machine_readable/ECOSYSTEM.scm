;; SPDX-License-Identifier: PMPL-1.0-or-later
;; SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell (hyperpolymath)

;;; ECOSYSTEM.scm — Stateful Artefacts for Git Forges
;;; Position in ecosystem and relationships to other projects

(define-module (stateful-artefacts ecosystem)
  #:export (ecosystem))

(define ecosystem
  '((version . "1.0")
    (name . "stateful-artefacts-for-gitforges")
    (type . "infrastructure")
    (purpose . "Transform static documentation into living, self-aware artefacts
                that reflect project state in real-time")

    (position-in-ecosystem
      (org . "hyperpolymath")
      (constellation . "tools")
      (role . "documentation-infrastructure")
      (layer . "meta-tooling"))

    (related-projects
      ((name . "meta-scm")
       (relationship . "specification-source")
       (description . "Provides META.scm format specification"))

      ((name . "state.scm")
       (relationship . "specification-source")
       (description . "Provides STATE.scm format specification"))

      ((name . "ecosystem.scm")
       (relationship . "specification-source")
       (description . "Provides ECOSYSTEM.scm format specification"))

      ((name . "playbook-scm")
       (relationship . "specification-source")
       (description . "Provides PLAYBOOK.scm format specification"))

      ((name . "agentic-scm")
       (relationship . "specification-source")
       (description . "Provides AGENTIC.scm format specification"))

      ((name . "neurosym-scm")
       (relationship . "specification-source")
       (description . "Provides NEUROSYM.scm format specification"))

      ((name . "robot-repo-bot")
       (relationship . "potential-consumer")
       (description . "Could use Gnosis for automated repo documentation"))

      ((name . "git-hud")
       (relationship . "sibling-standard")
       (description . "Git repository supervision and health monitoring")))

    (what-this-is
      ("A Haskell-based rendering engine called Gnosis")
      ("A template syntax using (:placeholder) tags")
      ("Guile Scheme metadata files as the source of truth")
      ("Paxos-lite conflict resolution for concurrent edits")
      ("Tri-Guard safety system for accessibility")
      ("Pre-commit hooks for automatic hydration")
      ("GitHub/GitLab/Codeberg compliant output"))

    (what-this-is-not
      ("A web server or API")
      ("A replacement for CI/CD")
      ("A CMS or wiki system")
      ("A JavaScript framework")
      ("A real-time collaboration tool"))

    (integration
      (git-forges . ("github" "gitlab" "codeberg" "sourcehut"))
      (ci-cd . "local-only")  ;; Follows "No CI Loop" treaty
      (package-manager . "guix")
      (build-tool . "cabal"))))
