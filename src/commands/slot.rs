// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//! Slot and provider management commands

use crate::graph::EcosystemGraph;
use crate::types::{BindingMode, Provider, ProviderType, Slot, SlotBinding};
use anyhow::{Context, Result};
use chrono::Utc;
use std::path::PathBuf;

/// Arguments for slot commands
pub struct SlotArgs {
    /// Slot category
    pub category: Option<String>,
    /// Interface version
    pub version: Option<String>,
    /// Description
    pub description: Option<String>,
    /// Required capabilities (comma-separated)
    pub capabilities: Option<String>,
}

/// Arguments for provider commands
pub struct ProviderArgs {
    /// Slot ID this provider satisfies
    pub slot: Option<String>,
    /// Provider type
    pub provider_type: Option<String>,
    /// Repository ID (for local providers)
    pub repo: Option<String>,
    /// External URI (for ecosystem/external providers)
    pub uri: Option<String>,
    /// Interface version
    pub version: Option<String>,
    /// Capabilities (comma-separated)
    pub capabilities: Option<String>,
    /// Priority
    pub priority: Option<i32>,
    /// Is fallback
    pub fallback: bool,
}

/// Arguments for binding commands
pub struct BindingArgs {
    /// Consumer repository
    pub consumer: Option<String>,
    /// Slot ID
    pub slot: Option<String>,
    /// Provider ID
    pub provider: Option<String>,
}

