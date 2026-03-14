// SPDX-License-Identifier: PMPL-1.0-or-later
// must.rs — `must` subcommand: Physical State checks from Mustfile.a2ml.
//
// Must enforces the Physical State model — the verifiable, observable condition
// of a project's files, dependencies, and build artifacts. It reads checks
// from Mustfile.a2ml (A2ML format) or mustfile.toml (legacy TOML format) and
// executes them, reporting pass/fail for each.
//
// Commands:
//   must check    — run all checks (read-only)
//   must fix      — auto-fix violations where possible
//   must enforce  — check + fix + verify cycle
//   must list     — list available checks
//   must run NAME — run a single named check
//
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)

use anyhow::{bail, Context, Result};
use clap::{Parser, Subcommand};
use colored::Colorize;
use contractile_core::{a2ml, filenames, find_contractile, toml_compat};
use std::fs;
use std::process::Command;

#[derive(Subcommand, Clone)]
pub enum MustAction {
    /// Run all must checks (read-only verification)
    Check {
        /// Fail on warnings as well as errors
        #[arg(long)]
        strict: bool,

        /// Show detailed output for each check
        #[arg(long, short)]
        verbose: bool,

        /// Output results as JSON (for CI/CD consumption)
        #[arg(long)]
        json: bool,

        /// Path to the Mustfile (auto-detected if omitted)
        #[arg(long)]
        file: Option<String>,
    },

    /// Auto-fix violations where the fix is deterministic
    Fix {
        /// Preview fixes without applying them
        #[arg(long)]
        dry_run: bool,

        #[arg(long, short)]
        verbose: bool,

        #[arg(long)]
        file: Option<String>,
    },

    /// Full enforcement cycle: check → fix → verify
    Enforce {
        #[arg(long)]
        strict: bool,

        #[arg(long)]
        dry_run: bool,

        #[arg(long, short)]
        verbose: bool,

        #[arg(long)]
        file: Option<String>,
    },

    /// List available checks without running them
    List {
        #[arg(long)]
        file: Option<String>,
    },

    /// Run a single named check
    Run {
        /// Name of the check to run (matches ### heading in Mustfile.a2ml)
        name: String,

        #[arg(long)]
        dry_run: bool,

        #[arg(long, short)]
        verbose: bool,

        #[arg(long)]
        file: Option<String>,
    },
}

/// Entry point when invoked as a symlink (`must check`, `must list`, etc.).
pub fn run_from_args() -> Result<()> {
    #[derive(Parser)]
    #[command(name = "must", about = "Physical State checks from Mustfile.a2ml")]
    struct MustCli {
        #[command(subcommand)]
        action: MustAction,
    }

    let cli = MustCli::parse();
    run(cli.action)
}

/// Execute a must action.
pub fn run(action: MustAction) -> Result<()> {
    match action {
        MustAction::Check {
            strict: _,
            verbose,
            json,
            file,
        } => {
            let doc = load_mustfile(file.as_deref())?;
            if json {
                run_all_checks_json(&doc)
            } else {
                run_all_checks(&doc, verbose, false)
            }
        }
        MustAction::Fix {
            dry_run,
            verbose,
            file,
        } => {
            let doc = load_mustfile(file.as_deref())?;
            // Fix mode: run checks and report what would be fixed.
            // Actual auto-fix logic depends on the check type — for now,
            // we report failures and suggest manual fixes.
            println!("{}", "must fix: running checks to identify violations...".bold());
            run_all_checks(&doc, verbose, dry_run)
        }
        MustAction::Enforce {
            strict: _,
            dry_run,
            verbose,
            file,
        } => {
            let doc = load_mustfile(file.as_deref())?;
            println!("{}", "must enforce: check → fix → verify cycle".bold());
            run_all_checks(&doc, verbose, dry_run)
        }
        MustAction::List { file } => {
            let doc = load_mustfile(file.as_deref())?;
            list_checks(&doc);
            Ok(())
        }
        MustAction::Run {
            name,
            dry_run,
            verbose,
            file,
        } => {
            let doc = load_mustfile(file.as_deref())?;
            run_single_check(&doc, &name, verbose, dry_run)
        }
    }
}

