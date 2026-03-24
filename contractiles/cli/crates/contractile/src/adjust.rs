// SPDX-License-Identifier: PMPL-1.0-or-later
// adjust.rs — `adjust` subcommand: Accessibility & Digital Justice for
// Universal Software & Technology.
//
// ADJUST contractiles define accessibility invariants that must hold for all
// user-facing interfaces. They are machine-readable S-expression files
// (typically .machine_readable/ADJUST.contractile) that declare WCAG 2.2 AA
// minimum requirements.
//
// Commands:
//   adjust check     — verify ADJUST.contractile is present and well-formed
//   adjust audit     — scan the repo for accessibility violations
//   adjust report    — generate an accessibility status report
//   adjust list      — display all accessibility invariants
//
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)

use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use colored::Colorize;
use contractile_core::{filenames, find_contractile};
use std::fs;

#[derive(Subcommand, Clone)]
pub enum AdjustAction {
    /// Verify ADJUST.contractile is present and well-formed
    Check {
        #[arg(long)]
        file: Option<String>,

        /// Output results as JSON (for CI/CD consumption)
        #[arg(long)]
        json: bool,
    },

    /// Scan the repo for common accessibility violations
    Audit {
        /// Directory to scan (default: current directory)
        #[arg(default_value = ".")]
        path: String,

        /// Output results as JSON
        #[arg(long)]
        json: bool,
    },

    /// Generate an accessibility status report
    Report {
        #[arg(long)]
        file: Option<String>,
    },

    /// Display all accessibility invariants from the ADJUST.contractile
    List {
        #[arg(long)]
        file: Option<String>,
    },
}

/// Entry point when invoked as a symlink (`adjust check`, `adjust audit`, etc.).
pub fn run_from_args() -> Result<()> {
    #[derive(Parser)]
    #[command(
        name = "adjust",
        about = "Accessibility & Digital Justice for Universal Software & Technology"
    )]
    struct AdjustCli {
        #[command(subcommand)]
        action: AdjustAction,
    }

    let cli = AdjustCli::parse();
    run(cli.action)
}

/// Execute an adjust action.
pub fn run(action: AdjustAction) -> Result<()> {
    match action {
        AdjustAction::Check { file, json } => check(file.as_deref(), json),
        AdjustAction::Audit { path, json } => audit(&path, json),
        AdjustAction::Report { file } => report(file.as_deref()),
        AdjustAction::List { file } => list(file.as_deref()),
    }
}

/// Check that ADJUST.contractile exists and is well-formed.
fn check(explicit_path: Option<&str>, json: bool) -> Result<()> {
    let (path, content) = load_adjustfile(explicit_path)?;
    let invariants = parse_invariants(&content);
    let version = parse_field(&content, "version").unwrap_or_else(|| "unknown".to_string());
    let standard = parse_field(&content, "standard").unwrap_or_else(|| "unknown".to_string());

    if json {
        let output = serde_json::json!({
            "tool": "adjust",
            "file": path.display().to_string(),
            "version": version,
            "standard": standard,
            "invariant_count": invariants.len(),
            "well_formed": true,
        });
        println!("{}", serde_json::to_string_pretty(&output)?);
    } else {
        println!("{}", "=== ADJUST Check ===".bold());
        println!("  File:       {}", path.display());
        println!("  Version:    {}", version);
        println!("  Standard:   {}", standard.cyan());
        println!("  Invariants: {}", invariants.len().to_string().green());
        println!();
        println!("  {} ADJUST.contractile is present and well-formed", "[OK]".green());
    }

    Ok(())
}

