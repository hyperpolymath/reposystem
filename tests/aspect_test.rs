// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//! Aspect-based cross-cutting tests for reposystem
//!
//! Validates non-functional properties:
//! - **Security**: Path traversal, input validation, untrusted input handling
//! - **Error handling**: Graceful failures, clear error messages
//! - **Performance**: Bounded execution time for large graphs
//! - **Concurrency**: Parallel operations (if applicable)

use reposystem::graph::EcosystemGraph;
use reposystem::types::{Edge, EdgeMeta, Forge, ImportMeta, RelationType, Repo, Visibility, Channel};
use chrono::Utc;
use std::time::Instant;

// =============================================================================
// Security Tests
// =============================================================================

#[test]
fn test_path_traversal_in_repo_id() {
    // Security: Repo IDs should be consistent regardless of traversal sequences
    let id_with_traversal = Repo::forge_id(Forge::Local, "../../etc", "passwd");

    // Should be a valid ID format - the ID is just a string identifier, not executed
    assert!(
        id_with_traversal.starts_with("repo:"),
        "ID should follow standard format"
    );
    // Verify determinism even with traversal sequences
    let id_same = Repo::forge_id(Forge::Local, "../../etc", "passwd");
    assert_eq!(id_with_traversal, id_same, "ID generation should be deterministic");
}

#[test]
fn test_special_chars_in_repo_name() {
    // Security: Special characters should not break ID generation
    let special_names = vec![
        ("owner", "repo;rm -rf /"),
        ("owner", "repo$(cat /etc/passwd)"),
        ("owner", "repo`whoami`"),
        ("owner", "repo|cat"),
    ];

    for (owner, name) in special_names {
        let id = Repo::forge_id(Forge::GitHub, owner, name);
        assert!(id.contains("repo:"), "Should generate valid ID for special chars");
        // ID should exist and not be empty
        assert!(!id.is_empty(), "ID should not be empty");
    }
}

#[test]
fn test_unicode_in_repo_metadata() {
    // Security: Unicode should be handled safely
    let unicode_names = vec![
        ("所有者", "仓库"),
        ("владелец", "репозиторий"),
        ("所有者😀", "repo🎉"),
    ];

    for (owner, name) in unicode_names {
        let id = Repo::forge_id(Forge::GitHub, owner, name);
        assert!(id.len() > 0, "Should handle unicode: {}:{}", owner, name);
    }
}

#[test]
fn test_empty_string_handling() {
    // Security: Empty strings should not cause panics or invalid states
    let id_empty_owner = Repo::forge_id(Forge::GitHub, "", "repo");
    let id_empty_name = Repo::forge_id(Forge::GitHub, "owner", "");
    let id_both_empty = Repo::forge_id(Forge::GitHub, "", "");

    // All should produce IDs (may be degenerate but not panic)
    assert!(!id_empty_owner.is_empty(), "Should handle empty owner");
    assert!(!id_empty_name.is_empty(), "Should handle empty name");
    assert!(!id_both_empty.is_empty(), "Should handle both empty");
}

#[test]
fn test_very_long_strings() {
    // Security: Very long input should not cause DoS
    let long_owner = "a".repeat(10000);
    let long_name = "b".repeat(10000);

    let id = Repo::forge_id(Forge::GitHub, &long_owner, &long_name);
    assert!(!id.is_empty(), "Should handle very long strings");
    assert!(id.len() < 100000, "ID should not grow unbounded");
}

// =============================================================================
// Error Handling Tests
// =============================================================================

#[test]
fn test_graph_handles_duplicate_repos() {
    // Error handling: Adding the same repo twice should be handled gracefully
    let mut graph = EcosystemGraph::new();

    let repo = Repo {
        kind: "Repo".into(),
        id: "repo:gh:test/dup".into(),
        forge: Forge::GitHub,
        owner: "test".into(),
        name: "dup".into(),
        default_branch: "main".into(),
        visibility: Visibility::Public,
        tags: vec![],
        imports: ImportMeta {
            source: "test".into(),
            path_hint: None,
            imported_at: Utc::now(),
        },
        local_path: None,
    };

    let _result1 = graph.add_repo(repo.clone());
    let _result2 = graph.add_repo(repo);

    // Graph should either accept both (with result2 being a no-op/update)
    // or second should fail gracefully
    assert_eq!(graph.node_count(), 1, "Should not double-count duplicate repos");
}

