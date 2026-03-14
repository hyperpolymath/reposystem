// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//
//! Deflate operation — pack a standalone repo into a monorepo as a component.
//!
//! Steps:
//! 1. Read `.morph.a2ml` manifest (or auto-detect classification)
//! 2. Classify files as owned/inherited/ignored
//! 3. Copy owned files into the monorepo at the target path
//! 4. Strip inherited files (monorepo root provides these)
//! 5. Create/update manifest in the monorepo

use anyhow::{Context, Result};
use owo_colors::OwoColorize;
use std::path::PathBuf;

use crate::detect;
use crate::manifest;

/// Options for the deflate operation.
pub struct DeflateOpts {
    pub repo_path: PathBuf,
    pub monorepo_dir: Option<PathBuf>,
    pub target_path: Option<String>,
    pub squash: bool,
    pub dry_run: bool,
    pub verbose: bool,
}

/// Run the deflate operation.
pub fn run(opts: DeflateOpts) -> Result<()> {
    let monorepo_dir = opts
        .monorepo_dir
        .unwrap_or_else(|| PathBuf::from("."));

    // 1. Try to read manifest, fall back to auto-detection
    let (manifest, auto_detected) = match manifest::parse_from_dir(&opts.repo_path) {
        Ok(m) => {
            manifest::validate(&m)?;
            (Some(m), false)
        }
        Err(_) => {
            println!(
                "  {} No .morph.a2ml found, using auto-detection heuristics",
                "note".yellow().bold()
            );
            (None, true)
        }
    };

    let component_name = manifest
        .as_ref()
        .map(|m| m.component.name.clone())
        .unwrap_or_else(|| {
            opts.repo_path
                .file_name()
                .map(|n| n.to_string_lossy().to_string())
                .unwrap_or_else(|| "unknown".to_string())
        });

    let target_path = opts
        .target_path
        .map(PathBuf::from)
        .or_else(|| manifest.as_ref().map(|m| m.component.path.clone()))
        .unwrap_or_else(|| PathBuf::from(&component_name));

    let dest_dir = monorepo_dir.join(&target_path);

    println!(
        "{} {} → {}",
        "Deflating".green().bold(),
        component_name.cyan(),
        dest_dir.display().to_string().cyan()
    );

    if opts.dry_run {
        println!("{}", "(dry run — no files will be written)".yellow());
    }

    // 2. Classify and copy files
    let mut owned_count = 0;
    let mut inherited_count = 0;
    let mut ignored_count = 0;

    if let Some(ref m) = manifest {
        // Manifest-driven classification
        let owned_glob = build_glob_set(&m.files.owned)?;
        let inherited_glob = build_glob_set(&m.files.inherited)?;

        for entry in walkdir::WalkDir::new(&opts.repo_path)
            .follow_links(false)
            .into_iter()
            .flatten()
        {
            if !entry.file_type().is_file() {
                continue;
            }
            let relative = entry
                .path()
                .strip_prefix(&opts.repo_path)
                .unwrap_or(entry.path());

            // Always skip .git
            if relative
                .components()
                .any(|c| c.as_os_str() == ".git")
            {
                continue;
            }

            let relative_str = relative.to_string_lossy();

            if inherited_glob.is_match(relative_str.as_ref()) {
                // Strip inherited files
                inherited_count += 1;
                if opts.verbose {
                    println!("  {} {} (inherited)", "strip".yellow(), relative.display());
                }
            } else if owned_glob.is_match(relative_str.as_ref()) {
                // Copy owned files
                copy_file(entry.path(), &dest_dir.join(relative), opts.dry_run, opts.verbose)?;
                owned_count += 1;
            } else {
                // Unmatched — treat as owned (conservative)
                copy_file(entry.path(), &dest_dir.join(relative), opts.dry_run, opts.verbose)?;
                owned_count += 1;
            }
        }
    } else {
        // Auto-detection classification
        let classifications = detect::classify_directory(&opts.repo_path);

        for (relative, class) in &classifications {
            let source = opts.repo_path.join(relative);

            match class {
                detect::FileClass::Owned => {
                    copy_file(&source, &dest_dir.join(relative), opts.dry_run, opts.verbose)?;
                    owned_count += 1;
                }
                detect::FileClass::Inherited => {
                    inherited_count += 1;
                    if opts.verbose {
                        println!(
                            "  {} {} (inherited)",
                            "strip".yellow(),
                            relative.display()
                        );
                    }
                }
                detect::FileClass::Ignored => {
                    ignored_count += 1;
                    if opts.verbose {
                        println!(
                            "  {} {} (ignored)",
                            "skip".dimmed(),
                            relative.display()
                        );
                    }
                }
            }
        }
    }

    // 3. Generate manifest if auto-detected
    if auto_detected && !opts.dry_run {
        let manifest_path = dest_dir.join(manifest::MANIFEST_FILENAME);
        let manifest_content = generate_manifest(&component_name, &target_path);
        if let Some(parent) = manifest_path.parent() {
            std::fs::create_dir_all(parent)?;
        }
        std::fs::write(&manifest_path, manifest_content)
            .with_context(|| format!("Failed to write manifest: {}", manifest_path.display()))?;
        println!(
            "  {} Generated {}",
            "new".green(),
            manifest::MANIFEST_FILENAME
        );
    }

    // 4. History squashing (Phase 2)
    if opts.squash && !opts.dry_run {
        println!(
            "  {} Squashing history into a single commit...",
            "hist".blue().bold()
        );
        let squash_msg = format!(
            "Deflate {} into monorepo (squashed)\n\nCreated by git-morph deflate --squash",
            component_name
        );
        match crate::history::squash_history(&dest_dir, &squash_msg) {
            Ok(()) => {
                println!(
                    "  {} History squashed into a single commit",
                    "done".green().bold()
                );
            }
            Err(e) => {
                println!(
                    "  {} History squashing failed: {e}",
                    "warn".yellow().bold()
                );
                println!("  Files were copied successfully, but history was not squashed.");
            }
        }
    } else if opts.squash && opts.dry_run {
        println!(
            "  {} --squash would create a single commit from all history",
            "note".yellow().bold()
        );
    }

    // Summary
    println!();
    println!(
        "  {} owned file(s) copied",
        owned_count.to_string().green().bold()
    );
    println!(
        "  {} inherited file(s) stripped",
        inherited_count.to_string().yellow().bold()
    );
    if ignored_count > 0 {
        println!(
            "  {} file(s) ignored",
            ignored_count.to_string().dimmed()
        );
    }
    if opts.dry_run {
        println!("\n{}", "No files written (dry run).".yellow());
    } else {
        println!(
            "\nComponent deflated into: {}",
            dest_dir.display().to_string().cyan().bold()
        );
    }

    Ok(())
}

