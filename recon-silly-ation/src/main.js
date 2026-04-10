// SPDX-License-Identifier: PMPL-1.0-or-later
// Deno main entry point for documentation reconciliation
// Replaces Node.js/npm with Deno runtime

import { parseArgs } from "@std/cli/parse_args.ts";
import { load as loadEnv } from "@std/dotenv/mod.ts";

// Load WASM modules for acceleration
import { initWasm, hashContentWasm } from "./wasm/mod.js";

// Import ReScript-generated modules
// Note: ReScript compiles to ES modules that Deno can import
import * as Pipeline from "../lib/js/src/Pipeline.bs.js";
import * as Types from "../lib/js/src/Types.bs.js";

// Load environment variables
const env = await loadEnv({ export: true });

// Initialize WASM modules
await initWasm();

function printHelp() {
  console.log(`
Documentation Reconciliation System (Deno Edition)
===================================================

Usage: deno run --allow-read --allow-env --allow-net src/main.js [command] [options]

Commands:
  scan              Scan repositories once
  daemon            Run in continuous daemon mode
  compile           Compile to standalone AOT binary
  help              Show this help message

Options:
  --repo <path>             Repository path (can specify multiple)
  --daemon                  Run in daemon mode
  --interval <seconds>      Scan interval (default: 300)
  --threshold <float>       Auto-resolve threshold (default: 0.9)
  --arango-url <url>        ArangoDB URL
  --arango-db <name>        Database name
  --arango-user <user>      Username
  --arango-password <pass>  Password

Environment Variables:
  ARANGO_URL                ArangoDB URL
  ARANGO_DATABASE           Database name
  ARANGO_USERNAME           Username
  ARANGO_PASSWORD           Password

Examples:
  # Scan a repository
  deno run --allow-read --allow-env --allow-net src/main.js scan --repo /path/to/repo

  # Compile to AOT binary (no runtime needed)
  deno task compile:aot

  # Run compiled binary
  ./bin/recon-silly-ation-aot scan --repo /repo

  # Daemon mode with WASM acceleration
  deno run --allow-read --allow-env --allow-net src/main.js daemon --repo /repo --interval 300
`);
}

async function main() {
  const args = parseArgs(Deno.args, {
    boolean: ["daemon", "help"],
    string: [
      "repo",
      "arango-url",
      "arango-db",
      "arango-user",
      "arango-password",
    ],
    collect: ["repo"],
    default: {
      threshold: 0.9,
      interval: 300,
    },
  });

  const command = args._[0]?.toString() || "help";

  if (args.help || command === "help") {
    printHelp();
    Deno.exit(0);
  }

  // Build configuration
  const config = {
    arangoUrl: args["arango-url"] || Deno.env.get("ARANGO_URL") || "http://localhost:8529",
    arangoDatabase: args["arango-db"] || Deno.env.get("ARANGO_DATABASE") || "reconciliation",
    arangoUsername: args["arango-user"] || Deno.env.get("ARANGO_USERNAME") || "root",
    arangoPassword: args["arango-password"] || Deno.env.get("ARANGO_PASSWORD") || "",
    autoResolveThreshold: args.threshold || 0.9,
    repositoryPaths: args.repo || [],
    scanInterval: args.daemon ? (args.interval || 300) : null,
  };

  if (config.repositoryPaths.length === 0) {
    console.error("Error: No repositories specified. Use --repo <path>");
    Deno.exit(1);
  }

  console.log("🚀 Deno-powered Documentation Reconciliation System");
  console.log("⚡ WASM acceleration enabled");
  console.log("");

  switch (command) {
    case "scan":
      console.log("Running single scan...");
      // Call ReScript Pipeline
      await Pipeline.run(config);
      break;

    case "daemon":
      console.log("Starting daemon mode...");
      await Pipeline.runContinuous(config);
      break;

    case "compile":
      console.log("Use: deno task compile:aot");
      break;

    default:
      console.error(`Unknown command: ${command}`);
      console.log("Use 'help' for usage information");
      Deno.exit(1);
  }
}

// Run main
if (import.meta.main) {
  await main();
}
