// SPDX-License-Identifier: PMPL-1.0-or-later
// trust.rs — `trust` subcommand: Integrity & provenance verification from Trustfile.a2ml.
//
// Trust handles cryptographic verification: hash checking, signature
// validation, provenance attestation, and post-quantum crypto verification.
// Each verification step in the Trustfile has a `command:` entry that is
// executed and its exit code checked.
//
// Commands:
//   trust verify         — run all verification steps
//   trust verify NAME    — run a single named verification
//   trust list           — list available verifications
//   trust hash FILE      — compute and display the SHA-256 hash of a file
//   trust sign FILE      — sign a file (placeholder for key management)
//
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)

use anyhow::{bail, Context, Result};
use clap::{Parser, Subcommand};
use colored::Colorize;
use contractile_core::{a2ml, filenames, find_contractile};
use std::fs;
use std::process::Command;

#[derive(Subcommand, Clone)]
pub enum TrustAction {
    /// Run all trust verifications (hash checks, signature validations)
    Verify {
        /// Run only a specific named verification
        name: Option<String>,

        #[arg(long, short)]
        verbose: bool,

        #[arg(long)]
        dry_run: bool,

        /// Output results as JSON (for CI/CD consumption)
        #[arg(long)]
        json: bool,

        #[arg(long)]
        file: Option<String>,
    },

    /// List available verification steps
    List {
        #[arg(long)]
        file: Option<String>,
    },

    /// Compute SHA-256 hash of a file
    Hash {
        /// Path to the file to hash
        path: String,
    },

    /// Sign a file (creates .sig alongside it)
    Sign {
        /// Path to the file to sign
        path: String,

        /// Path to the signing key
        #[arg(long)]
        key: Option<String>,
    },
}

/// Entry point when invoked as a symlink (`trust verify`, `trust list`, etc.).
pub fn run_from_args() -> Result<()> {
    #[derive(Parser)]
    #[command(name = "trust", about = "Integrity & provenance verification from Trustfile.a2ml")]
    struct TrustCli {
        #[command(subcommand)]
        action: TrustAction,
    }

    let cli = TrustCli::parse();
    run(cli.action)
}

/// Execute a trust action.
pub fn run(action: TrustAction) -> Result<()> {
    match action {
        TrustAction::Verify {
            name,
            verbose,
            dry_run,
            json,
            file,
        } => {
            let doc = load_trustfile(file.as_deref())?;
            if json {
                run_all_verifications_json(&doc)
            } else if let Some(name) = name {
                run_single_verification(&doc, &name, verbose, dry_run)
            } else {
                run_all_verifications(&doc, verbose, dry_run)
            }
        }
        TrustAction::List { file } => {
            let doc = load_trustfile(file.as_deref())?;
            list_verifications(&doc);
            Ok(())
        }
        TrustAction::Hash { path } => {
            let output = Command::new("sha256sum")
                .arg(&path)
                .output()
                .context("running sha256sum")?;
            if output.status.success() {
                print!("{}", String::from_utf8_lossy(&output.stdout));
            } else {
                bail!(
                    "sha256sum failed: {}",
                    String::from_utf8_lossy(&output.stderr)
                );
            }
            Ok(())
        }
        TrustAction::Sign { path, key } => {
            let key_path = key.as_deref().unwrap_or("signing.key");
            println!(
                "{} Signing {} with key {}",
                "trust:".bold(),
                path.cyan(),
                key_path.dimmed()
            );
            println!(
                "{}",
                "Sign operation is a placeholder — integrate with your key management system"
                    .yellow()
            );
            Ok(())
        }
    }
}

/// Load and parse the Trustfile.
fn load_trustfile(explicit_path: Option<&str>) -> Result<a2ml::A2mlDocument> {
    let path = if let Some(p) = explicit_path {
        std::path::PathBuf::from(p)
    } else {
        find_contractile(filenames::TRUSTFILE_A2ML)
            .context("Trustfile.a2ml not found. Searched: contractiles/trust/, trust/, ./")?
    };

    let content = fs::read_to_string(&path)
        .with_context(|| format!("reading Trustfile: {}", path.display()))?;

    a2ml::parse(&content).with_context(|| format!("parsing Trustfile: {}", path.display()))
}

