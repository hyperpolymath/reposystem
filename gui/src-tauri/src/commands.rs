// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//
//! Tauri IPC commands wrapping EcosystemGraph

use reposystem::types::{
    AspectAnnotation, Edge, Group, Plan, Provider, Repo, Slot, SlotBinding,
    Channel, EdgeMeta, RelationType, Polarity, AnnotationSource, ProviderType,
    BindingMode,
};
use reposystem::graph::EcosystemGraph;
use std::sync::Mutex;
use tauri::State;
use chrono::Utc;
use anyhow::Error as AnyhowError;

// ============================================================================
// Read Operations
// ============================================================================

#[tauri::command]
pub fn get_repos(graph: State<Mutex<EcosystemGraph>>) -> Vec<Repo> {
    let g = graph.lock().unwrap();
    g.repos().to_vec()
}

#[tauri::command]
pub fn get_edges(graph: State<Mutex<EcosystemGraph>>) -> Vec<Edge> {
    let g = graph.lock().unwrap();
    g.edges().to_vec()
}

#[tauri::command]
pub fn get_groups(graph: State<Mutex<EcosystemGraph>>) -> Vec<Group> {
    let g = graph.lock().unwrap();
    g.groups().to_vec()
}

#[tauri::command]
pub fn get_aspects(graph: State<Mutex<EcosystemGraph>>) -> Vec<AspectAnnotation> {
    let g = graph.lock().unwrap();
    g.aspects.annotations.clone()
}

#[tauri::command]
pub fn get_slots(graph: State<Mutex<EcosystemGraph>>) -> Vec<Slot> {
    let g = graph.lock().unwrap();
    g.slots.slots.clone()
}

#[tauri::command]
pub fn get_providers(graph: State<Mutex<EcosystemGraph>>) -> Vec<Provider> {
    let g = graph.lock().unwrap();
    g.slots.providers.clone()
}

#[tauri::command]
pub fn get_bindings(graph: State<Mutex<EcosystemGraph>>) -> Vec<SlotBinding> {
    let g = graph.lock().unwrap();
    g.slots.bindings.clone()
}

#[tauri::command]
pub fn get_plans(graph: State<Mutex<EcosystemGraph>>) -> Vec<Plan> {
    let g = graph.lock().unwrap();
    g.plans.plans.clone()
}

// ============================================================================
// Edge Operations
// ============================================================================

#[tauri::command]
pub fn add_edge(
    graph: State<Mutex<EcosystemGraph>>,
    from: String,
    to: String,
    rel: String,
    label: Option<String>,
) -> Result<Edge, String> {
    let mut g = graph.lock().unwrap();

    let rel_type = match rel.as_str() {
        "uses" => RelationType::Uses,
        "provides" => RelationType::Provides,
        "extends" => RelationType::Extends,
        "mirrors" => RelationType::Mirrors,
        "replaces" => RelationType::Replaces,
        _ => return Err(format!("Unknown relation type: {}", rel)),
    };

    let edge_id = format!("edge:{}:{}", &from[..8.min(from.len())], &to[..8.min(to.len())]);

    let edge = Edge {
        kind: "Edge".into(),
        id: edge_id.clone(),
        from: from.clone(),
        to: to.clone(),
        rel: rel_type,
        channel: Channel::Unknown,
        label,
        evidence: vec![],
        meta: EdgeMeta {
            created_by: "gui".into(),
            created_at: Utc::now(),
        },
    };

    g.add_edge(edge.clone()).map_err(|e: AnyhowError| e.to_string())?;
    Ok(edge)
}

#[tauri::command]
pub fn remove_edge(graph: State<Mutex<EcosystemGraph>>, edge_id: String) -> Result<(), String> {
    let mut g = graph.lock().unwrap();
    g.store.edges.retain(|e| e.id != edge_id);
    Ok(())
}

// ============================================================================
// Group Operations
// ============================================================================

#[tauri::command]
pub fn create_group(
    graph: State<Mutex<EcosystemGraph>>,
    name: String,
    description: Option<String>,
) -> Result<Group, String> {
    let mut g = graph.lock().unwrap();

    let group_id = format!("group:{}", name.to_lowercase().replace(' ', "-"));

    let group = Group {
        kind: "Group".into(),
        id: group_id.clone(),
        name: name.clone(),
        description,
        members: vec![],
    };

    g.add_group(group.clone());
    Ok(group)
}

#[tauri::command]
pub fn add_to_group(
    graph: State<Mutex<EcosystemGraph>>,
    group_id: String,
    repo_id: String,
) -> Result<(), String> {
    let mut g = graph.lock().unwrap();

    if let Some(group) = g.store.groups.iter_mut().find(|gr| gr.id == group_id) {
        if !group.members.contains(&repo_id) {
            group.members.push(repo_id);
        }
        Ok(())
    } else {
        Err(format!("Group not found: {}", group_id))
    }
}

