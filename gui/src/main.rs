// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//
//! Reposystem GUI — Railway yard visualization for repository ecosystem.
//!
//! Gossamer-based desktop application. Registers 20 IPC commands for graph
//! operations (repos, edges, groups, aspects, slots, providers, bindings,
//! plans) via `gossamer_rs::App`.

#![forbid(unsafe_code)]

use std::sync::Mutex;

use chrono::Utc;
use gossamer_rs::App;
use reposystem::graph::EcosystemGraph;
use reposystem::types::{
    AnnotationSource, AspectAnnotation, BindingMode, Channel, Edge, EdgeMeta, Group, Plan,
    Polarity, Provider, ProviderType, RelationType, Slot, SlotBinding,
};
use serde_json::{json, Value};

// =============================================================================
// Shared graph state — thread-safe via Mutex, shared across all command closures
// =============================================================================

/// Wrap the graph in a Mutex for safe concurrent access from IPC handlers.
/// The Mutex is shared via `Arc`-like semantics (each closure captures a
/// reference to the same `Mutex<EcosystemGraph>`).
type SharedGraph = Mutex<EcosystemGraph>;

// =============================================================================
// Helper: extract string field from JSON payload
// =============================================================================

/// Extract a required string field from the JSON payload, returning an
/// IPC-friendly error string on failure.
fn required_str(payload: &Value, field: &str) -> Result<String, String> {
    payload[field]
        .as_str()
        .map(|s| s.to_string())
        .ok_or_else(|| format!("missing required field: {}", field))
}

/// Extract an optional string field from the JSON payload.
fn optional_str(payload: &Value, field: &str) -> Option<String> {
    payload[field].as_str().map(|s| s.to_string())
}

// =============================================================================
// Entry point
// =============================================================================

