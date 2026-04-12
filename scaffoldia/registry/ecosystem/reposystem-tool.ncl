# SPDX-License-Identifier: PMPL-1.0-or-later
# Template for reposystem ecosystem tools (git-dispatcher, git-hud style)

{
  metadata = {
    name = "reposystem-tool",
    description = "Template for tools in the reposystem ecosystem",
    version = "1.0.0",
    author = "Jonathan D.A. Jewell",
    license = "PMPL-1.0-or-later",
  },

  structure = {
    directories = [
      "src",
      "src/types",
      "src/parsers",
      "src/cli",
      "src/engine",
      "tests",
      "tests/fixtures",
      ".machine_readable",
      ".github/workflows",
      "docs",
    ],

    files = {
      # Ecosystem-specific STATE.scm
      ".machine_readable/STATE.scm" = {
        content = ''
;; SPDX-License-Identifier: PMPL-1.0-or-later
;; STATE.scm - Project state for {{name}}
;; Media-Type: application/vnd.state+scm

(state
  (metadata
    (version "0.1.0")
    (schema-version "1.0")
    (created "{{created_date}}")
    (updated "{{created_date}}")
    (project "{{name}}")
    (repo "github.com/{{github_user}}/{{name}}"))

  (project-context
    (name "{{name}}")
    (tagline "{{description}}")
    (description "{{long_description}}")
    (tech-stack ("ReScript" "Deno")))

  (current-position
    (phase "design")
    (overall-completion 5)
    (components
      ((name . "Types") (status . "planned") (completion . 0))
      ((name . "CLI") (status . "planned") (completion . 0))
      ((name . "Engine") (status . "planned") (completion . 0))
      ((name . "Tests") (status . "planned") (completion . 0)))
    (working-features ()))

  (route-to-mvp
    (milestones
      ((id . "m1-foundation")
       (name . "v0.1.0 - Foundation")
       (status . "planned")
       (completion . 0)
       (items
        ((task . "Define types") (status . "planned"))
        ((task . "Build CLI scaffold") (status . "planned"))
        ((task . "Add tests") (status . "planned"))))))

  (blockers-and-issues
    (critical
      ((id . "CRIT-001")
       (description . "Needs implementation")
       (impact . "Cannot be used")))
    (high)
    (medium)
    (low))

  (critical-next-actions
    (immediate
      ("Define core types")
      ("Build CLI interface")
      ("Add unit tests"))
    (this-week
      ("Implement core engine")
      ("Add integration tests"))
    (this-month
      ("Complete v0.1.0")
      ("Write documentation")))

  (integration
    (reposystem-role . "{{reposystem_role}}")
    (upstream-tools . "{{upstream_tools}}")
    (downstream-tools . "{{downstream_tools}}")
    (seo-score . "0")
    (health-score . "0")
    (gnosis-enabled . "true"))

  (session-history
    ((date . "{{created_date}}")
     (accomplishments
      ("Repository scaffolded with scaffoldia"
       "Initial structure created"
       "Ready for implementation")))))
        '',
      },

      # ECOSYSTEM.scm with relationships
      ".machine_readable/ECOSYSTEM.scm" = {
        content = ''
;; SPDX-License-Identifier: PMPL-1.0-or-later
;; ECOSYSTEM.scm - Ecosystem relationships for {{name}}
;; Media-Type: application/vnd.ecosystem+scm

(ecosystem
  (version "1.0")
  (name "{{name}}")
  (type "{{ecosystem_type}}")
  (purpose "{{purpose}}")

  (position-in-ecosystem
    (category "{{category}}")
    (subcategory "{{subcategory}}")
    (unique-value "{{unique_value}}"))

  (related-projects
    ; Upstream: provides data/services we consume
    ((name . "reposystem")
     (relationship . "{{upstream_relationship}}")
     (description . "{{upstream_description}}"))

    ; Downstream: consumes our data/services
    ((name . "git-hud")
     (relationship . "{{downstream_relationship}}")
     (description . "{{downstream_description}}"))

    ; Parallel: same layer, different functions
    ((name . "git-seo")
     (relationship . "parallel")
     (description . "Both provide analysis data for ecosystem"))))
        '',
      },

      # README template with ecosystem integration
      "README.template.adoc" = {
        content = ''
= (:project-context.name)

image:https://img.shields.io/badge/License-PMPL--1.0-blue.svg[License: PMPL-1.0]

// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: {{year}} {{author}}

*(:project-context.tagline)*

== Status

Phase: *(:current-position.phase)* | Progress: *(:current-position.overall-completion)%*

== Purpose

(:project-context.description)

== Ecosystem Position

Role: *(:integration.reposystem-role)*

Upstream: (:integration.upstream-tools)

Downstream: (:integration.downstream-tools)

== Metrics

* SEO Score: *(:integration.seo-score)/100*
* Health: *(:integration.health-score)/100*

== Installation

[source,bash]
----
git clone https://github.com/{{github_user}}/{{name}}.git
cd {{name}}
just setup
just build
----

== Usage

[source,bash]
----
{{name}} --help
----

== Development

See link:docs/EXECUTION-ENGINE.adoc[Execution Engine Architecture] for technical design.

== Integration

This tool integrates with:

* **reposystem** - (:integration.upstream-tools)
* **git-hud** - (:integration.downstream-tools)
* **gitbot-fleet** - Bot coordination

See link:docs/ECOSYSTEM-INTEGRATION.adoc[Ecosystem Integration] for details.

== License

PMPL-1.0-or-later - see link:LICENSE.txt[LICENSE.txt]

_Auto-updated: (:integration.gnosis-last-render)_
        '',
      },

      # Integration operations types
      "src/types/Integration.res" = {
        content = ''
// SPDX-License-Identifier: PMPL-1.0-or-later
// Integration.res - Types for ecosystem integration

// Integration with reposystem
type reposystemIntegration = {
  graphPath: string,
  autoRegister: bool,
  defaultAspects: array<string>,
}

// Integration with git-seo
type gitSeoIntegration = {
  autoUpdate: bool,
  threshold: int,
  reportPath: string,
}

// Integration with gnosis
type gnosisIntegration = {
  enabled: bool,
  autoRender: bool,
  templatesGlob: string,
}

// Integration context
type integrationContext = {
  reposystem: option<reposystemIntegration>,
  gitSeo: option<gitSeoIntegration>,
  gnosis: option<gnosisIntegration>,
}
        '',
      },

      # Ecosystem integration docs
      "docs/ECOSYSTEM-INTEGRATION.adoc" = {
        content = ''
= Ecosystem Integration

{{name}} integrates with the reposystem ecosystem.

== Upstream Integration

Consumes from:
- reposystem (graph data, plans)

== Downstream Integration

Provides to:
- git-hud (status, metrics)

== Data Flow

[source,text]
----
reposystem → {{name}} → git-hud
----

== Configuration

See `.integration.toml` for settings.
        '',
      },
    },
  },
}
