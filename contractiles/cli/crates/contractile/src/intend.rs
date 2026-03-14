// SPDX-License-Identifier: PMPL-1.0-or-later
// intend.rs — `intend` subcommand: Future intent & roadmap from Intentfile.a2ml.
//
// Intentfiles are purely declarative — they declare what the project intends
// to do, not what it does now. The `intend` CLI displays this information
// and optionally probes whether declared intents have been realised.
//
// Commands:
//   intend list     — display all declared intents as a readable checklist
//   intend check    — probe whether declared intents have been realised
//   intend progress — summary of intent realisation status
//
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)

use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use colored::Colorize;
use contractile_core::{a2ml, filenames, find_contractile};
use std::fs;

#[derive(Subcommand, Clone)]
pub enum IntendAction {
    /// Display all declared intents as a readable checklist
    List {
        #[arg(long)]
        file: Option<String>,
    },

    /// Probe whether declared intents have been realised
    /// (checks for evidence of each intent in the codebase)
    Check {
        #[arg(long)]
        file: Option<String>,

        #[arg(long, short)]
        verbose: bool,
    },

    /// Summary of intent realisation progress
    Progress {
        #[arg(long)]
        file: Option<String>,
    },
}

/// Entry point when invoked as a symlink (`intend list`, `intend check`, etc.).
pub fn run_from_args() -> Result<()> {
    #[derive(Parser)]
    #[command(name = "intend", about = "Future intent & roadmap from Intentfile.a2ml")]
    struct IntendCli {
        #[command(subcommand)]
        action: IntendAction,
    }

    let cli = IntendCli::parse();
    run(cli.action)
}

/// Execute an intend action.
pub fn run(action: IntendAction) -> Result<()> {
    match action {
        IntendAction::List { file } => {
            let doc = load_intentfile(file.as_deref())?;
            display_intents(&doc);
            Ok(())
        }
        IntendAction::Check { file, verbose } => {
            let doc = load_intentfile(file.as_deref())?;
            check_intents(&doc, verbose)
        }
        IntendAction::Progress { file } => {
            let doc = load_intentfile(file.as_deref())?;
            show_progress(&doc);
            Ok(())
        }
    }
}

/// Load and parse the Intentfile.
fn load_intentfile(explicit_path: Option<&str>) -> Result<a2ml::A2mlDocument> {
    let path = if let Some(p) = explicit_path {
        std::path::PathBuf::from(p)
    } else {
        // Intentfile lives in lust/ (legacy naming) or contractiles/lust/.
        find_contractile(filenames::INTENTFILE_A2ML)
            .context("Intentfile.a2ml not found. Searched: contractiles/lust/, lust/, ./")?
    };

    let content = fs::read_to_string(&path)
        .with_context(|| format!("reading Intentfile: {}", path.display()))?;

    a2ml::parse(&content).with_context(|| format!("parsing Intentfile: {}", path.display()))
}