fn main() -> Result<(), gossamer_rs::Error> {
    // Load graph from default location
    let config = reposystem::config::load().unwrap_or_default();
    let graph = EcosystemGraph::load(&config.data_dir)
        .unwrap_or_else(|_| EcosystemGraph::new());

    // Shared graph state — leaked into a &'static reference so closures
    // can capture it without lifetime issues. The graph lives for the
    // entire process lifetime, so this is safe and intentional.
    let graph: &'static SharedGraph = Box::leak(Box::new(Mutex::new(graph)));

    let mut app = App::new("Reposystem - Railway Yard", 1200, 800)?;

    // =========================================================================
    // Read Operations (8 commands)
    // =========================================================================

    app.command("get_repos", {
        move |_payload| {
            let g = graph.lock().unwrap();
            Ok(serde_json::to_value(g.repos().to_vec()).unwrap())
        }
    });

    app.command("get_edges", {
        move |_payload| {
            let g = graph.lock().unwrap();
            Ok(serde_json::to_value(g.edges().to_vec()).unwrap())
        }
    });

    app.command("get_groups", {
        move |_payload| {
            let g = graph.lock().unwrap();
            Ok(serde_json::to_value(g.groups().to_vec()).unwrap())
        }
    });

    app.command("get_aspects", {
        move |_payload| {
            let g = graph.lock().unwrap();
            Ok(serde_json::to_value(g.aspects.annotations.clone()).unwrap())
        }
    });

    app.command("get_slots", {
        move |_payload| {
            let g = graph.lock().unwrap();
            Ok(serde_json::to_value(g.slots.slots.clone()).unwrap())
        }
    });

    app.command("get_providers", {
        move |_payload| {
            let g = graph.lock().unwrap();
            Ok(serde_json::to_value(g.slots.providers.clone()).unwrap())
        }
    });

    app.command("get_bindings", {
        move |_payload| {
            let g = graph.lock().unwrap();
            Ok(serde_json::to_value(g.slots.bindings.clone()).unwrap())
        }
    });

    app.command("get_plans", {
        move |_payload| {
            let g = graph.lock().unwrap();
            Ok(serde_json::to_value(g.plans.plans.clone()).unwrap())
        }
    });

    // =========================================================================
    // Edge Operations (2 commands)
    // =========================================================================

    app.command("add_edge", {
        move |payload| {
            let from = required_str(&payload, "from")?;
            let to = required_str(&payload, "to")?;
            let rel = required_str(&payload, "rel")?;
            let label = optional_str(&payload, "label");

            let rel_type = match rel.as_str() {
                "uses" => RelationType::Uses,
                "provides" => RelationType::Provides,
                "extends" => RelationType::Extends,
                "mirrors" => RelationType::Mirrors,
                "replaces" => RelationType::Replaces,
                _ => return Err(format!("Unknown relation type: {}", rel)),
            };

            let edge_id = format!(
                "edge:{}:{}",
                &from[..8.min(from.len())],
                &to[..8.min(to.len())]
            );

            let edge = Edge {
                kind: "Edge".into(),
                id: edge_id,
                from,
                to,
                rel: rel_type,
                channel: Channel::Unknown,
                label,
                evidence: vec![],
                meta: EdgeMeta {
                    created_by: "gui".into(),
                    created_at: Utc::now(),
                },
            };

            let mut g = graph.lock().unwrap();
            g.add_edge(edge.clone())
                .map_err(|e| e.to_string())?;

            Ok(serde_json::to_value(&edge).unwrap())
        }
    });

    app.command("remove_edge", {
        move |payload| {
            let edge_id = required_str(&payload, "edge_id")?;
            let mut g = graph.lock().unwrap();
            g.store.edges.retain(|e| e.id != edge_id);
            Ok(json!(null))
        }
    });

    // =========================================================================
    // Group Operations (3 commands)
    // =========================================================================

    app.command("create_group", {
        move |payload| {
            let name = required_str(&payload, "name")?;
            let description = optional_str(&payload, "description");

            let group_id = format!("group:{}", name.to_lowercase().replace(' ', "-"));

            let group = Group {
                kind: "Group".into(),
                id: group_id,
                name,
                description,
                members: vec![],
            };

            let mut g = graph.lock().unwrap();
            g.add_group(group.clone());

            Ok(serde_json::to_value(&group).unwrap())
        }
    });

    app.command("add_to_group", {
        move |payload| {
            let group_id = required_str(&payload, "group_id")?;
            let repo_id = required_str(&payload, "repo_id")?;

            let mut g = graph.lock().unwrap();
            if let Some(group) = g.store.groups.iter_mut().find(|gr| gr.id == group_id) {
                if !group.members.contains(&repo_id) {
                    group.members.push(repo_id);
                }
                Ok(json!(null))
            } else {
                Err(format!("Group not found: {}", group_id))
            }
        }
    });

    app.command("remove_from_group", {
        move |payload| {
            let group_id = required_str(&payload, "group_id")?;
            let repo_id = required_str(&payload, "repo_id")?;

            let mut g = graph.lock().unwrap();
            if let Some(group) = g.store.groups.iter_mut().find(|gr| gr.id == group_id) {
                group.members.retain(|m| m != &repo_id);
                Ok(json!(null))
            } else {
                Err(format!("Group not found: {}", group_id))
            }
        }
    });

    // =========================================================================
    // Aspect Operations (2 commands)
    // =========================================================================

    app.command("tag_aspect", {
        move |payload| {
            let target = required_str(&payload, "target")?;
            let aspect_id = required_str(&payload, "aspect_id")?;
            let weight = payload["weight"]
                .as_u64()
                .map(|w| w as u8)
                .ok_or("missing required field: weight")?;
            let polarity = required_str(&payload, "polarity")?;
            let reason = required_str(&payload, "reason")?;

            let pol = match polarity.as_str() {
                "risk" => Polarity::Risk,
                "strength" => Polarity::Strength,
                "neutral" => Polarity::Neutral,
                _ => return Err(format!("Unknown polarity: {}", polarity)),
            };

            let ann_id = format!("aa:{}:{}", target, aspect_id);

            let annotation = AspectAnnotation {
                kind: "AspectAnnotation".into(),
                id: ann_id,
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

            let mut g = graph.lock().unwrap();
            g.aspects.annotations.push(annotation.clone());

            Ok(serde_json::to_value(&annotation).unwrap())
        }
    });

    app.command("remove_aspect", {
        move |payload| {
            let annotation_id = required_str(&payload, "annotation_id")?;
            let mut g = graph.lock().unwrap();
            g.aspects.annotations.retain(|a| a.id != annotation_id);
            Ok(json!(null))
        }
    });

    // =========================================================================
    // Slot Operations (4 commands)
    // =========================================================================

    app.command("create_slot", {
        move |payload| {
            let name = required_str(&payload, "name")?;
            let category = required_str(&payload, "category")?;
            let interface_version = optional_str(&payload, "interface_version");
            let description = required_str(&payload, "description")?;
            let capabilities: Vec<String> = payload["capabilities"]
                .as_array()
                .map(|arr| {
                    arr.iter()
                        .filter_map(|v| v.as_str().map(|s| s.to_string()))
                        .collect()
                })
                .unwrap_or_default();

            let slot_id = format!("slot:{}.{}", category, name);

            let slot = Slot {
                kind: "Slot".into(),
                id: slot_id,
                name,
                category,
                description,
                interface_version,
                required_capabilities: capabilities,
            };

            let mut g = graph.lock().unwrap();
            g.slots.slots.push(slot.clone());

            Ok(serde_json::to_value(&slot).unwrap())
        }
    });

    app.command("create_provider", {
        move |payload| {
            let name = required_str(&payload, "name")?;
            let slot_id = required_str(&payload, "slot_id")?;
            let provider_type = required_str(&payload, "provider_type")?;
            let repo_id = optional_str(&payload, "repo_id");
            let external_uri = optional_str(&payload, "external_uri");
            let interface_version = optional_str(&payload, "interface_version");
            let capabilities: Vec<String> = payload["capabilities"]
                .as_array()
                .map(|arr| {
                    arr.iter()
                        .filter_map(|v| v.as_str().map(|s| s.to_string()))
                        .collect()
                })
                .unwrap_or_default();
            let priority = payload["priority"]
                .as_i64()
                .map(|p| p as i32)
                .ok_or("missing required field: priority")?;
            let is_fallback = payload["is_fallback"].as_bool().unwrap_or(false);

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
                id: provider_id,
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

            let mut g = graph.lock().unwrap();
            g.slots.providers.push(provider.clone());

            Ok(serde_json::to_value(&provider).unwrap())
        }
    });

    app.command("bind_slot", {
        move |payload| {
            let consumer_id = required_str(&payload, "consumer_id")?;
            let slot_id = required_str(&payload, "slot_id")?;
            let provider_id = required_str(&payload, "provider_id")?;

            let binding_id = format!("binding:{}:{}:{}", consumer_id, slot_id, provider_id);

            let binding = SlotBinding {
                kind: "SlotBinding".into(),
                id: binding_id,
                consumer_id,
                slot_id,
                provider_id,
                mode: BindingMode::Manual,
                created_at: Utc::now(),
                created_by: "gui".into(),
            };

            let mut g = graph.lock().unwrap();
            g.slots.bindings.push(binding.clone());

            Ok(serde_json::to_value(&binding).unwrap())
        }
    });

    app.command("unbind_slot", {
        move |payload| {
            let binding_id = required_str(&payload, "binding_id")?;
            let mut g = graph.lock().unwrap();
            g.slots.bindings.retain(|b| b.id != binding_id);
            Ok(json!(null))
        }
    });

    // =========================================================================
    // Persistence (1 command)
    // =========================================================================

    app.command("save_graph", {
        move |_payload| {
            let g = graph.lock().unwrap();
            let config = reposystem::config::load().map_err(|e| e.to_string())?;
            g.save(&config.data_dir).map_err(|e| e.to_string())?;
            Ok(json!(null))
        }
    });

    // =========================================================================
    // Load frontend and run event loop
    // =========================================================================

    app.navigate("http://localhost:1420")?;
    app.run();
    Ok(())
}
