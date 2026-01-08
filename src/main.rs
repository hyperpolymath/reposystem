// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//
//! Reposystem CLI - Railway yard for your repository ecosystem

use anyhow::Result;
use clap::{Parser, Subcommand};

// Use the library modules
use reposystem::commands;

#[derive(Parser)]
#[command(name = "reposystem")]
#[command(author, version, about, long_about = None)]
#[command(propagate_version = true)]
struct Cli {
    /// Increase verbosity (-v, -vv, -vvv)
    #[arg(short, long, action = clap::ArgAction::Count)]
    verbose: u8,

    /// Quiet mode (suppress non-error output)
    #[arg(short, long)]
    quiet: bool,

    /// Configuration file path
    #[arg(short, long, env = "REPOSYSTEM_CONFIG")]
    config: Option<std::path::PathBuf>,

    /// Data directory override
    #[arg(long, env = "REPOSYSTEM_DATA_DIR")]
    data_dir: Option<std::path::PathBuf>,

    /// Disable colored output
    #[arg(long, env = "NO_COLOR")]
    no_color: bool,

    /// Output in JSON format
    #[arg(long)]
    json: bool,

    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Scan repositories and build dependency graph
    Scan {
        /// Path to scan
        #[arg(default_value = ".")]
        path: std::path::PathBuf,

        /// Deep scan with full metadata
        #[arg(long)]
        deep: bool,

        /// Shallow scan (fast)
        #[arg(long)]
        shallow: bool,

        /// Extract metadata
        #[arg(long)]
        metadata: bool,

        /// Detect workspaces (Cargo, npm, etc.)
        #[arg(long)]
        detect_workspaces: bool,
    },

    /// Launch interactive TUI
    View,

    /// Export graph to various formats
    Export {
        /// Output format (dot, json, yaml, toml)
        #[arg(short, long, default_value = "dot")]
        format: String,

        /// Output file (stdout if not specified)
        #[arg(short, long)]
        output: Option<std::path::PathBuf>,

        /// Filter by aspect
        #[arg(long)]
        aspect: Option<String>,
    },

    /// Manage edges (relationships) between repositories
    Edge {
        /// Action: add, remove, list
        action: String,

        /// Source repository (name or ID)
        #[arg(long)]
        from: Option<String>,

        /// Target repository (name or ID)
        #[arg(long)]
        to: Option<String>,

        /// Relationship type: uses, provides, extends, mirrors, replaces
        #[arg(long, default_value = "uses")]
        rel: Option<String>,

        /// Channel type: api, artifact, config, runtime, human, unknown
        #[arg(long)]
        channel: Option<String>,

        /// Human-readable label
        #[arg(long)]
        label: Option<String>,

        /// Evidence reference (file path, URL, etc.)
        #[arg(long)]
        evidence: Option<String>,
    },

    /// Manage repository groups
    Group {
        /// Action: create, add, remove, delete, list, show
        action: String,

        /// Group name
        name: Option<String>,

        /// Repositories to add/remove
        repos: Vec<String>,
    },

    /// Manage aspect annotations
    Aspect {
        /// Action: tag, remove, list, show, filter
        action: String,

        /// Target repository or edge (name or ID)
        #[arg(long)]
        target: Option<String>,

        /// Aspect name (security, reliability, etc.)
        #[arg(long)]
        aspect: Option<String>,

        /// Weight (0-3)
        #[arg(long)]
        weight: Option<u8>,

        /// Polarity: risk, strength, neutral
        #[arg(long)]
        polarity: Option<String>,

        /// Reason for annotation
        #[arg(long)]
        reason: Option<String>,

        /// Evidence reference
        #[arg(long)]
        evidence: Option<String>,
    },

    /// Manage scenarios
    Scenario {
        /// Action: create, delete, switch, compare
        action: String,

        /// Scenario name
        name: String,

        /// Base scenario for comparison
        #[arg(long)]
        base: Option<String>,
    },

    /// Identify weak links in ecosystem
    WeakLinks {
        /// Aspect to analyze
        #[arg(long)]
        aspect: Option<String>,

        /// Minimum severity
        #[arg(long)]
        severity: Option<String>,
    },

    /// Get or set configuration
    Config {
        /// Configuration key
        key: String,

        /// Value to set (omit to get)
        value: Option<String>,
    },

    /// Generate shell completions
    Completions {
        /// Shell type (bash, zsh, fish, powershell)
        shell: clap_complete::Shell,
    },
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    // Initialize logging
    let log_level = match cli.verbose {
        0 if cli.quiet => tracing::Level::ERROR,
        0 => tracing::Level::INFO,
        1 => tracing::Level::DEBUG,
        _ => tracing::Level::TRACE,
    };

    tracing_subscriber::fmt()
        .with_max_level(log_level)
        .with_target(false)
        .init();

    // Execute command
    match cli.command {
        Commands::Scan { path, deep, shallow, metadata, detect_workspaces } => {
            commands::scan::run(path, deep, shallow, metadata, detect_workspaces)
        }
        Commands::View => {
            commands::view::run()
        }
        Commands::Export { format, output, aspect } => {
            commands::export::run(&format, output, aspect)
        }
        Commands::Edge { action, from, to, rel, channel, label, evidence } => {
            commands::edge::run(&action, from, to, rel, channel, label, evidence)
        }
        Commands::Group { action, name, repos } => {
            commands::group::run(&action, name, repos)
        }
        Commands::Aspect { action, target, aspect, weight, polarity, reason, evidence } => {
            let args = commands::aspect::AspectArgs {
                weight,
                polarity,
                reason,
                evidence,
            };
            commands::aspect::run(&action, target, aspect, args)
        }
        Commands::Scenario { action, name, base } => {
            commands::scenario::run(&action, &name, base)
        }
        Commands::WeakLinks { aspect, severity } => {
            commands::weak_links::run(aspect, severity)
        }
        Commands::Config { key, value } => {
            commands::config::run(&key, value)
        }
        Commands::Completions { shell } => {
            commands::completions::run(shell)
        }
    }
}
