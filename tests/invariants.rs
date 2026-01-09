// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//! Invariant tests for the reposystem graph - i1 seam review
//!
//! These tests verify critical invariants:
//! 1. Graph determinism - same operations produce same results
//! 2. Tag provenance - all annotations have valid metadata
//! 3. Export fidelity - data survives round-trips

use chrono::Utc;
use reposystem::graph::EcosystemGraph;
use reposystem::types::{
    AnnotationSource, ApplyResult, AspectAnnotation, AuditEntry, AuditStore, BindingMode,
    Channel, Edge, EdgeMeta, Evidence, Forge, Group, ImportMeta, OpResult, Polarity,
    Provider, ProviderType, RelationType, Repo, Slot, SlotBinding, Visibility,
};
use std::collections::HashSet;
use tempfile::TempDir;

// =============================================================================
// Test Helpers
// =============================================================================

fn make_repo(name: &str, forge: Forge, owner: &str) -> Repo {
    Repo {
        kind: "Repo".into(),
        id: Repo::forge_id(forge, owner, name),
        forge,
        owner: owner.into(),
        name: name.into(),
        default_branch: "main".into(),
        visibility: Visibility::Public,
        tags: vec!["test".into()],
        imports: ImportMeta {
            source: "test".into(),
            path_hint: None,
            imported_at: Utc::now(),
        },
        local_path: None,
    }
}

fn make_edge(from: &str, to: &str, rel: RelationType, label: Option<&str>) -> Edge {
    Edge {
        kind: "Edge".into(),
        id: Edge::generate_id(from, to, rel, Channel::Api, label),
        from: from.into(),
        to: to.into(),
        rel,
        channel: Channel::Api,
        label: label.map(String::from),
        evidence: vec![],
        meta: EdgeMeta {
            created_by: "test".into(),
            created_at: Utc::now(),
        },
    }
}

fn make_annotation(target: &str, aspect: &str, weight: u8, polarity: Polarity) -> AspectAnnotation {
    AspectAnnotation {
        kind: "AspectAnnotation".into(),
        id: format!("aa:{}:{}", target.replace(':', "-"), aspect),
        target: target.into(),
        aspect_id: format!("aspect:{}", aspect),
        weight,
        polarity,
        reason: format!("Test annotation for {} on {}", aspect, target),
        evidence: vec![],
        source: AnnotationSource {
            mode: "manual".into(),
            who: "test".into(),
            when: Utc::now(),
            rule_id: None,
        },
    }
}

// =============================================================================
// Graph Determinism Tests
// =============================================================================

#[test]
fn test_repo_id_determinism() {
    // Same inputs should always produce the same ID
    let id1 = Repo::forge_id(Forge::GitHub, "owner", "repo");
    let id2 = Repo::forge_id(Forge::GitHub, "owner", "repo");
    let id3 = Repo::forge_id(Forge::GitHub, "owner", "repo");

    assert_eq!(id1, id2);
    assert_eq!(id2, id3);
    assert_eq!(id1, "repo:gh:owner/repo");
}

#[test]
fn test_repo_id_uniqueness() {
    // Different inputs should produce different IDs
    let id1 = Repo::forge_id(Forge::GitHub, "owner", "repo1");
    let id2 = Repo::forge_id(Forge::GitHub, "owner", "repo2");
    let id3 = Repo::forge_id(Forge::GitLab, "owner", "repo1");
    let id4 = Repo::forge_id(Forge::GitHub, "other", "repo1");

    let ids: HashSet<_> = [id1.clone(), id2.clone(), id3.clone(), id4.clone()].into_iter().collect();
    assert_eq!(ids.len(), 4, "All IDs should be unique");
}

#[test]
fn test_edge_id_determinism() {
    // Same inputs should always produce the same edge ID
    let id1 = Edge::generate_id("repo:a", "repo:b", RelationType::Uses, Channel::Api, Some("test"));
    let id2 = Edge::generate_id("repo:a", "repo:b", RelationType::Uses, Channel::Api, Some("test"));
    let id3 = Edge::generate_id("repo:a", "repo:b", RelationType::Uses, Channel::Api, Some("test"));

    assert_eq!(id1, id2);
    assert_eq!(id2, id3);
    assert!(id1.starts_with("edge:"));
}

#[test]
fn test_edge_id_uniqueness() {
    // Different inputs should produce different IDs
    let id1 = Edge::generate_id("repo:a", "repo:b", RelationType::Uses, Channel::Api, None);
    let id2 = Edge::generate_id("repo:a", "repo:c", RelationType::Uses, Channel::Api, None);
    let id3 = Edge::generate_id("repo:a", "repo:b", RelationType::Provides, Channel::Api, None);
    let id4 = Edge::generate_id("repo:a", "repo:b", RelationType::Uses, Channel::Artifact, None);
    let id5 = Edge::generate_id("repo:a", "repo:b", RelationType::Uses, Channel::Api, Some("label"));

    let ids: HashSet<_> = [id1, id2, id3, id4, id5].into_iter().collect();
    assert_eq!(ids.len(), 5, "All edge IDs should be unique");
}

#[test]
fn test_local_repo_id_determinism() {
    use std::path::PathBuf;

    // Same path should always produce the same ID
    let path = PathBuf::from("/tmp/test-repo");
    let id1 = Repo::local_id(&path);
    let id2 = Repo::local_id(&path);

    assert_eq!(id1, id2);
    assert!(id1.starts_with("repo:local:"));
}

#[test]
fn test_add_repo_idempotent() {
    let mut graph = EcosystemGraph::new();
    let repo = make_repo("test", Forge::GitHub, "owner");

    // Add the same repo multiple times
    graph.add_repo(repo.clone());
    graph.add_repo(repo.clone());
    graph.add_repo(repo.clone());

    // Should only have one repo
    assert_eq!(graph.node_count(), 1);
    assert_eq!(graph.repos().len(), 1);
}

#[test]
fn test_add_edge_idempotent() {
    let mut graph = EcosystemGraph::new();

    let repo_a = make_repo("a", Forge::GitHub, "test");
    let repo_b = make_repo("b", Forge::GitHub, "test");
    graph.add_repo(repo_a.clone());
    graph.add_repo(repo_b.clone());

    let edge = make_edge(&repo_a.id, &repo_b.id, RelationType::Uses, Some("dep"));

    // Add the same edge multiple times
    graph.add_edge(edge.clone()).unwrap();
    graph.add_edge(edge.clone()).unwrap();
    graph.add_edge(edge.clone()).unwrap();

    // Should only have one edge
    assert_eq!(graph.edge_count(), 1);
}

#[test]
fn test_graph_operation_order_independence() {
    // Adding repos in different orders should produce equivalent graphs
    let repo_a = make_repo("alpha", Forge::GitHub, "test");
    let repo_b = make_repo("beta", Forge::GitHub, "test");
    let repo_c = make_repo("gamma", Forge::GitHub, "test");

    let mut graph1 = EcosystemGraph::new();
    graph1.add_repo(repo_a.clone());
    graph1.add_repo(repo_b.clone());
    graph1.add_repo(repo_c.clone());

    let mut graph2 = EcosystemGraph::new();
    graph2.add_repo(repo_c.clone());
    graph2.add_repo(repo_a.clone());
    graph2.add_repo(repo_b.clone());

    // Both graphs should have the same repos
    assert_eq!(graph1.node_count(), graph2.node_count());

    let ids1: HashSet<_> = graph1.repos().iter().map(|r| &r.id).collect();
    let ids2: HashSet<_> = graph2.repos().iter().map(|r| &r.id).collect();
    assert_eq!(ids1, ids2);
}

