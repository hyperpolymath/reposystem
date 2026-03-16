// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//
//! git-morph — Transform repos between monorepo components and standalone repos.
//!
//! A single git extension with directional subcommands:
//!   - `git morph inflate` — monorepo component → standalone repo
//!   - `git morph deflate` — standalone repo → monorepo component
//!   - `git morph list`    — list morphable components
//!   - `git morph diff`    — preview changes without writing

#![forbid(unsafe_code)]
use clap::{Parser, Subcommand};
use std::path::PathBuf;
use tracing_subscriber::EnvFilter;

mod deflate;
mod detect;
mod diff;
mod history;
mod inflate;
mod manifest;
mod template;

/// Transform repos between monorepo components and standalone repos.
#[derive(Parser)]
#[command(name = "git-morph", version, about, long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// Extract a monorepo component into a standalone repo.
    Inflate {
        /// Path to the component within the monorepo.
        component: String,

        /// Output directory for the standalone repo.
        #[arg(short, long)]
        output: Option<String>,

        /// Template to use (overrides manifest).
        #[arg(short, long)]
        template: Option<String>,

        /// Preserve git history for owned files.
        #[arg(short = 'H', long)]
        with_history: bool,

        /// Preview without writing files.
        #[arg(short = 'n', long)]
        dry_run: bool,

        /// Verbose output.
        #[arg(short, long)]
        verbose: bool,
    },

    /// Pack a standalone repo into a monorepo as a component.
    Deflate {
        /// Path to the standalone repo.
        repo: String,

        /// Target monorepo directory.
        #[arg(short, long)]
        into: Option<String>,

        /// Path within the monorepo to place the component.
        #[arg(short, long)]
        at: Option<String>,

        /// Squash history into a single commit.
        #[arg(short, long)]
        squash: bool,

        /// Preview without writing files.
        #[arg(short = 'n', long)]
        dry_run: bool,

        /// Verbose output.
        #[arg(short, long)]
        verbose: bool,
    },

    /// List components with .morph.a2ml manifests.
    List {
        /// Directory to scan.
        #[arg(short, long, default_value = ".")]
        dir: String,

        /// Scan subdirectories recursively.
        #[arg(short, long)]
        recursive: bool,
    },

    /// Preview what inflate or deflate would change.
    Diff {
        /// Direction: "inflate" or "deflate".
        direction: String,

        /// Path to component or repo.
        path: String,
    },
}

fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_default_env())
        .init();

    let cli = Cli::parse();

    match cli.command {
        Command::Inflate {
            component,
            output,
            template,
            with_history,
            dry_run,
            verbose,
        } => {
            let opts = inflate::InflateOpts {
                component_path: component.into(),
                output_dir: output.map(Into::into),
                template_override: template,
                with_history,
                dry_run,
                verbose,
            };
            inflate::run(opts)?;
        }

        Command::Deflate {
            repo,
            into,
            at,
            squash,
            dry_run,
            verbose,
        } => {
            let opts = deflate::DeflateOpts {
                repo_path: repo.into(),
                monorepo_dir: into.map(Into::into),
                target_path: at,
                squash,
                dry_run,
                verbose,
            };
            deflate::run(opts)?;
        }

        Command::List { dir, recursive } => {
            let manifests = manifest::find_manifests(&PathBuf::from(dir), recursive)?;
            if manifests.is_empty() {
                println!("No .morph.a2ml manifests found.");
            } else {
                println!("Found {} morphable component(s):\n", manifests.len());
                for m in &manifests {
                    println!(
                        "  {} ({})",
                        m.component.name,
                        m.component.path.display()
                    );
                    println!(
                        "    owned: {} pattern(s), inherited: {} pattern(s)",
                        m.files.owned.len(),
                        m.files.inherited.len()
                    );
                    if let Some(ref tmpl) = m.template {
                        println!("    template: {}", tmpl.name);
                    }
                    println!();
                }
            }
        }

        Command::Diff { direction, path } => {
            diff::run(&direction, &path)?;
        }
    }

    Ok(())
}