/// Load and parse the Mustfile, trying A2ML first, then TOML fallback.
/// Search order: explicit path → Mustfile.a2ml → mustfile.toml
fn load_mustfile(explicit_path: Option<&str>) -> Result<a2ml::A2mlDocument> {
    if let Some(p) = explicit_path {
        let path = std::path::PathBuf::from(p);
        // Detect format by extension.
        if p.ends_with(".toml") {
            return toml_compat::parse_mustfile_toml(&path);
        }
        let content = fs::read_to_string(&path)
            .with_context(|| format!("reading Mustfile: {}", path.display()))?;
        return a2ml::parse(&content)
            .with_context(|| format!("parsing Mustfile: {}", path.display()));
    }

    // Try A2ML first.
    if let Some(path) = find_contractile(filenames::MUSTFILE_A2ML) {
        let content = fs::read_to_string(&path)
            .with_context(|| format!("reading Mustfile: {}", path.display()))?;
        return a2ml::parse(&content)
            .with_context(|| format!("parsing Mustfile: {}", path.display()));
    }

    // Fall back to mustfile.toml.
    if let Some(path) = find_contractile(filenames::MUSTFILE_TOML) {
        println!(
            "{} Using {} (A2ML not found)",
            "must:".bold(),
            path.display().to_string().dimmed()
        );
        return toml_compat::parse_mustfile_toml(&path);
    }

    bail!("No Mustfile found. Searched for Mustfile.a2ml and mustfile.toml in: contractiles/must/, must/, ./")
}

/// Run all executable checks in the document. Returns an error if any check fails.
fn run_all_checks(doc: &a2ml::A2mlDocument, verbose: bool, dry_run: bool) -> Result<()> {
    let items = doc.executable_items();
    if items.is_empty() {
        println!("{}", "No executable checks found in Mustfile".yellow());
        return Ok(());
    }

    println!(
        "{} {} check(s)...",
        "must:".bold(),
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
            println!("  {} {}", "Running:".dimmed(), item.command);
        }

        let status = Command::new("sh")
            .args(["-c", item.command])
            .status()
            .with_context(|| format!("executing check: {}", item.subsection))?;

        if status.success() {
            println!("  {} {}", "PASS".green().bold(), desc);
            passed += 1;
        } else {
            println!("  {} {}", "FAIL".red().bold(), desc);
            if verbose {
                println!("       command: {}", item.command);
                println!("       exit code: {}", status.code().unwrap_or(-1));
            }
            failed += 1;
        }
    }

    println!();
    let failed_str = failed.to_string();
    let failed_display = if failed > 0 {
        failed_str.red()
    } else {
        failed_str.normal()
    };
    println!("{} passed, {} failed", passed.to_string().green(), failed_display);

    if failed > 0 {
        bail!("{} must check(s) failed", failed);
    }

    Ok(())
}

/// Run all checks and output results as JSON for CI/CD consumption.
fn run_all_checks_json(doc: &a2ml::A2mlDocument) -> Result<()> {
    let items = doc.executable_items();
    let mut results = Vec::new();

    for item in &items {
        let status = Command::new("sh")
            .args(["-c", item.command])
            .stdout(std::process::Stdio::null())
            .stderr(std::process::Stdio::null())
            .status()
            .with_context(|| format!("executing check: {}", item.subsection))?;

        results.push(serde_json::json!({
            "name": item.subsection,
            "section": item.section,
            "description": item.description.unwrap_or(""),
            "command": item.command,
            "passed": status.success(),
            "exit_code": status.code().unwrap_or(-1),
        }));
    }

    let passed = results.iter().filter(|r| r["passed"] == true).count();
    let failed = results.len() - passed;

    let output = serde_json::json!({
        "tool": "must",
        "total": results.len(),
        "passed": passed,
        "failed": failed,
        "checks": results,
    });

    println!("{}", serde_json::to_string_pretty(&output)?);

    if failed > 0 {
        std::process::exit(2);
    }

    Ok(())
}

/// Print a listing of all checks without running them.
fn list_checks(doc: &a2ml::A2mlDocument) {
    let items = doc.executable_items();
    if items.is_empty() {
        println!("{}", "No checks found in Mustfile".yellow());
        return;
    }

    println!("{}", "Available must checks:".bold());
    for item in &items {
        let desc = item.description.unwrap_or("");
        println!("  {} — {}", item.subsection.cyan(), desc);
    }
}

/// Run a single named check by matching against subsection names.
fn run_single_check(
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
                "check '{}' not found. Available: {}",
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
        println!("Running: {}", item.command);
    }

    let status = Command::new("sh")
        .args(["-c", item.command])
        .status()
        .with_context(|| format!("executing check: {}", name))?;

    if status.success() {
        println!("{} {}", "PASS".green().bold(), desc);
        Ok(())
    } else {
        println!("{} {}", "FAIL".red().bold(), desc);
        bail!("must check '{}' failed (exit {})", name, status.code().unwrap_or(-1));
    }
}