// =============================================================================
// Tag Provenance Tests
// =============================================================================

#[test]
fn test_annotation_has_valid_source() {
    let annotation = make_annotation("repo:test", "security", 2, Polarity::Risk);

    // Source metadata must be present
    assert!(!annotation.source.mode.is_empty());
    assert!(!annotation.source.who.is_empty());
    // Timestamp should be reasonable (not in distant past or future)
    let now = Utc::now();
    let diff = (now - annotation.source.when).num_seconds().abs();
    assert!(diff < 60, "Annotation timestamp should be recent");
}

#[test]
fn test_annotation_references_valid_aspect() {
    let graph = EcosystemGraph::new();

    // Default aspects should be loaded
    let valid_aspects: HashSet<_> = graph.aspects.aspects.iter().map(|a| &a.id).collect();

    // Create annotation with valid aspect
    let annotation = make_annotation("repo:test", "security", 2, Polarity::Risk);

    assert!(
        valid_aspects.contains(&annotation.aspect_id),
        "Annotation should reference a valid aspect"
    );
}

#[test]
fn test_annotation_weight_bounds() {
    // Weight must be 0-3
    for weight in 0..=3 {
        let ann = make_annotation("repo:test", "security", weight, Polarity::Neutral);
        assert!(ann.weight <= 3, "Weight must be <= 3");
    }
}

#[test]
fn test_annotation_polarity_coverage() {
    // All polarity values should be usable
    let risk = make_annotation("repo:a", "security", 2, Polarity::Risk);
    let strength = make_annotation("repo:b", "security", 2, Polarity::Strength);
    let neutral = make_annotation("repo:c", "security", 2, Polarity::Neutral);

    assert_eq!(risk.polarity, Polarity::Risk);
    assert_eq!(strength.polarity, Polarity::Strength);
    assert_eq!(neutral.polarity, Polarity::Neutral);
}

#[test]
fn test_default_aspects_loaded() {
    let graph = EcosystemGraph::new();

    // Should have the 10 default aspects
    assert!(graph.aspects.aspects.len() >= 10);

    let aspect_ids: HashSet<_> = graph.aspects.aspects.iter().map(|a| a.id.as_str()).collect();

    // Check for key aspects from DATA-MODEL.adoc
    assert!(aspect_ids.contains("aspect:security"));
    assert!(aspect_ids.contains("aspect:reliability"));
    assert!(aspect_ids.contains("aspect:maintainability"));
    assert!(aspect_ids.contains("aspect:portability"));
    assert!(aspect_ids.contains("aspect:performance"));
    assert!(aspect_ids.contains("aspect:observability"));
}

#[test]
fn test_annotation_target_validation() {
    let mut graph = EcosystemGraph::new();
    let repo = make_repo("test", Forge::GitHub, "owner");
    graph.add_repo(repo.clone());

    // Add annotation targeting the repo
    let annotation = make_annotation(&repo.id, "security", 2, Polarity::Risk);
    graph.aspects.annotations.push(annotation.clone());

    // Verify annotation target exists in graph
    assert!(
        graph.get_repo(&annotation.target).is_some(),
        "Annotation should target an existing repo"
    );
}

// =============================================================================
// Export Fidelity Tests
// =============================================================================

#[test]
fn test_json_export_import_fidelity() {
    let temp_dir = TempDir::new().unwrap();

    // Create a complex graph
    let mut graph = EcosystemGraph::new();

    // Add repos
    let repo_a = make_repo("alpha", Forge::GitHub, "test");
    let repo_b = make_repo("beta", Forge::GitLab, "test");
    let repo_c = make_repo("gamma", Forge::Codeberg, "other");
    graph.add_repo(repo_a.clone());
    graph.add_repo(repo_b.clone());
    graph.add_repo(repo_c.clone());

    // Add edges with evidence
    let mut edge1 = make_edge(&repo_a.id, &repo_b.id, RelationType::Uses, Some("api client"));
    edge1.evidence.push(Evidence {
        evidence_type: "file".into(),
        reference: "Cargo.toml".into(),
        excerpt: Some("beta = \"1.0\"".into()),
        confidence: 0.95,
    });
    graph.add_edge(edge1).unwrap();

    let edge2 = make_edge(&repo_b.id, &repo_c.id, RelationType::Provides, None);
    graph.add_edge(edge2).unwrap();

    // Add group
    let group = Group {
        kind: "Group".into(),
        id: "group:test-cluster".into(),
        name: "Test Cluster".into(),
        description: Some("A test cluster".into()),
        members: vec![repo_a.id.clone(), repo_b.id.clone()],
    };
    graph.add_group(group);

    // Add annotations
    let ann1 = make_annotation(&repo_a.id, "security", 2, Polarity::Risk);
    let ann2 = make_annotation(&repo_b.id, "reliability", 3, Polarity::Strength);
    graph.aspects.annotations.push(ann1);
    graph.aspects.annotations.push(ann2);

    // Save
    graph.save(temp_dir.path()).unwrap();

    // Load
    let loaded = EcosystemGraph::load(temp_dir.path()).unwrap();

    // Verify repos
    assert_eq!(loaded.store.repos.len(), 3);
    for orig_repo in [&repo_a, &repo_b, &repo_c] {
        let loaded_repo = loaded.get_repo(&orig_repo.id).expect("Repo should exist");
        assert_eq!(loaded_repo.name, orig_repo.name);
        assert_eq!(loaded_repo.forge, orig_repo.forge);
        assert_eq!(loaded_repo.owner, orig_repo.owner);
        assert_eq!(loaded_repo.visibility, orig_repo.visibility);
    }

    // Verify edges
    assert_eq!(loaded.store.edges.len(), 2);
    let loaded_edge1 = loaded.store.edges.iter().find(|e| e.from == repo_a.id).unwrap();
    assert_eq!(loaded_edge1.to, repo_b.id);
    assert_eq!(loaded_edge1.rel, RelationType::Uses);
    assert_eq!(loaded_edge1.evidence.len(), 1);
    assert_eq!(loaded_edge1.evidence[0].confidence, 0.95);

    // Verify groups
    assert_eq!(loaded.store.groups.len(), 1);
    let loaded_group = &loaded.store.groups[0];
    assert_eq!(loaded_group.name, "Test Cluster");
    assert_eq!(loaded_group.members.len(), 2);

    // Verify annotations
    assert_eq!(loaded.aspects.annotations.len(), 2);

    // Verify petgraph rebuilt correctly
    assert_eq!(loaded.node_count(), 3);
    assert_eq!(loaded.edge_count(), 2);
}

