// SPDX-License-Identifier: PMPL-1.0-or-later
// contractile — Unified CLI for the contractile system.
//
// Provides subcommands for each contractile type:
//   contractile must check|fix|enforce|list
//   contractile trust verify|hash|sign
//   contractile dust status|rollback|replay
//   contractile intend list|check|progress
//   contractile k9 eval|run|typecheck
//   contractile gen-just
//
// Can also be invoked via symlinks: `must`, `trust`, `dust`, `intend`, `k9`
// which behave as if the binary name were the subcommand.
//
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)

mod dust;
mod gen_just;
mod intend;
mod k9_cmd;
mod must;
mod trust;

use clap::{Parser, Subcommand};
use std::env;

/// Contractile — unified runner for Must/Trust/Dust/Intend/K9 contract files.
///
/// Each subcommand processes its corresponding A2ML contractile file and
/// executes the declared operations: checks, verifications, rollbacks,
/// intent reporting, or K9 component evaluation.
#[derive(Parser)]
#[command(name = "contractile", version, about)]
struct Cli {
    #[command(subcommand)]
    command: Option<Commands>,
}

#[derive(Subcommand)]
enum Commands {
    /// Physical state checks from Mustfile.a2ml (or mustfile.toml)
    Must {
        #[command(subcommand)]
        action: must::MustAction,
    },

    /// Integrity and provenance verification from Trustfile.a2ml
    Trust {
        #[command(subcommand)]
        action: trust::TrustAction,
    },

    /// Recovery and rollback actions from Dustfile.a2ml
    Dust {
        #[command(subcommand)]
        action: dust::DustAction,
    },

    /// Future intent and roadmap from Intentfile.a2ml
    Intend {
        #[command(subcommand)]
        action: intend::IntendAction,
    },

    /// K9 Nickel component operations
    K9 {
        #[command(subcommand)]
        action: k9_cmd::K9Action,
    },

    /// Generate contractile.just from all A2ML and K9 sources
    GenJust {
        /// Directory containing contractile files (default: ./contractiles/)
        #[arg(long, default_value = "contractiles")]
        dir: String,

        /// Output file path (default: contractile.just)
        #[arg(long, short, default_value = "contractile.just")]
        output: String,
    },
}

fn main() {
    // ── Symlink dispatch ──
    // If the binary was invoked as `must`, `trust`, `dust`, `intend`, or `k9`
    // (via a symlink), treat the binary name as the subcommand and re-parse
    // arguments with that prefix. We use argv[0] rather than current_exe()
    // because current_exe() resolves symlinks to the real binary path.
    let exe_name = env::args()
        .next()
        .and_then(|arg0| {
            std::path::Path::new(&arg0)
                .file_name()
                .map(|n| n.to_string_lossy().into_owned())
        })
        .unwrap_or_default();

    let result = match exe_name.as_str() {
        "must" => must::run_from_args(),
        "trust" => trust::run_from_args(),
        "dust" => dust::run_from_args(),
        "intend" => intend::run_from_args(),
        "k9" => k9_cmd::run_from_args(),
        _ => run_unified(),
    };

    if let Err(e) = result {
        eprintln!("Error: {:#}", e);
        std::process::exit(1);
    }
}

/// Run the unified `contractile <subcommand>` dispatcher.
fn run_unified() -> anyhow::Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Some(Commands::Must { action }) => must::run(action),
        Some(Commands::Trust { action }) => trust::run(action),
        Some(Commands::Dust { action }) => dust::run(action),
        Some(Commands::Intend { action }) => intend::run(action),
        Some(Commands::K9 { action }) => k9_cmd::run(action),
        Some(Commands::GenJust { dir, output }) => gen_just::run(&dir, &output),
        None => {
            // No subcommand — print help.
            use clap::CommandFactory;
            Cli::command().print_help()?;
            println!();
            Ok(())
        }
    }
}