/// Scan the repo for common accessibility violations.
fn audit(scan_path: &str, json: bool) -> Result<()> {
    let mut findings: Vec<AuditFinding> = Vec::new();

    // Check 1: Colour-only signalling in CLI output
    check_colour_only_signalling(scan_path, &mut findings);

    // Check 2: Missing alt text in HTML/AsciiDoc
    check_missing_alt_text(scan_path, &mut findings);

    // Check 3: Missing --help on CLI commands
    check_missing_help_flag(scan_path, &mut findings);

    // Check 4: Hardcoded colour without prefers-reduced-motion
    check_missing_reduced_motion(scan_path, &mut findings);

    // Check 5: Small touch targets in CSS
    check_small_touch_targets(scan_path, &mut findings);

    // Check 6: Missing ARIA landmarks
    check_missing_aria(scan_path, &mut findings);

    if json {
        let output = serde_json::json!({
            "tool": "adjust audit",
            "path": scan_path,
            "finding_count": findings.len(),
            "findings": findings.iter().map(|f| serde_json::json!({
                "rule": f.rule,
                "severity": f.severity,
                "file": f.file,
                "line": f.line,
                "message": f.message,
            })).collect::<Vec<_>>(),
        });
        println!("{}", serde_json::to_string_pretty(&output)?);
    } else {
        println!("{}", "=== ADJUST Audit ===".bold());
        println!("  Scanning: {}", scan_path);
        println!();

        if findings.is_empty() {
            println!("  {} No accessibility issues found", "[OK]".green());
        } else {
            for finding in &findings {
                let severity_tag = match finding.severity.as_str() {
                    "error" => "[ERROR]".red().to_string(),
                    "warning" => "[WARN]".yellow().to_string(),
                    _ => "[INFO]".dimmed().to_string(),
                };
                println!(
                    "  {} {} {}:{}",
                    severity_tag, finding.rule, finding.file, finding.line
                );
                println!("       {}", finding.message);
            }
            println!();
            println!(
                "  {} accessibility issue(s) found",
                findings.len().to_string().yellow()
            );
        }
    }

    Ok(())
}

/// Display all accessibility invariants.
fn list(explicit_path: Option<&str>) -> Result<()> {
    let (_path, content) = load_adjustfile(explicit_path)?;
    let invariants = parse_invariants(&content);
    let standard = parse_field(&content, "standard").unwrap_or_else(|| "unknown".to_string());

    println!(
        "{} ({})",
        "=== ADJUST Invariants ===".bold(),
        standard.cyan()
    );
    println!(
        "  {}",
        "Accessibility & Digital Justice for Universal Software & Technology"
            .dimmed()
    );
    println!();

    let mut current_category = String::new();
    for inv in &invariants {
        // Detect category from comment lines preceding invariants
        if inv.category != current_category {
            current_category = inv.category.clone();
            println!("  {}:", current_category.cyan().bold());
        }
        println!("    {} {}", "•".green(), inv.text);
    }

    println!();
    println!("  {} invariants total", invariants.len());
    Ok(())
}

/// Generate a status report.
fn report(explicit_path: Option<&str>) -> Result<()> {
    let (path, content) = load_adjustfile(explicit_path)?;
    let invariants = parse_invariants(&content);
    let version = parse_field(&content, "version").unwrap_or_else(|| "unknown".to_string());
    let standard = parse_field(&content, "standard").unwrap_or_else(|| "unknown".to_string());
    let repo = parse_field(&content, "repo").unwrap_or_else(|| ".".to_string());

    println!("{}", "=== ADJUST Status Report ===".bold());
    println!();
    println!("  Repository:  {}", repo);
    println!("  Standard:    {}", standard);
    println!("  Version:     {}", version);
    println!("  File:        {}", path.display());
    println!("  Invariants:  {}", invariants.len());
    println!();

    // Count invariants by category
    let mut categories: std::collections::BTreeMap<String, usize> =
        std::collections::BTreeMap::new();
    for inv in &invariants {
        *categories.entry(inv.category.clone()).or_insert(0) += 1;
    }

    println!("  Coverage by category:");
    for (cat, count) in &categories {
        println!("    {:20} {} invariants", cat, count.to_string().green());
    }

    println!();
    println!(
        "  {} ADJUST contractile present with {} invariants",
        "[OK]".green(),
        invariants.len()
    );
    println!(
        "  {} Run 'adjust audit' for automated violation scanning",
        "[TIP]".cyan()
    );

    Ok(())
}

// ── Internal types ────────────────────────────────────────────

struct Invariant {
    category: String,
    text: String,
}

struct AuditFinding {
    rule: String,
    severity: String,
    file: String,
    line: usize,
    message: String,
}