/// Display all declared intents as a formatted checklist.
/// Handles both simple intents (direct `- text` entries) and structured
/// intents (`### name` subsections with metadata fields like status,
/// priority, evidence, etc.).
fn display_intents(doc: &a2ml::A2mlDocument) {
    if let Some(abstract_text) = &doc.abstract_text {
        println!("{}", abstract_text.dimmed());
        println!();
    }

    println!("{}", "=== Declared Intent ===".bold());

    if doc.sections.is_empty() {
        println!("{}", "No intents declared".yellow());
        return;
    }

    for section in &doc.sections {
        println!();
        println!("{}:", section.name.cyan().bold());

        // Print direct entries as bullet points (simple intents).
        for entry in &section.entries {
            if entry.key == entry.value || entry.value.is_empty() {
                println!("  [ ] {}", entry.key);
            } else {
                println!("  [ ] {}", entry.value);
            }
        }

        // Print structured intents (subsections with metadata).
        for sub in &section.subsections {
            let description = sub
                .get("description")
                .unwrap_or(&sub.name);
            let status = sub.get("status").unwrap_or("declared");
            let priority = sub.get("priority");

            // Status-aware checkbox rendering.
            let checkbox = match status {
                "realised" => "[x]".green().to_string(),
                "in-progress" => "[~]".yellow().to_string(),
                "abandoned" => "[/]".red().to_string(),
                "superseded" => "[>]".dimmed().to_string(),
                "accepted" => "[+]".cyan().to_string(),
                _ => "[ ]".normal().to_string(),
            };

            let priority_tag = priority
                .map(|p| format!(" [{}]", p))
                .unwrap_or_default();

            println!(
                "  {} {} {}{}",
                checkbox,
                description,
                format!("({})", status).dimmed(),
                priority_tag.dimmed()
            );

            // Show target and notes if present.
            if let Some(target) = sub.get("target") {
                println!("       target: {}", target.dimmed());
            }
            if let Some(depends) = sub.get("depends_on") {
                println!("       depends: {}", depends.dimmed());
            }
        }

        // Print prose lines (plain text within the section).
        for line in &section.prose {
            let trimmed = line.trim();
            if !trimmed.is_empty() {
                if trimmed.starts_with('-') {
                    let content = trimmed.trim_start_matches('-').trim();
                    println!("  [ ] {}", content);
                } else {
                    println!("  {}", trimmed);
                }
            }
        }
    }
}

/// Check whether declared intents have been realised.
/// Runs evidence probes for structured intents and reports results.
fn check_intents(doc: &a2ml::A2mlDocument, verbose: bool) -> Result<()> {
    println!("{}", "=== Intent Realisation Check ===".bold());
    println!();

    let mut total = 0;
    let mut realised = 0;
    let mut probed = 0;

    for section in &doc.sections {
        println!("{}:", section.name.cyan().bold());

        // Simple intents (no evidence probes).
        for entry in &section.entries {
            total += 1;
            let text = if entry.value.is_empty() {
                &entry.key
            } else {
                &entry.value
            };
            println!("  {} {}", "[ ]".yellow(), text);
        }

        // Structured intents — run evidence probes if available.
        for sub in &section.subsections {
            total += 1;
            let description = sub.get("description").unwrap_or(&sub.name);
            let status = sub.get("status").unwrap_or("declared");

            // Already marked as realised in the Intentfile.
            if status == "realised" {
                realised += 1;
                println!("  {} {} {}", "[x]".green(), description, "(realised)".dimmed());
                continue;
            }

            if status == "abandoned" || status == "superseded" {
                println!("  {} {} ({})", "[/]".dimmed(), description, status);
                continue;
            }

            // Try evidence probe if available.
            if let Some(evidence) = sub.get("evidence") {
                probed += 1;
                let probe_result = run_evidence_probe(evidence, verbose);
                if probe_result {
                    realised += 1;
                    println!("  {} {} {}", "[x]".green(), description, "(evidence confirmed)".green());
                } else {
                    println!("  {} {} {}", "[ ]".yellow(), description, format!("({})", status).dimmed());
                }
            } else {
                println!("  {} {} {} {}", "[ ]".yellow(), description, format!("({})", status).dimmed(), "(no probe)".dimmed());
            }
        }

        // Prose intents.
        for line in &section.prose {
            let trimmed = line.trim();
            if trimmed.starts_with('-') {
                total += 1;
                let content = trimmed.trim_start_matches('-').trim();
                println!("  {} {}", "[ ]".yellow(), content);
            }
        }
    }

    println!();
    println!(
        "{} intent(s): {} realised, {} probed, {} remaining",
        total,
        realised.to_string().green(),
        probed,
        (total - realised).to_string().yellow()
    );
    Ok(())
}

