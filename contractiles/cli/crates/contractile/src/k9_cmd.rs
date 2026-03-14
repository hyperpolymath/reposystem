// SPDX-License-Identifier: PMPL-1.0-or-later
// k9_cmd.rs — `k9` subcommand: K9 Nickel component operations.
//
// K9 contractiles are self-validating components written in Nickel. This
// subcommand bridges to the `nickel` binary for evaluation and type checking,
// and handles the three security levels (Kennel/Yard/Hunt) with appropriate
// safety checks.
//
// Commands:
//   k9 eval FILE       — evaluate a K9 component (Kennel/Yard level)
//   k9 run FILE        — execute Hunt-level recipes (signature check)
//   k9 typecheck FILE  — validate Nickel contracts
//   k9 info FILE       — display component pedigree and security level
//
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)

use anyhow::{bail, Context, Result};
use clap::{Parser, Subcommand};
use colored::Colorize;
use contractile_core::k9::{self, LeashLevel};
use std::path::Path;
use std::process::Command;

#[derive(Subcommand, Clone)]
pub enum K9Action {
    /// Evaluate a K9 component and display its exported JSON
    Eval {
        /// Path to the .k9.ncl file
        file: String,

        /// Output format: json (default), pretty
        #[arg(long, default_value = "pretty")]
        format: String,
    },

    /// Execute Hunt-level recipes from a K9 component
    Run {
        /// Path to the .k9.ncl file
        file: String,

        /// Specific recipe to run (default: the component's default recipe)
        #[arg(long)]
        recipe: Option<String>,

        /// Preview commands without executing them
        #[arg(long)]
        dry_run: bool,

        /// Skip signature verification (DANGEROUS — use only for local dev)
        #[arg(long)]
        no_verify: bool,
    },

    /// Validate Nickel contracts without evaluating
    Typecheck {
        /// Path to the .k9.ncl file
        file: String,
    },

    /// Display component pedigree, security level, and available recipes
    Info {
        /// Path to the .k9.ncl file
        file: String,
    },
}

/// Entry point when invoked as a symlink (`k9 eval`, `k9 run`, etc.).
pub fn run_from_args() -> Result<()> {
    #[derive(Parser)]
    #[command(name = "k9", about = "K9 Nickel component operations")]
    struct K9Cli {
        #[command(subcommand)]
        action: K9Action,
    }

    let cli = K9Cli::parse();
    run(cli.action)
}

