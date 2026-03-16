;; SPDX-License-Identifier: PMPL-1.0-or-later
;; SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
;;
;; Git Dispatcher Ecosystem Position
;; ==================================

(ecosystem
 (version . "1.0")
 (name . "git-dispatcher")
 (type . "automation-tool")
 (purpose . "Dispatch repo operations based on Reposystem scenarios")

 (position-in-ecosystem
  (layer . "orchestration")
  (role . "execution coordinator")
  (consumers . ("git-hud" "gitbot-fleet"))
  (providers . ("reposystem")))

 (related-projects
  ((name . "reposystem")
   (relationship . "upstream-source")
   (integration . "Consumes graph exports and scenario plans")
   (direction . "reposystem → git-dispatcher"))

  ((name . "git-hud")
   (relationship . "sibling-standard")
   (integration . "Surfaces dispatch status and outcomes")
   (direction . "git-dispatcher → git-hud"))

  ((name . "gitbot-fleet")
   (relationship . "sibling-tools")
   (integration . "Executes operations at scale")
   (direction . "git-dispatcher → gitbot-fleet")))

 (integration-points
  ((point . "plan-ingest")
   (format . "reposystem plan + graph export")
   (purpose . "Translate scenario into actionable operations"))

  ((point . "dispatch-events")
   (format . "structured JSON")
   (purpose . "Audit and UI status updates")))

 (dependencies
  ((name . "rust-toolchain")
   (purpose . "CLI compilation")
   (optional . #f)))
  (opsm-integration
    (relationship "core")
    (description "multi-repo dispatch for OPSM rollouts.")
    (direction "opsm -> git-dispatcher"))
)
