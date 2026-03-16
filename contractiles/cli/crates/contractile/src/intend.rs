// SPDX-License-Identifier: PMPL-1.0-or-later
// intend.rs — `intend` subcommand: Future intent & roadmap from Intentfile.a2ml.
//
// Intentfiles are purely declarative — they declare what the project intends
// to do, not what it does now. The `intend` CLI displays this information,
// probes whether declared intents have been realised, and provides lifecycle
// commands that modify the Intentfile in place.
//
// Commands:
//   intend list      — display all declared intents as a readable checklist
//   intend check     — probe whether declared intents have been realised
//   intend progress  — summary of intent realisation status
//   intend accept    — move intent from declared → accepted
//   intend start     — move intent from accepted → in-progress
//   intend realise   — move intent from in-progress → realised
//   intend abandon   — move intent to abandoned (with reason)
//   intend supersede — mark intent as superseded by another
//
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)

use anyhow::{bail, Context, Result};
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

        /// Output results as JSON (for CI/CD consumption)
        #[arg(long)]
        json: bool,
    },

    /// Summary of intent realisation progress
    Progress {
        #[arg(long)]
        file: Option<String>,
    },

    /// Move an intent from declared → accepted
    Accept {
        /// Name of the intent (matches ### heading)
        name: String,
        #[arg(long)]
        file: Option<String>,
    },

    /// Move an intent from accepted → in-progress
    Start {
        /// Name of the intent (matches ### heading)
        name: String,
        #[arg(long)]
        file: Option<String>,
    },

    /// Move an intent from in-progress → realised
    Realise {
        /// Name of the intent (matches ### heading)
        name: String,
        /// Optional note to add (defaults to "Realised YYYY-MM-DD")
        #[arg(long)]
        note: Option<String>,
        #[arg(long)]
        file: Option<String>,
    },

    /// Move an intent to abandoned status
    Abandon {
        /// Name of the intent (matches ### heading)
        name: String,
        /// Reason for abandonment (required)
        #[arg(long)]
        reason: String,
        #[arg(long)]
        file: Option<String>,
    },

    /// Mark an intent as superseded by another
    Supersede {
        /// Name of the intent to supersede
        old: String,
        /// Name of the new intent that replaces it
        new: String,
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
        IntendAction::Check { file, verbose, json } => {
            let doc = load_intentfile(file.as_deref())?;
            if json {
                check_intents_json(&doc)
            } else {
                check_intents(&doc, verbose)
            }
        }
        IntendAction::Progress { file } => {
            let doc = load_intentfile(file.as_deref())?;
            show_progress(&doc);
            Ok(())
        }
        IntendAction::Accept { name, file } => {
            transition_intent(file.as_deref(), &name, "declared", "accepted", None)
        }
        IntendAction::Start { name, file } => {
            transition_intent(file.as_deref(), &name, "accepted", "in-progress", None)
        }
        IntendAction::Realise { name, note, file } => {
            let today = today_string();
            let default_note = format!("Realised {}", today);
            let note_text = note.as_deref().unwrap_or(&default_note);
            transition_intent(
                file.as_deref(),
                &name,
                "in-progress",
                "realised",
                Some(note_text),
            )
        }
        IntendAction::Abandon { name, reason, file } => {
            let note = format!("Abandoned: {}", reason);
            transition_intent(file.as_deref(), &name, "", "abandoned", Some(&note))
        }
        IntendAction::Supersede { old, new, file } => {
            let note = format!("Superseded by {}", new);
            transition_intent(file.as_deref(), &old, "", "superseded", Some(&note))
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

/// Run all intent checks and output as JSON.
fn check_intents_json(doc: &a2ml::A2mlDocument) -> Result<()> {
    let mut results = Vec::new();

    for section in &doc.sections {
        for sub in &section.subsections {
            let description = sub.get("description").unwrap_or(&sub.name);
            let status = sub.get("status").unwrap_or("declared");
            let evidence = sub.get("evidence");

            let realised = if status == "realised" {
                true
            } else if let Some(ev) = evidence {
                run_evidence_probe(ev, false)
            } else {
                false
            };

            results.push(serde_json::json!({
                "name": sub.name,
                "section": section.name,
                "description": description,
                "status": status,
                "evidence": evidence.unwrap_or(""),
                "realised": realised,
            }));
        }
    }

    let realised_count = results.iter().filter(|r| r["realised"] == true).count();

    let output = serde_json::json!({
        "tool": "intend",
        "total": results.len(),
        "realised": realised_count,
        "remaining": results.len() - realised_count,
        "intents": results,
    });

    println!("{}", serde_json::to_string_pretty(&output)?);
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
        return std::process::Command::new("bash")
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
        return std::process::Command::new("bash")
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
        return std::process::Command::new("bash")
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

/// Transition an intent's status by editing the Intentfile.a2ml in place.
/// Finds the `### name` subsection and updates its `- status:` line.
/// If `expected_from` is non-empty, validates the current status first.
fn transition_intent(
    explicit_path: Option<&str>,
    name: &str,
    expected_from: &str,
    new_status: &str,
    note: Option<&str>,
) -> Result<()> {
    let path = if let Some(p) = explicit_path {
        std::path::PathBuf::from(p)
    } else {
        find_contractile(filenames::INTENTFILE_A2ML)
            .context("Intentfile.a2ml not found")?
    };

    let content = fs::read_to_string(&path)
        .with_context(|| format!("reading Intentfile: {}", path.display()))?;

    // Parse to validate the intent exists and check current status.
    let doc = a2ml::parse(&content)
        .with_context(|| format!("parsing Intentfile: {}", path.display()))?;

    // Find the intent across all sections.
    let mut found = false;
    let mut current_status = String::new();
    for section in &doc.sections {
        if let Some(sub) = section.subsection(name) {
            found = true;
            current_status = sub.get("status").unwrap_or("declared").to_string();
            break;
        }
    }

    if !found {
        let all_names: Vec<&str> = doc
            .sections
            .iter()
            .flat_map(|s| s.subsections.iter().map(|sub| sub.name.as_str()))
            .collect();
        bail!(
            "intent '{}' not found. Available:\n  {}",
            name,
            all_names.join("\n  ")
        );
    }

    // Validate transition if expected_from is specified.
    if !expected_from.is_empty() && current_status != expected_from {
        bail!(
            "intent '{}' is '{}', expected '{}'. Cannot transition to '{}'",
            name,
            current_status,
            expected_from,
            new_status
        );
    }

    // Edit the file in place using line-level manipulation.
    // Strategy: track when we're inside the target `### name` subsection,
    // replace `- status:` and `- notes:` lines, and handle the boundary
    // between subsections correctly.
    let lines: Vec<&str> = content.lines().collect();
    let mut new_lines: Vec<String> = Vec::with_capacity(lines.len() + 2);
    let mut in_target = false;
    let mut status_replaced = false;
    let mut notes_replaced = false;

    for line in &lines {
        let trimmed = line.trim();

        // ── Heading detection ──
        // When we hit a new heading (### or ##), check if we're leaving
        // the target subsection or entering it.
        if trimmed.starts_with("### ") || trimmed.starts_with("## ") {
            // If we were in the target and leaving without replacing status,
            // insert the status line before this heading.
            if in_target && !status_replaced {
                new_lines.push(format!("- status: {}", new_status));
                status_replaced = true;
                if let Some(note_text) = note {
                    if !notes_replaced {
                        new_lines.push(format!("- notes: {}", note_text));
                        notes_replaced = true;
                    }
                }
            }

            // Check if this heading IS the target subsection.
            if let Some(heading) = trimmed.strip_prefix("### ") {
                in_target = heading.trim() == name;
            } else {
                // It's a ## section heading — we've left any subsection.
                in_target = false;
            }

            new_lines.push(line.to_string());
            continue;
        }

        // ── Inside the target subsection: replace status/notes lines ──
        if in_target {
            if trimmed.starts_with("- status:") {
                new_lines.push(format!("- status: {}", new_status));
                status_replaced = true;
                continue;
            }

            if let Some(note_text) = note {
                if trimmed.starts_with("- notes:") {
                    new_lines.push(format!("- notes: {}", note_text));
                    notes_replaced = true;
                    continue;
                }
            }
        }

        new_lines.push(line.to_string());
    }

    // If we reached EOF still inside the target without replacing, append.
    if in_target && !status_replaced {
        new_lines.push(format!("- status: {}", new_status));
    }

    // If we have a note but no existing notes line was found, insert it
    // right after the status line within the target subsection.
    if let Some(note_text) = note {
        if !notes_replaced {
            let mut final_lines: Vec<String> = Vec::with_capacity(new_lines.len() + 1);
            let mut inserted = false;
            let mut scanning_target = false;
            for line in &new_lines {
                if line.trim().starts_with("### ") {
                    let heading = line.trim().strip_prefix("### ").unwrap_or("").trim();
                    scanning_target = heading == name;
                }
                final_lines.push(line.clone());
                if scanning_target
                    && line.trim().starts_with("- status:")
                    && !inserted
                {
                    final_lines.push(format!("- notes: {}", note_text));
                    inserted = true;
                }
            }
            new_lines = final_lines;
        }
    }

    // Write the modified content back.
    let new_content = new_lines.join("\n");
    // Preserve trailing newline if original had one.
    let new_content = if content.ends_with('\n') && !new_content.ends_with('\n') {
        format!("{}\n", new_content)
    } else {
        new_content
    };

    fs::write(&path, &new_content)
        .with_context(|| format!("writing Intentfile: {}", path.display()))?;

    println!(
        "{} '{}': {} → {}",
        "intend:".bold(),
        name.cyan(),
        current_status.dimmed(),
        new_status.green()
    );

    if let Some(note_text) = note {
        println!("  {}", note_text.dimmed());
    }

    Ok(())
}

/// Get today's date as YYYY-MM-DD string.
fn today_string() -> String {
    // Use a simple approach without chrono dependency.
    let output = std::process::Command::new("date")
        .args(["+%Y-%m-%d"])
        .output()
        .ok()
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
        .unwrap_or_else(|| "unknown-date".to_string());
    output
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
