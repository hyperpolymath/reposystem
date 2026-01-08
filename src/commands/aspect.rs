// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//! Aspect tagging commands - annotate repos and edges with aspect weights

use crate::graph::EcosystemGraph;
use crate::types::{AnnotationSource, AspectAnnotation, Evidence, Polarity};
use anyhow::{Context, Result};
use chrono::Utc;
use sha2::{Digest, Sha256};
use std::path::PathBuf;

/// Run aspect command
pub fn run(action: &str, target: Option<String>, aspect: Option<String>, args: AspectArgs) -> Result<()> {
    let data_dir = get_data_dir()?;
    let mut graph = EcosystemGraph::load(&data_dir)
        .with_context(|| format!("Failed to load graph from {}", data_dir.display()))?;

    match action {
        "tag" | "add" => {
            let target = target.ok_or_else(|| anyhow::anyhow!("--target is required"))?;
            let aspect_name = aspect.ok_or_else(|| anyhow::anyhow!("--aspect is required"))?;

            // Resolve target (repo or edge)
            let target_id = resolve_target(&graph, &target)?;

            // Validate aspect exists
            let aspect_id = format!("aspect:{}", aspect_name.to_lowercase());
            if !graph.aspects.aspects.iter().any(|a| a.id == aspect_id) {
                let valid: Vec<_> = graph.aspects.aspects.iter().map(|a| &a.name).collect();
                anyhow::bail!("Unknown aspect: {}. Valid: {:?}", aspect_name, valid);
            }

            // Parse weight (0-3)
            let weight = args.weight.unwrap_or(1).min(3);

            // Parse polarity
            let polarity = match args.polarity.as_deref().unwrap_or("neutral") {
                "risk" | "weakness" | "concern" => Polarity::Risk,
                "strength" | "positive" => Polarity::Strength,
                "neutral" | "observation" => Polarity::Neutral,
                other => anyhow::bail!("Unknown polarity: {}. Valid: risk, strength, neutral", other),
            };

            // Generate annotation ID
            let annotation_id = generate_annotation_id(&target_id, &aspect_id);

            // Build evidence
            let evidence = if let Some(ref ev) = args.evidence {
                vec![Evidence {
                    evidence_type: "manual".into(),
                    reference: ev.clone(),
                    excerpt: None,
                    confidence: 1.0,
                }]
            } else {
                vec![]
            };

            let annotation = AspectAnnotation {
                kind: "AspectAnnotation".into(),
                id: annotation_id.clone(),
                target: target_id.clone(),
                aspect_id: aspect_id.clone(),
                weight,
                polarity,
                reason: args.reason.unwrap_or_else(|| "Manual annotation".into()),
                evidence,
                source: AnnotationSource {
                    mode: "manual".into(),
                    who: "user".into(),
                    when: Utc::now(),
                    rule_id: None,
                },
            };

            // Check if annotation already exists, update if so
            if let Some(existing) = graph.aspects.annotations.iter_mut().find(|a| a.target == target_id && a.aspect_id == aspect_id) {
                *existing = annotation;
                println!("Updated annotation on {} for {}", target_id, aspect_name);
            } else {
                graph.aspects.annotations.push(annotation);
                println!("Added {} annotation to {}", aspect_name, target_id);
            }

            println!("  weight: {}/3", weight);
            println!("  polarity: {:?}", polarity);

            graph.save(&data_dir)?;
        }

        "remove" | "rm" => {
            let target = target.ok_or_else(|| anyhow::anyhow!("--target is required"))?;
            let aspect_name = aspect.ok_or_else(|| anyhow::anyhow!("--aspect is required"))?;

            let target_id = resolve_target(&graph, &target)?;
            let aspect_id = format!("aspect:{}", aspect_name.to_lowercase());

            let before = graph.aspects.annotations.len();
            graph.aspects.annotations.retain(|a| !(a.target == target_id && a.aspect_id == aspect_id));

            if graph.aspects.annotations.len() < before {
                graph.save(&data_dir)?;
                println!("Removed {} annotation from {}", aspect_name, target_id);
            } else {
                println!("No {} annotation found on {}", aspect_name, target_id);
            }
        }

        "list" | "ls" => {
            // List available aspects
            println!("Available aspects:");
            for aspect in &graph.aspects.aspects {
                let count = graph.aspects.annotations.iter().filter(|a| a.aspect_id == aspect.id).count();
                println!("  {} - {} ({} annotations)", aspect.name, aspect.description, count);
            }
        }

        "show" => {
            let target = target.ok_or_else(|| anyhow::anyhow!("--target is required"))?;
            let target_id = resolve_target(&graph, &target)?;

            let annotations: Vec<_> = graph
                .aspects
                .annotations
                .iter()
                .filter(|a| a.target == target_id)
                .collect();

            if annotations.is_empty() {
                println!("No annotations on {}", target_id);
                return Ok(());
            }

            println!("Annotations on {}:", target_id);
            for ann in annotations {
                let aspect_name = graph
                    .aspects
                    .aspects
                    .iter()
                    .find(|a| a.id == ann.aspect_id)
                    .map(|a| a.name.as_str())
                    .unwrap_or(&ann.aspect_id);

                println!("  {} [{}/3, {:?}]", aspect_name, ann.weight, ann.polarity);
                println!("    reason: {}", ann.reason);
            }
        }

        "filter" => {
            // Filter and show repos/edges by aspect
            let aspect_name = aspect.unwrap_or_else(|| "security".into());
            let aspect_id = format!("aspect:{}", aspect_name.to_lowercase());

            let annotations: Vec<_> = graph
                .aspects
                .annotations
                .iter()
                .filter(|a| a.aspect_id == aspect_id)
                .collect();

            if annotations.is_empty() {
                println!("No {} annotations found", aspect_name);
                return Ok(());
            }

            println!("{} view ({} annotations):", aspect_name, annotations.len());
            for ann in annotations {
                let target_name = if ann.target.starts_with("repo:") {
                    graph.get_repo(&ann.target).map(|r| r.name.clone()).unwrap_or_else(|| ann.target.clone())
                } else {
                    ann.target.clone()
                };

                let icon = match ann.polarity {
                    Polarity::Risk => "⚠",
                    Polarity::Strength => "✓",
                    Polarity::Neutral => "○",
                };

                println!("  {} {} [weight: {}] - {}", icon, target_name, ann.weight, ann.reason);
            }
        }

        other => {
            anyhow::bail!("Unknown action: {}. Valid: tag, remove, list, show, filter", other);
        }
    }

    Ok(())
}

