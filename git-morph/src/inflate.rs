// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//
//! Inflate operation — extract a monorepo component into a standalone repo.
//!
//! Steps:
//! 1. Read `.morph.a2ml` manifest from the component directory
//! 2. Copy owned files preserving directory structure
//! 3. Generate inherited files from template
//! 4. Optionally filter git history
//! 5. Write manifest into the standalone repo

use anyhow::{Context, Result};
use owo_colors::OwoColorize;
use std::path::PathBuf;

use crate::manifest;
use crate::template;

/// Options for the inflate operation.
pub struct InflateOpts {
    pub component_path: PathBuf,
    pub output_dir: Option<PathBuf>,
    pub template_override: Option<String>,
    pub with_history: bool,
    pub dry_run: bool,
    pub verbose: bool,
}

/// Run the inflate operation.
pub fn run(opts: InflateOpts) -> Result<()> {
    // 1. Read and validate manifest
    let manifest = manifest::parse_from_dir(&opts.component_path)
        .with_context(|| {
            format!(
                "No .morph.a2ml found in {}. Create one or use `git morph deflate` on a standalone repo instead.",
                opts.component_path.display()
            )
        })?;
    manifest::validate(&manifest)?;

    let component_name = &manifest.component.name;
    let output_dir = opts
        .output_dir
        .unwrap_or_else(|| PathBuf::from(format!("../{component_name}")));

    println!(
        "{} {} → {}",
        "Inflating".green().bold(),
        component_name.cyan(),
        output_dir.display().to_string().cyan()
    );

    if opts.dry_run {
        println!("{}", "(dry run — no files will be written)".yellow());
    }

    // 2. Copy owned files
    let owned_glob = build_owned_glob(&manifest.files.owned)?;
    let mut owned_count = 0;

    for entry in walkdir::WalkDir::new(&opts.component_path)
        .follow_links(false)
        .into_iter()
        .flatten()
    {
        if !entry.file_type().is_file() {
            continue;
        }
        let relative = entry
            .path()
            .strip_prefix(&opts.component_path)
            .unwrap_or(entry.path());

        // Skip .git, build dirs
        if relative
            .components()
            .any(|c| {
                let s = c.as_os_str().to_string_lossy();
                s == ".git" || s == "target" || s == "node_modules"
            })
        {
            continue;
        }

        // Skip the manifest itself (we'll write a fresh one)
        if relative.file_name().map(|f| f == manifest::MANIFEST_FILENAME).unwrap_or(false) {
            continue;
        }

        let relative_str = relative.to_string_lossy();
        if !owned_glob.is_match(relative_str.as_ref()) {
            if opts.verbose {
                println!("  {} {}", "skip".dimmed(), relative.display());
            }
            continue;
        }

        let dest = output_dir.join(relative);

        if opts.dry_run || opts.verbose {
            println!("  {} {}", "copy".green(), relative.display());
        }

        if !opts.dry_run {
            if let Some(parent) = dest.parent() {
                std::fs::create_dir_all(parent)?;
            }
            std::fs::copy(entry.path(), &dest).with_context(|| {
                format!(
                    "Failed to copy {} → {}",
                    entry.path().display(),
                    dest.display()
                )
            })?;
        }

        owned_count += 1;
    }

    // 3. Apply template for inherited files
    let template_name = opts
        .template_override
        .as_deref()
        .or(manifest.template.as_ref().map(|t| t.name.as_str()))
        .unwrap_or(template::DEFAULT_TEMPLATE);

    let mut vars = template::default_vars(
        component_name,
        manifest
            .template
            .as_ref()
            .and_then(|t| t.vars.get("description"))
            .map(|s| s.as_str()),
    );

    // Merge manifest template vars
    if let Some(ref tmpl) = manifest.template {
        for (k, v) in &tmpl.vars {
            vars.insert(k.clone(), v.clone());
        }
    }

    let inherited_count = match template::resolve(template_name, &opts.component_path) {
        Ok(tmpl) => {
            let copied = template::apply_inherited(
                &tmpl,
                &manifest.files.inherited,
                &output_dir,
                &vars,
                opts.dry_run,
            )?;
            copied.len()
        }
        Err(e) => {
            println!(
                "  {} Template '{}' not found: {e}",
                "warn".yellow().bold(),
                template_name
            );
            println!("  Inherited files will not be generated.");
            0
        }
    };

    // 4. Write manifest into standalone repo
    let manifest_dest = output_dir.join(manifest::MANIFEST_FILENAME);
    if !opts.dry_run {
        let manifest_content = std::fs::read_to_string(
            opts.component_path.join(manifest::MANIFEST_FILENAME),
        )?;
        if let Some(parent) = manifest_dest.parent() {
            std::fs::create_dir_all(parent)?;
        }
        std::fs::write(&manifest_dest, manifest_content)?;
    }

    // 5. History filtering (Phase 2)
    if opts.with_history && !opts.dry_run {
        println!(
            "  {} Filtering git history for owned files...",
            "hist".blue().bold()
        );
        match crate::history::filter_history_for_component(
            &opts.component_path,
            &manifest.component.path,
            &manifest.files.owned,
            &output_dir,
        ) {
            Ok(count) => {
                println!(
                    "  {} commit(s) replayed from filtered history",
                    count.to_string().green().bold()
                );
            }
            Err(e) => {
                println!(
                    "  {} History filtering failed: {e}",
                    "warn".yellow().bold()
                );
                println!("  Files were copied successfully, but history was not preserved.");
            }
        }
    } else if opts.with_history && opts.dry_run {
        println!(
            "  {} --with-history would filter and replay git history",
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
        "  {} inherited file(s) from template",
        inherited_count.to_string().green().bold()
    );
    if opts.dry_run {
        println!("\n{}", "No files written (dry run).".yellow());
    } else {
        println!(
            "\nStandalone repo ready at: {}",
            output_dir.display().to_string().cyan().bold()
        );
    }

    Ok(())
}

/// Build a glob set from owned file patterns.
fn build_owned_glob(patterns: &[String]) -> Result<globset::GlobSet> {
    let mut builder = globset::GlobSetBuilder::new();
    for pattern in patterns {
        builder.add(
            globset::Glob::new(pattern)
                .with_context(|| format!("Invalid owned glob: {pattern}"))?,
        );
    }
    builder.build().context("Failed to build owned glob set")
}
