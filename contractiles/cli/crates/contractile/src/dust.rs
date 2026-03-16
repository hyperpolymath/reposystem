// SPDX-License-Identifier: PMPL-1.0-or-later
// dust.rs — `dust` subcommand: Recovery & rollback from Dustfile.a2ml.
//
// Dust provides the "undo layer" for contractile-managed repos. Each action
// in the Dustfile declares a recovery path: handler for log replay, rollback
// for file reversion, undo for deployment failure, transform for event mapping.
//
// Unlike must/trust which run all checks by default, dust actions are
// invoked selectively — you rollback a specific thing, not everything.
//
// Commands:
//   dust status           — list available recovery actions
//   dust rollback NAME    — execute a named rollback
//   dust replay NAME      — replay a named handler
//   dust run NAME         — execute any dust action by name
//   dust list             — list all dust actions
//
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)

use anyhow::{bail, Context, Result};
use clap::{Parser, Subcommand};
use colored::Colorize;
use contractile_core::{a2ml, filenames, find_contractile};
use std::fs;
use std::process::Command;

#[derive(Subcommand, Clone)]
pub enum DustAction {
    /// Show available recovery/rollback actions
    Status {
        #[arg(long)]
        file: Option<String>,
    },

    /// Execute a named rollback action
    Rollback {
        /// Name of the rollback target (matches ### heading in Dustfile.a2ml)
        name: String,

        #[arg(long)]
        dry_run: bool,

        #[arg(long, short)]
        verbose: bool,

        #[arg(long)]
        file: Option<String>,
    },

    /// Replay a named handler (e.g. decision log replay)
    Replay {
        /// Name of the handler to replay
        name: String,

        #[arg(long)]
        dry_run: bool,

        #[arg(long, short)]
        verbose: bool,

        #[arg(long)]
        file: Option<String>,
    },

    /// Execute any dust action by subsection name
    Run {
        /// Name of the dust action (matches ### heading)
        name: String,

        #[arg(long)]
        dry_run: bool,

        #[arg(long, short)]
        verbose: bool,

        #[arg(long)]
        file: Option<String>,
    },

    /// List all dust actions with their types
    List {
        #[arg(long)]
        file: Option<String>,
    },
}

/// Entry point when invoked as a symlink (`dust status`, `dust rollback`, etc.).
pub fn run_from_args() -> Result<()> {
    #[derive(Parser)]
    #[command(name = "dust", about = "Recovery & rollback from Dustfile.a2ml")]
    struct DustCli {
        #[command(subcommand)]
        action: DustAction,
    }

    let cli = DustCli::parse();
    run(cli.action)
}

/// Execute a dust action.
pub fn run(action: DustAction) -> Result<()> {
    match action {
        DustAction::Status { file } | DustAction::List { file } => {
            let doc = load_dustfile(file.as_deref())?;
            list_actions(&doc);
            Ok(())
        }
        DustAction::Rollback {
            name,
            dry_run,
            verbose,
            file,
        } => {
            let doc = load_dustfile(file.as_deref())?;
            run_action(&doc, &name, Some("rollback"), verbose, dry_run)
        }
        DustAction::Replay {
            name,
            dry_run,
            verbose,
            file,
        } => {
            let doc = load_dustfile(file.as_deref())?;
            run_action(&doc, &name, Some("handler"), verbose, dry_run)
        }
        DustAction::Run {
            name,
            dry_run,
            verbose,
            file,
        } => {
            let doc = load_dustfile(file.as_deref())?;
            // Run any executable action matching the name, regardless of key type.
            run_action(&doc, &name, None, verbose, dry_run)
        }
    }
}

/// Load and parse the Dustfile.
fn load_dustfile(explicit_path: Option<&str>) -> Result<a2ml::A2mlDocument> {
    let path = if let Some(p) = explicit_path {
        std::path::PathBuf::from(p)
    } else {
        find_contractile(filenames::DUSTFILE_A2ML)
            .context("Dustfile.a2ml not found. Searched: contractiles/dust/, dust/, ./")?
    };

    let content = fs::read_to_string(&path)
        .with_context(|| format!("reading Dustfile: {}", path.display()))?;

    a2ml::parse(&content).with_context(|| format!("parsing Dustfile: {}", path.display()))
}

/// List all available dust actions with their types and descriptions.
fn list_actions(doc: &a2ml::A2mlDocument) {
    let items = doc.executable_items();
    if items.is_empty() {
        println!("{}", "No recovery actions found in Dustfile".yellow());
        return;
    }

    println!("{}", "Available dust recovery actions:".bold());
    for item in &items {
        let desc = item.description.unwrap_or("");
        let key_tag = match item.key {
            "rollback" => "rollback".yellow(),
            "undo" => "undo".red(),
            "handler" => "handler".cyan(),
            "transform" => "transform".blue(),
            other => other.normal(),
        };
        println!(
            "  {} [{}] — {}",
            item.subsection.cyan(),
            key_tag,
            desc
        );
    }
}

