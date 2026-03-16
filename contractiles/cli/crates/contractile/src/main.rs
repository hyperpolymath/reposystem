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

#![forbid(unsafe_code)]
mod doctor;
mod dust;
mod gen_just;
mod init;
mod intend;
mod k9_cmd;
mod must;
mod status;
mod trust;

use clap::{CommandFactory, Parser, Subcommand};
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

    /// Scaffold contractile files into a repository
    Init {
        /// Project name (auto-detected from Cargo.toml/deno.json if omitted)
        #[arg(long)]
        name: Option<String>,

        /// Overwrite existing contractile files
        #[arg(long)]
        force: bool,
    },

    /// Show unified status dashboard across all contractile types
    Status {
        /// Quick mode: just count items without running checks
        #[arg(long, short)]
        quick: bool,
    },

    /// Diagnose tooling availability and versions
    Doctor,

    /// Create symlinks (must, trust, dust, intend, k9) pointing to this binary
    Setup,

    /// Generate shell completions
    Completions {
        /// Shell to generate completions for (bash, zsh, fish, elvish, powershell)
        shell: clap_complete::Shell,
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

/// Create symlinks for must, trust, dust, intend, k9 alongside the contractile binary.
fn setup_symlinks() -> anyhow::Result<()> {
    let exe = env::current_exe()?;
    let dir = exe
        .parent()
        .ok_or_else(|| anyhow::anyhow!("cannot determine binary directory"))?;

    let commands = ["must", "trust", "dust", "intend", "k9"];

    for cmd in &commands {
        let link_path = dir.join(cmd);

        // Remove existing symlink/file if present
        if link_path.exists() || link_path.symlink_metadata().is_ok() {
            std::fs::remove_file(&link_path).ok();
        }

        #[cfg(unix)]
        std::os::unix::fs::symlink(&exe, &link_path)?;

        #[cfg(windows)]
        std::fs::copy(&exe, &link_path)?;

        println!("  {} → {}", cmd, exe.display());
    }

    println!(
        "\n{} symlinks created in {}",
        commands.len(),
        dir.display()
    );
    println!("Make sure {} is in your PATH.", dir.display());

    Ok(())
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
        Some(Commands::Init { name, force }) => init::run(name.as_deref(), force),
        Some(Commands::Status { quick }) => status::run(quick),
        Some(Commands::Doctor) => doctor::run(),
        Some(Commands::Setup) => setup_symlinks(),
        Some(Commands::Completions { shell }) => {
            clap_complete::generate(
                shell,
                &mut Cli::command(),
                "contractile",
                &mut std::io::stdout(),
            );
            Ok(())
        }
        None => {
            // No subcommand — print help.
            Cli::command().print_help()?;
            println!();
            Ok(())
        }
    }
}
