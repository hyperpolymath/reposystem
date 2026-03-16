;; SPDX-License-Identifier: PMPL-1.0-or-later
;; STATE.scm - Project state for stateful-artefacts
;; Media-Type: application/vnd.state+scm

(state
  (metadata
    (version "1.6.0")
    (schema-version "1.0")
    (created "2025-01-24")
    (updated "2026-03-08")
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
    (phase "beta")
    (overall-completion 98)
    (components
      (sexp-parser "complete" "Recursive descent S-expression parser")
      (template-renderer "complete" "(:placeholder) syntax with filter pipeline")
      (flexitext "complete" "Accessibility model: visual + alt-text pairing")
      (tri-guard "complete" "Sanitization for URL, alt-text, table contexts")
      (sixscm-enhanced "complete" "Deep tree traversal, dotted paths, leaf keys")
      (dax-conditionals "complete" "{{#if}} blocks with ==, !=, >, <, >=, <= operators")
      (dax-else "complete" "{{#else}} blocks with nesting support")
      (dax-loops "complete" "{{#for x in list}} iteration over comma-sep values")
      (dax-index "complete" "{{@index}} 0-based counter in loops")
      (dax-filters "complete" "uppercase, lowercase, capitalize, thousands-separator")
      (numeric-comparison "complete" "DAX >=, <=, >, < operators for integer values")
      (relative-time "complete" "ISO timestamp parsing to human-readable dates")
      (round-value "complete" "Numeric rounding with decimal truncation")
      (paxos-lite "complete" "Timestamp-based ballot for concurrent STATE.scm edits")
      (badges-mode "complete" "Shields.io badge rendering for visual emphasis")
      (plain-mode "complete" "Plain text rendering (default)")
      (cli "complete" "--plain, --badges, --scm-path, --dump-context, --version, --help, --fetch-npm, --fetch-crate, --fetch-pypi")
      (test-suite "complete" "94 unit + 23 integration + 23 P2P tests across 11 categories")
      (benchmarks "complete" "Haskell in-process benchmarks with deepseq forcing + 8-phase harness")
      (pre-commit-hook "complete" "Auto-hydrate .template.md files on git commit")
      (nested-conditionals "complete" "{{#if}} inside {{#if}} via recursive processing")
      (dashboard "complete" "Dual mode: Git forge API + local SCM file loading, component grid, health score")
      (annotation-layer "complete" "Hypothesis-style post-it notes: sidebar, highlights, threading, export/import JSON")
      (plugin-system "complete" "6 filter plugins + 2 renderer plugins + 3 data source plugins (npm, crates.io, PyPI)")
      (browser-extension "complete" "MV3 extension: SCM detection on GitHub/GitLab, status badge, format toggle, annotation injection")
      (extension-icons "complete" "SVG source icon with PNG renders at 16, 48, 128px")
      (chrome-web-store-prep "complete" "MPL-2.0 license file for Chrome Web Store submission")
      (integration-tests "complete" "23 end-to-end tests: placeholders, conditionals, loops, filters, badges, context dump, cross-file, CLI, plugins")
      (point-to-point-tests "complete" "23 P2P tests: CLI parsing, SCM loading, DAX->renderer, renderer->output")
      (cli-packaging "complete" "install.sh script with PATH detection and pre-commit hook setup")
      (performance-ci "complete" "GitHub Actions workflow: benchmarks, test matrix, binary size regression guard"))
    (working-features
      ("S-expression parsing with comment stripping and dotted pairs")
      ("Template hydration: (:key), (:dotted.path.key), (:key | filter)")
      ("6scm loading: all 6 files merged with priority ordering")
      ("Enhanced extraction: deep tree traversal + leaf key shortcuts")
      ("DAX conditionals: {{#if key == value}} ... {{#else}} ... {{/if}}")
      ("DAX numeric comparison: >, <, >=, <= with integer parsing")
      ("DAX loops: {{#for item in list}} ... {{/for}} with {{@index}}")
      ("Filters: uppercase, lowercase, capitalize, thousands-separator, relativeTime, round, emojify, slug, truncate, strip-html, count-words, reverse")
      ("Dual render modes: --plain (default) and --badges")
      ("Context dump: --dump-context shows all resolved keys")
      ("Configurable SCM path: --scm-path for cross-repo rendering")
      ("Paxos-Lite: timestamp-based conflict resolution for concurrent edits")
      ("Pre-commit hook: auto-hydrate .template.md on commit")
      ("Dashboard: dual-mode (forge API + local SCM), component grid, health score")
      ("Annotation layer: highlights, sidebar, threading, JSON export/import")
      ("Browser extension: SCM detection, status badge, format toggle, annotation injection")
      ("Plugin system: 6 built-in filters + 2 renderers (JSON, CSV) + 3 data sources (npm, crates.io, PyPI)")
      ("Test suite: 94 unit tests + 23 integration tests + 23 point-to-point tests")
      ("Benchmarks: deepseq-forced Haskell benchmarks (26 cases) + 8-phase harness")
      ("Data source CLI: --fetch-npm, --fetch-crate, --fetch-pypi flags")
      ("Performance CI: benchmark workflow with binary size regression guard")))

  (blockers-and-issues
    (low
      ("gui/src-tauri Cargo.lock has broken path dependency to reposystem-plan")
      ("Radicle remote has stale project ID — needs rad init")))

  (critical-next-actions
    (this-month
      ("Publish to Chrome Web Store")
      ("Add http-client dependency to enable live data source fetching")
      ("Wire data source output into SCM context for template rendering"))))