#[test]
fn test_dot_export_contains_all_elements() {
    let mut graph = EcosystemGraph::new();

    let repo_a = make_repo("alpha", Forge::GitHub, "test");
    let repo_b = make_repo("beta", Forge::GitHub, "test");
    graph.add_repo(repo_a.clone());
    graph.add_repo(repo_b.clone());

    let edge = make_edge(&repo_a.id, &repo_b.id, RelationType::Uses, Some("test-label"));
    graph.add_edge(edge).unwrap();

    let group = Group {
        kind: "Group".into(),
        id: "group:test".into(),
        name: "Test Group".into(),
        description: None,
        members: vec![repo_a.id.clone()],
    };
    graph.add_group(group);

    let dot = graph.to_dot();

    // Should contain graph declaration
    assert!(dot.contains("digraph ecosystem"));

    // Should contain all repos
    assert!(dot.contains(&repo_a.id));
    assert!(dot.contains(&repo_b.id));
    assert!(dot.contains("alpha"));
    assert!(dot.contains("beta"));

    // Should contain edge
    assert!(dot.contains("->"));
    assert!(dot.contains("test-label"));

    // Should contain group as subgraph
    assert!(dot.contains("subgraph"));
    assert!(dot.contains("Test Group"));
}

#[test]
fn test_json_export_valid_structure() {
    let mut graph = EcosystemGraph::new();
    graph.add_repo(make_repo("test", Forge::GitHub, "owner"));

    let json = graph.to_json().unwrap();

    // Should be valid JSON
    let parsed: serde_json::Value = serde_json::from_str(&json).expect("Should be valid JSON");

    // Should have expected top-level keys
    assert!(parsed.get("repos").is_some());
    assert!(parsed.get("components").is_some());
    assert!(parsed.get("groups").is_some());
    assert!(parsed.get("edges").is_some());
}

#[test]
fn test_empty_graph_round_trip() {
    let temp_dir = TempDir::new().unwrap();

    // Save empty graph
    let graph = EcosystemGraph::new();
    graph.save(temp_dir.path()).unwrap();

    // Load it back
    let loaded = EcosystemGraph::load(temp_dir.path()).unwrap();

    // Should be empty but valid
    assert!(loaded.is_empty());
    assert_eq!(loaded.node_count(), 0);
    assert_eq!(loaded.edge_count(), 0);

    // Should still have default aspects
    assert!(!loaded.aspects.aspects.is_empty());
}

#[test]
fn test_scenarios_and_changesets_round_trip() {
    use reposystem::types::{ChangeOp, ChangeSet, Scenario};

    let temp_dir = TempDir::new().unwrap();
    let mut graph = EcosystemGraph::new();

    // Add a repo for edge operations
    let repo_a = make_repo("a", Forge::GitHub, "test");
    let repo_b = make_repo("b", Forge::GitHub, "test");
    graph.add_repo(repo_a.clone());
    graph.add_repo(repo_b.clone());

    // Add a scenario
    let scenario = Scenario {
        kind: "Scenario".into(),
        id: "scenario:test-scenario".into(),
        name: "Test Scenario".into(),
        base: None,
        description: Some("A test scenario".into()),
        created_at: Utc::now(),
    };
    graph.store.scenarios.push(scenario);

    // Add a changeset with operations
    let edge_to_add = make_edge(&repo_a.id, &repo_b.id, RelationType::Uses, Some("scenario edge"));
    let changeset = ChangeSet {
        kind: "ChangeSet".into(),
        scenario_id: "scenario:test-scenario".into(),
        ops: vec![
            ChangeOp::AddEdge { edge: edge_to_add },
        ],
    };
    graph.store.changesets.push(changeset);

    // Save
    graph.save(temp_dir.path()).unwrap();

    // Load
    let loaded = EcosystemGraph::load(temp_dir.path()).unwrap();

    // Verify scenario
    assert_eq!(loaded.store.scenarios.len(), 1);
    assert_eq!(loaded.store.scenarios[0].name, "Test Scenario");

    // Verify changeset
    assert_eq!(loaded.store.changesets.len(), 1);
    assert_eq!(loaded.store.changesets[0].ops.len(), 1);
}

// =============================================================================
// Graph Integrity Tests
// =============================================================================

#[test]
fn test_edge_requires_valid_endpoints() {
    let mut graph = EcosystemGraph::new();

    // Only add one repo
    let repo_a = make_repo("a", Forge::GitHub, "test");
    graph.add_repo(repo_a.clone());

    // Try to add edge to non-existent target
    let edge = make_edge(&repo_a.id, "repo:gh:test/nonexistent", RelationType::Uses, None);
    let result = graph.add_edge(edge);

    // Should fail
    assert!(result.is_err());
}

#[test]
fn test_petgraph_sync_with_store() {
    let mut graph = EcosystemGraph::new();

    // Add repos
    let repo_a = make_repo("a", Forge::GitHub, "test");
    let repo_b = make_repo("b", Forge::GitHub, "test");
    graph.add_repo(repo_a.clone());
    graph.add_repo(repo_b.clone());

    // Add edge
    let edge = make_edge(&repo_a.id, &repo_b.id, RelationType::Uses, None);
    graph.add_edge(edge).unwrap();

    // petgraph and store should be in sync
    assert_eq!(graph.node_count(), graph.store.repos.len());
    assert_eq!(graph.edge_count(), graph.store.edges.len());
}

#[test]
fn test_group_members_can_be_validated() {
    let mut graph = EcosystemGraph::new();

    let repo_a = make_repo("a", Forge::GitHub, "test");
    let repo_b = make_repo("b", Forge::GitHub, "test");
    graph.add_repo(repo_a.clone());
    graph.add_repo(repo_b.clone());

    // Create group with valid members
    let group = Group {
        kind: "Group".into(),
        id: "group:test".into(),
        name: "Test".into(),
        description: None,
        members: vec![repo_a.id.clone(), repo_b.id.clone()],
    };
    graph.add_group(group.clone());

    // All members should exist in graph
    for member_id in &graph.store.groups[0].members {
        assert!(
            graph.get_repo(member_id).is_some(),
            "Group member {} should exist in graph",
            member_id
        );
    }
}

// =============================================================================
// f2: Slot/Provider Invariant Tests
// =============================================================================

fn make_slot(category: &str, name: &str) -> Slot {
    Slot {
        kind: "Slot".into(),
        id: Slot::generate_id(category, name),
        name: name.into(),
        category: category.into(),
        description: format!("Test {} slot", name),
        interface_version: Some("v1".into()),
        required_capabilities: vec!["basic".into()],
    }
}

fn make_provider(slot_id: &str, name: &str, provider_type: ProviderType) -> Provider {
    Provider {
        kind: "Provider".into(),
        id: Provider::generate_id(slot_id, name),
        name: name.into(),
        slot_id: slot_id.into(),
        provider_type,
        repo_id: None,
        external_uri: None,
        interface_version: Some("v1".into()),
        capabilities: vec!["basic".into()],
        priority: 0,
        is_fallback: false,
    }
}

fn make_binding(consumer_id: &str, slot_id: &str, provider_id: &str) -> SlotBinding {
    SlotBinding {
        kind: "SlotBinding".into(),
        id: SlotBinding::generate_id(consumer_id, slot_id),
        consumer_id: consumer_id.into(),
        slot_id: slot_id.into(),
        provider_id: provider_id.into(),
        mode: BindingMode::Manual,
        created_at: Utc::now(),
        created_by: "test".into(),
    }
}

#[test]
fn test_slot_id_determinism() {
    let id1 = Slot::generate_id("container", "runtime");
    let id2 = Slot::generate_id("container", "runtime");
    let id3 = Slot::generate_id("container", "runtime");

    assert_eq!(id1, id2);
    assert_eq!(id2, id3);
    assert_eq!(id1, "slot:container.runtime");
}

