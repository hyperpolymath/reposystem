// SPDX-License-Identifier: PMPL-1.0-or-later
// gen_just.rs — `contractile gen-just`: Generate contractile.just from A2ML + K9 sources.
//
// Scans a directory for *.a2ml and *.k9.ncl files, parses them, and emits a
// single `contractile.just` file that can be imported into any repo's Justfile:
//
//   import "contractile.just"
//
// This bridges the contractile system into the Just task runner, allowing
// developers to use `just must-check`, `just trust-verify`, `just dust-status`
// etc. without needing the contractile CLI installed.
//
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)

use anyhow::{Context, Result};
use colored::Colorize;
use contractile_core::just_emitter;
use std::fs;
use std::path::Path;

/// Generate contractile.just from all sources in the given directory.
pub fn run(dir: &str, output: &str) -> Result<()> {
    let dir_path = Path::new(dir);

    if !dir_path.is_dir() {
        // If the specified directory doesn't exist, try common alternatives.
        let alternatives = ["contractiles", ".", "contracts"];
        let found = alternatives.iter().find(|d| Path::new(d).is_dir());

        if let Some(alt) = found {
            println!(
                "{} '{}' not found, using '{}'",
                "gen-just:".bold(),
                dir,
                alt
            );
            return run(alt, output);
        }

        anyhow::bail!(
            "Directory '{}' not found. Create it or specify --dir",
            dir
        );
    }

    println!(
        "{} Scanning {} for A2ML and K9 sources...",
        "gen-just:".bold(),
        dir_path.display()
    );

    let content = just_emitter::emit_all(dir_path)
        .context("generating Just recipes from contractile sources")?;

    fs::write(output, &content)
        .with_context(|| format!("writing output file: {}", output))?;

    // Count what we generated.
    let recipe_count = content.lines().filter(|l| l.ends_with(':') && !l.starts_with('#')).count();

    println!(
        "{} Generated {} with {} recipe(s)",
        "gen-just:".bold(),
        output.cyan(),
        recipe_count
    );
    println!(
        "  Add `import \"{}\"` to your Justfile to use them",
        output
    );

    Ok(())
}