/// Run a single evidence probe and return true if the intent is realised.
/// Supported probe formats:
///   "FILE exists"           — check file existence
///   "FILE contains PATTERN" — check file contents
///   "command: COMMAND"      — run shell command, check exit code
///   "must: CHECK_NAME"      — delegate to must check
///   "trust: VERIFY_NAME"    — delegate to trust verify
fn run_evidence_probe(evidence: &str, verbose: bool) -> bool {
    let evidence = evidence.trim();

    // "command: ..." — run a shell command.
    if let Some(cmd) = evidence.strip_prefix("command:") {
        let cmd = cmd.trim();
        if verbose {
            println!("       probe: {}", cmd);
        }
        return std::process::Command::new("sh")
            .args(["-c", cmd])
            .stdout(std::process::Stdio::null())
            .stderr(std::process::Stdio::null())
            .status()
            .map(|s| s.success())
            .unwrap_or(false);
    }

    // "must: CHECK_NAME" — delegate to contractile must.
    if let Some(check) = evidence.strip_prefix("must:") {
        let cmd = format!("contractile must run {} 2>/dev/null", check.trim());
        if verbose {
            println!("       probe: {}", cmd);
        }
        return std::process::Command::new("sh")
            .args(["-c", &cmd])
            .stdout(std::process::Stdio::null())
            .stderr(std::process::Stdio::null())
            .status()
            .map(|s| s.success())
            .unwrap_or(false);
    }

    // "trust: VERIFY_NAME" — delegate to contractile trust.
    if let Some(verify) = evidence.strip_prefix("trust:") {
        let cmd = format!("contractile trust verify {} 2>/dev/null", verify.trim());
        if verbose {
            println!("       probe: {}", cmd);
        }
        return std::process::Command::new("sh")
            .args(["-c", &cmd])
            .stdout(std::process::Stdio::null())
            .stderr(std::process::Stdio::null())
            .status()
            .map(|s| s.success())
            .unwrap_or(false);
    }

    // "FILE contains PATTERN" — grep for pattern in file.
    if evidence.contains(" contains ") {
        let parts: Vec<&str> = evidence.splitn(2, " contains ").collect();
        if parts.len() == 2 {
            let file = parts[0].trim();
            let pattern = parts[1].trim();
            if verbose {
                println!("       probe: grep -q '{}' {}", pattern, file);
            }
            return std::process::Command::new("grep")
                .args(["-q", pattern, file])
                .status()
                .map(|s| s.success())
                .unwrap_or(false);
        }
    }

    // "FILE exists" — check file existence.
    if evidence.ends_with(" exists") {
        let file = evidence.trim_end_matches(" exists").trim();
        if verbose {
            println!("       probe: test -e {}", file);
        }
        return std::path::Path::new(file).exists();
    }

    // Unknown probe format — cannot determine.
    false
}

/// Show a summary of intent progress.
fn show_progress(doc: &a2ml::A2mlDocument) {
    let mut total_sections = 0;
    let mut total_items = 0;
    let mut by_status: std::collections::HashMap<String, usize> = std::collections::HashMap::new();

    for section in &doc.sections {
        total_sections += 1;
        // Count direct entries.
        total_items += section.entries.len();
        // Count prose intents.
        total_items += section
            .prose
            .iter()
            .filter(|l| l.trim().starts_with('-'))
            .count();
        // Count structured intents and tally by status.
        for sub in &section.subsections {
            total_items += 1;
            let status = sub.get("status").unwrap_or("declared").to_string();
            *by_status.entry(status).or_insert(0) += 1;
        }
    }

    println!("{}", "=== Intent Progress ===".bold());
    println!("  Sections:     {}", total_sections);
    println!("  Intent items: {}", total_items);

    // Print status breakdown in lifecycle order.
    let order = ["declared", "accepted", "in-progress", "realised", "superseded", "abandoned"];
    for status in &order {
        if let Some(count) = by_status.get(*status) {
            let colored_status = match *status {
                "realised" => status.green().to_string(),
                "in-progress" => status.yellow().to_string(),
                "abandoned" => status.red().to_string(),
                _ => status.normal().to_string(),
            };
            println!("  {:14} {}", colored_status, count);
        }
    }
}