#[test]
fn test_slot_id_uniqueness() {
    let id1 = Slot::generate_id("container", "runtime");
    let id2 = Slot::generate_id("container", "builder");
    let id3 = Slot::generate_id("router", "runtime");

    let ids: HashSet<_> = [id1, id2, id3].into_iter().collect();
    assert_eq!(ids.len(), 3, "All slot IDs should be unique");
}

#[test]
fn test_provider_id_determinism() {
    let id1 = Provider::generate_id("slot:container.runtime", "podman");
    let id2 = Provider::generate_id("slot:container.runtime", "podman");

    assert_eq!(id1, id2);
    assert!(id1.starts_with("provider:"));
}

#[test]
fn test_provider_id_uniqueness() {
    let id1 = Provider::generate_id("slot:container.runtime", "podman");
    let id2 = Provider::generate_id("slot:container.runtime", "docker");
    let id3 = Provider::generate_id("slot:router.core", "podman");

    let ids: HashSet<_> = [id1, id2, id3].into_iter().collect();
    assert_eq!(ids.len(), 3, "All provider IDs should be unique");
}

#[test]
fn test_binding_id_determinism() {
    let id1 = SlotBinding::generate_id("repo:gh:test/app", "slot:container.runtime");
    let id2 = SlotBinding::generate_id("repo:gh:test/app", "slot:container.runtime");

    assert_eq!(id1, id2);
    assert!(id1.starts_with("binding:"));
}

#[test]
fn test_slot_store_providers_for_slot() {
    let mut graph = EcosystemGraph::new();

    let slot = make_slot("container", "runtime");
    graph.slots.slots.push(slot.clone());

    let provider1 = make_provider(&slot.id, "podman", ProviderType::Local);
    let provider2 = make_provider(&slot.id, "docker", ProviderType::Local);
    let other_slot = make_slot("router", "core");
    let provider3 = make_provider(&other_slot.id, "cadre", ProviderType::Ecosystem);

    graph.slots.slots.push(other_slot);
    graph.slots.providers.push(provider1);
    graph.slots.providers.push(provider2);
    graph.slots.providers.push(provider3);

    let providers = graph.slots.providers_for_slot(&slot.id);
    assert_eq!(providers.len(), 2);
    assert!(providers.iter().any(|p| p.name == "podman"));
    assert!(providers.iter().any(|p| p.name == "docker"));
}

#[test]
fn test_slot_store_compatibility_check() {
    let mut graph = EcosystemGraph::new();

    let slot = Slot {
        kind: "Slot".into(),
        id: "slot:container.runtime".into(),
        name: "runtime".into(),
        category: "container".into(),
        description: "Container runtime".into(),
        interface_version: Some("v1".into()),
        required_capabilities: vec!["run".into(), "build".into()],
    };
    graph.slots.slots.push(slot);

    // Compatible provider
    let provider1 = Provider {
        kind: "Provider".into(),
        id: "provider:container.runtime:podman".into(),
        name: "podman".into(),
        slot_id: "slot:container.runtime".into(),
        provider_type: ProviderType::Local,
        repo_id: None,
        external_uri: None,
        interface_version: Some("v1".into()),
        capabilities: vec!["run".into(), "build".into(), "push".into()],
        priority: 10,
        is_fallback: false,
    };
    graph.slots.providers.push(provider1);

    // Incompatible provider (missing capability)
    let provider2 = Provider {
        kind: "Provider".into(),
        id: "provider:container.runtime:minimal".into(),
        name: "minimal".into(),
        slot_id: "slot:container.runtime".into(),
        provider_type: ProviderType::Stub,
        repo_id: None,
        external_uri: None,
        interface_version: Some("v1".into()),
        capabilities: vec!["run".into()], // Missing "build"
        priority: 0,
        is_fallback: true,
    };
    graph.slots.providers.push(provider2);

    // Check compatible provider
    let compat1 = graph.slots.check_compatibility(
        "slot:container.runtime",
        "provider:container.runtime:podman"
    );
    assert!(compat1.compatible, "podman should be compatible");
    assert!(compat1.version_match);
    assert!(compat1.capabilities_missing.is_empty());

    // Check incompatible provider
    let compat2 = graph.slots.check_compatibility(
        "slot:container.runtime",
        "provider:container.runtime:minimal"
    );
    assert!(!compat2.compatible, "minimal should be incompatible");
    assert!(compat2.capabilities_missing.contains(&"build".into()));
}

#[test]
fn test_slot_store_bindings() {
    let mut graph = EcosystemGraph::new();

    let repo = make_repo("app", Forge::GitHub, "test");
    graph.add_repo(repo.clone());

    let slot = make_slot("container", "runtime");
    graph.slots.slots.push(slot.clone());

    let provider = make_provider(&slot.id, "podman", ProviderType::Local);
    graph.slots.providers.push(provider.clone());

    let binding = make_binding(&repo.id, &slot.id, &provider.id);
    graph.slots.bindings.push(binding.clone());

    // Test get_binding
    let retrieved = graph.slots.get_binding(&repo.id, &slot.id);
    assert!(retrieved.is_some());
    assert_eq!(retrieved.unwrap().provider_id, provider.id);

    // Test bindings_for_consumer
    let consumer_bindings = graph.slots.bindings_for_consumer(&repo.id);
    assert_eq!(consumer_bindings.len(), 1);

    // Test bindings_for_provider
    let provider_bindings = graph.slots.bindings_for_provider(&provider.id);
    assert_eq!(provider_bindings.len(), 1);
}

#[test]
fn test_slots_round_trip() {
    let temp_dir = TempDir::new().unwrap();
    let mut graph = EcosystemGraph::new();

    // Add repos
    let repo_a = make_repo("app", Forge::GitHub, "test");
    let repo_b = make_repo("runtime-impl", Forge::GitHub, "test");
    graph.add_repo(repo_a.clone());
    graph.add_repo(repo_b.clone());

    // Add slot
    let slot = Slot {
        kind: "Slot".into(),
        id: "slot:container.runtime".into(),
        name: "runtime".into(),
        category: "container".into(),
        description: "Container runtime slot".into(),
        interface_version: Some("v1".into()),
        required_capabilities: vec!["run".into(), "build".into()],
    };
    graph.slots.slots.push(slot.clone());

    // Add providers
    let provider1 = Provider {
        kind: "Provider".into(),
        id: "provider:container.runtime:podman".into(),
        name: "podman".into(),
        slot_id: slot.id.clone(),
        provider_type: ProviderType::Local,
        repo_id: Some(repo_b.id.clone()),
        external_uri: None,
        interface_version: Some("v1".into()),
        capabilities: vec!["run".into(), "build".into()],
        priority: 10,
        is_fallback: false,
    };
    let provider2 = Provider {
        kind: "Provider".into(),
        id: "provider:container.runtime:cerro-torre".into(),
        name: "cerro-torre".into(),
        slot_id: slot.id.clone(),
        provider_type: ProviderType::Ecosystem,
        repo_id: None,
        external_uri: Some("https://cerro-torre.example.com".into()),
        interface_version: Some("v1".into()),
        capabilities: vec!["run".into(), "build".into()],
        priority: 5,
        is_fallback: true,
    };
    graph.slots.providers.push(provider1.clone());
    graph.slots.providers.push(provider2);

    // Add binding
    let binding = SlotBinding {
        kind: "SlotBinding".into(),
        id: SlotBinding::generate_id(&repo_a.id, &slot.id),
        consumer_id: repo_a.id.clone(),
        slot_id: slot.id.clone(),
        provider_id: provider1.id.clone(),
        mode: BindingMode::Manual,
        created_at: Utc::now(),
        created_by: "test".into(),
    };
    graph.slots.bindings.push(binding);

    // Save
    graph.save(temp_dir.path()).unwrap();

    // Verify slots.json was created
    assert!(temp_dir.path().join("slots.json").exists());

    // Load
    let loaded = EcosystemGraph::load(temp_dir.path()).unwrap();

    // Verify slots
    assert_eq!(loaded.slots.slots.len(), 1);
    let loaded_slot = &loaded.slots.slots[0];
    assert_eq!(loaded_slot.id, slot.id);
    assert_eq!(loaded_slot.name, "runtime");
    assert_eq!(loaded_slot.required_capabilities.len(), 2);

    // Verify providers
    assert_eq!(loaded.slots.providers.len(), 2);
    let loaded_provider = loaded.slots.providers.iter()
        .find(|p| p.name == "podman")
        .expect("podman provider should exist");
    assert_eq!(loaded_provider.repo_id, Some(repo_b.id.clone()));
    assert_eq!(loaded_provider.priority, 10);

    // Verify bindings
    assert_eq!(loaded.slots.bindings.len(), 1);
    let loaded_binding = &loaded.slots.bindings[0];
    assert_eq!(loaded_binding.consumer_id, repo_a.id);
    assert_eq!(loaded_binding.provider_id, provider1.id);
    assert_eq!(loaded_binding.mode, BindingMode::Manual);
}

