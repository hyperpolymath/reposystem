// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//! Criterion benchmarks for reposystem core operations
//!
//! Measures:
//! - Graph traversal performance (scan throughput)
//! - Config parsing throughput
//! - Graph export (DOT) performance
//! - Repository ID generation

use criterion::{black_box, criterion_group, criterion_main, Criterion};
use reposystem::graph::EcosystemGraph;
use reposystem::types::{Edge, EdgeMeta, Forge, ImportMeta, RelationType, Repo, Visibility, Channel};
use chrono::Utc;

// =============================================================================
// Helper Functions
// =============================================================================

/// Create a synthetic repo
fn make_test_repo(id: usize) -> Repo {
    Repo {
        kind: "Repo".into(),
        id: format!("repo:gh:bench/repo{}", id),
        forge: Forge::GitHub,
        owner: "bench".into(),
        name: format!("repo{}", id),
        default_branch: "main".into(),
        visibility: Visibility::Public,
        tags: vec!["benchmark".into()],
        imports: ImportMeta {
            source: "bench".into(),
            path_hint: None,
            imported_at: Utc::now(),
        },
        local_path: None,
    }
}

/// Create a synthetic edge
fn make_test_edge(from_id: usize, to_id: usize, edge_id: usize) -> Edge {
    Edge {
        kind: "Edge".into(),
        id: format!("edge:bench:{}", edge_id),
        from: format!("repo:gh:bench/repo{}", from_id),
        to: format!("repo:gh:bench/repo{}", to_id),
        rel: RelationType::Uses,
        channel: Channel::Api,
        label: None,
        evidence: vec![],
        meta: EdgeMeta {
            created_by: "bench".into(),
            created_at: Utc::now(),
        },
    }
}

/// Build a graph with N repos and edges
fn build_graph(num_repos: usize) -> EcosystemGraph {
    let mut graph = EcosystemGraph::new();

    // Add repos
    for i in 0..num_repos {
        let repo = make_test_repo(i);
        let _ = graph.add_repo(repo);
    }

    // Add some edges (create a chain: 0→1→2→...→N-1)
    for i in 0..num_repos.saturating_sub(1) {
        let edge = make_test_edge(i, i + 1, i);
        let _ = graph.add_edge(edge);
    }

    graph
}

// =============================================================================
// Repo ID Generation Benchmark
// =============================================================================

fn bench_repo_id_generation(c: &mut Criterion) {
    c.bench_function("repo_id_github_small", |b| {
        b.iter(|| {
            Repo::forge_id(
                black_box(Forge::GitHub),
                black_box("owner"),
                black_box("repo"),
            )
        })
    });

    c.bench_function("repo_id_gitlab_medium", |b| {
        b.iter(|| {
            Repo::forge_id(
                black_box(Forge::GitLab),
                black_box("very-long-owner-name-for-testing"),
                black_box("very-long-repo-name-for-testing"),
            )
        })
    });

    c.bench_function("repo_id_local_filesystem", |b| {
        b.iter(|| {
            Repo::forge_id(
                black_box(Forge::Local),
                black_box("/home/user/projects"),
                black_box("myrepo"),
            )
        })
    });
}

// =============================================================================
// Graph Building Benchmark
// =============================================================================

fn bench_graph_construction(c: &mut Criterion) {
    c.bench_function("graph_add_10_repos", |b| {
        b.iter(|| {
            let mut graph = EcosystemGraph::new();
            for i in 0..10 {
                let repo = make_test_repo(black_box(i));
                let _ = graph.add_repo(repo);
            }
            black_box(graph)
        })
    });

    c.bench_function("graph_add_50_repos", |b| {
        b.iter(|| {
            let mut graph = EcosystemGraph::new();
            for i in 0..50 {
                let repo = make_test_repo(black_box(i));
                let _ = graph.add_repo(repo);
            }
            black_box(graph)
        })
    });

    c.bench_function("graph_add_100_repos", |b| {
        b.iter(|| {
            let mut graph = EcosystemGraph::new();
            for i in 0..100 {
                let repo = make_test_repo(black_box(i));
                let _ = graph.add_repo(repo);
            }
            black_box(graph)
        })
    });
}

