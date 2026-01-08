// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//! Export command - exports the ecosystem graph to various formats

use crate::graph::EcosystemGraph;
use anyhow::{Context, Result};
use std::fs;
use std::io::Write;
use std::path::PathBuf;
use tracing::info;

/// Supported export formats
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ExportFormat {
    /// Graphviz DOT format
    Dot,
    /// JSON format
    Json,
    /// YAML format (future)
    Yaml,
    /// TOML format (future)
    Toml,
}

impl ExportFormat {
    /// Parse format from string
    pub fn from_str(s: &str) -> Option<Self> {
        match s.to_lowercase().as_str() {
            "dot" | "graphviz" => Some(Self::Dot),
            "json" => Some(Self::Json),
            "yaml" | "yml" => Some(Self::Yaml),
            "toml" => Some(Self::Toml),
            _ => None,
        }
    }

    /// Get file extension for format
    pub fn extension(&self) -> &'static str {
        match self {
            Self::Dot => "dot",
            Self::Json => "json",
            Self::Yaml => "yaml",
            Self::Toml => "toml",
        }
    }
}

/// Run the export command
pub fn run(format: &str, output: Option<PathBuf>, aspect: Option<String>) -> Result<()> {
    info!("Exporting to {}", format);

    let export_format = ExportFormat::from_str(format)
        .ok_or_else(|| anyhow::anyhow!("Unknown export format: {}. Supported: dot, json", format))?;

    // Load the graph
    let data_dir = get_data_dir()?;
    let graph = EcosystemGraph::load(&data_dir)
        .with_context(|| format!("Failed to load graph from {}", data_dir.display()))?;

    if graph.is_empty() {
        eprintln!("Warning: Graph is empty. Run 'reposystem scan' first.");
    }

    // Apply aspect filter if specified
    if let Some(ref aspect_name) = aspect {
        info!("Filtering by aspect: {}", aspect_name);
        // TODO: Implement aspect filtering
        eprintln!("Note: Aspect filtering not yet implemented");
    }

    // Generate output
    let content = match export_format {
        ExportFormat::Dot => graph.to_dot(),
        ExportFormat::Json => graph.to_json()?,
        ExportFormat::Yaml => {
            anyhow::bail!("YAML export not yet implemented");
        }
        ExportFormat::Toml => {
            anyhow::bail!("TOML export not yet implemented");
        }
    };

    // Write output
    match output {
        Some(path) => {
            fs::write(&path, &content)
                .with_context(|| format!("Failed to write to {}", path.display()))?;
            println!("Exported to {}", path.display());
        }
        None => {
            // Write to stdout
            let mut stdout = std::io::stdout().lock();
            stdout.write_all(content.as_bytes())?;
            stdout.write_all(b"\n")?;
        }
    }

    Ok(())
}

/// Get the data directory
fn get_data_dir() -> Result<PathBuf> {
    if let Ok(dir) = std::env::var("REPOSYSTEM_DATA_DIR") {
        return Ok(PathBuf::from(dir));
    }

    let data_dir = directories::ProjectDirs::from("org", "hyperpolymath", "reposystem")
        .map(|dirs| dirs.data_dir().to_path_buf())
        .unwrap_or_else(|| {
            std::env::current_dir()
                .unwrap_or_else(|_| PathBuf::from("."))
                .join(".reposystem")
        });

    Ok(data_dir)
}