/// Run slot command
pub fn run_slot(action: &str, name: Option<String>, args: SlotArgs) -> Result<()> {
    let data_dir = get_data_dir()?;
    let mut graph = EcosystemGraph::load(&data_dir)
        .with_context(|| format!("Failed to load graph from {}", data_dir.display()))?;

    match action {
        "create" | "new" => {
            let name = name.ok_or_else(|| anyhow::anyhow!("Slot name is required"))?;
            let category = args.category.ok_or_else(|| anyhow::anyhow!("Slot category is required (--category)"))?;

            let slot_id = Slot::generate_id(&category, &name);

            // Check if slot already exists
            if graph.slots.slots.iter().any(|s| s.id == slot_id) {
                anyhow::bail!("Slot already exists: {}", slot_id);
            }

            let capabilities: Vec<String> = args.capabilities
                .map(|c| c.split(',').map(|s| s.trim().to_string()).collect())
                .unwrap_or_default();

            let slot = Slot {
                kind: "Slot".into(),
                id: slot_id.clone(),
                name: name.clone(),
                category: category.clone(),
                description: args.description.unwrap_or_else(|| format!("{} slot", name)),
                interface_version: args.version,
                required_capabilities: capabilities,
            };

            graph.slots.slots.push(slot);
            graph.save(&data_dir)?;

            println!("Created slot: {} ({})", name, slot_id);
            println!("  category: {}", category);
        }

        "delete" | "rm" => {
            let name = name.ok_or_else(|| anyhow::anyhow!("Slot name or ID is required"))?;

            // Find by ID or name
            let slot_id = if name.starts_with("slot:") {
                name.clone()
            } else {
                // Try to find by name
                graph.slots.slots.iter()
                    .find(|s| s.name == name)
                    .map(|s| s.id.clone())
                    .ok_or_else(|| anyhow::anyhow!("Slot not found: {}", name))?
            };

            // Check if any providers use this slot
            let providers: Vec<_> = graph.slots.providers.iter()
                .filter(|p| p.slot_id == slot_id)
                .map(|p| p.name.clone())
                .collect();

            if !providers.is_empty() {
                anyhow::bail!("Cannot delete slot '{}': has providers: {:?}", name, providers);
            }

            let before = graph.slots.slots.len();
            graph.slots.slots.retain(|s| s.id != slot_id);

            if graph.slots.slots.len() < before {
                graph.save(&data_dir)?;
                println!("Deleted slot: {}", name);
            } else {
                println!("Slot not found: {}", name);
            }
        }

        "list" | "ls" => {
            if graph.slots.slots.is_empty() {
                println!("No slots defined. Use 'reposystem slot create <name> --category <cat>' to create one.");
                return Ok(());
            }

            println!("Slots ({}):", graph.slots.slots.len());
            for slot in &graph.slots.slots {
                let provider_count = graph.slots.providers_for_slot(&slot.id).len();
                let version_info = slot.interface_version.as_ref()
                    .map(|v| format!(" ({})", v))
                    .unwrap_or_default();

                println!("  {}{} - {} providers", slot.id, version_info, provider_count);
                if !slot.required_capabilities.is_empty() {
                    println!("    requires: {:?}", slot.required_capabilities);
                }
            }
        }

        "show" => {
            let name = name.ok_or_else(|| anyhow::anyhow!("Slot name or ID is required"))?;

            let slot = graph.slots.slots.iter()
                .find(|s| s.id == name || s.name == name || s.id.ends_with(&format!(".{}", name)))
                .ok_or_else(|| anyhow::anyhow!("Slot not found: {}", name))?;

            println!("Slot: {}", slot.name);
            println!("  id: {}", slot.id);
            println!("  category: {}", slot.category);
            println!("  description: {}", slot.description);
            if let Some(v) = &slot.interface_version {
                println!("  interface version: {}", v);
            }
            if !slot.required_capabilities.is_empty() {
                println!("  required capabilities: {:?}", slot.required_capabilities);
            }

            let providers = graph.slots.providers_for_slot(&slot.id);
            if providers.is_empty() {
                println!("  providers: (none)");
            } else {
                println!("  providers ({}):", providers.len());
                for p in providers {
                    let type_str = match p.provider_type {
                        ProviderType::Local => "local",
                        ProviderType::Ecosystem => "ecosystem",
                        ProviderType::External => "external",
                        ProviderType::Stub => "stub",
                    };
                    let fallback = if p.is_fallback { " [fallback]" } else { "" };
                    println!("    {} ({}, priority: {}){}", p.name, type_str, p.priority, fallback);
                }
            }

            let bindings: Vec<_> = graph.slots.bindings.iter()
                .filter(|b| b.slot_id == slot.id)
                .collect();
            if !bindings.is_empty() {
                println!("  bindings ({}):", bindings.len());
                for b in bindings {
                    let consumer_name = graph.get_repo(&b.consumer_id)
                        .map(|r| r.name.as_str())
                        .unwrap_or(&b.consumer_id);
                    let provider = graph.slots.providers.iter()
                        .find(|p| p.id == b.provider_id)
                        .map(|p| p.name.as_str())
                        .unwrap_or(&b.provider_id);
                    println!("    {} -> {}", consumer_name, provider);
                }
            }
        }

        other => {
            anyhow::bail!("Unknown slot action: {}. Valid: create, delete, list, show", other);
        }
    }

    Ok(())
}

