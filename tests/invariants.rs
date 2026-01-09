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
    AnnotationSource, AspectAnnotation, BindingMode, Channel, Edge, EdgeMeta, Evidence,
    Forge, Group, ImportMeta, Polarity, Provider, ProviderType, RelationType, Repo,
    Slot, SlotBinding, Visibility,
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
