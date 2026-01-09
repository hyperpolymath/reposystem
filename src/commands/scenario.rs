// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//! Scenario management commands - create, compare, and switch between scenarios

use crate::graph::EcosystemGraph;
use crate::types::{ChangeSet, Scenario};
use anyhow::{Context, Result};
use chrono::Utc;
use std::path::PathBuf;

/// Run scenario command
pub fn run(action: &str, name: Option<String>, base: Option<String>) -> Result<()> {
    let data_dir = get_data_dir()?;
    let mut graph = EcosystemGraph::load(&data_dir)
        .with_context(|| format!("Failed to load graph from {}", data_dir.display()))?;

    match action {
        "create" | "new" => {
            let name = name.ok_or_else(|| anyhow::anyhow!("Scenario name is required"))?;
            let scenario_id = format!("scenario:{}", slug(&name));

            // Check if scenario already exists
            if graph.store.scenarios.iter().any(|s| s.id == scenario_id) {
                anyhow::bail!("Scenario already exists: {}", name);
            }

            // Validate base scenario if provided
            if let Some(ref base_name) = base {
                let base_id = format!("scenario:{}", slug(base_name));
                if !graph.store.scenarios.iter().any(|s| s.id == base_id) {
                    anyhow::bail!("Base scenario not found: {}", base_name);
                }
            }

            let base_id = base.as_ref().map(|b| format!("scenario:{}", slug(b)));

            let scenario = Scenario {
                kind: "Scenario".into(),
                id: scenario_id.clone(),
                name: name.to_string(),
                base: base_id,
                description: None,
                created_at: Utc::now(),
            };

            // Create empty changeset for this scenario
            let changeset = ChangeSet {
                kind: "ChangeSet".into(),
                scenario_id: scenario_id.clone(),
                ops: vec![],
            };

            graph.store.scenarios.push(scenario);
            graph.store.changesets.push(changeset);
            graph.save(&data_dir)?;

            println!("Created scenario: {} ({})", name, scenario_id);
            if let Some(b) = base {
                println!("  base: {}", b);
            }
        }

        "delete" | "rm" => {
            let name = name.ok_or_else(|| anyhow::anyhow!("Scenario name is required"))?;
            let scenario_id = format!("scenario:{}", slug(&name));

            // Check if any scenarios use this as a base
            let dependents: Vec<_> = graph
                .store
                .scenarios
                .iter()
                .filter(|s| s.base.as_ref() == Some(&scenario_id))
                .map(|s| s.name.clone())
                .collect();

            if !dependents.is_empty() {
                anyhow::bail!(
                    "Cannot delete scenario '{}': used as base by: {:?}",
                    name,
                    dependents
                );
            }

            let before = graph.store.scenarios.len();
            graph.store.scenarios.retain(|s| s.id != scenario_id && s.name != name);
            graph.store.changesets.retain(|c| c.scenario_id != scenario_id);

            if graph.store.scenarios.len() < before {
                graph.save(&data_dir)?;
                println!("Deleted scenario: {}", name);
            } else {
                println!("Scenario not found: {}", name);
            }
        }

        "list" | "ls" => {
            if graph.store.scenarios.is_empty() {
                println!("No scenarios defined. Use 'reposystem scenario create <name>' to create one.");
                return Ok(());
            }

            println!("Scenarios ({}):", graph.store.scenarios.len());
            for scenario in &graph.store.scenarios {
                let ops_count = graph
                    .store
                    .changesets
                    .iter()
                    .find(|c| c.scenario_id == scenario.id)
                    .map(|c| c.ops.len())
                    .unwrap_or(0);

                let base_info = scenario
                    .base
                    .as_ref()
                    .map(|b| format!(" (base: {})", b.replace("scenario:", "")))
                    .unwrap_or_default();

                println!("  {}{} - {} ops", scenario.name, base_info, ops_count);
            }
        }

        "show" => {
            let name = name.ok_or_else(|| anyhow::anyhow!("Scenario name is required"))?;
            let scenario_id = format!("scenario:{}", slug(&name));

            let scenario = graph
                .store
                .scenarios
                .iter()
                .find(|s| s.id == scenario_id || s.name == name)
                .ok_or_else(|| anyhow::anyhow!("Scenario not found: {}", name))?;

            let changeset = graph
                .store
                .changesets
                .iter()
                .find(|c| c.scenario_id == scenario.id);

            println!("Scenario: {}", scenario.name);
            println!("  id: {}", scenario.id);
            if let Some(base) = &scenario.base {
                println!("  base: {}", base);
            }
            if let Some(desc) = &scenario.description {
                println!("  description: {}", desc);
            }
            println!("  created: {}", scenario.created_at.format("%Y-%m-%d %H:%M:%S"));

            if let Some(cs) = changeset {
                println!("  operations ({}):", cs.ops.len());
                for op in &cs.ops {
                    match op {
                        crate::types::ChangeOp::AddEdge { edge } => {
                            println!("    + edge: {} -> {}", edge.from, edge.to);
                        }
                        crate::types::ChangeOp::RemoveEdge { edge_id } => {
                            println!("    - edge: {}", edge_id);
                        }
                        crate::types::ChangeOp::AddAnnotation { annotation } => {
                            println!("    + annotation: {} on {}", annotation.aspect_id, annotation.target);
                        }
                        crate::types::ChangeOp::RemoveAnnotation { annotation_id } => {
                            println!("    - annotation: {}", annotation_id);
                        }
                        crate::types::ChangeOp::SetGroupMembership { group_id, members } => {
                            println!("    ~ group {}: {} members", group_id, members.len());
                        }
                    }
                }
            }
        }

        "compare" => {
            // Compare two scenarios (name is scenario A, base is scenario B)
            let name = name.ok_or_else(|| anyhow::anyhow!("Scenario name is required for compare"))?;
            let scenario_a_id = format!("scenario:{}", slug(&name));
            let scenario_b_id = base
                .map(|b| format!("scenario:{}", slug(&b)))
                .unwrap_or_else(|| "baseline".into());

            let scenario_a = graph
                .store
                .scenarios
                .iter()
                .find(|s| s.id == scenario_a_id || s.name == name);

            let changeset_a = scenario_a.and_then(|s| {
                graph
                    .store
                    .changesets
                    .iter()
                    .find(|c| c.scenario_id == s.id)
            });

            let changeset_b = if scenario_b_id == "baseline" {
                None
            } else {
                graph
                    .store
                    .scenarios
                    .iter()
                    .find(|s| s.id == scenario_b_id)
                    .and_then(|s| {
                        graph
                            .store
                            .changesets
                            .iter()
                            .find(|c| c.scenario_id == s.id)
                    })
            };

            let ops_a = changeset_a.map(|c| c.ops.len()).unwrap_or(0);
            let ops_b = changeset_b.map(|c| c.ops.len()).unwrap_or(0);

            println!("Comparing scenarios:");
            println!("  A: {} ({} ops)", name, ops_a);
            println!("  B: {} ({} ops)", scenario_b_id.replace("scenario:", ""), ops_b);
            println!();

            if ops_a == 0 && ops_b == 0 {
                println!("Both scenarios have no operations (same as baseline).");
            } else {
                println!("Operations in A but not in baseline: {}", ops_a);
                println!("Operations in B but not in baseline: {}", ops_b);
            }
        }

        other => {
            anyhow::bail!(
                "Unknown action: {}. Valid: create, delete, list, show, compare",
                other
            );
        }
    }

    Ok(())
}

/// Convert a name to a slug for IDs
fn slug(name: &str) -> String {
    name.to_lowercase()
        .chars()
        .map(|c| if c.is_alphanumeric() { c } else { '-' })
        .collect::<String>()
        .trim_matches('-')
        .to_string()
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