/// Additional arguments for aspect commands
#[derive(Default)]
pub struct AspectArgs {
    /// Weight of the annotation (0-3)
    pub weight: Option<u8>,
    /// Polarity: risk, strength, or neutral
    pub polarity: Option<String>,
    /// Human-readable reason for the annotation
    pub reason: Option<String>,
    /// Evidence reference (file path, URL, etc.)
    pub evidence: Option<String>,
}

/// Resolve a target name to ID (repo or edge)
fn resolve_target(graph: &EcosystemGraph, target: &str) -> Result<String> {
    // Check if it's already a full ID
    if target.starts_with("repo:") || target.starts_with("edge:") {
        return Ok(target.to_string());
    }

    // Try to find a repo by name
    let matches: Vec<_> = graph
        .repos()
        .iter()
        .filter(|r| r.name == target)
        .collect();

    match matches.len() {
        0 => anyhow::bail!("No repo found: {}", target),
        1 => Ok(matches[0].id.clone()),
        _ => {
            eprintln!("Multiple repos match '{}':", target);
            for r in &matches {
                eprintln!("  {} ({})", r.name, r.id);
            }
            anyhow::bail!("Ambiguous name. Use full ID.");
        }
    }
}

/// Generate a deterministic annotation ID
fn generate_annotation_id(target: &str, aspect_id: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(target.as_bytes());
    hasher.update(aspect_id.as_bytes());
    let hash = hex::encode(hasher.finalize());
    format!("aa:{}", &hash[..8])
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
