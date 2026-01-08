// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//! Group management commands - create clusters of related repositories

use crate::graph::EcosystemGraph;
use crate::types::Group;
use anyhow::{Context, Result};
use std::path::PathBuf;

/// Run group command
pub fn run(action: &str, name: Option<String>, repos: Vec<String>) -> Result<()> {
    let data_dir = get_data_dir()?;
    let mut graph = EcosystemGraph::load(&data_dir)
        .with_context(|| format!("Failed to load graph from {}", data_dir.display()))?;

    match action {
        "create" | "new" => {
            let name = name.ok_or_else(|| anyhow::anyhow!("Group name is required"))?;
            let group_id = format!("group:{}", slug(&name));

            // Resolve repo names to IDs
            let member_ids: Vec<String> = repos
                .iter()
                .map(|r| resolve_repo_id(&graph, r))
                .collect::<Result<Vec<_>>>()?;

            let group = Group {
                kind: "Group".into(),
                id: group_id.clone(),
                name: name.clone(),
                description: None,
                members: member_ids.clone(),
            };

            graph.add_group(group);
            graph.save(&data_dir)?;

            println!("Created group: {} ({})", name, group_id);
            if !member_ids.is_empty() {
                println!("  members: {}", member_ids.len());
            }
        }

        "add" => {
            let name = name.ok_or_else(|| anyhow::anyhow!("Group name is required"))?;
            let group_id = format!("group:{}", slug(&name));

            // Resolve repo IDs first (before mutable borrow)
            let repo_ids: Vec<String> = repos
                .iter()
                .map(|r| resolve_repo_id(&graph, r))
                .collect::<Result<Vec<_>>>()?;

            let group = graph
                .store
                .groups
                .iter_mut()
                .find(|g| g.id == group_id || g.name == name)
                .ok_or_else(|| anyhow::anyhow!("Group not found: {}", name))?;

            for repo_id in repo_ids {
                if !group.members.contains(&repo_id) {
                    group.members.push(repo_id.clone());
                    println!("Added {} to {}", repo_id, group.name);
                } else {
                    println!("{} already in {}", repo_id, group.name);
                }
            }

            graph.save(&data_dir)?;
        }

        "remove" | "rm" => {
            let name = name.ok_or_else(|| anyhow::anyhow!("Group name is required"))?;
            let group_id = format!("group:{}", slug(&name));

            // Resolve repo IDs first (before mutable borrow)
            let repo_ids: Vec<String> = repos
                .iter()
                .map(|r| resolve_repo_id(&graph, r))
                .collect::<Result<Vec<_>>>()?;

            let group = graph
                .store
                .groups
                .iter_mut()
                .find(|g| g.id == group_id || g.name == name)
                .ok_or_else(|| anyhow::anyhow!("Group not found: {}", name))?;

            for repo_id in repo_ids {
                let before = group.members.len();
                group.members.retain(|m| m != &repo_id);
                if group.members.len() < before {
                    println!("Removed {} from {}", repo_id, group.name);
                } else {
                    println!("{} not in {}", repo_id, group.name);
                }
            }

            graph.save(&data_dir)?;
        }

        "delete" => {
            let name = name.ok_or_else(|| anyhow::anyhow!("Group name is required"))?;
            let group_id = format!("group:{}", slug(&name));

            let before = graph.store.groups.len();
            graph.store.groups.retain(|g| g.id != group_id && g.name != name);

            if graph.store.groups.len() < before {
                graph.save(&data_dir)?;
                println!("Deleted group: {}", name);
            } else {
                println!("Group not found: {}", name);
            }
        }

        "list" | "ls" => {
            if graph.store.groups.is_empty() {
                println!("No groups defined. Use 'reposystem group create <name>' to create one.");
                return Ok(());
            }

            println!("Groups ({}):", graph.store.groups.len());
            for group in &graph.store.groups {
                println!("  {} ({} members)", group.name, group.members.len());
                for member in &group.members {
                    let repo_name = graph.get_repo(member).map(|r| r.name.as_str()).unwrap_or(member);
                    println!("    - {}", repo_name);
                }
            }
        }

        "show" => {
            let name = name.ok_or_else(|| anyhow::anyhow!("Group name is required"))?;
            let group_id = format!("group:{}", slug(&name));

            let group = graph
                .store
                .groups
                .iter()
                .find(|g| g.id == group_id || g.name == name)
                .ok_or_else(|| anyhow::anyhow!("Group not found: {}", name))?;

            println!("Group: {}", group.name);
            println!("  id: {}", group.id);
            if let Some(desc) = &group.description {
                println!("  description: {}", desc);
            }
            println!("  members ({}):", group.members.len());
            for member in &group.members {
                let repo = graph.get_repo(member);
                if let Some(r) = repo {
                    println!("    {} [{}]", r.name, r.id);
                } else {
                    println!("    {} (not found)", member);
                }
            }
        }

        other => {
            anyhow::bail!("Unknown action: {}. Valid: create, add, remove, delete, list, show", other);
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

/// Resolve a repo name or ID to a full ID
fn resolve_repo_id(graph: &EcosystemGraph, name_or_id: &str) -> Result<String> {
    if name_or_id.starts_with("repo:") {
        if graph.get_repo(name_or_id).is_some() {
            return Ok(name_or_id.to_string());
        }
        anyhow::bail!("Repo not found: {}", name_or_id);
    }

    let matches: Vec<_> = graph
        .repos()
        .iter()
        .filter(|r| r.name == name_or_id)
        .collect();

    match matches.len() {
        0 => anyhow::bail!("No repo found: {}", name_or_id),
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
