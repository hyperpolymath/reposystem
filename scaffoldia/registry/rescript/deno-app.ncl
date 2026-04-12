# SPDX-License-Identifier: PMPL-1.0-or-later
# ReScript + Deno application template

{
  metadata = {
    name = "rescript-deno-app",
    description = "ReScript application with Deno runtime",
    version = "1.0.0",
    author = "Jonathan D.A. Jewell",
    license = "PMPL-1.0-or-later",
  },

  structure = {
    # Source directories
    directories = [
      "src",
      "src/types",
      "src/cli",
      "src/engine",
      "tests",
      "tests/fixtures",
      ".machine_readable",
      ".github/workflows",
      "docs",
    ],

    # Core files
    files = {
      # Build configuration
      "bsconfig.json" = {
        content = ''
{
  "name": "{{name}}",
  "version": "{{version}}",
  "sources": [
    {
      "dir": "src",
      "subdirs": true
    }
  ],
  "package-specs": [
    {
      "module": "es6",
      "in-source": true
    }
  ],
  "suffix": ".mjs",
  "bs-dependencies": [],
  "warnings": {
    "error": "+101"
  },
  "namespace": true,
  "refmt": 3,
  "bsc-flags": ["-open Belt"]
}
        '',
      },

      # Deno configuration
      "deno.json" = {
        content = ''
{
  "tasks": {
    "dev": "deno run --allow-read --allow-write --allow-env --allow-run src/main.mjs",
    "test": "deno test --allow-read --allow-write --allow-env tests/",
    "fmt": "deno fmt src/ tests/",
    "lint": "deno lint src/ tests/",
    "compile": "rescript build",
    "watch": "rescript build -w",
    "clean": "rescript clean"
  },
  "fmt": {
    "files": {
      "include": ["src/", "tests/"],
      "exclude": ["lib/", "node_modules/"]
    }
  },
  "compilerOptions": {
    "allowJs": true,
    "lib": ["deno.window"]
  }
}
        '',
      },

      # Justfile
      "justfile" = {
        content = ''
# SPDX-License-Identifier: PMPL-1.0-or-later
# justfile - Task runner for {{name}}

default:
    @just --list

setup:
    @echo "Setting up {{name}}..."
    @which rescript || echo "⚠ ReScript not found"
    @which deno || echo "⚠ Deno not found"

build:
    rescript build

watch:
    rescript build -w

clean:
    rescript clean

run *ARGS:
    deno run --allow-read --allow-write --allow-env --allow-run src/main.mjs {{ARGS}}

test:
    deno test --allow-read --allow-write --allow-env tests/

fmt:
    deno fmt src/ tests/

lint:
    deno lint src/ tests/
        '',
      },

      # STATE.scm with integration fields
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
    (tech-stack ("ReScript" "Deno")))

  (current-position
    (phase "initial")
    (overall-completion 0)
    (components ())
    (working-features ()))

  (integration
    (seo-score . "0")
    (seo-last-updated . "never")
    (health-score . "0")
    (reposystem-registered . "false")
    (gnosis-enabled . "true")
    (gnosis-last-render . "{{created_date}}"))

  (route-to-mvp
    (milestones ()))

  (blockers-and-issues
    (critical)
    (high)
    (medium)
    (low))

  (critical-next-actions
    (immediate
      ("Implement core functionality")
      ("Add tests")
      ("Write documentation")))

  (session-history ()))
        '',
      },

      # README template with placeholders
      "README.template.adoc" = {
        content = ''
= (:project-context.name)

image:https://img.shields.io/badge/License-PMPL--1.0-blue.svg[License: PMPL-1.0]

// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: {{year}} {{author}}

*(:project-context.tagline)*

== Status

Phase: *(:current-position.phase)* | Progress: *(:current-position.overall-completion)%*

== Discoverability

SEO Score: *(:integration.seo-score)/100* (Last updated: (:integration.seo-last-updated))

== Installation

[source,bash]
----
# Clone the repository
git clone https://github.com/{{github_user}}/{{name}}.git
cd {{name}}

# Setup
just setup
just build
----

== Usage

[source,bash]
----
just run
----

== Development

[source,bash]
----
just watch    # Watch and rebuild
just test     # Run tests
just fmt      # Format code
just lint     # Lint code
----

== License

PMPL-1.0-or-later - see link:LICENSE.txt[LICENSE.txt]

_Last updated: (:integration.gnosis-last-render)_
        '',
      },

      # Gnosis auto-render workflow
      ".github/workflows/gnosis-render.yml" = {
        content = ''
# SPDX-License-Identifier: PMPL-1.0-or-later
name: Gnosis Auto-Render

on:
  push:
    paths:
      - '.machine_readable/**'
    branches: [main]

jobs:
  render:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install gnosis
        run: |
          # TODO: Install gnosis binary
          echo "Gnosis installation needed"

      - name: Render templates
        run: |
          # TODO: Call gnosis on all .template.* files
          echo "Template rendering needed"

      - name: Commit changes
        run: |
          git config user.name "Gnosis Bot"
          git config user.email "bot@hyperpolymath.org"
          git add README.adoc
          git commit -m "docs: auto-update from STATE.scm" || true
          git push
        '',
      },

      # Main entry point stub
      "src/main.mjs" = {
        content = ''
#!/usr/bin/env -S deno run --allow-read --allow-write --allow-env

// SPDX-License-Identifier: PMPL-1.0-or-later
// main.mjs - Entry point for {{name}}

function main() {
  const args = Deno.args;
  console.log("{{name}} v{{version}}");
  console.log("Args:", args);
  return 0;
}

Deno.exit(main());
        '',
      },
    },
  },
}
