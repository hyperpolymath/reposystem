;; SPDX-License-Identifier: PMPL-1.0-or-later
;; SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
;;
;; Git Dispatcher Neurosymbolic Integration
;; ========================================

(define-module (git-dispatcher neurosym)
  #:export (integration-model boundaries))

(define integration-model
  '((philosophy . "LLM proposes dispatch intent; symbolic plan remains source of truth")

    (layers
     ((layer . "symbolic")
      (role . "source of truth")
      (components . ("reposystem plans" "graph export" "policy rules"))
      (properties
       ("Deterministic" "Auditable" "Reversible")))

     ((layer . "neural")
      (role . "proposal and explanation")
      (capabilities
       ("Summarize plans"
        "Suggest batch boundaries"
        "Surface risk hotspots"))
      (outputs . "Advice only")))))

(define boundaries
  '((what-neural-can-do
     ("Explain plan impacts"
      "Summarize audit logs"
      "Recommend ordering"))

    (what-neural-cannot-do
     ("Execute dispatch"
      "Approve changes"
      "Modify plans"))))
