// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//! Edge management commands - create and remove relationships between repos

use crate::graph::EcosystemGraph;
use crate::types::{Channel, Edge, EdgeMeta, Evidence, RelationType};
use anyhow::{Context, Result};
use chrono::Utc;
use std::path::PathBuf;

/// Run edge command
pub fn run(
    action: &str,
    from: Option<String>,
    to: Option<String>,
    rel: Option<String>,
    channel: Option<String>,
    label: Option<String>,
    evidence: Option<String>,
) -> Result<()> {
    let data_dir = get_data_dir()?;
    let mut graph = EcosystemGraph::load(&data_dir)
        .with_context(|| format!("Failed to load graph from {}", data_dir.display()))?;

    match action {
        "add" | "create" => {
            let from = from.ok_or_else(|| anyhow::anyhow!("--from is required"))?;
            let to = to.ok_or_else(|| anyhow::anyhow!("--to is required"))?;

            // Parse relationship type
            let rel_type = match rel.as_deref().unwrap_or("uses") {
                "uses" => RelationType::Uses,
                "provides" => RelationType::Provides,
                "extends" => RelationType::Extends,
                "mirrors" => RelationType::Mirrors,
                "replaces" => RelationType::Replaces,
                other => anyhow::bail!("Unknown relation type: {}. Valid: uses, provides, extends, mirrors, replaces", other),
            };

            // Parse channel type
            let chan = match channel.as_deref().unwrap_or("unknown") {
                "api" => Channel::Api,
                "artifact" => Channel::Artifact,
                "config" => Channel::Config,
                "runtime" => Channel::Runtime,
                "human" => Channel::Human,
                "unknown" => Channel::Unknown,
                other => anyhow::bail!("Unknown channel: {}. Valid: api, artifact, config, runtime, human, unknown", other),
            };

            // Resolve repo IDs (allow short names)
            let from_id = resolve_repo_id(&graph, &from)?;
            let to_id = resolve_repo_id(&graph, &to)?;

            // Generate edge ID
            let edge_id = Edge::generate_id(&from_id, &to_id, rel_type, chan, label.as_deref());

            // Build evidence if provided
            let evidence_vec = if let Some(ev) = evidence {
                vec![Evidence {
                    evidence_type: "manual".into(),
                    reference: ev,
                    excerpt: None,
                    confidence: 1.0,
                }]
            } else {
                vec![Evidence {
                    evidence_type: "manual".into(),
                    reference: "user-created".into(),
                    excerpt: None,
                    confidence: 1.0,
                }]
            };

            let edge = Edge {
                kind: "Edge".into(),
                id: edge_id.clone(),
                from: from_id.clone(),
                to: to_id.clone(),
                rel: rel_type,
                channel: chan,
                label: label.clone(),
                evidence: evidence_vec,
                meta: EdgeMeta {
                    created_by: "manual".into(),
                    created_at: Utc::now(),
                },
            };

            graph.add_edge(edge)?;
            graph.save(&data_dir)?;

            println!("Created edge: {} -> {}", from_id, to_id);
            if let Some(l) = label {
                println!("  label: {}", l);
            }
            println!("  id: {}", edge_id);
        }

        "remove" | "delete" | "rm" => {
            let from = from.ok_or_else(|| anyhow::anyhow!("--from is required"))?;
            let to = to.ok_or_else(|| anyhow::anyhow!("--to is required"))?;

            let from_id = resolve_repo_id(&graph, &from)?;
            let to_id = resolve_repo_id(&graph, &to)?;

            // Find and remove matching edges
            let initial_count = graph.store.edges.len();
            graph.store.edges.retain(|e| !(e.from == from_id && e.to == to_id));
            let removed = initial_count - graph.store.edges.len();

            if removed > 0 {
                graph.save(&data_dir)?;
                println!("Removed {} edge(s) from {} -> {}", removed, from_id, to_id);
            } else {
                println!("No edges found from {} -> {}", from_id, to_id);
            }
        }

        "list" | "ls" => {
            if graph.store.edges.is_empty() {
                println!("No edges defined. Use 'reposystem edge add' to create one.");
                return Ok(());
            }

            println!("Edges ({}):", graph.store.edges.len());
            for edge in &graph.store.edges {
                let from_name = graph.get_repo(&edge.from).map(|r| r.name.as_str()).unwrap_or(&edge.from);
                let to_name = graph.get_repo(&edge.to).map(|r| r.name.as_str()).unwrap_or(&edge.to);
                let label = edge.label.as_deref().unwrap_or("");
                println!("  {} --[{:?}/{}]--> {}", from_name, edge.rel, label, to_name);
            }
        }

        other => {
            anyhow::bail!("Unknown action: {}. Valid: add, remove, list", other);
        }
    }

    Ok(())
}

/// Resolve a repo name or ID to a full ID
fn resolve_repo_id(graph: &EcosystemGraph, name_or_id: &str) -> Result<String> {
    // If it looks like a full ID, use it directly
    if name_or_id.starts_with("repo:") {
        if graph.get_repo(name_or_id).is_some() {
            return Ok(name_or_id.to_string());
        }
        anyhow::bail!("Repo not found: {}", name_or_id);
    }

    // Otherwise, search by name
    let matches: Vec<_> = graph
        .repos()
        .iter()
        .filter(|r| r.name == name_or_id || r.name.contains(name_or_id))
        .collect();

    match matches.len() {
        0 => anyhow::bail!("No repo found matching: {}", name_or_id),
        1 => Ok(matches[0].id.clone()),
        _ => {
            eprintln!("Multiple repos match '{}':", name_or_id);
            for r in &matches {
                eprintln!("  {} ({})", r.name, r.id);
            }
            anyhow::bail!("Ambiguous repo name. Use full ID.");
        }
    }
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
