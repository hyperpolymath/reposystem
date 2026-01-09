// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//! Weak link detection - identify risky or fragile edges in the ecosystem

use crate::graph::EcosystemGraph;
use crate::types::Polarity;
use anyhow::{Context, Result};
use std::path::PathBuf;

/// A detected weak link in the ecosystem
#[derive(Debug)]
struct WeakLink {
    /// The edge or repo involved
    target_id: String,
    /// Human-readable target name
    target_name: String,
    /// Why this is considered weak
    reason: String,
    /// Severity level (1-3)
    severity: u8,
    /// Related aspect
    aspect: String,
}

/// Identify weak links in the ecosystem graph
pub fn run(aspect: Option<String>, severity: Option<String>) -> Result<()> {
    let data_dir = get_data_dir()?;
    let graph = EcosystemGraph::load(&data_dir)
        .with_context(|| format!("Failed to load graph from {}", data_dir.display()))?;

    let min_severity: u8 = match severity.as_deref() {
        Some("low") | Some("1") => 1,
        Some("medium") | Some("2") => 2,
        Some("high") | Some("3") => 3,
        Some(other) => anyhow::bail!("Unknown severity: {}. Valid: low, medium, high (or 1-3)", other),
        None => 1, // Show all by default
    };

    let aspect_filter = aspect.map(|a| format!("aspect:{}", a.to_lowercase()));

    let mut weak_links: Vec<WeakLink> = Vec::new();

    // 1. Find repos/edges with risk annotations
    for annotation in &graph.aspects.annotations {
        if annotation.polarity != Polarity::Risk {
            continue;
        }

        if annotation.weight < min_severity {
            continue;
        }

        if let Some(ref filter) = aspect_filter {
            if &annotation.aspect_id != filter {
                continue;
            }
        }

        let target_name = if annotation.target.starts_with("repo:") {
            graph
                .get_repo(&annotation.target)
                .map(|r| r.name.clone())
                .unwrap_or_else(|| annotation.target.clone())
        } else if annotation.target.starts_with("edge:") {
            // Find edge and format as "from -> to"
            graph
                .store
                .edges
                .iter()
                .find(|e| e.id == annotation.target)
                .map(|e| {
                    let from_name = graph.get_repo(&e.from).map(|r| r.name.as_str()).unwrap_or(&e.from);
                    let to_name = graph.get_repo(&e.to).map(|r| r.name.as_str()).unwrap_or(&e.to);
                    format!("{} -> {}", from_name, to_name)
                })
                .unwrap_or_else(|| annotation.target.clone())
        } else {
            annotation.target.clone()
        };

        let aspect_name = graph
            .aspects
            .aspects
            .iter()
            .find(|a| a.id == annotation.aspect_id)
            .map(|a| a.name.clone())
            .unwrap_or_else(|| annotation.aspect_id.replace("aspect:", ""));

        weak_links.push(WeakLink {
            target_id: annotation.target.clone(),
            target_name,
            reason: annotation.reason.clone(),
            severity: annotation.weight,
            aspect: aspect_name,
        });
    }

    // 2. Find single points of failure (repos with many incoming edges but no redundancy)
    let mut incoming_counts: std::collections::HashMap<&str, usize> = std::collections::HashMap::new();
    for edge in &graph.store.edges {
        *incoming_counts.entry(&edge.to).or_insert(0) += 1;
    }

    for (repo_id, count) in incoming_counts {
        if count >= 3 {
            // Only flag if there's a risk annotation OR no strength annotation
            let has_reliability_strength = graph
                .aspects
                .annotations
                .iter()
                .any(|a| {
                    a.target == repo_id
                        && a.aspect_id == "aspect:reliability"
                        && a.polarity == Polarity::Strength
                });

            if !has_reliability_strength {
                let repo_name = graph
                    .get_repo(repo_id)
                    .map(|r| r.name.clone())
                    .unwrap_or_else(|| repo_id.to_string());

                // Check if not already in weak_links
                if !weak_links.iter().any(|w| w.target_id == repo_id && w.aspect == "Reliability") {
                    weak_links.push(WeakLink {
                        target_id: repo_id.to_string(),
                        target_name: repo_name,
                        reason: format!("Single point of failure: {} repos depend on this", count),
                        severity: if count >= 5 { 3 } else { 2 },
                        aspect: "Reliability".into(),
                    });
                }
            }
        }
    }

    // 3. Find edges without evidence
    for edge in &graph.store.edges {
        if edge.evidence.is_empty() {
            let from_name = graph.get_repo(&edge.from).map(|r| r.name.as_str()).unwrap_or(&edge.from);
            let to_name = graph.get_repo(&edge.to).map(|r| r.name.as_str()).unwrap_or(&edge.to);

            weak_links.push(WeakLink {
                target_id: edge.id.clone(),
                target_name: format!("{} -> {}", from_name, to_name),
                reason: "Edge has no evidence".into(),
                severity: 1,
                aspect: "Maintainability".into(),
            });
        }
    }

    // Filter by severity
    weak_links.retain(|w| w.severity >= min_severity);

    // Sort by severity (highest first)
    weak_links.sort_by(|a, b| b.severity.cmp(&a.severity));

    // Output results
    if weak_links.is_empty() {
        println!("No weak links found.");
        if min_severity > 1 {
            println!("  (try lowering severity filter)");
        }
        return Ok(());
    }

    println!("Weak links ({}):", weak_links.len());
    println!();

    for link in &weak_links {
        let severity_icon = match link.severity {
            3 => "!!!",
            2 => "!! ",
            _ => "!  ",
        };

        println!("{} [{}] {}", severity_icon, link.aspect, link.target_name);
        println!("    {}", link.reason);
    }

    println!();
    println!("Legend: !!! = high, !! = medium, ! = low");

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
