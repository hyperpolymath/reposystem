// SPDX-License-Identifier: PMPL-1.0-or-later
// init.rs — `contractile init`: Scaffold contractile files into a repository.
//
// Creates the contractiles/ directory structure with starter A2ML files
// tailored to the detected project type. This is how repos adopt the
// contractile system — run `contractile init` and you get Mustfile,
// Trustfile, Dustfile, Intentfile, and a generated contractile.just.
//
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)

use anyhow::{bail, Context, Result};
use colored::Colorize;
use std::fs;
use std::path::Path;

/// Run the init command.
pub fn run(project_name: Option<&str>, force: bool) -> Result<()> {
    let contractiles_dir = Path::new("contractiles");

    if contractiles_dir.exists() && !force {
        bail!(
            "contractiles/ already exists. Use --force to overwrite starter files."
        );
    }

    // Detect project name from current directory or Cargo.toml/deno.json/gleam.toml.
    let name = project_name
        .map(String::from)
        .or_else(detect_project_name)
        .unwrap_or_else(|| {
            std::env::current_dir()
                .ok()
                .and_then(|p| p.file_name().map(|n| n.to_string_lossy().into_owned()))
                .unwrap_or_else(|| "my-project".to_string())
        });

    println!(
        "{} Initialising contractiles for '{}'...",
        "init:".bold(),
        name.cyan()
    );

    // Create directory structure.
    let dirs = [
        "contractiles/must",
        "contractiles/trust",
        "contractiles/dust",
        "contractiles/lust",
        "contractiles/k9/validators",
    ];

    for dir in &dirs {
        fs::create_dir_all(dir)
            .with_context(|| format!("creating directory: {}", dir))?;
    }

    // Write starter A2ML files.
    write_if_missing(
        "contractiles/must/Mustfile.a2ml",
        &generate_mustfile(&name),
        force,
    )?;

    write_if_missing(
        "contractiles/trust/Trustfile.a2ml",
        &generate_trustfile(&name),
        force,
    )?;

    write_if_missing(
        "contractiles/dust/Dustfile.a2ml",
        &generate_dustfile(&name),
        force,
    )?;

    write_if_missing(
        "contractiles/lust/Intentfile.a2ml",
        &generate_intentfile(&name),
        force,
    )?;

    // Generate contractile.just.
    println!("  {} Generating contractile.just...", "+".green());
    let just_content =
        contractile_core::just_emitter::emit_all(contractiles_dir)
            .context("generating contractile.just")?;
    fs::write("contractile.just", &just_content)
        .context("writing contractile.just")?;

    // Print summary.
    println!();
    println!("{}", "Contractiles initialised:".bold());
    println!("  contractiles/must/Mustfile.a2ml     — Physical State checks");
    println!("  contractiles/trust/Trustfile.a2ml   — Integrity verifications");
    println!("  contractiles/dust/Dustfile.a2ml     — Recovery/rollback actions");
    println!("  contractiles/lust/Intentfile.a2ml   — Future intent/roadmap");
    println!("  contractile.just                     — Generated Just recipes");
    println!();
    println!("{}", "Next steps:".bold());
    println!("  1. Edit the A2ML files to match your project");
    println!("  2. Add `import? \"contractile.just\"` to your Justfile");
    println!("  3. Run `must check` to verify Physical State");
    println!("  4. Run `trust list` to see available verifications");
    println!("  5. Run `intend list` to see your roadmap");

    Ok(())
}

/// Write a file only if it doesn't exist (or force is set).
fn write_if_missing(path: &str, content: &str, force: bool) -> Result<()> {
    let p = Path::new(path);
    if p.exists() && !force {
        println!("  {} {} (already exists)", "skip".dimmed(), path);
        return Ok(());
    }
    fs::write(p, content)
        .with_context(|| format!("writing: {}", path))?;
    println!("  {} {}", "+".green(), path);
    Ok(())
}

