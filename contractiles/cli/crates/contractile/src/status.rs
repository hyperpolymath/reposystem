// SPDX-License-Identifier: PMPL-1.0-or-later
// status.rs — `contractile status`: Unified dashboard across all contractile types.
//
// Shows a single-screen overview of the project's contractile health:
//   - Must: how many checks pass/fail
//   - Trust: how many verifications pass/fail
//   - Dust: how many recovery actions are available
//   - Intend: how many intents are realised/in-progress/declared
//
// This is the daily-driver command — run `contractile status` to see
// where the project stands across all contractile dimensions.
//
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)

use anyhow::{Context, Result};
use colored::Colorize;
use contractile_core::{a2ml, filenames, find_contractile};
use std::fs;
use std::process::Command;

/// Run the status dashboard.
pub fn run(quick: bool) -> Result<()> {
    println!("{}", "=== Contractile Status ===".bold());
    println!();

    let mut any_found = false;

    // ── Must ──
    if let Some(path) = find_contractile(filenames::MUSTFILE_A2ML)
        .or_else(|| find_contractile(filenames::MUSTFILE_TOML))
    {
        any_found = true;
        let doc = load_a2ml_or_toml(&path)?;
        let items = doc.executable_items();

        if quick || items.is_empty() {
            println!(
                "  {} {} check(s) declared",
                "MUST".cyan().bold(),
                items.len()
            );
        } else {
            let (passed, failed) = run_checks_silent(&items);
            let status_icon = if failed == 0 {
                "PASS".green().bold()
            } else {
                "FAIL".red().bold()
            };
            println!(
                "  {} {} — {}/{} passed",
                "MUST".cyan().bold(),
                status_icon,
                passed,
                items.len()
            );
            if failed > 0 {
                // Show which ones failed.
                for item in &items {
                    let ok = Command::new("sh")
                        .args(["-c", item.command])
                        .stdout(std::process::Stdio::null())
                        .stderr(std::process::Stdio::null())
                        .status()
                        .map(|s| s.success())
                        .unwrap_or(false);
                    if !ok {
                        let desc = item.description.unwrap_or(item.subsection);
                        println!("         {} {}", "FAIL".red(), desc);
                    }
                }
            }
        }
    }

    // ── Trust ──
    if let Some(path) = find_contractile(filenames::TRUSTFILE_A2ML) {
        any_found = true;
        let content = fs::read_to_string(&path)?;
        let doc = a2ml::parse(&content)?;
        let items = doc.executable_items();

        if quick || items.is_empty() {
            println!(
                "  {} {} verification(s) declared",
                "TRUST".cyan().bold(),
                items.len()
            );
        } else {
            let (passed, failed) = run_checks_silent(&items);
            let status_icon = if failed == 0 {
                "PASS".green().bold()
            } else {
                "FAIL".red().bold()
            };
            println!(
                "  {} {} — {}/{} verified",
                "TRUST".cyan().bold(),
                status_icon,
                passed,
                items.len()
            );
        }
    }

    // ── Dust ──
    if let Some(path) = find_contractile(filenames::DUSTFILE_A2ML) {
        any_found = true;
        let content = fs::read_to_string(&path)?;
        let doc = a2ml::parse(&content)?;
        let items = doc.executable_items();

        // Count by type.
        let rollbacks = items.iter().filter(|i| i.key == "rollback").count();
        let undos = items.iter().filter(|i| i.key == "undo").count();
        let handlers = items.iter().filter(|i| i.key == "handler").count();
        let transforms = items.iter().filter(|i| i.key == "transform").count();

        println!(
            "  {} {} action(s): {} rollback, {} undo, {} handler, {} transform",
            "DUST".cyan().bold(),
            items.len(),
            rollbacks,
            undos,
            handlers,
            transforms
        );
    }

    // ── Intend ──
    if let Some(path) = find_contractile(filenames::INTENTFILE_A2ML) {
        any_found = true;
        let content = fs::read_to_string(&path)?;
        let doc = a2ml::parse(&content)?;

        let mut total = 0;
        let mut by_status: std::collections::HashMap<&str, usize> =
            std::collections::HashMap::new();

        for section in &doc.sections {
            total += section.entries.len();
            total += section.prose.iter().filter(|l| l.trim().starts_with('-')).count();
            for sub in &section.subsections {
                total += 1;
                let status = sub.get("status").unwrap_or("declared");
                *by_status.entry(status).or_insert(0) += 1;
            }
        }

        let realised = by_status.get("realised").copied().unwrap_or(0);
        let in_progress = by_status.get("in-progress").copied().unwrap_or(0);
        let declared = total - realised - in_progress
            - by_status.get("abandoned").copied().unwrap_or(0)
            - by_status.get("superseded").copied().unwrap_or(0);

        println!(
            "  {} {} intent(s): {} realised, {} active, {} pending",
            "INTEND".cyan().bold(),
            total,
            realised.to_string().green(),
            in_progress.to_string().yellow(),
            declared
        );
    }

    // ── K9 ──
    let k9_count = count_k9_files();
    if k9_count > 0 {
        any_found = true;
        println!(
            "  {} {} component(s) available",
            "K9".cyan().bold(),
            k9_count
        );
    }

    if !any_found {
        println!("  {} No contractile files found", "NONE".yellow());
        println!("  Run `contractile init` to scaffold contractiles for this repo");
    }

    println!();
    Ok(())
}

/// Load an A2ML file, or fall back to TOML if the path ends in .toml.
fn load_a2ml_or_toml(path: &std::path::Path) -> Result<a2ml::A2mlDocument> {
    if path.extension().and_then(|e| e.to_str()) == Some("toml") {
        contractile_core::toml_compat::parse_mustfile_toml(path)
    } else {
        let content = fs::read_to_string(path)
            .with_context(|| format!("reading: {}", path.display()))?;
        a2ml::parse(&content)
            .with_context(|| format!("parsing: {}", path.display()))
    }
}

/// Run all executable items silently and return (passed, failed) counts.
fn run_checks_silent(items: &[a2ml::ExecutableItem<'_>]) -> (usize, usize) {
    let mut passed = 0;
    let mut failed = 0;

    for item in items {
        let ok = Command::new("sh")
            .args(["-c", item.command])
            .stdout(std::process::Stdio::null())
            .stderr(std::process::Stdio::null())
            .status()
            .map(|s| s.success())
            .unwrap_or(false);

        if ok {
            passed += 1;
        } else {
            failed += 1;
        }
    }

    (passed, failed)
}

/// Count .k9.ncl files in the contractiles directory.
fn count_k9_files() -> usize {
    let dirs = ["contractiles/k9", "k9"];
    let mut count = 0;

    for dir in &dirs {
        let dir_path = std::path::Path::new(dir);
        if dir_path.is_dir() {
            count += count_ncl_recursive(dir_path);
        }
    }

    count
}

/// Recursively count .k9.ncl files.
fn count_ncl_recursive(dir: &std::path::Path) -> usize {
    let mut count = 0;
    if let Ok(entries) = fs::read_dir(dir) {
        for entry in entries.flatten() {
            let path = entry.path();
            if path.is_dir() {
                count += count_ncl_recursive(&path);
            } else if path
                .file_name()
                .and_then(|n| n.to_str())
                .map(|n| n.ends_with(".k9.ncl"))
                .unwrap_or(false)
            {
                count += 1;
            }
        }
    }
    count
}