#[test]
fn test_provider_substitution_preserves_repo_identity() {
    // Invariant from ROADMAP i2: Changing a provider changes edges, not repo identity
    let mut graph = EcosystemGraph::new();

    let consumer = make_repo("app", Forge::GitHub, "test");
    let provider_repo1 = make_repo("podman-impl", Forge::GitHub, "test");
    let provider_repo2 = make_repo("docker-impl", Forge::GitHub, "test");
    graph.add_repo(consumer.clone());
    graph.add_repo(provider_repo1.clone());
    graph.add_repo(provider_repo2.clone());

    let slot = make_slot("container", "runtime");
    graph.slots.slots.push(slot.clone());

    let provider1 = Provider {
        kind: "Provider".into(),
        id: Provider::generate_id(&slot.id, "podman"),
        name: "podman".into(),
        slot_id: slot.id.clone(),
        provider_type: ProviderType::Local,
        repo_id: Some(provider_repo1.id.clone()),
        external_uri: None,
        interface_version: Some("v1".into()),
        capabilities: vec!["basic".into()],
        priority: 10,
        is_fallback: false,
    };
    let provider2 = Provider {
        kind: "Provider".into(),
        id: Provider::generate_id(&slot.id, "docker"),
        name: "docker".into(),
        slot_id: slot.id.clone(),
        provider_type: ProviderType::Local,
        repo_id: Some(provider_repo2.id.clone()),
        external_uri: None,
        interface_version: Some("v1".into()),
        capabilities: vec!["basic".into()],
        priority: 5,
        is_fallback: false,
    };
    graph.slots.providers.push(provider1.clone());
    graph.slots.providers.push(provider2.clone());

    // Create initial binding
    let binding1 = make_binding(&consumer.id, &slot.id, &provider1.id);
    let binding_id = binding1.id.clone();
    graph.slots.bindings.push(binding1);

    // Verify consumer repo identity before switch
    let consumer_before = graph.get_repo(&consumer.id).unwrap();
    let consumer_id_before = consumer_before.id.clone();

    // Switch provider by updating binding
    graph.slots.bindings.retain(|b| b.id != binding_id);
    let binding2 = make_binding(&consumer.id, &slot.id, &provider2.id);
    graph.slots.bindings.push(binding2);

    // Verify consumer repo identity unchanged after switch
    let consumer_after = graph.get_repo(&consumer.id).unwrap();
    assert_eq!(consumer_after.id, consumer_id_before, "Consumer repo ID should not change when switching providers");

    // Verify binding changed
    let current_binding = graph.slots.get_binding(&consumer.id, &slot.id).unwrap();
    assert_eq!(current_binding.provider_id, provider2.id);
}

#[test]
fn test_empty_slot_store_round_trip() {
    let temp_dir = TempDir::new().unwrap();

    let graph = EcosystemGraph::new();
    graph.save(temp_dir.path()).unwrap();

    let loaded = EcosystemGraph::load(temp_dir.path()).unwrap();

    assert!(loaded.slots.slots.is_empty());
    assert!(loaded.slots.providers.is_empty());
    assert!(loaded.slots.bindings.is_empty());
}

#[test]
fn test_dot_export_includes_slots_overlay() {
    let mut graph = EcosystemGraph::new();

    // Add repos
    let consumer = make_repo("webapp", Forge::GitHub, "test");
    let impl_repo = make_repo("auth-impl", Forge::GitHub, "test");
    graph.add_repo(consumer.clone());
    graph.add_repo(impl_repo.clone());

    // Add slot
    let slot = make_slot("auth", "provider");
    graph.slots.slots.push(slot.clone());

    // Add provider linked to impl_repo
    let provider = Provider {
        kind: "Provider".into(),
        id: Provider::generate_id(&slot.id, "keycloak"),
        name: "keycloak".into(),
        slot_id: slot.id.clone(),
        provider_type: ProviderType::Local,
        repo_id: Some(impl_repo.id.clone()),
        external_uri: None,
        interface_version: Some("v1".into()),
        capabilities: vec!["oauth".into(), "oidc".into()],
        priority: 10,
        is_fallback: false,
    };
    graph.slots.providers.push(provider.clone());

    // Add binding
    let binding = make_binding(&consumer.id, &slot.id, &provider.id);
    graph.slots.bindings.push(binding);

    // Export to DOT
    let dot = graph.to_dot();

    // Verify slots are represented as diamonds
    assert!(dot.contains("shape=diamond"), "Slots should be diamond-shaped");
    assert!(dot.contains(&slot.id), "Slot ID should appear in DOT");
    assert!(dot.contains("lightyellow"), "Slots should have lightyellow fill");

    // Verify providers are represented as hexagons
    assert!(dot.contains("shape=hexagon"), "Providers should be hexagon-shaped");
    assert!(dot.contains(&provider.id), "Provider ID should appear in DOT");
    assert!(dot.contains("lightblue"), "Non-fallback providers should have lightblue fill");

    // Verify provider-to-slot relationship
    assert!(dot.contains("satisfies"), "Provider should show 'satisfies' relationship to slot");

    // Verify provider-to-repo implementation link
    assert!(dot.contains("impl"), "Provider should show 'impl' link to repo");

    // Verify bindings
    assert!(dot.contains("darkgreen"), "Bindings should be dark green");
    assert!(dot.contains("uses (manual)"), "Binding should show mode");
}

// =========================================================================
// f3 Tests: Plan Generation + Dry-Run
// =========================================================================

use reposystem::types::{
    Plan, PlanOp, PlanStatus, PlanStore, PlanDiff, RiskLevel, FileChangeType,
};

