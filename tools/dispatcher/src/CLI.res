// SPDX-License-Identifier: PMPL-1.0-or-later
// CLI.res - Command-line interface for git-dispatcher

open Plan

type command =
  | Execute({planPath: string, dryRun: bool})
  | Validate({planPath: string})
  | Help
  | Version

// Parse command line arguments
let parseArgs = (args: array<string>): command => {
  if Array.length(args) == 0 {
    Help
  } else {
    switch args[0] {
    | Some("execute") | Some("exec") | Some("run") => {
        let planPath = Array.get(args, 1)->Option.getWithDefault("plan.json")
        let dryRun = Array.some(args, arg => arg == "--dry-run" || arg == "-d")
        (Execute({planPath: planPath, dryRun: dryRun}): command)
      }
    | Some("validate") | Some("check") => {
        let planPath = Array.get(args, 1)->Option.getWithDefault("plan.json")
        (Validate({planPath: planPath}): command)
      }
    | Some("version") | Some("-v") | Some("--version") =>
        (Version: command)
    | Some("help") | Some("-h") | Some("--help") | _ =>
        (Help: command)
    }
  }
}

// Display help text
let showHelp = () => {
  Console.log("git-dispatcher - Execution engine for reposystem plans\n")
  Console.log("USAGE:")
  Console.log("  git-dispatcher <command> [options]\n")
  Console.log("COMMANDS:")
  Console.log("  execute <plan>     Execute a plan file")
  Console.log("    --dry-run, -d    Dry run mode (no changes)")
  Console.log("  validate <plan>    Validate a plan file")
  Console.log("  help               Show this help")
  Console.log("  version            Show version\n")
  Console.log("EXAMPLES:")
  Console.log("  git-dispatcher execute plan.json")
  Console.log("  git-dispatcher execute plan.json --dry-run")
  Console.log("  git-dispatcher validate plan.json")
}

// Display version
let showVersion = () => {
  Console.log("git-dispatcher v0.1.0-dev")
  Console.log("ReScript + Deno execution engine")
}

// Load plan from JSON file
let loadPlan = (path: string): Promise.t<Result.t<plan, string>> => {
  // TODO v0.1.0: Use Deno.readTextFile
  Console.log(`[CLI] Would load plan from: ${path}`)

  // Mock plan for testing
  let mockPlan: plan = {
    id: "test-plan-001",
    name: "Test Integration Plan",
    description: "Test plan for integration operations",
    scenarioId: Some("test-scenario"),
    operations: [
      {
        id: "op-001",
        opType: UpdateMetadataFromSeo({
          repoPath: "/path/to/repo",
          runAnalysis: true,
        }),
        risk: Medium,
        description: "Update SEO metadata",
        requires: [],
        reversible: true,
      },
      {
        id: "op-002",
        opType: RenderDocumentation({
          repoPath: "/path/to/repo",
          templates: [],
        }),
        risk: Low,
        description: "Render documentation",
        requires: ["op-001"],
        reversible: true,
      },
    ],
    rollbackPlan: [],
    createdAt: Date.now()->Float.toString,
    metadata: Js.Dict.empty(),
  }

  Promise.resolve(Ok(mockPlan))
}

// Validate a plan
let validatePlan = (plan: plan): Result.t<unit, string> => {
  // Basic validation
  if String.length(plan.id) == 0 {
    Error("Plan ID is empty")
  } else if Array.length(plan.operations) == 0 {
    Error("Plan has no operations")
  } else {
    Console.log(`✓ Plan ${plan.id} is valid`)
    Console.log(`  Name: ${plan.name}`)
    Console.log(`  Operations: ${Int.toString(Array.length(plan.operations))}`)
    Ok()
  }
}

// Execute a plan
let executePlan = (planPath: string, dryRun: bool): Promise.t<int> => {
  loadPlan(planPath)
    ->Promise.then(result => {
      switch result {
      | Error(err) => {
          Console.error(`Failed to load plan: ${err}`)
          Promise.resolve(1)
        }
      | Ok(plan) => {
          let ctx: executionContext = {
            planId: plan.id,
            dryRun,
            parallel: false,
            maxRetries: 3,
            timeout: 300,
            auditLog: true,
            requireApproval: false,
          }

          Executor.executePlan(plan, ctx)
            ->Promise.then(result => {
              Console.log("\n=== Execution Complete ===")
              Console.log(`Plan: ${result.planId}`)
              Console.log(`Status: ${statusToString(result.status)}`)
              Console.log(`Operations: ${Int.toString(Array.length(result.operations))}`)

              let exitCode = if isSuccessful(result.status) { 0 } else { 1 }
              Promise.resolve(exitCode)
            })
        }
      }
    })
}

// Main entry point
let run = (args: array<string>): Promise.t<int> => {
  let cmd = parseArgs(args)

  switch cmd {
  | Help => {
      showHelp()
      Promise.resolve(0)
    }
  | Version => {
      showVersion()
      Promise.resolve(0)
    }
  | Validate({planPath}) => {
      loadPlan(planPath)
        ->Promise.then(result => {
          switch result {
          | Error(err) => {
              Console.error(`Failed to load plan: ${err}`)
              Promise.resolve(1)
            }
          | Ok(plan) => {
              switch validatePlan(plan) {
              | Ok() => Promise.resolve(0)
              | Error(err) => {
                  Console.error(`Validation failed: ${err}`)
                  Promise.resolve(1)
                }
              }
            }
          }
        })
    }
  | Execute({planPath, dryRun}) =>
      executePlan(planPath, dryRun)
  }
}
