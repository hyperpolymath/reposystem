// SPDX-License-Identifier: PMPL-1.0-or-later
// Command-line interface for documentation reconciliation
// Usage: node lib/js/src/CLI.bs.js [options]

open Types

@module("process") @val
external argv: array<string> = "argv"

@module("process") @val
external env: Js.Dict.t<string> = "env"

@module("process") @val
external exit: int => unit = "exit"

// Parse command line arguments
type cliArgs = {
  repositories: array<string>,
  arangoUrl: option<string>,
  arangoDb: option<string>,
  arangoUser: option<string>,
  arangoPassword: option<string>,
  threshold: option<float>,
  daemon: bool,
  interval: option<int>,
  help: bool,
}

let parseArgs = (): cliArgs => {
  // ReScript arrays don't support `[head, ...rest]` destructuring patterns.
  // Convert the raw argv array to an immutable list once so the recursive
  // parser can use `list{head, ...rest}` pattern matching throughout.
  let args = argv->Belt.Array.sliceToEnd(2)->Belt.List.fromArray

  let rec parse = (args: list<string>, acc: cliArgs): cliArgs => {
    switch args {
    | list{} => acc
    | list{arg, ...rest} =>
      switch arg {
      | "--help" | "-h" => {...acc, help: true}
      | "--daemon" | "-d" => parse(rest, {...acc, daemon: true})
      | "--repo" | "-r" =>
        switch rest {
        | list{path, ...remaining} =>
          parse(remaining, {
            ...acc,
            repositories: Belt.Array.concat(acc.repositories, [path]),
          })
        | list{} => acc
        }
      | "--arango-url" =>
        switch rest {
        | list{url, ...remaining} => parse(remaining, {...acc, arangoUrl: Some(url)})
        | list{} => acc
        }
      | "--arango-db" =>
        switch rest {
        | list{db, ...remaining} => parse(remaining, {...acc, arangoDb: Some(db)})
        | list{} => acc
        }
      | "--arango-user" =>
        switch rest {
        | list{user, ...remaining} => parse(remaining, {...acc, arangoUser: Some(user)})
        | list{} => acc
        }
      | "--arango-password" =>
        switch rest {
        | list{pass, ...remaining} => parse(remaining, {...acc, arangoPassword: Some(pass)})
        | list{} => acc
        }
      | "--threshold" | "-t" =>
        switch rest {
        | list{thresh, ...remaining} =>
          switch Belt.Float.fromString(thresh) {
          | Some(value) => parse(remaining, {...acc, threshold: Some(value)})
          | None => parse(remaining, acc)
          }
        | list{} => acc
        }
      | "--interval" | "-i" =>
        switch rest {
        | list{interval, ...remaining} =>
          switch Belt.Int.fromString(interval) {
          | Some(value) => parse(remaining, {...acc, interval: Some(value)})
          | None => parse(remaining, acc)
          }
        | list{} => acc
        }
      | _ => parse(rest, acc) // Skip unknown args
      }
    }
  }

  parse(args, {
    repositories: [],
    arangoUrl: None,
    arangoDb: None,
    arangoUser: None,
    arangoPassword: None,
    threshold: None,
    daemon: false,
    interval: None,
    help: false,
  })
}

// Load configuration from environment variables
let loadFromEnv = (args: cliArgs): cliArgs => {
  {
    ...args,
    arangoUrl: switch args.arangoUrl {
    | Some(_) => args.arangoUrl
    | None => env->Js.Dict.get("ARANGO_URL")
    },
    arangoDb: switch args.arangoDb {
    | Some(_) => args.arangoDb
    | None => env->Js.Dict.get("ARANGO_DATABASE")
    },
    arangoUser: switch args.arangoUser {
    | Some(_) => args.arangoUser
    | None => env->Js.Dict.get("ARANGO_USERNAME")
    },
    arangoPassword: switch args.arangoPassword {
    | Some(_) => args.arangoPassword
    | None => env->Js.Dict.get("ARANGO_PASSWORD")
    },
  }
}

// Create config from CLI args
let createConfig = (args: cliArgs): result<config, string> => {
  if Belt.Array.length(args.repositories) == 0 {
    Error("No repositories specified. Use --repo <path> to specify repositories.")
  } else {
    let arangoUrl = args.arangoUrl->Belt.Option.getWithDefault("http://localhost:8529")
    let arangoDb = args.arangoDb->Belt.Option.getWithDefault("reconciliation")
    let arangoUser = args.arangoUser->Belt.Option.getWithDefault("root")
    let arangoPassword = args.arangoPassword->Belt.Option.getWithDefault("")
    let threshold = args.threshold->Belt.Option.getWithDefault(0.9)

    Ok({
      arangoUrl: arangoUrl,
      arangoDatabase: arangoDb,
      arangoUsername: arangoUser,
      arangoPassword: arangoPassword,
      autoResolveThreshold: threshold,
      repositoryPaths: args.repositories,
      scanInterval: args.interval,
    })
  }
}

// Print help message
let printHelp = (): unit => {
  Js.Console.log("
Documentation Reconciliation System
=====================================

Usage: node lib/js/src/CLI.bs.js [options]

Options:
  -r, --repo <path>           Repository path to scan (can be specified multiple times)
  -d, --daemon                Run in daemon mode (continuous scanning)
  -i, --interval <seconds>    Scan interval in daemon mode (default: 300)
  -t, --threshold <float>     Auto-resolve confidence threshold (default: 0.9)

  --arango-url <url>          ArangoDB URL (default: http://localhost:8529)
  --arango-db <name>          ArangoDB database name (default: reconciliation)
  --arango-user <username>    ArangoDB username (default: root)
  --arango-password <pass>    ArangoDB password (default: empty)

  -h, --help                  Show this help message

Environment Variables:
  ARANGO_URL                  ArangoDB URL
  ARANGO_DATABASE             ArangoDB database name
  ARANGO_USERNAME             ArangoDB username
  ARANGO_PASSWORD             ArangoDB password

Examples:
  # Scan a single repository
  node lib/js/src/CLI.bs.js --repo /path/to/repo

  # Scan multiple repositories with custom threshold
  node lib/js/src/CLI.bs.js --repo /repo1 --repo /repo2 --threshold 0.95

  # Run in daemon mode, scanning every 5 minutes
  node lib/js/src/CLI.bs.js --repo /path/to/repo --daemon --interval 300

  # Use custom ArangoDB instance
  node lib/js/src/CLI.bs.js --repo /repo --arango-url http://arango:8529 --arango-db mydb
")
}

// Main entry point
let main = async (): unit => {
  let args = parseArgs()

  if args.help {
    printHelp()
    exit(0)
  }

  let argsWithEnv = loadFromEnv(args)

  switch createConfig(argsWithEnv) {
  | Error(msg) => {
      Js.Console.error(`Error: ${msg}`)
      Js.Console.log("\nUse --help for usage information")
      exit(1)
    }
  | Ok(config) => {
      if args.daemon {
        Js.Console.log("Starting in daemon mode...")
        await Pipeline.runContinuous(config)
      } else {
        let result = await Pipeline.run(config)
        switch result {
        | Ok(_) => exit(0)
        | Error(msg) => {
            Js.Console.error(`Pipeline failed: ${msg}`)
            exit(1)
          }
        }
      }
    }
  }
}

// Auto-run if executed directly
let _ = main()
