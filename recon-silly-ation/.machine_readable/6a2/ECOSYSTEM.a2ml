;; SPDX-License-Identifier: PMPL-1.0-or-later
;; ECOSYSTEM.scm - Project ecosystem positioning
;; Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

(ecosystem
  ((version . "1.0.0")
   (name . "Recon-Silly-Ation")
   (type . "reconciliation-engine")
   (purpose . "Document reconciliation, deduplication, and policy enforcement")

   (position-in-ecosystem . "machine-side-processor")

   (related-projects
     ((formatrix-docs . ((relationship . "input-source")
                        (description . "Human editor producing documents for reconciliation")))
      (docubot . ((relationship . "assistant")
                 (description . "LLM-powered document generation with guardrails")))
      (docudactyl . ((relationship . "orchestrator")
                    (description . "Coordinates workflows between components")))
      (git-hud . ((relationship . "infrastructure")
                  (description . "Git repository management and monitoring")))
      (rhodium-standard . ((relationship . "compliance-framework")
                          (description . "RSR compliance checking and validation")))))

   (components
     ((reconforth . ((type . "dsl")
                    (description . "Stack-based Forth-like language for reconciliation rules")))
      (enforcement-bot . ((type . "service")
                         (description . "Automated policy compliance checking")))
      (pack-shipper . ((type . "service")
                      (description . "Bundle distribution to multiple destinations")))
      (logic-engine . ((type . "module")
                      (description . "Datalog-style cross-document inference")))))

   (integrations
     ((arangodb . "Graph and document storage")
      (formatrix-core . "Format parsing and AST conversion")
      (wasm . "High-performance hashing and normalization")
      (haskell-validator . "Type-safe schema validation")))

   (what-this-is
     ("A document reconciliation engine")
     ("A stack-based DSL for defining reconciliation rules")
     ("An enforcement bot for policy compliance")
     ("A pack shipper for bundle distribution")
     ("RSR compliance validator"))

   (what-this-is-not
     ("A document editor (use formatrix-docs)")
     ("An LLM document generator (use docubot)")
     ("A workflow orchestrator (use docudactyl)")
     ("A general-purpose programming language"))))