/// Try to detect the project name from common config files.
fn detect_project_name() -> Option<String> {
    // Cargo.toml
    if let Ok(content) = fs::read_to_string("Cargo.toml") {
        if let Ok(table) = content.parse::<toml::Table>() {
            if let Some(name) = table
                .get("package")
                .and_then(|p| p.get("name"))
                .and_then(|n| n.as_str())
            {
                return Some(name.to_string());
            }
        }
    }

    // deno.json
    if let Ok(content) = fs::read_to_string("deno.json") {
        if let Ok(json) = serde_json::from_str::<serde_json::Value>(&content) {
            if let Some(name) = json.get("name").and_then(|n| n.as_str()) {
                return Some(name.to_string());
            }
        }
    }

    // gleam.toml
    if let Ok(content) = fs::read_to_string("gleam.toml") {
        if let Ok(table) = content.parse::<toml::Table>() {
            if let Some(name) = table.get("name").and_then(|n| n.as_str()) {
                return Some(name.to_string());
            }
        }
    }

    None
}

/// Generate a starter Mustfile.a2ml for a project.
fn generate_mustfile(name: &str) -> String {
    format!(
        r#"# SPDX-License-Identifier: PMPL-1.0-or-later
# Mustfile (A2ML Canonical)

@abstract:
Physical State contract for {name}.
Declares what must be true about this project's files and configuration.
@end

@requires:
- section: Checks
@end

## Checks

### license-present
- description: LICENSE file must exist
- run: test -f LICENSE
- severity: critical

### readme-present
- description: README must exist
- run: test -f README.adoc || test -f README.md
- severity: critical

### spdx-headers
- description: Source files should have SPDX license headers
- run: find . -name '*.rs' -o -name '*.res' -o -name '*.gleam' | head -20 | xargs -r grep -L 'SPDX-License-Identifier' | wc -l | grep -q '^0$'
- severity: warning

### no-banned-files
- description: No Dockerfiles or Makefiles
- run: test ! -f Dockerfile && test ! -f Makefile
- severity: critical
"#
    )
}

/// Generate a starter Trustfile.a2ml for a project.
fn generate_trustfile(name: &str) -> String {
    format!(
        r#"# SPDX-License-Identifier: PMPL-1.0-or-later
# Trustfile (A2ML Canonical)

@abstract:
Integrity and provenance verification for {name}.
@end

@requires:
- section: Verifications
@end

## Verifications

### license-content
- description: LICENSE contains expected SPDX identifier
- command: grep -q 'SPDX\|License\|MIT\|Apache\|PMPL\|MPL' LICENSE
- severity: warning

### no-secrets-committed
- description: No .env or credential files in repo
- command: test ! -f .env && test ! -f credentials.json && test ! -f .env.local
- severity: critical

### container-images-pinned
- description: Containerfile base images use pinned digests
- command: test ! -f Containerfile || grep -q '@sha256:' Containerfile
- severity: warning
"#
    )
}

/// Generate a starter Dustfile.a2ml for a project.
fn generate_dustfile(name: &str) -> String {
    format!(
        r#"# SPDX-License-Identifier: PMPL-1.0-or-later
# Dustfile (A2ML Canonical)

@abstract:
Recovery and rollback paths for {name}.
Declares how to undo significant state changes.
@end

@requires:
- section: Source
@end

## Source

### source-rollback
- description: Revert all source changes to last commit
- rollback: git checkout HEAD -- .
- blast_radius: file
- precondition: git stash
- notes: Stashes uncommitted work before reverting
"#
    )
}

/// Generate a starter Intentfile.a2ml for a project.
fn generate_intentfile(name: &str) -> String {
    format!(
        r#"# SPDX-License-Identifier: PMPL-1.0-or-later
# Intentfile (A2ML Canonical)

@abstract:
Declared future intent for {name}.
@end

@requires:
- section: Features
- section: Quality
@end

## Features

### initial-release
- description: Ship v1.0.0
- status: in-progress
- priority: critical

## Quality

### test-coverage
- description: Achieve meaningful test coverage
- status: declared
- priority: medium
"#
    )
}