/// Execute a dust action by name, optionally filtering by key type.
/// Checks preconditions before executing, runs verify_after on success.
fn run_action(
    doc: &a2ml::A2mlDocument,
    name: &str,
    key_filter: Option<&str>,
    verbose: bool,
    dry_run: bool,
) -> Result<()> {
    let items = doc.executable_items();

    // Find matching items — if key_filter is set, only match that key type.
    let matching: Vec<_> = items
        .iter()
        .filter(|i| {
            i.subsection == name && key_filter.map_or(true, |k| i.key == k)
        })
        .collect();

    if matching.is_empty() {
        let available: Vec<String> = items
            .iter()
            .map(|i| format!("{} [{}]", i.subsection, i.key))
            .collect();
        bail!(
            "dust action '{}'{} not found. Available:\n  {}",
            name,
            key_filter
                .map(|k| format!(" (type: {})", k))
                .unwrap_or_default(),
            available.join("\n  ")
        );
    }

    // Look up precondition, verify_after, and blast_radius from the subsection.
    let subsection_meta = doc.sections.iter()
        .flat_map(|s| s.subsections.iter())
        .find(|sub| sub.name == name);

    let precondition = subsection_meta.and_then(|s| s.get("precondition"));
    let verify_after = subsection_meta.and_then(|s| s.get("verify_after"));
    let blast_radius = subsection_meta.and_then(|s| s.get("blast_radius"));

    for item in &matching {
        let desc = item.description.unwrap_or(item.subsection);

        if dry_run {
            if let Some(pre) = precondition {
                println!("  {} precondition: {}", "[DRY-RUN]".cyan(), pre);
            }
            println!(
                "  {} [{}] {} → {}",
                "[DRY-RUN]".cyan(),
                item.key,
                desc,
                item.command
            );
            if let Some(verify) = verify_after {
                println!("  {} verify_after: {}", "[DRY-RUN]".cyan(), verify);
            }
            continue;
        }

        // ── Precondition check ──
        if let Some(pre_cmd) = precondition {
            if verbose {
                println!("  {} precondition: {}", "checking".dimmed(), pre_cmd);
            }
            let pre_status = Command::new("bash")
                .args(["-c", pre_cmd])
                .status()
                .with_context(|| format!("running precondition for: {}", name))?;

            if !pre_status.success() {
                bail!(
                    "precondition failed for dust action '{}': {}",
                    name,
                    pre_cmd
                );
            }
            if verbose {
                println!("  {} precondition passed", "OK".green());
            }
        }

        // ── Show blast radius warning ──
        if let Some(radius) = blast_radius {
            match radius {
                "cluster" | "global" => {
                    println!(
                        "  {} blast radius: {} — proceed with caution",
                        "WARNING".yellow().bold(),
                        radius.red().bold()
                    );
                }
                _ => {
                    if verbose {
                        println!("  {} blast radius: {}", "info".dimmed(), radius);
                    }
                }
            }
        }

        // ── Execute the action ──
        println!(
            "{} Executing {} for {}...",
            "dust:".bold(),
            item.key.yellow(),
            item.subsection.cyan()
        );

        if verbose {
            println!("  {}", item.command.dimmed());
        }

        let status = Command::new("bash")
            .args(["-c", item.command])
            .status()
            .with_context(|| format!("executing dust action: {}", item.subsection))?;

        if !status.success() {
            println!("  {} {}", "FAILED".red().bold(), desc);
            bail!(
                "dust {} '{}' failed (exit {})",
                item.key,
                name,
                status.code().unwrap_or(-1)
            );
        }

        println!("  {} {}", "DONE".green().bold(), desc);

        // ── Post-recovery verification ──
        if let Some(verify_cmd) = verify_after {
            println!(
                "  {} verifying recovery...",
                "dust:".bold()
            );
            if verbose {
                println!("  {}", verify_cmd.dimmed());
            }
            let verify_status = Command::new("bash")
                .args(["-c", verify_cmd])
                .status()
                .with_context(|| format!("running verify_after for: {}", name))?;

            if verify_status.success() {
                println!("  {} post-recovery verification passed", "VERIFIED".green().bold());
            } else {
                println!(
                    "  {} post-recovery verification failed: {}",
                    "WARNING".yellow().bold(),
                    verify_cmd
                );
            }
        }
    }

    Ok(())
}
