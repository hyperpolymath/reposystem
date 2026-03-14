// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//
//! Diff command — preview what inflate or deflate would change.
//!
//! This is essentially a convenience alias for `--dry-run` on either direction,
//! with a more detailed summary showing file classifications.

use anyhow::Result;
use owo_colors::OwoColorize;
use std::path::Path;

use crate::detect;
use crate::manifest;

/// Run the diff preview.
pub fn run(direction: &str, path: &str) -> Result<()> {
    match direction {
        "inflate" => diff_inflate(Path::new(path)),
        "deflate" => diff_deflate(Path::new(path)),
        _ => {
            anyhow::bail!(
                "Unknown direction '{}'. Use 'inflate' or 'deflate'.",
                direction
            );
        }
    }
}

/// Preview what inflate would produce.
fn diff_inflate(component_path: &Path) -> Result<()> {
    let manifest = manifest::parse_from_dir(component_path)?;
    manifest::validate(&manifest)?;

    println!(
        "{} inflate preview for '{}'",
        "Diff:".cyan().bold(),
        manifest.component.name.green()
    );
    println!();

    let owned_glob = build_glob_set(&manifest.files.owned)?;
    let mut owned = Vec::new();
    let mut skipped = Vec::new();

    for entry in walkdir::WalkDir::new(component_path)
        .follow_links(false)
        .into_iter()
        .flatten()
    {
        if !entry.file_type().is_file() {
            continue;
        }
        let relative = entry
            .path()
            .strip_prefix(component_path)
            .unwrap_or(entry.path());

        if relative.components().any(|c| {
            let s = c.as_os_str().to_string_lossy();
            s == ".git" || s == "target" || s == "node_modules"
        }) {
            continue;
        }

        let relative_str = relative.to_string_lossy();
        if owned_glob.is_match(relative_str.as_ref()) {
            owned.push(relative.to_path_buf());
        } else {
            skipped.push(relative.to_path_buf());
        }
    }

    println!("  {} Owned files (will be copied):", ">>>".green());
    for f in &owned {
        println!("    + {}", f.display().to_string().green());
    }

    println!();
    println!(
        "  {} Inherited files (from template):",
        "+++".cyan()
    );
    for pattern in &manifest.files.inherited {
        println!("    ~ {} (from template)", pattern.cyan());
    }

    if !skipped.is_empty() {
        println!();
        println!("  {} Skipped files:", "---".dimmed());
        for f in &skipped {
            println!("    - {}", f.display().to_string().dimmed());
        }
    }

    println!();
    println!(
        "Summary: {} owned, {} inherited patterns, {} skipped",
        owned.len().to_string().green().bold(),
        manifest.files.inherited.len().to_string().cyan().bold(),
        skipped.len().to_string().dimmed()
    );

    Ok(())
}

/// Preview what deflate would produce.
fn diff_deflate(repo_path: &Path) -> Result<()> {
    let has_manifest = repo_path.join(manifest::MANIFEST_FILENAME).exists();

    let component_name = repo_path
        .file_name()
        .map(|n| n.to_string_lossy().to_string())
        .unwrap_or_else(|| "unknown".to_string());

    println!(
        "{} deflate preview for '{}'",
        "Diff:".cyan().bold(),
        component_name.green()
    );

    if has_manifest {
        println!("  Using manifest: {}", manifest::MANIFEST_FILENAME);
    } else {
        println!(
            "  {} No manifest — using auto-detection",
            "note".yellow().bold()
        );
    }
    println!();

    let classifications = detect::classify_directory(repo_path);

    let mut owned = Vec::new();
    let mut inherited = Vec::new();
    let mut ignored = Vec::new();

    for (path, class) in &classifications {
        match class {
            detect::FileClass::Owned => owned.push(path),
            detect::FileClass::Inherited => inherited.push(path),
            detect::FileClass::Ignored => ignored.push(path),
        }
    }

    println!("  {} Owned files (will be copied):", ">>>".green());
    for f in &owned {
        println!("    + {}", f.display().to_string().green());
    }

    println!();
    println!(
        "  {} Inherited files (will be stripped):",
        "---".yellow()
    );
    for f in &inherited {
        println!("    - {}", f.display().to_string().yellow());
    }

    if !ignored.is_empty() {
        println!();
        println!("  {} Ignored files:", "...".dimmed());
        for f in &ignored {
            println!("    x {}", f.display().to_string().dimmed());
        }
    }

    println!();
    println!(
        "Summary: {} owned, {} inherited (stripped), {} ignored",
        owned.len().to_string().green().bold(),
        inherited.len().to_string().yellow().bold(),
        ignored.len().to_string().dimmed()
    );

    Ok(())
}

/// Build a glob set from patterns.
fn build_glob_set(patterns: &[String]) -> Result<globset::GlobSet> {
    let mut builder = globset::GlobSetBuilder::new();
    for pattern in patterns {
        builder.add(globset::Glob::new(pattern)?);
    }
    Ok(builder.build()?)
}
