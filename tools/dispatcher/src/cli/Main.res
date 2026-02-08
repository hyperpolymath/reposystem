// SPDX-License-Identifier: PMPL-1.0-or-later
// Main.res - CLI entry point

// CLI command types
type rec command =
  | Plan({action: planAction})
  | Execute({planId: string, dryRun: bool})
  | Status({planId: option<string>})
  | Audit({filter: Audit.auditFilter})
  | Help
  | Version

and planAction =
  | Load({path: string})
  | Show({planId: string})
  | List
  | Validate({planId: string})

// CLI result
type cliResult =
  | Success({message: string, data: option<JSON.t>})
  | Error({message: string, code: int})

// Version info
let version = "0.1.0"
let banner = `
┌──────────────────────────────────────────┐
│  git-dispatcher v${version}                │
│  Git workflow dispatcher                 │
│  https://github.com/hyperpolymath        │
└──────────────────────────────────────────┘
`

// Help text
let helpText = `
Usage: git-dispatcher <command> [options]

Commands:
  plan load <file>        Load a plan from JSON file
  plan show <plan-id>     Display plan details
  plan list              List all loaded plans
  plan validate <id>     Validate plan structure

  execute <plan-id>      Execute a plan
  execute --dry-run <id> Dry-run execution (show operations)

  status                 Show execution status for all plans
  status <plan-id>       Show status for specific plan

  audit                  Show audit log
  audit --plan <id>      Show audit log for specific plan

  help                   Show this help message
  version                Show version information

Options:
  --dry-run              Execute in dry-run mode (no actual operations)
  --parallel             Execute operations in parallel where safe
  --timeout <seconds>    Set operation timeout (default: 300)
  --no-audit             Disable audit logging

Examples:
  # Load a plan from reposystem
  git-dispatcher plan load plans/scenario-123.json

  # Dry-run to see what would execute
  git-dispatcher execute --dry-run plan-abc123

  # Execute plan
  git-dispatcher execute plan-abc123

  # Check execution status
  git-dispatcher status plan-abc123

  # View audit log
  git-dispatcher audit --plan plan-abc123
`

// Parse command line arguments
let parseArgs = (args: array<string>): Result.t<command, string> => {
  let len = Array.length(args)

  if len == 0 {
    Ok(Help)
  } else {
    switch args[0] {
    | Some("help") | Some("--help") | Some("-h") => Ok(Help)
    | Some("version") | Some("--version") | Some("-v") => Ok(Version)
    | Some("plan") =>
      switch args[1] {
      | Some("load") =>
        switch args[2] {
        | Some(path) => Ok(Plan({action: Load({path: path})}))
        | None => Error("Missing path argument for 'plan load'")
        }
      | Some("show") =>
        switch args[2] {
        | Some(planId) => Ok(Plan({action: Show({planId: planId})}))
        | None => Error("Missing plan-id argument for 'plan show'")
        }
      | Some("list") => Ok(Plan({action: List}))
      | Some("validate") =>
        switch args[2] {
        | Some(planId) => Ok(Plan({action: Validate({planId: planId})}))
        | None => Error("Missing plan-id argument for 'plan validate'")
        }
      | _ => Error("Unknown plan action. Use: load, show, list, validate")
      }
    | Some("execute") =>
      let dryRun = Array.some(args, arg => arg == "--dry-run")
      switch args->Array.keep(arg => arg != "--dry-run")->Array.get(1) {
      | Some(planId) => Ok(Execute({planId: planId, dryRun: dryRun}))
      | None => Error("Missing plan-id argument for 'execute'")
      }
    | Some("status") =>
      switch args[1] {
      | Some(planId) => Ok(Status({planId: Some(planId)}))
      | None => Ok(Status({planId: None}))
      }
    | Some("audit") => {
        let filter: Audit.auditFilter = {
          planId: None,
          eventType: None,
          startDate: None,
          endDate: None,
          limit: 100,
        }
        Ok(Audit({filter: filter}))
      }
    | Some(cmd) => Error(`Unknown command: ${cmd}`)
    | None => Ok(Help)
    }
  }
}

// Run command
let run = (command: command): cliResult => {
  switch command {
  | Help => Success({message: helpText, data: None})
  | Version => Success({message: banner, data: None})
  | Plan({action}) =>
    switch action {
    | Load({path}) => Success({
        message: `Would load plan from: ${path}`,
        data: None,
      })
    | Show({planId}) => Success({
        message: `Would show plan: ${planId}`,
        data: None,
      })
    | List => Success({
        message: "Would list all plans",
        data: None,
      })
    | Validate({planId}) => Success({
        message: `Would validate plan: ${planId}`,
        data: None,
      })
    }
  | Execute({planId, dryRun}) =>
    if dryRun {
      Success({
        message: `Dry-run execution for plan: ${planId}`,
        data: None,
      })
    } else {
      Success({
        message: `Would execute plan: ${planId}`,
        data: None,
      })
    }
  | Status({planId}) =>
    switch planId {
    | Some(id) => Success({
        message: `Would show status for plan: ${id}`,
        data: None,
      })
    | None => Success({
        message: "Would show status for all plans",
        data: None,
      })
    }
  | Audit({filter: _}) => Success({
      message: "Would show audit log",
      data: None,
    })
  }
}

// Entry point (called from JS/Deno)
let main = (args: array<string>): int => {
  switch parseArgs(args) {
  | Ok(command) =>
    switch run(command) {
    | Success({message, data: _}) => {
        Js.log(message)
        0
      }
    | Error({message, code}) => {
        Js.log("Error: " ++ message)
        code
      }
    }
  | Error(msg) => {
      Js.log("Error: " ++ msg)
      Js.log("\nUse 'git-dispatcher help' for usage information")
      1
    }
  }
}
