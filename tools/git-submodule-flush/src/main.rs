// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//! git-submodule-flush — Recursively commit and push dirty submodule trees bottom-up
//!
//! Walks a git repository's submodule tree depth-first, committing changes at
//! each level from the leaves upward. This ensures parent repos always point to
//! real, pushed commits rather than dirty submodule pointers.
//!
//! Designed as a standalone CLI tool that can also be invoked by Hypatia as a
//! fix-script for the "dirty-submodule-pointer" pattern.
//!
//! ## My-Lang Graduation Target
//!
//! This tool is the benchmark for my-lang stdlib readiness. When my-lang gains
//! process::spawn(), fs::walk_dir(), and fs::write(), it should be rewritten in
//! my-lang as a graduation exercise. The CLI contract and test suite remain the
//! same regardless of implementation language.
//!
//! ## Usage
//!
//!   git-submodule-flush [OPTIONS] [REPO]
//!
//!   # Preview what would be committed (default: dry-run)
//!   git-submodule-flush /path/to/monorepo
//!
//!   # Actually commit and push
//!   git-submodule-flush --execute /path/to/monorepo
//!
//!   # Limit recursion depth
//!   git-submodule-flush --execute --max-depth 3 /path/to/monorepo
//!
//!   # Skip specific repos
//!   git-submodule-flush --execute --skip idaptik --skip broken-repo /path/to/monorepo
//!
//!   # Custom commit message
//!   git-submodule-flush --execute --message "chore: flush submodules" /path/to/monorepo
//!
//!   # JSON output for Hypatia integration
//!   git-submodule-flush --json /path/to/monorepo

#![forbid(unsafe_code)]

use anyhow::{Context, Result};
use clap::Parser;
use std::collections::HashSet;
use std::path::PathBuf;

mod flush;
mod guards;

use flush::{FlushPlan, FlushResult};

/// git-submodule-flush — Recursively commit dirty submodule trees bottom-up
#[derive(Parser)]
#[command(name = "git-submodule-flush", version, about)]
struct Cli {
    /// Path to the git repository (default: current directory)
    #[arg(default_value = ".")]
    repo: PathBuf,

    /// Actually commit and push (default: dry-run preview)
    #[arg(long)]
    execute: bool,

    /// Maximum submodule recursion depth (0 = this repo only, no submodules)
    #[arg(long, default_value = "5")]
    max_depth: usize,

    /// Skip repos matching these names (repeatable)
    #[arg(long, action = clap::ArgAction::Append)]
    skip: Vec<String>,

    /// Commit message (default: "chore: flush submodule changes")
    #[arg(long, default_value = "chore: flush submodule changes")]
    message: String,

    /// Git author string (default: use git config)
    #[arg(long)]
    author: Option<String>,

    /// Push after committing
    #[arg(long, default_value = "true")]
    push: bool,

    /// Remote to push to
    #[arg(long, default_value = "origin")]
    remote: String,

    /// Maximum changed files before requiring --force-large (safety guard)
    #[arg(long, default_value = "50")]
    large_threshold: usize,

    /// Allow committing repos with more than --large-threshold changes
    #[arg(long)]
    force_large: bool,

    /// Run panic-attack assail before each commit
    #[arg(long)]
    panic_attack: bool,

    /// Output as JSON (for Hypatia recipe integration)
    #[arg(long)]
    json: bool,

    /// Verbose output
    #[arg(short, long)]
    verbose: bool,
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    tracing_subscriber::fmt()
        .with_env_filter(if cli.verbose {
            "debug"
        } else {
            "info"
        })
        .with_target(false)
        .init();

    let repo = cli.repo.canonicalize().context("Repository path not found")?;

    if !repo.join(".git").exists() {
        anyhow::bail!("{} is not a git repository", repo.display());
    }

    let skip_set: HashSet<String> = cli.skip.into_iter().collect();

    // Phase 1: Build the flush plan (always safe — read-only)
    let plan = FlushPlan::build(
        &repo,
        cli.max_depth,
        &skip_set,
        cli.large_threshold,
        cli.force_large,
    )?;

    if plan.is_empty() {
        if cli.json {
            println!("{}", serde_json::to_string_pretty(&FlushResult::clean())?);
        } else {
            println!("All submodules clean — nothing to flush.");
        }
        return Ok(());
    }

    // Display the plan
    if !cli.json {
        plan.display();
    }

    if !cli.execute {
        if cli.json {
            println!("{}", serde_json::to_string_pretty(&plan.to_preview())?);
        } else {
            println!("\nDry run — pass --execute to commit and push.");
        }
        return Ok(());
    }

    // Phase 2: Execute the plan bottom-up
    let result = plan.execute(
        &cli.message,
        cli.author.as_deref(),
        cli.push,
        &cli.remote,
        cli.panic_attack,
    )?;

    if cli.json {
        println!("{}", serde_json::to_string_pretty(&result)?);
    } else {
        result.display();
    }

    Ok(())
}
