;; SPDX-License-Identifier: PMPL-1.0-or-later
;; SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
;;
;; Reposystem Ecosystem Position
;; =============================
;; Where this project sits in the hyperpolymath ecosystem

(ecosystem
 (version . "1.0")
 (name . "reposystem")
 (type . "infrastructure-tool")
 (purpose . "Multi-repository component wiring with aspect tagging and scenario management")

 (position-in-ecosystem
  (layer . "orchestration")
  (role . "source-of-truth dependency graph")
 (consumers . ("git-hud" "git-seo" "git-dispatcher"))
  (providers . ()))

 (related-projects
  ;; Core constellation - tightly coupled
  ((name . "git-hud")
   (relationship . "sibling-standard")
   (integration . "consumes reposystem graph for forge HUD")
   (direction . "reposystem → git-hud"))

  ((name . "git-seo")
   (relationship . "sibling-standard")
   (integration . "consumes graph for discoverability artifacts")
   (direction . "reposystem → git-seo"))

  ((name . "git-dispatcher")
   (relationship . "sibling-standard")
   (integration . "dispatches repo actions driven by graph scenarios")
   (direction . "reposystem → git-dispatcher"))

  ;; Standards this enforces
  ((name . "rhodium-standard-repositories")
   (relationship . "standard-consumer")
   (integration . "reposystem helps audit RSR compliance")
   (direction . "RSR → reposystem"))

  ;; Existing related work
  ((name . "gitbot-fleet")
   (relationship . "sibling-tools")
   (integration . "automation fleet that can consume dispatch plans")
   (direction . "reposystem → gitbot-fleet"))

  ((name . "scaffoldia")
   (relationship . "sibling-tools")
   (integration . "scaffold generator informed by graph metadata")
   (direction . "reposystem → scaffoldia"))

  ((name . "stateful-artefacts-for-gitforges")
   (relationship . "sibling-tools")
   (integration . "metadata artifacts that can be wired into graph outputs")
   (direction . "reposystem ↔ stateful-artefacts-for-gitforges"))

  ;; Potential consumers
  ((name . "robot-repo-cleaner")
   (relationship . "potential-consumer")
   (integration . "could use graph for batch operations")
   (direction . "reposystem → robot-repo-cleaner"))

  ((name . "git-eco-bot")
   (relationship . "potential-consumer")
   (integration . "could use graph for ecosystem health")
   (direction . "reposystem → git-eco-bot"))

  ;; Infrastructure providers this might wire
  ((name . "cerro-torre")
   (relationship . "potential-provider")
   (integration . "container runtime slot")
   (slot . "container.runtime"))

  ((name . "cadre-router")
   (relationship . "potential-provider")
   (integration . "router slot")
   (slot . "router.core")))

 (what-this-is
  ("Visual wiring layer for multi-repo ecosystems"
   "Component substitution with reversibility"
   "Aspect tagging for orthogonal views"
   "Scenario comparison for A/B testing"
   "Railway yard mental model for repo management"
   "Source-of-truth for dependency graphs"))

 (what-this-is-not
  ("Not a CI/CD system (that's what slots wire to)"
   "Not a package manager (uses existing package info)"
   "Not a forge replacement (git-hud handles that)"
   "Not an auto-magical rewriter (manual-first doctrine)"
   "Not enterprise architecture bloatware"))

 (integration-points
 ((point . "graph-export")
  (format . "JSON + DOT")
  (consumers . ("git-hud" "git-seo" "external-tools")))

  ((point . "slot-registry")
   (format . "Nickel schema")
   (purpose . "Define what can be swapped"))

  ((point . "scenario-api")
   (format . "CLI + future HTTP")
   (purpose . "Compare and apply scenarios")))

 (dependencies
  ((name . "graphviz")
   (purpose . "DOT rendering")
   (optional . #t))

  ((name . "rust-toolchain")
   (purpose . "CLI compilation")
   (optional . #f)))
  (opsm-integration
    (relationship "core")
    (description "graph/context source for OPSM ecosystem views.")
    (direction "opsm -> reposystem"))
)