fn make_plan(scenario_id: &str, operations: Vec<PlanOp>) -> Plan {
    Plan {
        kind: "Plan".into(),
        id: Plan::generate_id(scenario_id),
        name: format!("Test plan for {}", scenario_id),
        scenario_id: scenario_id.into(),
        description: Some("Test plan".into()),
        operations,
        overall_risk: Plan::calculate_overall_risk(&[]),
        status: PlanStatus::Draft,
        created_at: Utc::now(),
        created_by: "test".into(),
        applied_at: None,
        rollback_plan_id: None,
    }
}

#[test]
fn test_plan_id_determinism() {
    // Plan IDs should follow a pattern based on scenario
    let scenario_id = "scenario:test";
    let plan_id = Plan::generate_id(scenario_id);

    assert!(plan_id.starts_with("plan:test:"), "Plan ID should start with scenario name");
    assert!(plan_id.len() > 15, "Plan ID should include timestamp");
}

#[test]
fn test_plan_risk_calculation() {
    // Empty operations should have Low risk
    let empty_risk = Plan::calculate_overall_risk(&[]);
    assert_eq!(empty_risk, RiskLevel::Low);

    // Single low risk operation
    let low_ops = vec![
        PlanOp::CreateBinding {
            consumer_id: "repo:test".into(),
            slot_id: "slot:test".into(),
            provider_id: "provider:test".into(),
            risk: RiskLevel::Low,
            reason: "test".into(),
        },
    ];
    assert_eq!(Plan::calculate_overall_risk(&low_ops), RiskLevel::Low);

    // Mixed risks should return highest
    let mixed_ops = vec![
        PlanOp::CreateBinding {
            consumer_id: "repo:test1".into(),
            slot_id: "slot:test".into(),
            provider_id: "provider:test".into(),
            risk: RiskLevel::Low,
            reason: "test".into(),
        },
        PlanOp::SwitchBinding {
            binding_id: "binding:test".into(),
            consumer_id: "repo:test2".into(),
            slot_id: "slot:test".into(),
            from_provider_id: "provider:old".into(),
            to_provider_id: "provider:new".into(),
            risk: RiskLevel::High,
            reason: "test".into(),
        },
    ];
    assert_eq!(Plan::calculate_overall_risk(&mixed_ops), RiskLevel::High);

    // Critical risk should propagate
    let critical_ops = vec![
        PlanOp::RemoveBinding {
            binding_id: "binding:test".into(),
            consumer_id: "repo:test".into(),
            slot_id: "slot:test".into(),
            provider_id: "provider:test".into(),
            risk: RiskLevel::Critical,
            reason: "test".into(),
        },
    ];
    assert_eq!(Plan::calculate_overall_risk(&critical_ops), RiskLevel::Critical);
}

#[test]
fn test_rollback_plan_reverses_operations() {
    // Create a plan with various operations
    let operations = vec![
        PlanOp::SwitchBinding {
            binding_id: "binding:consumer:slot".into(),
            consumer_id: "repo:consumer".into(),
            slot_id: "slot:test".into(),
            from_provider_id: "provider:old".into(),
            to_provider_id: "provider:new".into(),
            risk: RiskLevel::Medium,
            reason: "Upgrade".into(),
        },
        PlanOp::CreateBinding {
            consumer_id: "repo:new-consumer".into(),
            slot_id: "slot:test".into(),
            provider_id: "provider:new".into(),
            risk: RiskLevel::Low,
            reason: "New binding".into(),
        },
    ];

    let plan = Plan {
        kind: "Plan".into(),
        id: "plan:test:original".into(),
        name: "Original Plan".into(),
        scenario_id: "scenario:test".into(),
        description: None,
        operations,
        overall_risk: RiskLevel::Medium,
        status: PlanStatus::Ready,
        created_at: Utc::now(),
        created_by: "test".into(),
        applied_at: None,
        rollback_plan_id: None,
    };

    // Generate rollback
    let rollback = PlanStore::generate_rollback(&plan);

    // Verify rollback properties
    assert!(rollback.id.contains("rollback"), "Rollback ID should contain 'rollback'");
    assert!(rollback.name.contains("Rollback"), "Rollback name should contain 'Rollback'");
    assert_eq!(rollback.scenario_id, plan.scenario_id);

    // Operations should be reversed in order
    assert_eq!(rollback.operations.len(), 2);

    // First rollback op should reverse the CreateBinding (last original op)
    match &rollback.operations[0] {
        PlanOp::RemoveBinding { consumer_id, slot_id, provider_id, .. } => {
            assert_eq!(consumer_id, "repo:new-consumer");
            assert_eq!(slot_id, "slot:test");
            assert_eq!(provider_id, "provider:new");
        }
        _ => panic!("First rollback op should be RemoveBinding"),
    }

    // Second rollback op should reverse the SwitchBinding (first original op)
    match &rollback.operations[1] {
        PlanOp::SwitchBinding { from_provider_id, to_provider_id, .. } => {
            assert_eq!(from_provider_id, "provider:new", "From should be the new provider");
            assert_eq!(to_provider_id, "provider:old", "To should be the original provider");
        }
        _ => panic!("Second rollback op should be SwitchBinding"),
    }
}

#[test]
fn test_plan_op_descriptions() {
    let switch_op = PlanOp::SwitchBinding {
        binding_id: "binding:test".into(),
        consumer_id: "repo:app".into(),
        slot_id: "slot:db".into(),
        from_provider_id: "provider:mysql".into(),
        to_provider_id: "provider:postgres".into(),
        risk: RiskLevel::Medium,
        reason: "Migration".into(),
    };
    let desc = switch_op.description();
    assert!(desc.contains("Switch"), "Description should mention switch");
    assert!(desc.contains("repo:app"), "Description should mention consumer");

    let create_op = PlanOp::CreateBinding {
        consumer_id: "repo:new".into(),
        slot_id: "slot:cache".into(),
        provider_id: "provider:redis".into(),
        risk: RiskLevel::Low,
        reason: "New cache".into(),
    };
    let desc = create_op.description();
    assert!(desc.contains("Create"), "Description should mention create");

    let file_op = PlanOp::FileChange {
        repo_id: "repo:test".into(),
        file_path: "config.toml".into(),
        change_type: FileChangeType::Modify,
        diff: Some("+new line".into()),
        risk: RiskLevel::Low,
    };
    let desc = file_op.description();
    assert!(desc.contains("Modify"), "Description should mention file change type");
    assert!(desc.contains("config.toml"), "Description should mention file path");
}