/// Run provider command
pub fn run_provider(action: &str, name: Option<String>, args: ProviderArgs) -> Result<()> {
    let data_dir = get_data_dir()?;
    let mut graph = EcosystemGraph::load(&data_dir)
        .with_context(|| format!("Failed to load graph from {}", data_dir.display()))?;

    match action {
        "create" | "new" => {
            let name = name.ok_or_else(|| anyhow::anyhow!("Provider name is required"))?;
            let slot_id = args.slot.ok_or_else(|| anyhow::anyhow!("Slot ID is required (--slot)"))?;

            // Normalize slot ID
            let slot_id = if slot_id.starts_with("slot:") {
                slot_id
            } else {
                format!("slot:{}", slot_id)
            };

            // Verify slot exists
            if !graph.slots.slots.iter().any(|s| s.id == slot_id) {
                anyhow::bail!("Slot not found: {}", slot_id);
            }

            let provider_id = Provider::generate_id(&slot_id, &name);

            // Check if provider already exists
            if graph.slots.providers.iter().any(|p| p.id == provider_id) {
                anyhow::bail!("Provider already exists: {}", provider_id);
            }

            let provider_type = match args.provider_type.as_deref() {
                Some("local") => ProviderType::Local,
                Some("ecosystem") => ProviderType::Ecosystem,
                Some("external") => ProviderType::External,
                Some("stub") => ProviderType::Stub,
                Some(other) => anyhow::bail!("Unknown provider type: {}. Valid: local, ecosystem, external, stub", other),
                None => ProviderType::Local,
            };

            // Resolve repo ID if provided
            let repo_id = if let Some(ref repo_name) = args.repo {
                let repo = graph.store.repos.iter()
                    .find(|r| r.name == *repo_name || r.id == *repo_name)
                    .ok_or_else(|| anyhow::anyhow!("Repository not found: {}", repo_name))?;
                Some(repo.id.clone())
            } else {
                None
            };

            let capabilities: Vec<String> = args.capabilities
                .map(|c| c.split(',').map(|s| s.trim().to_string()).collect())
                .unwrap_or_default();

            let provider = Provider {
                kind: "Provider".into(),
                id: provider_id.clone(),
                name: name.clone(),
                slot_id: slot_id.clone(),
                provider_type,
                repo_id,
                external_uri: args.uri,
                interface_version: args.version,
                capabilities,
                priority: args.priority.unwrap_or(0),
                is_fallback: args.fallback,
            };

            graph.slots.providers.push(provider);
            graph.save(&data_dir)?;

            println!("Created provider: {} ({})", name, provider_id);
            println!("  for slot: {}", slot_id);
        }

        "delete" | "rm" => {
            let name = name.ok_or_else(|| anyhow::anyhow!("Provider name or ID is required"))?;

            let provider_id = if name.starts_with("provider:") {
                name.clone()
            } else {
                graph.slots.providers.iter()
                    .find(|p| p.name == name)
                    .map(|p| p.id.clone())
                    .ok_or_else(|| anyhow::anyhow!("Provider not found: {}", name))?
            };

            // Check if any bindings use this provider
            let bindings: Vec<_> = graph.slots.bindings_for_provider(&provider_id)
                .iter()
                .map(|b| b.consumer_id.clone())
                .collect();

            if !bindings.is_empty() {
                anyhow::bail!("Cannot delete provider '{}': used by bindings: {:?}", name, bindings);
            }

            let before = graph.slots.providers.len();
            graph.slots.providers.retain(|p| p.id != provider_id);

            if graph.slots.providers.len() < before {
                graph.save(&data_dir)?;
                println!("Deleted provider: {}", name);
            } else {
                println!("Provider not found: {}", name);
            }
        }

        "list" | "ls" => {
            if graph.slots.providers.is_empty() {
                println!("No providers defined. Use 'reposystem provider create <name> --slot <slot>' to create one.");
                return Ok(());
            }

            println!("Providers ({}):", graph.slots.providers.len());
            for provider in &graph.slots.providers {
                let type_str = match provider.provider_type {
                    ProviderType::Local => "local",
                    ProviderType::Ecosystem => "ecosystem",
                    ProviderType::External => "external",
                    ProviderType::Stub => "stub",
                };
                let fallback = if provider.is_fallback { " [fallback]" } else { "" };
                let binding_count = graph.slots.bindings_for_provider(&provider.id).len();

                println!("  {} ({}) - {} bindings{}", provider.id, type_str, binding_count, fallback);
            }
        }

        "show" => {
            let name = name.ok_or_else(|| anyhow::anyhow!("Provider name or ID is required"))?;

            let provider = graph.slots.providers.iter()
                .find(|p| p.id == name || p.name == name)
                .ok_or_else(|| anyhow::anyhow!("Provider not found: {}", name))?;

            println!("Provider: {}", provider.name);
            println!("  id: {}", provider.id);
            println!("  slot: {}", provider.slot_id);
            println!("  type: {:?}", provider.provider_type);
            if let Some(ref repo_id) = provider.repo_id {
                let repo_name = graph.get_repo(repo_id)
                    .map(|r| r.name.as_str())
                    .unwrap_or(repo_id);
                println!("  repo: {}", repo_name);
            }
            if let Some(ref uri) = provider.external_uri {
                println!("  uri: {}", uri);
            }
            if let Some(ref v) = provider.interface_version {
                println!("  interface version: {}", v);
            }
            if !provider.capabilities.is_empty() {
                println!("  capabilities: {:?}", provider.capabilities);
            }
            println!("  priority: {}", provider.priority);
            println!("  fallback: {}", provider.is_fallback);

            // Check compatibility with its slot
            let compat = graph.slots.check_compatibility(&provider.slot_id, &provider.id);
            println!("  compatibility: {} ({})", compat.compatible, compat.reason);

            let bindings = graph.slots.bindings_for_provider(&provider.id);
            if !bindings.is_empty() {
                println!("  used by ({}):", bindings.len());
                for b in bindings {
                    let consumer_name = graph.get_repo(&b.consumer_id)
                        .map(|r| r.name.as_str())
                        .unwrap_or(&b.consumer_id);
                    println!("    {}", consumer_name);
                }
            }
        }

        other => {
            anyhow::bail!("Unknown provider action: {}. Valid: create, delete, list, show", other);
        }
    }

    Ok(())
}