/// Execute a k9 action.
pub fn run(action: K9Action) -> Result<()> {
    match action {
        K9Action::Eval { file, format } => {
            let path = Path::new(&file);
            let component = k9::evaluate(path)?;

            match format.as_str() {
                "json" => {
                    println!(
                        "{}",
                        serde_json::to_string(&component.raw_json)
                            .context("serialising JSON")?
                    );
                }
                "pretty" | _ => {
                    println!(
                        "{}",
                        serde_json::to_string_pretty(&component.raw_json)
                            .context("serialising JSON")?
                    );
                }
            }
            Ok(())
        }

        K9Action::Run {
            file,
            recipe,
            dry_run,
            no_verify,
        } => {
            let path = Path::new(&file);
            let component = k9::evaluate(path)?;

            // ── Security level check ──
            let level = component.leash_level();
            if level != LeashLevel::Hunt {
                println!(
                    "{} Component is {} — no recipes to execute",
                    "k9:".bold(),
                    level,
                );
                println!("Use `k9 eval` for Kennel/Yard components");
                return Ok(());
            }

            // ── Signature check ──
            if component.requires_signature() && !no_verify {
                let sig_path = format!("{}.sig", file);
                let pub_path = format!("{}.pub", file);

                if !Path::new(&sig_path).exists() {
                    bail!(
                        "Hunt-level component requires signature but {} not found.\n\
                         Use --no-verify for local development only.",
                        sig_path
                    );
                }

                // Verify the signature if a public key is available.
                if Path::new(&pub_path).exists() {
                    println!("  {} Verifying signature...", "k9:".bold());
                    let verify_status = Command::new("openssl")
                        .args([
                            "dgst",
                            "-sha256",
                            "-verify",
                            &pub_path,
                            "-signature",
                            &sig_path,
                            &file,
                        ])
                        .output()
                        .context("running openssl for signature verification")?;

                    if verify_status.status.success() {
                        println!(
                            "  {} Signature verified against {}",
                            "VERIFIED".green().bold(),
                            pub_path
                        );
                    } else {
                        let stderr = String::from_utf8_lossy(&verify_status.stderr);
                        bail!(
                            "Signature verification FAILED for Hunt-level component.\n\
                             sig: {}\n\
                             pub: {}\n\
                             openssl: {}",
                            sig_path,
                            pub_path,
                            stderr.trim()
                        );
                    }
                } else {
                    // Signature file exists but no public key — warn but proceed.
                    println!(
                        "  {} Signature file found but no public key at {}",
                        "WARNING".yellow().bold(),
                        pub_path
                    );
                    println!(
                        "  {} Signature cannot be verified — proceeding on trust",
                        "WARNING".yellow().bold()
                    );
                }
            }

            if component.recipes.is_empty() {
                println!("{}", "No recipes found in K9 component".yellow());
                return Ok(());
            }

            // Determine which recipe to run.
            let target_recipe = recipe.as_deref().unwrap_or_else(|| {
                // Look for the default recipe pointer.
                component
                    .raw_json
                    .get("recipes")
                    .and_then(|r| r.get("default"))
                    .and_then(|d| d.get("recipe"))
                    .and_then(|r| r.as_str())
                    .unwrap_or("setup")
            });

            // Find and execute the recipe.
            let recipe_def = component
                .recipes
                .iter()
                .find(|r| r.name == target_recipe)
                .with_context(|| {
                    let available: Vec<&str> =
                        component.recipes.iter().map(|r| r.name.as_str()).collect();
                    format!(
                        "recipe '{}' not found. Available: {}",
                        target_recipe,
                        available.join(", ")
                    )
                })?;

            println!(
                "{} Running recipe '{}' ({} command(s))",
                "k9:".bold(),
                target_recipe.cyan(),
                recipe_def.commands.len()
            );

            for cmd in &recipe_def.commands {
                if dry_run {
                    println!("  {} {}", "[DRY-RUN]".cyan(), cmd);
                    continue;
                }

                println!("  {} {}", "$".dimmed(), cmd);
                let status = Command::new("sh")
                    .args(["-c", cmd])
                    .status()
                    .with_context(|| format!("executing K9 recipe command: {}", cmd))?;

                if !status.success() {
                    bail!(
                        "K9 recipe '{}' command failed (exit {}): {}",
                        target_recipe,
                        status.code().unwrap_or(-1),
                        cmd
                    );
                }
            }

            if !dry_run {
                println!("  {} Recipe '{}' complete", "DONE".green().bold(), target_recipe);
            }
            Ok(())
        }

        K9Action::Typecheck { file } => {
            let path = Path::new(&file);
            k9::typecheck(path)?;
            println!(
                "{} {} passes type checking",
                "OK".green().bold(),
                file
            );
            Ok(())
        }

        K9Action::Info { file } => {
            let path = Path::new(&file);
            let component = k9::evaluate(path)?;

            println!("{}", "=== K9 Component Info ===".bold());
            println!("  File:     {}", file);
            println!("  Security: {}", component.leash_level());

            if let Some(pedigree) = &component.pedigree {
                if let Some(meta) = &pedigree.metadata {
                    if let Some(name) = &meta.name {
                        println!("  Name:     {}", name);
                    }
                    if let Some(ver) = &meta.version {
                        println!("  Version:  {}", ver);
                    }
                    if let Some(desc) = &meta.description {
                        println!("  About:    {}", desc);
                    }
                    if let Some(author) = &meta.author {
                        println!("  Author:   {}", author);
                    }
                }
                if let Some(schema) = &pedigree.schema_version {
                    println!("  Schema:   {}", schema);
                }
            }

            if component.requires_signature() {
                println!("  Signed:   {} (signature required)", "YES".yellow());
            }

            if !component.recipes.is_empty() {
                println!();
                println!("  {}:", "Recipes".bold());
                for recipe in &component.recipes {
                    let desc = recipe
                        .description
                        .as_deref()
                        .unwrap_or("");
                    println!(
                        "    {} — {} ({} cmd(s))",
                        recipe.name.cyan(),
                        desc,
                        recipe.commands.len()
                    );
                }
            }

            Ok(())
        }
    }
}
