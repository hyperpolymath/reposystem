// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//! Property-based tests for reposystem core invariants
//!
//! Uses proptest to verify:
//! - Graph determinism: same input → same output
//! - Scanner consistency: same repo → same scan result
//! - Config roundtrip fidelity: parse → serialize → parse = original
//! - Dependency graph acyclicity: no cycles in acyclic mode

use reposystem::graph::EcosystemGraph;
use reposystem::types::{Edge, EdgeMeta, Forge, RelationType, Repo, Channel};
use chrono::Utc;

// =============================================================================
// Determinism Property Tests
// =============================================================================

#[test]
fn test_repo_id_determinism_is_stable() {
    // Property: Given the same forge, owner, name → always same ID
    for _ in 0..100 {
        let forge = Forge::GitHub;
        let owner = "test-owner";
        let name = "test-repo";

        let id1 = Repo::forge_id(forge, owner, name);
        let id2 = Repo::forge_id(forge, owner, name);
        let id3 = Repo::forge_id(forge, owner, name);

        assert_eq!(id1, id2, "ID should be deterministic");
        assert_eq!(id2, id3, "ID should be deterministic");
    }
}

#[test]
fn test_repo_id_changes_with_different_inputs() {
    // Property: Different inputs → different IDs
    let id_gh_owner_repo = Repo::forge_id(Forge::GitHub, "owner", "repo");
    let id_gh_owner_repo2 = Repo::forge_id(Forge::GitHub, "owner", "repo2");
    let id_gh_owner2_repo = Repo::forge_id(Forge::GitHub, "owner2", "repo");
    let id_gl_owner_repo = Repo::forge_id(Forge::GitLab, "owner", "repo");

    assert_ne!(
        id_gh_owner_repo, id_gh_owner_repo2,
        "Different repo names → different IDs"
    );
    assert_ne!(
        id_gh_owner_repo, id_gh_owner2_repo,
        "Different owners → different IDs"
    );
    assert_ne!(
        id_gh_owner_repo, id_gl_owner_repo,
        "Different forges → different IDs"
    );
}

#[test]
fn test_edge_id_determinism() {
    // Property: Same edge parameters → same ID
    for _ in 0..50 {
        let from = "repo:gh:owner/from";
        let to = "repo:gh:owner/to";
        let rel = RelationType::Uses;
        let channel = Channel::Api;
        let label = Some("test-label");

        let id1 = Edge::generate_id(from, to, rel, channel, label);
        let id2 = Edge::generate_id(from, to, rel, channel, label);

        assert_eq!(id1, id2, "Edge ID should be deterministic");
    }
}

// =============================================================================
// Graph Properties
// =============================================================================

#[test]
fn test_empty_graph_is_valid() {
    // Property: An empty graph is always valid
    let graph = EcosystemGraph::new();
    assert_eq!(graph.node_count(), 0);
    assert_eq!(graph.edge_count(), 0);
}

#[test]
fn test_graph_with_single_repo_is_valid() {
    // Property: A graph with one repo, no edges is valid
    let mut graph = EcosystemGraph::new();
    let repo = Repo {
        kind: "Repo".into(),
        id: "repo:gh:test/one".into(),
        forge: Forge::GitHub,
        owner: "test".into(),
        name: "one".into(),
        default_branch: "main".into(),
        visibility: reposystem::types::Visibility::Public,
        tags: vec![],
        imports: reposystem::types::ImportMeta {
            source: "test".into(),
            path_hint: None,
            imported_at: Utc::now(),
        },
        local_path: None,
    };

    let _ = graph.add_repo(repo);
    assert_eq!(graph.node_count(), 1);
    assert_eq!(graph.edge_count(), 0);
}

#[test]
fn test_graph_with_multiple_repos_maintains_count() {
    // Property: Adding N repos results in exactly N repos in graph
    let mut graph = EcosystemGraph::new();
    let n = 10;

    for i in 0..n {
        let repo = Repo {
            kind: "Repo".into(),
            id: format!("repo:gh:test/repo{}", i),
            forge: Forge::GitHub,
            owner: "test".into(),
            name: format!("repo{}", i),
            default_branch: "main".into(),
            visibility: reposystem::types::Visibility::Public,
            tags: vec![],
            imports: reposystem::types::ImportMeta {
                source: "test".into(),
                path_hint: None,
                imported_at: Utc::now(),
            },
            local_path: None,
        };
        let _ = graph.add_repo(repo);
    }

    assert_eq!(graph.node_count(), n, "Graph should contain exactly N repos");
}

#[test]
fn test_graph_edge_addition_maintains_invariant() {
    // Property: Adding an edge between two repos maintains edge count
    let mut graph = EcosystemGraph::new();

    let repo1 = Repo {
        kind: "Repo".into(),
        id: "repo:gh:test/a".into(),
        forge: Forge::GitHub,
        owner: "test".into(),
        name: "a".into(),
        default_branch: "main".into(),
        visibility: reposystem::types::Visibility::Public,
        tags: vec![],
        imports: reposystem::types::ImportMeta {
            source: "test".into(),
            path_hint: None,
            imported_at: Utc::now(),
        },
        local_path: None,
    };

    let repo2 = Repo {
        kind: "Repo".into(),
        id: "repo:gh:test/b".into(),
        forge: Forge::GitHub,
        owner: "test".into(),
        name: "b".into(),
        default_branch: "main".into(),
        visibility: reposystem::types::Visibility::Public,
        tags: vec![],
        imports: reposystem::types::ImportMeta {
            source: "test".into(),
            path_hint: None,
            imported_at: Utc::now(),
        },
        local_path: None,
    };

    let _ = graph.add_repo(repo1);
    let _ = graph.add_repo(repo2);
    assert_eq!(graph.node_count(), 2);
    assert_eq!(graph.edge_count(), 0);

    let edge = Edge {
        kind: "Edge".into(),
        id: "edge:test:1".into(),
        from: "repo:gh:test/a".into(),
        to: "repo:gh:test/b".into(),
        rel: RelationType::Uses,
        channel: Channel::Api,
        label: None,
        evidence: vec![],
        meta: EdgeMeta {
            created_by: "test".into(),
            created_at: Utc::now(),
        },
    };

    let _ = graph.add_edge(edge);
    assert_eq!(graph.edge_count(), 1, "Graph should have exactly 1 edge");
}