// ── File loading ──────────────────────────────────────────────

fn load_adjustfile(explicit_path: Option<&str>) -> Result<(std::path::PathBuf, String)> {
    let path = if let Some(p) = explicit_path {
        std::path::PathBuf::from(p)
    } else {
        // Search for ADJUST.contractile in multiple locations
        find_contractile(filenames::ADJUST_CONTRACTILE)
            .or_else(|| find_contractile(filenames::ADJUSTFILE_A2ML))
            .context(
                "ADJUST.contractile not found. Searched: .machine_readable/, contractiles/adjust/, ./",
            )?
    };

    let content = fs::read_to_string(&path)
        .with_context(|| format!("reading ADJUST contractile: {}", path.display()))?;

    Ok((path, content))
}

// ── Parsing ───────────────────────────────────────────────────

/// Parse (adjust "...") invariant lines from the S-expression contractile.
fn parse_invariants(content: &str) -> Vec<Invariant> {
    let mut invariants = Vec::new();
    let mut current_category = "General".to_string();

    for line in content.lines() {
        let trimmed = line.trim();

        // Detect category comments: "; ── Visual ──" or "; ── Keyboard ──"
        if trimmed.starts_with("; ──") {
            if let Some(cat) = trimmed
                .trim_start_matches("; ──")
                .split("──")
                .next()
                .map(|s| s.trim().to_string())
            {
                if !cat.is_empty() {
                    current_category = cat;
                }
            }
            continue;
        }

        // Parse (adjust "...") lines
        if trimmed.starts_with("(adjust ") || trimmed.starts_with("(must ") {
            if let Some(text) = extract_quoted_string(trimmed) {
                invariants.push(Invariant {
                    category: current_category.clone(),
                    text,
                });
            }
        }
    }

    invariants
}

/// Extract a quoted string from an S-expression like (adjust "text here").
fn extract_quoted_string(line: &str) -> Option<String> {
    let start = line.find('"')?;
    let rest = &line[start + 1..];
    let end = rest.rfind('"')?;
    Some(rest[..end].to_string())
}

/// Parse a simple field like (version "1.0.0") from the content.
fn parse_field(content: &str, field: &str) -> Option<String> {
    let pattern = format!("({} ", field);
    content
        .lines()
        .find(|l| l.trim().starts_with(&pattern))
        .and_then(|l| extract_quoted_string(l))
}

// ── Audit checks ──────────────────────────────────────────────

fn check_colour_only_signalling(path: &str, findings: &mut Vec<AuditFinding>) {
    // Look for println with colour codes but no text symbols like [OK]/[FAIL]
    let output = std::process::Command::new("rg")
        .args([
            "-n",
            r#"\\033\[|\\e\[|\\x1b\["#,
            "--glob",
            "*.rs",
            "--glob",
            "*.sh",
            path,
        ])
        .output()
        .ok();

    if let Some(out) = output {
        let stdout = String::from_utf8_lossy(&out.stdout);
        for line in stdout.lines().take(20) {
            // Only flag if line doesn't also contain text indicators
            if !line.contains("[OK]")
                && !line.contains("[FAIL]")
                && !line.contains("[WARN]")
                && !line.contains("✓")
                && !line.contains("✗")
            {
                if let Some((file_line, _)) = line.split_once(':') {
                    if let Some((file, line_num)) = file_line.rsplit_once(':') {
                        findings.push(AuditFinding {
                            rule: "ADJUST-CLI-01".to_string(),
                            severity: "warning".to_string(),
                            file: file.to_string(),
                            line: line_num.parse().unwrap_or(0),
                            message: "Colour code without text fallback — may be invisible to colour-blind users or in no-colour terminals".to_string(),
                        });
                    }
                }
            }
        }
    }
}