/// Run all verification steps and report results.
fn run_all_verifications(doc: &a2ml::A2mlDocument, verbose: bool, dry_run: bool) -> Result<()> {
    let items = doc.executable_items();
    if items.is_empty() {
        println!("{}", "No verifications found in Trustfile".yellow());
        return Ok(());
    }

    println!(
        "{} {} verification(s)...",
        "trust:".bold(),
        items.len()
    );

    let mut passed = 0;
    let mut failed = 0;

    for item in &items {
        let desc = item.description.unwrap_or(item.subsection);

        if dry_run {
            println!("  {} {} → {}", "[DRY-RUN]".cyan(), desc, item.command);
            passed += 1;
            continue;
        }

        if verbose {
            println!("  {} {}", "Verifying:".dimmed(), item.command);
        }

        let status = Command::new("bash")
            .args(["-c", item.command])
            .status()
            .with_context(|| format!("executing verification: {}", item.subsection))?;

        if status.success() {
            println!("  {} {}", "VERIFIED".green().bold(), desc);
            passed += 1;
        } else {
            println!("  {} {}", "FAILED".red().bold(), desc);
            if verbose {
                println!("       command: {}", item.command);
            }
            failed += 1;
        }
    }

    println!();
    println!("{} verified, {} failed", passed, failed);

    if failed > 0 {
        bail!("{} trust verification(s) failed", failed);
    }
    Ok(())
}

/// Run a single named verification.
fn run_single_verification(
    doc: &a2ml::A2mlDocument,
    name: &str,
    verbose: bool,
    dry_run: bool,
) -> Result<()> {
    let items = doc.executable_items();
    let item = items
        .iter()
        .find(|i| i.subsection == name)
        .with_context(|| {
            let available: Vec<&str> = items.iter().map(|i| i.subsection).collect();
            format!(
                "verification '{}' not found. Available: {}",
                name,
                available.join(", ")
            )
        })?;

    let desc = item.description.unwrap_or(item.subsection);

    if dry_run {
        println!("[DRY-RUN] {} → {}", desc, item.command);
        return Ok(());
    }

    if verbose {
        println!("Verifying: {}", item.command);
    }

    let status = Command::new("bash")
        .args(["-c", item.command])
        .status()
        .with_context(|| format!("executing verification: {}", name))?;

    if status.success() {
        println!("{} {}", "VERIFIED".green().bold(), desc);
        Ok(())
    } else {
        println!("{} {}", "FAILED".red().bold(), desc);
        bail!("trust verification '{}' failed", name);
    }
}

/// Run all verifications and output results as JSON.
fn run_all_verifications_json(doc: &a2ml::A2mlDocument) -> Result<()> {
    let items = doc.executable_items();
    let mut results = Vec::new();

    for item in &items {
        let status = Command::new("bash")
            .args(["-c", item.command])
            .stdout(std::process::Stdio::null())
            .stderr(std::process::Stdio::null())
            .status()
            .with_context(|| format!("executing verification: {}", item.subsection))?;

        results.push(serde_json::json!({
            "name": item.subsection,
            "section": item.section,
            "description": item.description.unwrap_or(""),
            "command": item.command,
            "verified": status.success(),
            "exit_code": status.code().unwrap_or(-1),
        }));
    }

    let verified = results.iter().filter(|r| r["verified"] == true).count();
    let failed = results.len() - verified;

    let output = serde_json::json!({
        "tool": "trust",
        "total": results.len(),
        "verified": verified,
        "failed": failed,
        "verifications": results,
    });

    println!("{}", serde_json::to_string_pretty(&output)?);

    if failed > 0 {
        std::process::exit(2);
    }
    Ok(())
}

/// List all available verifications.
fn list_verifications(doc: &a2ml::A2mlDocument) {
    let items = doc.executable_items();
    if items.is_empty() {
        println!("{}", "No verifications found in Trustfile".yellow());
        return;
    }

    println!("{}", "Available trust verifications:".bold());
    for item in &items {
        let desc = item.description.unwrap_or("");
        println!("  {} — {}", item.subsection.cyan(), desc);
    }
}
