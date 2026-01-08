// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//! Scan command - discovers git repositories and builds the ecosystem graph

use crate::graph::EcosystemGraph;
use crate::scanner::{ScanConfig, scan_path};
use crate::types::Forge;
use anyhow::{Context, Result};
use std::path::PathBuf;
use tracing::info;

/// Run the scan command
pub fn run(
    path: PathBuf,
    deep: bool,
    shallow: bool,
    metadata: bool,
    detect_workspaces: bool,
) -> Result<()> {
    info!("Scanning: {:?}", path);

    // Build scan config from flags
    let config = ScanConfig {
        max_depth: if shallow { 2 } else { 0 },
        follow_symlinks: false,
        deep: deep || metadata,
        ..Default::default()
    };

    // Perform the scan
    let results = scan_path(&path, &config)
        .with_context(|| format!("Failed to scan {}", path.display()))?;

    if results.is_empty() {
        println!("No git repositories found in {}", path.display());
        return Ok(());
    }

    // Build the ecosystem graph
    let mut graph = EcosystemGraph::new();

    for result in &results {
        graph.add_repo(result.repo.clone());

        // Report any warnings
        for warning in &result.warnings {
            eprintln!("  Warning for {}: {}", result.repo.name, warning);
        }
    }

    // Print summary
    println!("Found {} repositories:", graph.node_count());
    println!();

    for repo in graph.repos() {
        let forge_info = if repo.forge == Forge::Local {
            "local".to_string()
        } else {
            format!("{}/{}", repo.owner, repo.name)
        };

        println!(
            "  {} [{}:{}]",
            repo.name,
            repo.forge.code(),
            forge_info
        );

        if !repo.tags.is_empty() {
            println!("    tags: {}", repo.tags.join(", "));
        }
    }

    println!();

    // Determine data directory
    let data_dir = get_data_dir()?;
    graph.save(&data_dir)
        .with_context(|| format!("Failed to save graph to {}", data_dir.display()))?;

    println!("Graph saved to {}", data_dir.display());

    // If workspace detection is requested, look for monorepos
    if detect_workspaces {
        detect_and_report_workspaces(&graph);
    }

    Ok(())
}

/// Get the data directory for storing the graph
fn get_data_dir() -> Result<PathBuf> {
    // Check environment variable first
    if let Ok(dir) = std::env::var("REPOSYSTEM_DATA_DIR") {
        return Ok(PathBuf::from(dir));
    }

    // Use XDG data directory or fallback
    let data_dir = directories::ProjectDirs::from("org", "hyperpolymath", "reposystem")
        .map(|dirs| dirs.data_dir().to_path_buf())
        .unwrap_or_else(|| {
            std::env::current_dir()
                .unwrap_or_else(|_| PathBuf::from("."))
                .join(".reposystem")
        });

    Ok(data_dir)
}

/// Detect and report workspace patterns
fn detect_and_report_workspaces(graph: &EcosystemGraph) {
    // Look for Cargo workspaces
    let rust_repos: Vec<_> = graph
        .repos()
        .iter()
        .filter(|r| r.tags.contains(&"rust".to_string()))
        .collect();

    if rust_repos.len() > 1 {
        println!("Potential Cargo workspace detected ({} Rust repos)", rust_repos.len());
    }

    // Look for npm/deno workspaces
    let js_repos: Vec<_> = graph
        .repos()
        .iter()
        .filter(|r| {
            r.tags.contains(&"javascript".to_string())
                || r.tags.contains(&"deno".to_string())
        })
        .collect();

    if js_repos.len() > 1 {
        println!("Potential JS/Deno workspace detected ({} repos)", js_repos.len());
    }
}
