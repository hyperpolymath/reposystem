;; SPDX-License-Identifier: PMPL-1.0-or-later
;; STATE.scm - Project state for stateful-artefacts
;; Media-Type: application/vnd.state+scm

(state
  (metadata
    (version "1.1.0")
    (schema-version "1.0")
    (created "2025-01-24")
    (updated "2026-03-07")
    (project "stateful-artefacts")
    (repo "github.com/hyperpolymath/stateful-artefacts"))

  (project-context
    (name "Stateful Artefacts for Git Forges")
    (tagline "Metadata-driven documentation that updates automatically")
    (tech-stack
      (primary "Haskell")
      (config "Guile Scheme")
      (state-files "6scm")))

  (current-position
    (phase "alpha")
    (overall-completion 40)
    (components
      (sexp-parser "complete" "Recursive descent S-expression parser")
      (template-renderer "complete" "(:placeholder) syntax with filter pipeline")
      (flexitext "complete" "Accessibility model: visual + alt-text pairing")
      (tri-guard "complete" "Sanitization for URL, alt-text, table contexts")
      (sixscm-loader "complete" "Loads all 6 SCM files, merges contexts")
      (sixscm-enhanced "complete" "Deep tree traversal, dotted paths, leaf keys")
      (dax-conditionals "complete" "{{#if}} blocks with == and != operators")
      (dax-loops "complete" "{{#for x in list}} iteration over comma-sep values")
      (dax-filters "complete" "uppercase, lowercase, capitalize, thousands-separator")
      (paxos-lite "complete" "Timestamp-based ballot for concurrent STATE.scm edits")
      (badges-mode "complete" "Shields.io badge rendering for visual emphasis")
      (plain-mode "complete" "Plain text rendering (default)")
      (cli "complete" "--plain, --badges, --scm-path, --dump-context flags")
      (plugin-system "scaffolded" "Directory structure only, no implementation")
      (browser-extension "scaffolded" "Manifest + popup + content script, not functional")
      (dashboard "scaffolded" "HTML/CSS/JS shell, not connected to engine")
      (annotation-layer "designed" "Hypothesis-style post-it notes on rendered docs")
      (pre-commit-hook "planned" "Auto-hydrate templates on git commit")
      (numeric-comparison "planned" "DAX >= <= > < operators for numbers")
      (nested-conditionals "planned" "{{#if}} inside {{#if}}")
      (else-blocks "planned" "{{#else}} within {{#if}}")
      (index-access "planned" "{{@index}} counter in loops"))
    (working-features
      ("S-expression parsing with comment stripping and dotted pairs")
      ("Template hydration: (:key), (:dotted.path.key), (:key | filter)")
      ("6scm loading: all 6 files merged with priority ordering")
      ("Enhanced extraction: deep tree traversal + leaf key shortcuts")
      ("DAX conditionals: {{#if key == value}} ... {{/if}}")
      ("DAX loops: {{#for item in list}} ... {{/for}}")
      ("Filter pipeline: uppercase, lowercase, capitalize, thousands-separator")
      ("Dual render modes: --plain (default) and --badges")
      ("Context dump: --dump-context shows all resolved keys")
      ("Configurable SCM path: --scm-path for cross-repo rendering")
      ("Paxos-Lite: timestamp-based conflict resolution for concurrent edits")))

  (blockers-and-issues
    (high
      ("No tests — engine has zero test coverage")
      ("No pre-commit hook — templates must be rendered manually")
      ("Browser extension and dashboard are empty shells"))
    (medium
      ("relativeTime filter returns hardcoded 'recently'")
      ("roundValue filter is a no-op")
      ("No {{#else}} support in conditionals")
      ("No numeric comparison in DAX (only == and !=)")
      ("Annotation layer only designed, not implemented"))
    (low
      ("GHC warnings: head/tail partial function usage in DAX.hs")
      ("SixSCM.hs (basic loader) still in codebase but unused")))

  (critical-next-actions
    (immediate
      ("Add test suite for S-expression parser")
      ("Add test suite for template renderer")
      ("Add test suite for DAX conditionals and loops"))
    (this-week
      ("Create pre-commit hook for auto-hydration")
      ("Implement {{#else}} blocks")
      ("Implement numeric comparison in DAX"))
    (this-month
      ("Begin annotation layer implementation")
      ("Connect dashboard to gnosis engine output")
      ("Fix partial function warnings (head/tail)"))))