/// Run binding command
pub fn run_binding(action: &str, args: BindingArgs) -> Result<()> {
    let data_dir = get_data_dir()?;
    let mut graph = EcosystemGraph::load(&data_dir)
        .with_context(|| format!("Failed to load graph from {}", data_dir.display()))?;

    match action {
        "bind" | "create" => {
            let consumer = args.consumer.ok_or_else(|| anyhow::anyhow!("Consumer repo is required (--consumer)"))?;
            let slot_id = args.slot.ok_or_else(|| anyhow::anyhow!("Slot ID is required (--slot)"))?;
            let provider_id = args.provider.ok_or_else(|| anyhow::anyhow!("Provider ID is required (--provider)"))?;

            // Resolve consumer
            let consumer_id = graph.store.repos.iter()
                .find(|r| r.name == consumer || r.id == consumer)
                .map(|r| r.id.clone())
                .ok_or_else(|| anyhow::anyhow!("Consumer repo not found: {}", consumer))?;

            // Normalize slot ID
            let slot_id = if slot_id.starts_with("slot:") {
                slot_id
            } else {
                format!("slot:{}", slot_id)
            };

            // Verify slot exists
            if !graph.slots.slots.iter().any(|s| s.id == slot_id) {
                anyhow::bail!("Slot not found: {}", slot_id);
            }

            // Resolve provider
            let provider_id = if provider_id.starts_with("provider:") {
                provider_id
            } else {
                graph.slots.providers.iter()
                    .find(|p| p.name == provider_id)
                    .map(|p| p.id.clone())
                    .ok_or_else(|| anyhow::anyhow!("Provider not found: {}", provider_id))?
            };

            // Verify provider exists and is for this slot
            let provider = graph.slots.providers.iter()
                .find(|p| p.id == provider_id)
                .ok_or_else(|| anyhow::anyhow!("Provider not found: {}", provider_id))?;

            if provider.slot_id != slot_id {
                anyhow::bail!("Provider {} is for slot {}, not {}", provider_id, provider.slot_id, slot_id);
            }

            // Check compatibility
            let compat = graph.slots.check_compatibility(&slot_id, &provider_id);
            if !compat.compatible {
                anyhow::bail!("Provider incompatible: {}", compat.reason);
            }

            let binding_id = SlotBinding::generate_id(&consumer_id, &slot_id);

            // Remove existing binding if any
            graph.slots.bindings.retain(|b| b.id != binding_id);

            let binding = SlotBinding {
                kind: "SlotBinding".into(),
                id: binding_id.clone(),
                consumer_id: consumer_id.clone(),
                slot_id: slot_id.clone(),
                provider_id: provider_id.clone(),
                mode: BindingMode::Manual,
                created_at: Utc::now(),
                created_by: "user".into(),
            };

            graph.slots.bindings.push(binding);
            graph.save(&data_dir)?;

            let consumer_name = graph.get_repo(&consumer_id)
                .map(|r| r.name.as_str())
                .unwrap_or(&consumer_id);
            let provider_name = graph.slots.providers.iter()
                .find(|p| p.id == provider_id)
                .map(|p| p.name.as_str())
                .unwrap_or(&provider_id);

            println!("Bound {} to {} via {}", consumer_name, slot_id, provider_name);
        }

        "unbind" | "delete" | "rm" => {
            let consumer = args.consumer.ok_or_else(|| anyhow::anyhow!("Consumer repo is required (--consumer)"))?;
            let slot_id = args.slot.ok_or_else(|| anyhow::anyhow!("Slot ID is required (--slot)"))?;

            // Resolve consumer
            let consumer_id = graph.store.repos.iter()
                .find(|r| r.name == consumer || r.id == consumer)
                .map(|r| r.id.clone())
                .ok_or_else(|| anyhow::anyhow!("Consumer repo not found: {}", consumer))?;

            // Normalize slot ID
            let slot_id = if slot_id.starts_with("slot:") {
                slot_id
            } else {
                format!("slot:{}", slot_id)
            };

            let binding_id = SlotBinding::generate_id(&consumer_id, &slot_id);
            let before = graph.slots.bindings.len();
            graph.slots.bindings.retain(|b| b.id != binding_id);

            if graph.slots.bindings.len() < before {
                graph.save(&data_dir)?;
                println!("Removed binding for {} from {}", consumer, slot_id);
            } else {
                println!("No binding found for {} on {}", consumer, slot_id);
            }
        }

        "list" | "ls" => {
            if graph.slots.bindings.is_empty() {
                println!("No bindings defined. Use 'reposystem binding bind --consumer <repo> --slot <slot> --provider <provider>' to create one.");
                return Ok(());
            }

            println!("Bindings ({}):", graph.slots.bindings.len());
            for binding in &graph.slots.bindings {
                let consumer_name = graph.get_repo(&binding.consumer_id)
                    .map(|r| r.name.as_str())
                    .unwrap_or(&binding.consumer_id);
                let provider_name = graph.slots.providers.iter()
                    .find(|p| p.id == binding.provider_id)
                    .map(|p| p.name.as_str())
                    .unwrap_or(&binding.provider_id);
                let slot_short = binding.slot_id.replace("slot:", "");

                println!("  {} --[{}]--> {}", consumer_name, slot_short, provider_name);
            }
        }

        "show" => {
            let consumer = args.consumer.ok_or_else(|| anyhow::anyhow!("Consumer repo is required (--consumer)"))?;

            // Resolve consumer
            let consumer_id = graph.store.repos.iter()
                .find(|r| r.name == consumer || r.id == consumer)
                .map(|r| r.id.clone())
                .ok_or_else(|| anyhow::anyhow!("Consumer repo not found: {}", consumer))?;

            let consumer_name = graph.get_repo(&consumer_id)
                .map(|r| r.name.as_str())
                .unwrap_or(&consumer_id);

            let bindings = graph.slots.bindings_for_consumer(&consumer_id);
            if bindings.is_empty() {
                println!("No bindings for {}", consumer_name);
                return Ok(());
            }

            println!("Bindings for {}:", consumer_name);
            for binding in bindings {
                let provider = graph.slots.providers.iter()
                    .find(|p| p.id == binding.provider_id);
                let provider_name = provider.map(|p| p.name.as_str()).unwrap_or(&binding.provider_id);
                let slot_short = binding.slot_id.replace("slot:", "");

                println!("  {} -> {} ({:?})", slot_short, provider_name, binding.mode);
            }
        }

        other => {
            anyhow::bail!("Unknown binding action: {}. Valid: bind, unbind, list, show", other);
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