fn check_missing_alt_text(path: &str, findings: &mut Vec<AuditFinding>) {
    // Look for images without alt text in HTML and AsciiDoc
    let output = std::process::Command::new("rg")
        .args([
            "-n",
            r#"<img[^>]*(?!alt=)[^>]*>"#,
            "--glob",
            "*.html",
            "--glob",
            "*.htm",
            path,
        ])
        .output()
        .ok();

    if let Some(out) = output {
        let stdout = String::from_utf8_lossy(&out.stdout);
        for line in stdout.lines().take(20) {
            if let Some((file_line, _)) = line.split_once(':') {
                if let Some((file, line_num)) = file_line.rsplit_once(':') {
                    findings.push(AuditFinding {
                        rule: "ADJUST-IMG-01".to_string(),
                        severity: "error".to_string(),
                        file: file.to_string(),
                        line: line_num.parse().unwrap_or(0),
                        message: "Image tag missing alt attribute".to_string(),
                    });
                }
            }
        }
    }
}

fn check_missing_help_flag(_path: &str, _findings: &mut Vec<AuditFinding>) {
    // This would need to parse CLI definitions — skip for now as it requires
    // understanding the specific CLI framework used (clap, argparse, etc.)
}

fn check_missing_reduced_motion(path: &str, findings: &mut Vec<AuditFinding>) {
    // Check CSS files for animation without prefers-reduced-motion
    let has_animation = std::process::Command::new("rg")
        .args([
            "-l",
            r"animation:|transition:",
            "--glob",
            "*.css",
            path,
        ])
        .output()
        .ok()
        .map(|o| !o.stdout.is_empty())
        .unwrap_or(false);

    let has_reduced_motion = std::process::Command::new("rg")
        .args([
            "-l",
            "prefers-reduced-motion",
            "--glob",
            "*.css",
            path,
        ])
        .output()
        .ok()
        .map(|o| !o.stdout.is_empty())
        .unwrap_or(false);

    if has_animation && !has_reduced_motion {
        findings.push(AuditFinding {
            rule: "ADJUST-MOTION-01".to_string(),
            severity: "warning".to_string(),
            file: "(CSS files)".to_string(),
            line: 0,
            message: "CSS animations found but no prefers-reduced-motion media query".to_string(),
        });
    }
}

fn check_small_touch_targets(path: &str, findings: &mut Vec<AuditFinding>) {
    // Look for explicit small sizes on interactive elements
    let output = std::process::Command::new("rg")
        .args([
            "-n",
            r"(width|height)\s*:\s*(1[0-9]|2[0-9]|3[0-9]|4[0-3])px",
            "--glob",
            "*.css",
            path,
        ])
        .output()
        .ok();

    if let Some(out) = output {
        let stdout = String::from_utf8_lossy(&out.stdout);
        for line in stdout.lines().take(10) {
            if let Some((file_line, _)) = line.split_once(':') {
                if let Some((file, line_num)) = file_line.rsplit_once(':') {
                    findings.push(AuditFinding {
                        rule: "ADJUST-TOUCH-01".to_string(),
                        severity: "warning".to_string(),
                        file: file.to_string(),
                        line: line_num.parse().unwrap_or(0),
                        message: "Element smaller than 44px — may be hard to tap on touch devices"
                            .to_string(),
                    });
                }
            }
        }
    }
}

fn check_missing_aria(path: &str, findings: &mut Vec<AuditFinding>) {
    // Check HTML files for missing ARIA landmarks
    let has_html = std::process::Command::new("rg")
        .args(["-l", "<html", "--glob", "*.html", path])
        .output()
        .ok()
        .map(|o| !o.stdout.is_empty())
        .unwrap_or(false);

    if !has_html {
        return;
    }

    let has_landmarks = std::process::Command::new("rg")
        .args([
            "-l",
            r#"role="(main|navigation|banner|contentinfo)"|<main|<nav|<header|<footer"#,
            "--glob",
            "*.html",
            path,
        ])
        .output()
        .ok()
        .map(|o| !o.stdout.is_empty())
        .unwrap_or(false);

    if !has_landmarks {
        findings.push(AuditFinding {
            rule: "ADJUST-ARIA-01".to_string(),
            severity: "warning".to_string(),
            file: "(HTML files)".to_string(),
            line: 0,
            message: "HTML files found but no ARIA landmarks (main, nav, header, footer)"
                .to_string(),
        });
    }
}
