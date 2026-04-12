# SPDX-License-Identifier: PMPL-1.0-or-later
# Gitbot-fleet bot template (ReScript + Deno)

{
  metadata = {
    name = "gitbot-fleet-bot",
    description = "Bot template for gitbot-fleet ecosystem",
    version = "1.0.0",
    author = "Jonathan D.A. Jewell",
    license = "PMPL-1.0-or-later",
  },

  structure = {
    directories = [
      "src",
      "src/types",
      "src/operations",
      "src/strategies",
      "tests",
      ".machine_readable",
      ".github/workflows",
      "docs",
    ],

    files = {
      # ReScript configuration
      "bsconfig.json" = {
        content = ''
{
  "name": "{{name}}",
  "version": "0.1.0",
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
    "dev": "deno run --allow-read --allow-write --allow-env --allow-net --allow-run src/main.mjs",
    "test": "deno test --allow-read --allow-write --allow-env --allow-net tests/",
    "fmt": "deno fmt src/ tests/",
    "lint": "deno lint src/ tests/",
    "compile": "rescript build",
    "watch": "rescript build -w",
    "clean": "rescript clean"
  },
  "imports": {
    "@std/assert": "jsr:@std/assert@^1.0.0",
    "@std/path": "jsr:@std/path@^1.0.0",
    "@std/fs": "jsr:@std/fs@^1.0.0",
    "@std/http": "jsr:@std/http@^1.0.0"
  }
}
        '',
      },

      # Bot configuration type
      "src/types/Config.res" = {
        content = ''
// SPDX-License-Identifier: PMPL-1.0-or-later
// Config.res - Bot configuration types

type confidenceLevel =
  | Safe      // Auto-apply without review
  | Medium    // Create PR for review
  | Unsafe    // Manual only

type botConfig = {
  name: string,
  description: string,
  version: string,
  capabilities: array<string>,
  confidenceThreshold: confidenceLevel,
  rateLimit: int,  // ops per minute
  dryRunDefault: bool,
}

let defaultConfig: botConfig = {
  name: "{{name}}",
  description: "{{description}}",
  version: "0.1.0",
  capabilities: [],
  confidenceThreshold: Medium,
  rateLimit: 30,
  dryRunDefault: true,
}
        '',
      },

      # Operation types
      "src/types/Operation.res" = {
        content = ''
// SPDX-License-Identifier: PMPL-1.0-or-later
// Operation.res - Operation types for bot actions

type repoPath = string

type operationResult =
  | Success({message: string, changes: array<string>})
  | Failure({error: string, recoverable: bool})
  | Skipped({reason: string})

type operation = {
  id: string,
  repoPath: repoPath,
  description: string,
  confidence: Config.confidenceLevel,
  dryRun: bool,
}

type executionContext = {
  timestamp: string,
  botVersion: string,
  triggeredBy: string,
  metadata: Js.Dict.t<string>,
}
        '',
      },

      # Bot interface
      "src/Bot.res" = {
        content = ''
// SPDX-License-Identifier: PMPL-1.0-or-later
// Bot.res - Core bot interface

open Types.Config
open Types.Operation

// Bot capabilities
let capabilities = [
  "{{capability_1}}",
  "{{capability_2}}",
]

// Check if bot can handle operation
let canHandle = (opType: string): bool => {
  Array.some(capabilities, cap => cap == opType)
}

// Analyze repository and determine actions
let analyze = (repoPath: repoPath): Promise.t<array<operation>> => {
  Promise.resolve([])  // TODO: Implement analysis
}

// Execute single operation
let executeOperation = (
  op: operation,
  ctx: executionContext,
): Promise.t<operationResult> => {
  Promise.resolve(Skipped({reason: "Not implemented"}))  // TODO: Implement
}

// Execute all operations for a repository
let execute = (
  repoPath: repoPath,
  dryRun: bool,
): Promise.t<array<operationResult>> => {
  let ctx = {
    timestamp: Date.now()->Float.toString,
    botVersion: defaultConfig.version,
    triggeredBy: "manual",
    metadata: Js.Dict.empty(),
  }

  analyze(repoPath)
    ->Promise.then(ops => {
      ops
      ->Array.map(op => executeOperation({...op, dryRun}, ctx))
      ->Promise.all
    })
}
        '',
      },

      # Strategies module
      "src/strategies/Strategy.res" = {
        content = ''
// SPDX-License-Identifier: PMPL-1.0-or-later
// Strategy.res - Execution strategies for different confidence levels

open Types.Config
open Types.Operation

type strategyResult =
  | AutoApply({operations: array<operation>})
  | CreatePullRequest({
      title: string,
      body: string,
      operations: array<operation>,
    })
  | RequireManual({
      reason: string,
      operations: array<operation>,
    })

// Select strategy based on confidence level
let selectStrategy = (
  ops: array<operation>,
  config: botConfig,
): strategyResult => {
  // Group operations by confidence level
  let (safe, medium, unsafe) = Array.reduce(
    ops,
    ([], [], []),
    ((safeOps, mediumOps, unsafeOps), op) => {
      switch op.confidence {
      | Safe => (Array.concat(safeOps, [op]), mediumOps, unsafeOps)
      | Medium => (safeOps, Array.concat(mediumOps, [op]), unsafeOps)
      | Unsafe => (safeOps, mediumOps, Array.concat(unsafeOps, [op]))
      }
    },
  )

  // If any unsafe ops, require manual intervention
  if Array.length(unsafe) > 0 {
    RequireManual({
      reason: "Contains unsafe operations requiring manual review",
      operations: ops,
    })
  }
  // If only medium confidence ops, create PR
  else if Array.length(medium) > 0 {
    CreatePullRequest({
      title: `[{{name}}] Automated fixes`,
      body: `This PR contains ${Int.toString(Array.length(ops))} automated fixes.`,
      operations: ops,
    })
  }
  // All safe operations, auto-apply
  else {
    AutoApply({operations: safe})
  }
}
        '',
      },

      # Main entry point
      "src/main.mjs" = {
        content = ''
#!/usr/bin/env -S deno run --allow-read --allow-write --allow-env --allow-net --allow-run

// SPDX-License-Identifier: PMPL-1.0-or-later
// main.mjs - Entry point for {{name}}

import * as Bot from "./Bot.mjs";
import * as Config from "./types/Config.mjs";

async function main() {
  const args = Deno.args;

  if (args.length === 0) {
    console.log("{{name}} v" + Config.defaultConfig.version);
    console.log("Usage: {{name}} <repo-path> [--dry-run]");
    return 1;
  }

  const repoPath = args[0];
  const dryRun = args.includes("--dry-run");

  console.log(`Analyzing ${repoPath}...`);

  const results = await Bot.execute(repoPath, dryRun);

  console.log(`\nCompleted ${results.length} operations:`);
  results.forEach((result, i) => {
    console.log(`${i + 1}. ${result.TAG}`);
  });

  return 0;
}

Deno.exit(await main());
        ',
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

run REPO *ARGS:
    deno run --allow-read --allow-write --allow-env --allow-net --allow-run src/main.mjs reposystem {{ARGS}}

test:
    deno test --allow-read --allow-write --allow-env --allow-net tests/

fmt:
    deno fmt src/ tests/

lint:
    deno lint src/ tests/

clean:
    rescript clean
        '',
      },

      # STATE.scm
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
    (tech-stack ("ReScript" "Deno"))
    (bot-capabilities {{capabilities}}))

  (current-position
    (phase "initial")
    (overall-completion 0)
    (components ())
    (working-features ()))

  (integration
    (gitbot-fleet-member . "true")
    (confidence-level . "{{confidence}}")
    (operations-per-minute . "30")
    (seo-score . "0")
    (health-score . "0")
    (reposystem-registered . "false"))

  (route-to-mvp
    (milestones ()))

  (blockers-and-issues
    (critical)
    (high)
    (medium)
    (low))

  (critical-next-actions
    (immediate
      ("Implement analysis logic")
      ("Add operation executors")
      ("Write integration tests")))

  (session-history ()))
        '',
      },

      # ECOSYSTEM.scm
      ".machine_readable/ECOSYSTEM.scm" = {
        content = ''
;; SPDX-License-Identifier: PMPL-1.0-or-later
;; ECOSYSTEM.scm - Ecosystem relationships for {{name}}
;; Media-Type: application/vnd.ecosystem+scm

(ecosystem
  (version "1.0")
  (name "{{name}}")
  (type "automation-bot")
  (purpose "{{purpose}}")

  (position-in-ecosystem
    (category "gitbot-fleet")
    (subcategory "{{subcategory}}")
    (unique-value "{{unique_value}}"))

  (related-projects
    ; Upstream: receives commands from
    ((name . "git-dispatcher")
     (relationship . "command-source")
     (description . "Receives execution plans and operations"))

    ((name . "reposystem")
     (relationship . "data-source")
     (description . "Reads repository graph and relationships"))

    ; Downstream: reports to
    ((name . "gitbot-fleet")
     (relationship . "fleet-member")
     (description . "Part of coordinated bot fleet"))

    ; Parallel: other fleet members
    ((name . "rhodibot")
     (relationship . "sibling-bot")
     (description . "General-purpose fixes"))

    ((name . "echidnabot")
     (relationship . "sibling-bot")
     (description . "Security scanning and fixes"))))
        '',
      },

      # README template
      "README.template.adoc" = {
        content = ''
= (:project-context.name)

image:https://img.shields.io/badge/License-PMPL--1.0-blue.svg[License: PMPL-1.0]
image:https://img.shields.io/badge/Fleet-gitbot--fleet-orange.svg[Fleet Member]

// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: {{year}} {{author}}

*(:project-context.tagline)*

Part of the link:https://github.com/hyperpolymath/gitbot-fleet[gitbot-fleet] automation ecosystem.

== Status

Phase: *(:current-position.phase)* | Progress: *(:current-position.overall-completion)%*

== Capabilities

(:project-context.bot-capabilities)

== Confidence Level

*(:integration.confidence-level)* - (:integration.confidence-description)

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
# Dry run (preview changes)
just run /path/to/repo --dry-run

# Execute changes
just run /path/to/repo
----

== Integration

This bot integrates with:

* **git-dispatcher** - Receives operation plans
* **reposystem** - Reads repository graph
* **gitbot-fleet** - Coordinated fleet operations

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
        '',
      },
    },
  },
}