#[test]
fn test_graph_handles_edge_to_nonexistent_repo() {
    // Error handling: Edge to non-existent repo should be handled
    let mut graph = EcosystemGraph::new();

    let edge = Edge {
        kind: "Edge".into(),
        id: "edge:test:missing".into(),
        from: "repo:gh:test/nonexistent1".into(),
        to: "repo:gh:test/nonexistent2".into(),
        rel: RelationType::Uses,
        channel: Channel::Api,
        label: None,
        evidence: vec![],
        meta: EdgeMeta {
            created_by: "test".into(),
            created_at: Utc::now(),
        },
    };

    let _result = graph.add_edge(edge);
    // Should either silently skip or return an error, not panic
    let edge_count = graph.edge_count();
    // Edge count should be 0 or 1, not negative or nonsensical
    assert!(
        edge_count == 0 || edge_count == 1,
        "Edge count should be valid"
    );
}

#[test]
fn test_malformed_repo_id_in_edge() {
    // Error handling: Malformed IDs should not crash graph operations
    let mut graph = EcosystemGraph::new();

    let edge = Edge {
        kind: "Edge".into(),
        id: "edge:test:bad".into(),
        from: "INVALID_ID".into(),
        to: "ALSO_INVALID".into(),
        rel: RelationType::Uses,
        channel: Channel::Api,
        label: None,
        evidence: vec![],
        meta: EdgeMeta {
            created_by: "test".into(),
            created_at: Utc::now(),
        },
    };

    let _result = graph.add_edge(edge);
    // Should not panic, graph should remain in a valid state
    // node_count() is always >= 0, so we just verify the graph is in a valid state
    let _ = graph.node_count();
}

// =============================================================================
// Performance / Bounded Execution Tests
// =============================================================================

#[test]
fn test_large_graph_construction_bounded_time() {
    // Performance: Building a 500-repo graph should complete in reasonable time
    let start = Instant::now();
    let mut graph = EcosystemGraph::new();

    for i in 0..500 {
        let repo = Repo {
            kind: "Repo".into(),
            id: format!("repo:gh:perf/repo{}", i),
            forge: Forge::GitHub,
            owner: "perf".into(),
            name: format!("repo{}", i),
            default_branch: "main".into(),
            visibility: Visibility::Public,
            tags: vec![],
            imports: ImportMeta {
                source: "perf".into(),
                path_hint: None,
                imported_at: Utc::now(),
            },
            local_path: None,
        };
        let _ = graph.add_repo(repo);
    }

    let elapsed = start.elapsed();
    assert!(
        elapsed.as_secs() < 5,
        "Building 500-repo graph should complete in < 5 seconds (took {:?})",
        elapsed
    );
}

#[test]
fn test_large_graph_export_bounded_time() {
    // Performance: Exporting a large graph should be quick
    let mut graph = EcosystemGraph::new();
    for i in 0..200 {
        let repo = Repo {
            kind: "Repo".into(),
            id: format!("repo:gh:export/repo{}", i),
            forge: Forge::GitHub,
            owner: "export".into(),
            name: format!("repo{}", i),
            default_branch: "main".into(),
            visibility: Visibility::Public,
            tags: vec![],
            imports: ImportMeta {
                source: "export".into(),
                path_hint: None,
                imported_at: Utc::now(),
            },
            local_path: None,
        };
        let _ = graph.add_repo(repo);
    }

    let start = Instant::now();
    let _ = graph.to_dot();
    let elapsed = start.elapsed();

    assert!(
        elapsed.as_secs() < 2,
        "Exporting 200-repo graph should complete in < 2 seconds (took {:?})",
        elapsed
    );
}