#[test]
fn test_plan_store_queries() {
    let mut store = PlanStore::default();

    // Add plans for different scenarios
    let plan1 = Plan {
        kind: "Plan".into(),
        id: "plan:scenario-a:001".into(),
        name: "Plan A1".into(),
        scenario_id: "scenario:scenario-a".into(),
        description: None,
        operations: vec![],
        overall_risk: RiskLevel::Low,
        status: PlanStatus::Ready,
        created_at: Utc::now() - chrono::Duration::hours(2),
        created_by: "test".into(),
        applied_at: None,
        rollback_plan_id: None,
    };
    let plan2 = Plan {
        kind: "Plan".into(),
        id: "plan:scenario-a:002".into(),
        name: "Plan A2".into(),
        scenario_id: "scenario:scenario-a".into(),
        description: None,
        operations: vec![],
        overall_risk: RiskLevel::Medium,
        status: PlanStatus::Ready,
        created_at: Utc::now(),
        created_by: "test".into(),
        applied_at: None,
        rollback_plan_id: None,
    };
    let plan3 = Plan {
        kind: "Plan".into(),
        id: "plan:scenario-b:001".into(),
        name: "Plan B1".into(),
        scenario_id: "scenario:scenario-b".into(),
        description: None,
        operations: vec![],
        overall_risk: RiskLevel::High,
        status: PlanStatus::Draft,
        created_at: Utc::now(),
        created_by: "test".into(),
        applied_at: None,
        rollback_plan_id: None,
    };

    store.plans.push(plan1);
    store.plans.push(plan2);
    store.plans.push(plan3);

    // Test get_plan
    assert!(store.get_plan("plan:scenario-a:001").is_some());
    assert!(store.get_plan("nonexistent").is_none());

    // Test plans_for_scenario
    let scenario_a_plans = store.plans_for_scenario("scenario:scenario-a");
    assert_eq!(scenario_a_plans.len(), 2);

    let scenario_b_plans = store.plans_for_scenario("scenario:scenario-b");
    assert_eq!(scenario_b_plans.len(), 1);

    // Test latest_plan_for_scenario (should return plan2 as it's newer)
    let latest = store.latest_plan_for_scenario("scenario:scenario-a");
    assert!(latest.is_some());
    assert_eq!(latest.unwrap().id, "plan:scenario-a:002");
}

#[test]
fn test_plan_diff_summary() {
    let plan = Plan {
        kind: "Plan".into(),
        id: "plan:test".into(),
        name: "Test".into(),
        scenario_id: "scenario:test".into(),
        description: None,
        operations: vec![
            PlanOp::SwitchBinding {
                binding_id: "b1".into(),
                consumer_id: "c1".into(),
                slot_id: "s1".into(),
                from_provider_id: "p1".into(),
                to_provider_id: "p2".into(),
                risk: RiskLevel::Low,
                reason: "test".into(),
            },
            PlanOp::SwitchBinding {
                binding_id: "b2".into(),
                consumer_id: "c2".into(),
                slot_id: "s2".into(),
                from_provider_id: "p3".into(),
                to_provider_id: "p4".into(),
                risk: RiskLevel::Medium,
                reason: "test".into(),
            },
            PlanOp::CreateBinding {
                consumer_id: "c3".into(),
                slot_id: "s3".into(),
                provider_id: "p5".into(),
                risk: RiskLevel::High,
                reason: "test".into(),
            },
        ],
        overall_risk: RiskLevel::High,
        status: PlanStatus::Ready,
        created_at: Utc::now(),
        created_by: "test".into(),
        applied_at: None,
        rollback_plan_id: None,
    };

    let summary = plan.risk_summary();
    assert_eq!(summary.get("low"), Some(&1));
    assert_eq!(summary.get("medium"), Some(&1));
    assert_eq!(summary.get("high"), Some(&1));
}

#[test]
fn test_plans_round_trip() {
    let temp_dir = TempDir::new().unwrap();
    let mut graph = EcosystemGraph::new();

    // Add a plan
    let plan = Plan {
        kind: "Plan".into(),
        id: "plan:round-trip-test".into(),
        name: "Round Trip Test".into(),
        scenario_id: "scenario:test".into(),
        description: Some("Testing persistence".into()),
        operations: vec![
            PlanOp::CreateBinding {
                consumer_id: "repo:test".into(),
                slot_id: "slot:test".into(),
                provider_id: "provider:test".into(),
                risk: RiskLevel::Low,
                reason: "Test binding".into(),
            },
        ],
        overall_risk: RiskLevel::Low,
        status: PlanStatus::Ready,
        created_at: Utc::now(),
        created_by: "test".into(),
        applied_at: None,
        rollback_plan_id: None,
    };

    let diff = PlanDiff {
        plan_id: plan.id.clone(),
        bindings_changed: 0,
        bindings_created: 1,
        bindings_removed: 0,
        files_affected: 0,
        file_diffs: vec![],
    };

    graph.plans.plans.push(plan.clone());
    graph.plans.diffs.push(diff);

    // Save
    graph.save(temp_dir.path()).unwrap();

    // Verify plans.json was created
    assert!(temp_dir.path().join("plans.json").exists());

    // Load
    let loaded = EcosystemGraph::load(temp_dir.path()).unwrap();

    // Verify plans
    assert_eq!(loaded.plans.plans.len(), 1);
    let loaded_plan = &loaded.plans.plans[0];
    assert_eq!(loaded_plan.id, "plan:round-trip-test");
    assert_eq!(loaded_plan.name, "Round Trip Test");
    assert_eq!(loaded_plan.operations.len(), 1);

    // Verify diff
    assert_eq!(loaded.plans.diffs.len(), 1);
    assert_eq!(loaded.plans.diffs[0].bindings_created, 1);
}

#[test]
fn test_empty_plan_store_round_trip() {
    let temp_dir = TempDir::new().unwrap();

    let graph = EcosystemGraph::new();
    graph.save(temp_dir.path()).unwrap();

    // Verify plans.json was created
    assert!(temp_dir.path().join("plans.json").exists());

    let loaded = EcosystemGraph::load(temp_dir.path()).unwrap();

    assert!(loaded.plans.plans.is_empty());
    assert!(loaded.plans.diffs.is_empty());
}

// =============================================================================
// f4 Invariant Tests - Apply + Rollback Execution
// =============================================================================

#[test]
fn test_audit_entry_structure() {
    // Audit entries should have all required fields
    let entry = AuditEntry {
        kind: "AuditEntry".into(),
        id: "audit:plan:test:123".into(),
        plan_id: "plan:test".into(),
        result: ApplyResult::Success,
        op_results: vec![
            OpResult {
                op_index: 0,
                success: true,
                error: None,
                executed_at: Utc::now(),
            },
            OpResult {
                op_index: 1,
                success: true,
                error: None,
                executed_at: Utc::now(),
            },
        ],
        started_at: Utc::now() - chrono::Duration::seconds(5),
        finished_at: Utc::now(),
        applied_by: "test".into(),
        auto_rollback_triggered: false,
        rollback_plan_id: None,
        health_check_passed: Some(true),
        notes: vec!["Test note".into()],
    };

    assert_eq!(entry.kind, "AuditEntry");
    assert_eq!(entry.op_results.len(), 2);
    assert!(entry.op_results.iter().all(|r| r.success));
    assert_eq!(entry.result, ApplyResult::Success);
}

#[test]
fn test_apply_result_variants() {
    // All ApplyResult variants should serialize correctly
    let results = [
        ApplyResult::Success,
        ApplyResult::PartialFailure,
        ApplyResult::Failure,
        ApplyResult::RolledBack,
    ];

    for result in results {
        let json = serde_json::to_string(&result).unwrap();
        let loaded: ApplyResult = serde_json::from_str(&json).unwrap();
        assert_eq!(loaded, result);
    }
}

#[test]
fn test_op_result_captures_errors() {
    // Failed operations should capture error messages
    let failed_result = OpResult {
        op_index: 0,
        success: false,
        error: Some("Provider not found: provider:missing".into()),
        executed_at: Utc::now(),
    };

    assert!(!failed_result.success);
    assert!(failed_result.error.is_some());
    assert!(failed_result.error.as_ref().unwrap().contains("not found"));

    let success_result = OpResult {
        op_index: 1,
        success: true,
        error: None,
        executed_at: Utc::now(),
    };

    assert!(success_result.success);
    assert!(success_result.error.is_none());
}

