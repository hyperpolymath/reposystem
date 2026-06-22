// SPDX-License-Identifier: MPL-2.0
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
//
//! Import command — populate the ecosystem graph from the estate manifest.

use crate::importers::manifest::{self, ManifestImport};
use anyhow::{Context, Result};
use std::path::PathBuf;
use tracing::info;

/// Arguments for the import command.
pub struct ImportArgs {
    /// Path to the manifest (`repos.toml`).
    pub manifest: Option<PathBuf>,
    /// Path to the groups file (`repos.groups.toml`).
    pub groups: Option<PathBuf>,
    /// Estate id to stamp on imported nodes.
    pub estate: String,
    /// Estate display name.
    pub estate_name: Option<String>,
}

/// Run the import command.
///
/// # Errors
/// Returns an error for an unknown source or if the import/save fails.
pub fn run(source: &str, args: ImportArgs) -> Result<()> {
    match source {
        "manifest" | "repos" | "toml" => run_manifest(args),
        other => anyhow::bail!("Unknown import source: {other}. Supported: manifest"),
    }
}

fn run_manifest(args: ImportArgs) -> Result<()> {
    let opts = ManifestImport {
        manifest: args.manifest.unwrap_or_else(|| PathBuf::from("repos.toml")),
        groups: args
            .groups
            .or_else(|| Some(PathBuf::from("repos.groups.toml"))),
        estate_id: args.estate,
        estate_name: args.estate_name.unwrap_or_else(|| "Hyperpolymath".to_string()),
    };

    info!("Importing estate manifest from {}", opts.manifest.display());
    let (graph, summary) = manifest::import(&opts)?;

    let data_dir = crate::commands::data_dir()?;
    graph
        .save(&data_dir)
        .with_context(|| format!("Failed to save graph to {}", data_dir.display()))?;

    println!(
        "Imported {} repos, {} seams, {} groups into estate {}",
        summary.repos, summary.seams, summary.groups, opts.estate_id
    );
    println!("Graph saved to {}", data_dir.display());
    Ok(())
}