// =============================================================================
// Edge Addition Benchmark
// =============================================================================

fn bench_graph_edges(c: &mut Criterion) {
    c.bench_function("graph_add_edges_10_repos", |b| {
        b.iter_batched(
            || {
                let mut graph = EcosystemGraph::new();
                for i in 0..10 {
                    let repo = make_test_repo(i);
                    let _ = graph.add_repo(repo);
                }
                graph
            },
            |mut graph| {
                for i in 0..9 {
                    let edge = make_test_edge(i, i + 1, i);
                    let _ = graph.add_edge(edge);
                }
                black_box(graph)
            },
            criterion::BatchSize::SmallInput,
        )
    });

    c.bench_function("graph_add_edges_50_repos", |b| {
        b.iter_batched(
            || {
                let mut graph = EcosystemGraph::new();
                for i in 0..50 {
                    let repo = make_test_repo(i);
                    let _ = graph.add_repo(repo);
                }
                graph
            },
            |mut graph| {
                for i in 0..49 {
                    let edge = make_test_edge(i, i + 1, i);
                    let _ = graph.add_edge(edge);
                }
                black_box(graph)
            },
            criterion::BatchSize::SmallInput,
        )
    });
}

// =============================================================================
// Graph Export (DOT) Benchmark
// =============================================================================

fn bench_graph_export(c: &mut Criterion) {
    c.bench_function("export_dot_10_repos", |b| {
        let graph = build_graph(10);
        b.iter(|| {
            let _dot = black_box(&graph).to_dot();
        })
    });

    c.bench_function("export_dot_50_repos", |b| {
        let graph = build_graph(50);
        b.iter(|| {
            let _dot = black_box(&graph).to_dot();
        })
    });

    c.bench_function("export_dot_100_repos", |b| {
        let graph = build_graph(100);
        b.iter(|| {
            let _dot = black_box(&graph).to_dot();
        })
    });

    c.bench_function("export_dot_500_repos", |b| {
        let graph = build_graph(500);
        b.iter(|| {
            let _dot = black_box(&graph).to_dot();
        })
    });
}

// =============================================================================
// Graph Query Benchmark
// =============================================================================

fn bench_graph_queries(c: &mut Criterion) {
    c.bench_function("query_repo_count_100_repos", |b| {
        let graph = build_graph(100);
        b.iter(|| {
            let _count = black_box(&graph).node_count();
        })
    });

    c.bench_function("query_edge_count_100_repos", |b| {
        let graph = build_graph(100);
        b.iter(|| {
            let _count = black_box(&graph).edge_count();
        })
    });

    c.bench_function("query_repo_count_500_repos", |b| {
        let graph = build_graph(500);
        b.iter(|| {
            let _count = black_box(&graph).node_count();
        })
    });
}

// =============================================================================
// Forge Code Lookup
// =============================================================================

fn bench_forge_operations(c: &mut Criterion) {
    c.bench_function("forge_code_lookup", |b| {
        b.iter(|| {
            let forges = vec![
                Forge::GitHub,
                Forge::GitLab,
                Forge::Bitbucket,
                Forge::Codeberg,
                Forge::Sourcehut,
                Forge::Local,
            ];
            for forge in black_box(forges) {
                let _ = forge.code();
            }
        })
    });
}

// =============================================================================
// Criterion Group Setup
// =============================================================================

criterion_group!(
    benches,
    bench_repo_id_generation,
    bench_graph_construction,
    bench_graph_edges,
    bench_graph_export,
    bench_graph_queries,
    bench_forge_operations
);

criterion_main!(benches);