#[test]
fn test_audit_store_round_trip() {
    let temp_dir = TempDir::new().unwrap();
    let mut graph = EcosystemGraph::new();

    // Create audit entries
    let entry1 = AuditEntry {
        kind: "AuditEntry".into(),
        id: "audit:plan:test:001".into(),
        plan_id: "plan:test:001".into(),
        result: ApplyResult::Success,
        op_results: vec![
            OpResult {
                op_index: 0,
                success: true,
                error: None,
                executed_at: Utc::now(),
            },
        ],
        started_at: Utc::now() - chrono::Duration::seconds(10),
        finished_at: Utc::now() - chrono::Duration::seconds(5),
        applied_by: "test".into(),
        auto_rollback_triggered: false,
        rollback_plan_id: None,
        health_check_passed: Some(true),
        notes: vec![],
    };

    let entry2 = AuditEntry {
        kind: "AuditEntry".into(),
        id: "audit:plan:test:002".into(),
        plan_id: "plan:test:002".into(),
        result: ApplyResult::RolledBack,
        op_results: vec![
            OpResult {
                op_index: 0,
                success: true,
                error: None,
                executed_at: Utc::now(),
            },
            OpResult {
                op_index: 1,
                success: false,
                error: Some("Version mismatch".into()),
                executed_at: Utc::now(),
            },
        ],
        started_at: Utc::now() - chrono::Duration::seconds(5),
        finished_at: Utc::now(),
        applied_by: "test".into(),
        auto_rollback_triggered: true,
        rollback_plan_id: Some("rollback:plan:test:002".into()),
        health_check_passed: None,
        notes: vec!["Auto-rollback triggered".into()],
    };

    graph.audit.entries.push(entry1);
    graph.audit.entries.push(entry2);

    // Save
    graph.save(temp_dir.path()).unwrap();

    // Verify audit.json was created
    assert!(temp_dir.path().join("audit.json").exists());

    // Load
    let loaded = EcosystemGraph::load(temp_dir.path()).unwrap();

    // Verify entries
    assert_eq!(loaded.audit.entries.len(), 2);

    let loaded_entry1 = &loaded.audit.entries[0];
    assert_eq!(loaded_entry1.id, "audit:plan:test:001");
    assert_eq!(loaded_entry1.result, ApplyResult::Success);
    assert_eq!(loaded_entry1.op_results.len(), 1);

    let loaded_entry2 = &loaded.audit.entries[1];
    assert_eq!(loaded_entry2.id, "audit:plan:test:002");
    assert_eq!(loaded_entry2.result, ApplyResult::RolledBack);
    assert!(loaded_entry2.auto_rollback_triggered);
    assert!(loaded_entry2.rollback_plan_id.is_some());
    assert_eq!(loaded_entry2.op_results.len(), 2);
    assert!(loaded_entry2.op_results[1].error.is_some());
}

#[test]
fn test_empty_audit_store_round_trip() {
    let temp_dir = TempDir::new().unwrap();

    let graph = EcosystemGraph::new();
    graph.save(temp_dir.path()).unwrap();

    // Verify audit.json was created
    assert!(temp_dir.path().join("audit.json").exists());

    let loaded = EcosystemGraph::load(temp_dir.path()).unwrap();
    assert!(loaded.audit.entries.is_empty());
}

#[test]
fn test_audit_entry_timing_integrity() {
    // started_at should be before finished_at
    let started = Utc::now() - chrono::Duration::seconds(10);
    let finished = Utc::now();

    let entry = AuditEntry {
        kind: "AuditEntry".into(),
        id: "audit:timing:test".into(),
        plan_id: "plan:test".into(),
        result: ApplyResult::Success,
        op_results: vec![],
        started_at: started,
        finished_at: finished,
        applied_by: "test".into(),
        auto_rollback_triggered: false,
        rollback_plan_id: None,
        health_check_passed: None,
        notes: vec![],
    };

    assert!(entry.finished_at > entry.started_at);
    let duration = entry.finished_at - entry.started_at;
    assert!(duration.num_seconds() >= 0);
}

#[test]
fn test_audit_store_filter_by_plan() {
    let mut store = AuditStore::default();

    // Add entries for different plans
    store.entries.push(AuditEntry {
        kind: "AuditEntry".into(),
        id: "audit:plan-a:001".into(),
        plan_id: "plan:scenario-a".into(),
        result: ApplyResult::Success,
        op_results: vec![],
        started_at: Utc::now(),
        finished_at: Utc::now(),
        applied_by: "test".into(),
        auto_rollback_triggered: false,
        rollback_plan_id: None,
        health_check_passed: None,
        notes: vec![],
    });
    store.entries.push(AuditEntry {
        kind: "AuditEntry".into(),
        id: "audit:plan-a:002".into(),
        plan_id: "plan:scenario-a".into(),
        result: ApplyResult::PartialFailure,
        op_results: vec![],
        started_at: Utc::now(),
        finished_at: Utc::now(),
        applied_by: "test".into(),
        auto_rollback_triggered: false,
        rollback_plan_id: None,
        health_check_passed: None,
        notes: vec![],
    });
    store.entries.push(AuditEntry {
        kind: "AuditEntry".into(),
        id: "audit:plan-b:001".into(),
        plan_id: "plan:scenario-b".into(),
        result: ApplyResult::Success,
        op_results: vec![],
        started_at: Utc::now(),
        finished_at: Utc::now(),
        applied_by: "test".into(),
        auto_rollback_triggered: false,
        rollback_plan_id: None,
        health_check_passed: None,
        notes: vec![],
    });

    // Filter by plan ID
    let plan_a_entries: Vec<_> = store.entries.iter()
        .filter(|e| e.plan_id.contains("scenario-a"))
        .collect();
    assert_eq!(plan_a_entries.len(), 2);

    let plan_b_entries: Vec<_> = store.entries.iter()
        .filter(|e| e.plan_id.contains("scenario-b"))
        .collect();
    assert_eq!(plan_b_entries.len(), 1);
}

#[test]
fn test_auto_rollback_state_consistency() {
    // When auto_rollback_triggered is true, RolledBack result should be used
    // unless rollback itself failed
    let entry = AuditEntry {
        kind: "AuditEntry".into(),
        id: "audit:rollback:test".into(),
        plan_id: "plan:test".into(),
        result: ApplyResult::RolledBack,
        op_results: vec![
            OpResult {
                op_index: 0,
                success: true,
                error: None,
                executed_at: Utc::now(),
            },
            OpResult {
                op_index: 1,
                success: false,
                error: Some("Provider version mismatch".into()),
                executed_at: Utc::now(),
            },
        ],
        started_at: Utc::now(),
        finished_at: Utc::now(),
        applied_by: "test".into(),
        auto_rollback_triggered: true,
        rollback_plan_id: Some("rollback:plan:test".into()),
        health_check_passed: None, // Health check not run after rollback
        notes: vec!["Auto-rollback triggered after operation 2 failed".into()],
    };

    assert!(entry.auto_rollback_triggered);
    assert!(entry.rollback_plan_id.is_some());
    assert_eq!(entry.result, ApplyResult::RolledBack);
    // Health check should be None when rolled back
    assert!(entry.health_check_passed.is_none());
}