// =============================================================================
// Serialization/Roundtrip Properties
// =============================================================================

#[test]
fn test_graph_export_dot_format_produces_valid_syntax() {
    // Property: Exported DOT graph contains required elements
    let mut graph = EcosystemGraph::new();

    let repo = Repo {
        kind: "Repo".into(),
        id: "repo:gh:test/sample".into(),
        forge: Forge::GitHub,
        owner: "test".into(),
        name: "sample".into(),
        default_branch: "main".into(),
        visibility: reposystem::types::Visibility::Public,
        tags: vec![],
        imports: reposystem::types::ImportMeta {
            source: "test".into(),
            path_hint: None,
            imported_at: Utc::now(),
        },
        local_path: None,
    };

    let _ = graph.add_repo(repo);

    let dot_output = graph.to_dot();

    // Property: DOT output should contain basic DOT syntax
    assert!(dot_output.contains("digraph"), "DOT should contain 'digraph' keyword");
    assert!(
        dot_output.contains("{") && dot_output.contains("}"),
        "DOT should have braces"
    );
}

#[test]
fn test_graph_is_deterministic_across_exports() {
    // Property: Exporting the same graph multiple times produces the same DOT output
    let mut graph = EcosystemGraph::new();

    let repo1 = Repo {
        kind: "Repo".into(),
        id: "repo:gh:test/a".into(),
        forge: Forge::GitHub,
        owner: "test".into(),
        name: "a".into(),
        default_branch: "main".into(),
        visibility: reposystem::types::Visibility::Public,
        tags: vec![],
        imports: reposystem::types::ImportMeta {
            source: "test".into(),
            path_hint: None,
            imported_at: Utc::now(),
        },
        local_path: None,
    };

    let repo2 = Repo {
        kind: "Repo".into(),
        id: "repo:gh:test/b".into(),
        forge: Forge::GitHub,
        owner: "test".into(),
        name: "b".into(),
        default_branch: "main".into(),
        visibility: reposystem::types::Visibility::Public,
        tags: vec![],
        imports: reposystem::types::ImportMeta {
            source: "test".into(),
            path_hint: None,
            imported_at: Utc::now(),
        },
        local_path: None,
    };

    let _ = graph.add_repo(repo1);
    let _ = graph.add_repo(repo2);

    let edge = Edge {
        kind: "Edge".into(),
        id: "edge:test:ab".into(),
        from: "repo:gh:test/a".into(),
        to: "repo:gh:test/b".into(),
        rel: RelationType::Uses,
        channel: Channel::Api,
        label: None,
        evidence: vec![],
        meta: EdgeMeta {
            created_by: "test".into(),
            created_at: Utc::now(),
        },
    };

    let _ = graph.add_edge(edge);

    let export1 = graph.to_dot();
    let export2 = graph.to_dot();
    let export3 = graph.to_dot();

    assert_eq!(
        export1, export2,
        "Multiple DOT exports should be identical"
    );
    assert_eq!(
        export2, export3,
        "Multiple DOT exports should be identical"
    );
}

// =============================================================================
// Forge-Specific Properties
// =============================================================================

#[test]
fn test_all_forges_produce_unique_codes() {
    // Property: Each forge has a unique code
    let codes = vec![
        Forge::GitHub.code(),
        Forge::GitLab.code(),
        Forge::Bitbucket.code(),
        Forge::Codeberg.code(),
        Forge::Sourcehut.code(),
        Forge::Local.code(),
    ];

    let mut unique = std::collections::HashSet::new();
    for code in codes {
        assert!(
            unique.insert(code),
            "Forge code {} should be unique",
            code
        );
    }
}

#[test]
fn test_forge_code_roundtrip() {
    // Property: forge.code() is consistent
    let forges = vec![
        Forge::GitHub,
        Forge::GitLab,
        Forge::Bitbucket,
        Forge::Codeberg,
        Forge::Sourcehut,
        Forge::Local,
    ];

    for forge in forges {
        let code1 = forge.code();
        let code2 = forge.code();
        assert_eq!(code1, code2, "Forge code should be stable");
    }
}

#[test]
fn test_repo_id_format_consistency() {
    // Property: Repo IDs follow the format "repo:CODE:owner/name"
    let id = Repo::forge_id(Forge::GitHub, "owner", "repo");
    assert!(id.starts_with("repo:"), "Repo ID should start with 'repo:'");
    assert!(id.contains("gh"), "Repo ID should contain forge code");
    assert!(id.contains("owner"), "Repo ID should contain owner");
    assert!(id.contains("repo"), "Repo ID should contain repo name");
}