#[tauri::command]
pub fn remove_from_group(
    graph: State<Mutex<EcosystemGraph>>,
    group_id: String,
    repo_id: String,
) -> Result<(), String> {
    let mut g = graph.lock().unwrap();

    if let Some(group) = g.store.groups.iter_mut().find(|gr| gr.id == group_id) {
        group.members.retain(|m| m != &repo_id);
        Ok(())
    } else {
        Err(format!("Group not found: {}", group_id))
    }
}

// ============================================================================
// Aspect Operations
// ============================================================================

#[tauri::command]
pub fn tag_aspect(
    graph: State<Mutex<EcosystemGraph>>,
    target: String,
    aspect_id: String,
    weight: u8,
    polarity: String,
    reason: String,
) -> Result<AspectAnnotation, String> {
    let mut g = graph.lock().unwrap();

    let pol = match polarity.as_str() {
        "risk" => Polarity::Risk,
        "strength" => Polarity::Strength,
        "neutral" => Polarity::Neutral,
        _ => return Err(format!("Unknown polarity: {}", polarity)),
    };

    let ann_id = format!("aa:{}:{}", target, aspect_id);

    let annotation = AspectAnnotation {
        kind: "AspectAnnotation".into(),
        id: ann_id.clone(),
        target,
        aspect_id,
        weight,
        polarity: pol,
        reason,
        evidence: vec![],
        source: AnnotationSource {
            mode: "manual".into(),
            who: "gui".into(),
            when: Utc::now(),
            rule_id: None,
        },
    };

    g.aspects.annotations.push(annotation.clone());
    Ok(annotation)
}

#[tauri::command]
pub fn remove_aspect(
    graph: State<Mutex<EcosystemGraph>>,
    annotation_id: String,
) -> Result<(), String> {
    let mut g = graph.lock().unwrap();
    g.aspects.annotations.retain(|a| a.id != annotation_id);
    Ok(())
}

// ============================================================================
// Slot Operations
// ============================================================================

#[tauri::command]
pub fn create_slot(
    graph: State<Mutex<EcosystemGraph>>,
    name: String,
    category: String,
    interface_version: Option<String>,
    description: String,
    capabilities: Vec<String>,
) -> Result<Slot, String> {
    let mut g = graph.lock().unwrap();

    let slot_id = format!("slot:{}.{}", category, name);

    let slot = Slot {
        kind: "Slot".into(),
        id: slot_id.clone(),
        name,
        category,
        description,
        interface_version,
        required_capabilities: capabilities,
    };

    g.slots.slots.push(slot.clone());
    Ok(slot)
}

#[tauri::command]
pub fn create_provider(
    graph: State<Mutex<EcosystemGraph>>,
    name: String,
    slot_id: String,
    provider_type: String,
    repo_id: Option<String>,
    external_uri: Option<String>,
    interface_version: Option<String>,
    capabilities: Vec<String>,
    priority: i32,
    is_fallback: bool,
) -> Result<Provider, String> {
    let mut g = graph.lock().unwrap();

    let ptype = match provider_type.as_str() {
        "local" => ProviderType::Local,
        "ecosystem" => ProviderType::Ecosystem,
        "external" => ProviderType::External,
        "stub" => ProviderType::Stub,
        _ => return Err(format!("Unknown provider type: {}", provider_type)),
    };

    let provider_id = format!("provider:{}", name);

    let provider = Provider {
        kind: "Provider".into(),
        id: provider_id.clone(),
        name,
        slot_id,
        provider_type: ptype,
        repo_id,
        external_uri,
        interface_version,
        capabilities,
        priority,
        is_fallback,
    };

    g.slots.providers.push(provider.clone());
    Ok(provider)
}

#[tauri::command]
pub fn bind_slot(
    graph: State<Mutex<EcosystemGraph>>,
    consumer_id: String,
    slot_id: String,
    provider_id: String,
) -> Result<SlotBinding, String> {
    let mut g = graph.lock().unwrap();

    let binding_id = format!("binding:{}:{}:{}", consumer_id, slot_id, provider_id);

    let binding = SlotBinding {
        kind: "SlotBinding".into(),
        id: binding_id.clone(),
        consumer_id,
        slot_id,
        provider_id,
        mode: BindingMode::Manual,
        created_at: Utc::now(),
        created_by: "gui".into(),
    };

    g.slots.bindings.push(binding.clone());
    Ok(binding)
}

#[tauri::command]
pub fn unbind_slot(
    graph: State<Mutex<EcosystemGraph>>,
    binding_id: String,
) -> Result<(), String> {
    let mut g = graph.lock().unwrap();
    g.slots.bindings.retain(|b| b.id != binding_id);
    Ok(())
}

// ============================================================================
// Persistence
// ============================================================================

#[tauri::command]
pub fn save_graph(graph: State<Mutex<EcosystemGraph>>) -> Result<(), String> {
    let g = graph.lock().unwrap();
    let config = reposystem::config::load().map_err(|e: AnyhowError| e.to_string())?;
    g.save(&config.data_dir).map_err(|e: AnyhowError| e.to_string())
}