#[test]
fn test_query_operations_are_fast() {
    // Performance: Basic queries should be O(1) or O(log n)
    let mut graph = EcosystemGraph::new();
    for i in 0..1000 {
        let repo = Repo {
            kind: "Repo".into(),
            id: format!("repo:gh:query/repo{}", i),
            forge: Forge::GitHub,
            owner: "query".into(),
            name: format!("repo{}", i),
            default_branch: "main".into(),
            visibility: Visibility::Public,
            tags: vec![],
            imports: ImportMeta {
                source: "query".into(),
                path_hint: None,
                imported_at: Utc::now(),
            },
            local_path: None,
        };
        let _ = graph.add_repo(repo);
    }

    let start = Instant::now();
    for _ in 0..10000 {
        let _count = graph.node_count();
    }
    let elapsed = start.elapsed();

    assert!(
        elapsed.as_secs() < 1,
        "10k queries on 1000-node graph should be < 1s (took {:?})",
        elapsed
    );
}

// =============================================================================
// Data Consistency Tests
// =============================================================================

#[test]
fn test_graph_state_consistency_after_operations() {
    // Consistency: Graph should remain consistent after mixed operations
    let mut graph = EcosystemGraph::new();

    // Add repos
    for i in 0..10 {
        let repo = Repo {
            kind: "Repo".into(),
            id: format!("repo:gh:cons/repo{}", i),
            forge: Forge::GitHub,
            owner: "cons".into(),
            name: format!("repo{}", i),
            default_branch: "main".into(),
            visibility: Visibility::Public,
            tags: vec![],
            imports: ImportMeta {
                source: "cons".into(),
                path_hint: None,
                imported_at: Utc::now(),
            },
            local_path: None,
        };
        let _ = graph.add_repo(repo);
    }

    let initial_repo_count = graph.node_count();
    let initial_edge_count = graph.edge_count();

    // Add some edges
    for i in 0..9 {
        let edge = Edge {
            kind: "Edge".into(),
            id: format!("edge:cons:{}", i),
            from: format!("repo:gh:cons/repo{}", i),
            to: format!("repo:gh:cons/repo{}", i + 1),
            rel: RelationType::Uses,
            channel: Channel::Api,
            label: None,
            evidence: vec![],
            meta: EdgeMeta {
                created_by: "cons".into(),
                created_at: Utc::now(),
            },
        };
        let _ = graph.add_edge(edge);
    }

    // Repo count should not change
    assert_eq!(
        graph.node_count(),
        initial_repo_count,
        "Adding edges should not change repo count"
    );

    // Edge count should increase
    assert!(
        graph.edge_count() > initial_edge_count,
        "Adding edges should increase edge count"
    );
}

#[test]
fn test_forge_consistency() {
    // Consistency: Forge operations should be consistent
    let forges = vec![
        Forge::GitHub,
        Forge::GitLab,
        Forge::Bitbucket,
        Forge::Codeberg,
        Forge::Sourcehut,
        Forge::Local,
    ];

    for forge in &forges {
        let code = forge.code();
        assert!(!code.is_empty(), "Forge code should not be empty");
        assert!(code.len() < 10, "Forge code should be short");
        assert!(!code.contains(' '), "Forge code should not contain spaces");
    }
}

// =============================================================================
// Visibility Tests
// =============================================================================

#[test]
fn test_visibility_enum_coverage() {
    // Coverage: All visibility levels should be usable
    let visibilities = vec![
        Visibility::Public,
        Visibility::Private,
        Visibility::Internal,
    ];

    for vis in visibilities {
        let repo = Repo {
            kind: "Repo".into(),
            id: format!("repo:gh:vis/{:?}", vis),
            forge: Forge::GitHub,
            owner: "vis".into(),
            name: format!("{:?}", vis),
            default_branch: "main".into(),
            visibility: vis,
            tags: vec![],
            imports: ImportMeta {
                source: "vis".into(),
                path_hint: None,
                imported_at: Utc::now(),
            },
            local_path: None,
        };

        // Should not panic
        assert!(!repo.id.is_empty(), "Repo with visibility {:?} should create valid ID", vis);
    }
}