/// Copy a single file, creating parent directories as needed.
fn copy_file(source: &std::path::Path, dest: &std::path::Path, dry_run: bool, verbose: bool) -> Result<()> {
    if dry_run || verbose {
        if let Ok(relative) = dest.strip_prefix(".") {
            println!("  {} {}", "copy".green(), relative.display());
        } else {
            println!("  {} {}", "copy".green(), dest.display());
        }
    }

    if !dry_run {
        if let Some(parent) = dest.parent() {
            std::fs::create_dir_all(parent)?;
        }
        std::fs::copy(source, dest).with_context(|| {
            format!(
                "Failed to copy {} → {}",
                source.display(),
                dest.display()
            )
        })?;
    }

    Ok(())
}

/// Build a glob set from patterns.
fn build_glob_set(patterns: &[String]) -> Result<globset::GlobSet> {
    let mut builder = globset::GlobSetBuilder::new();
    for pattern in patterns {
        builder.add(
            globset::Glob::new(pattern)
                .with_context(|| format!("Invalid glob: {pattern}"))?,
        );
    }
    builder.build().context("Failed to build glob set")
}

/// Generate a minimal `.morph.a2ml` manifest for an auto-detected component.
fn generate_manifest(name: &str, path: &std::path::Path) -> String {
    format!(
        r#"# SPDX-License-Identifier: PMPL-1.0-or-later
# Auto-generated by git-morph deflate

[component]
name = "{name}"
path = "{path}"

[files]
owned = [
  "src/**",
  "lib/**",
  "tests/**",
  "docs/**",
  "examples/**",
  "Cargo.toml",
  "deno.json",
  "rescript.json",
  "build.zig",
  "justfile",
  "README.*",
]

inherited = [
  "LICENSE",
  "SECURITY.md",
  "CODE_OF_CONDUCT.md",
  "CONTRIBUTING.md",
  ".github/workflows/hypatia-scan.yml",
  ".github/workflows/mirror.yml",
  ".github/workflows/codeql.yml",
  ".github/workflows/scorecard.yml",
  ".github/workflows/quality.yml",
]

[template]
name = "rsr-template-repo"
vars = {{ repo_name = "{name}" }}
"#,
        path = path.display()
    )
}
