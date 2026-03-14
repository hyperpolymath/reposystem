// SPDX-License-Identifier: PMPL-1.0-or-later
// doctor.rs — `contractile doctor`: Diagnose tooling availability.
//
// Checks which tools the contractile system needs are available on PATH,
// reports their versions, and flags any missing dependencies that would
// prevent specific contractile operations from working.
//
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)

use colored::Colorize;
use std::process::Command;

/// Tool requirement with the command to check and what it's needed for.
struct ToolCheck {
    name: &'static str,
    command: &'static str,
    args: &'static [&'static str],
    needed_for: &'static str,
    required: bool,
}

const TOOLS: &[ToolCheck] = &[
    ToolCheck {
        name: "just",
        command: "just",
        args: &["--version"],
        needed_for: "Justfile orchestration, contractile.just recipes",
        required: true,
    },
    ToolCheck {
        name: "rg (ripgrep)",
        command: "rg",
        args: &["--version"],
        needed_for: "must checks (file content searching)",
        required: true,
    },
    ToolCheck {
        name: "jq",
        command: "jq",
        args: &["--version"],
        needed_for: "must checks (JSON validation)",
        required: false,
    },
    ToolCheck {
        name: "yq",
        command: "yq",
        args: &["--version"],
        needed_for: "must checks (YAML validation)",
        required: false,
    },
    ToolCheck {
        name: "nickel",
        command: "nickel",
        args: &["--version"],
        needed_for: "K9 component evaluation, policy compilation",
        required: false,
    },
    ToolCheck {
        name: "openssl",
        command: "openssl",
        args: &["version"],
        needed_for: "trust verify (signature verification), K9 Hunt signatures",
        required: true,
    },
    ToolCheck {
        name: "sha256sum",
        command: "sha256sum",
        args: &["--version"],
        needed_for: "trust hash (content hashing)",
        required: true,
    },
    ToolCheck {
        name: "git",
        command: "git",
        args: &["--version"],
        needed_for: "dust rollback (file reversion)",
        required: true,
    },
    ToolCheck {
        name: "cargo",
        command: "cargo",
        args: &["--version"],
        needed_for: "building the contractile CLI from source",
        required: false,
    },
    ToolCheck {
        name: "kyber-verify",
        command: "kyber-verify",
        args: &["--version"],
        needed_for: "trust verify (post-quantum signature verification)",
        required: false,
    },
];

/// Run the doctor diagnostic.
pub fn run() -> anyhow::Result<()> {
    println!("{}", "=== Contractile Doctor ===".bold());
    println!();

    let mut ok_count = 0;
    let mut warn_count = 0;
    let mut fail_count = 0;

    for tool in TOOLS {
        let result = Command::new(tool.command)
            .args(tool.args)
            .stdout(std::process::Stdio::piped())
            .stderr(std::process::Stdio::piped())
            .output();

        match result {
            Ok(output) if output.status.success() => {
                let version = String::from_utf8_lossy(&output.stdout)
                    .lines()
                    .next()
                    .unwrap_or("")
                    .trim()
                    .to_string();
                let version_short = if version.len() > 50 {
                    format!("{}...", &version[..47])
                } else {
                    version
                };
                println!(
                    "  {} {} — {}",
                    "OK".green().bold(),
                    tool.name,
                    version_short.dimmed()
                );
                ok_count += 1;
            }
            _ => {
                if tool.required {
                    println!(
                        "  {} {} — {}",
                        "MISSING".red().bold(),
                        tool.name,
                        tool.needed_for.dimmed()
                    );
                    fail_count += 1;
                } else {
                    println!(
                        "  {} {} — {} (optional: {})",
                        "WARN".yellow().bold(),
                        tool.name,
                        "not found".dimmed(),
                        tool.needed_for.dimmed()
                    );
                    warn_count += 1;
                }
            }
        }
    }

    // Check contractile CLI itself.
    println!();
    println!("  {} contractile v{}", "CLI".cyan().bold(), env!("CARGO_PKG_VERSION"));

    // Check for contractile files in current directory.
    let has_contractiles = std::path::Path::new("contractiles").is_dir();
    if has_contractiles {
        println!("  {} contractiles/ directory found", "OK".green().bold());
    } else {
        println!(
            "  {} No contractiles/ directory — run `contractile init`",
            "INFO".cyan()
        );
    }

    println!();
    println!(
        "  {} available, {} warnings, {} missing",
        ok_count.to_string().green(),
        warn_count.to_string().yellow(),
        fail_count.to_string().red()
    );

    if fail_count > 0 {
        println!();
        println!(
            "  {} Install missing required tools for full functionality",
            "ACTION".red().bold()
        );
    }

    Ok(())
}
