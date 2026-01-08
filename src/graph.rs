// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//! Graph data structures and algorithms for the ecosystem graph

use crate::types::{AspectStore, Edge, GraphStore, Group, Repo};
use anyhow::{Context, Result};
use petgraph::graph::{DiGraph, NodeIndex};
use std::collections::HashMap;
use std::fs;
use std::path::Path;

/// The ecosystem graph with petgraph backing for algorithms
pub struct EcosystemGraph {
    /// The underlying directed graph
    graph: DiGraph<String, String>,
    /// Map from repo ID to node index
    node_indices: HashMap<String, NodeIndex>,
    /// The graph store (repos, components, groups, edges)
    pub store: GraphStore,
    /// Aspect definitions and annotations
    pub aspects: AspectStore,
}

impl Default for EcosystemGraph {
    fn default() -> Self {
        Self::new()
    }
}

impl EcosystemGraph {
    /// Create a new empty ecosystem graph
    #[must_use]
    pub fn new() -> Self {
        Self {
            graph: DiGraph::new(),
            node_indices: HashMap::new(),
            store: GraphStore::default(),
            aspects: AspectStore::default(),
        }
    }

    /// Load graph from a directory containing graph.json and aspects.json
    pub fn load(dir: &Path) -> Result<Self> {
        let graph_path = dir.join("graph.json");
        let aspects_path = dir.join("aspects.json");

        let store: GraphStore = if graph_path.exists() {
            let content = fs::read_to_string(&graph_path)
                .with_context(|| format!("Failed to read {}", graph_path.display()))?;
            serde_json::from_str(&content)
                .with_context(|| format!("Failed to parse {}", graph_path.display()))?
        } else {
            GraphStore::default()
        };

        let aspects: AspectStore = if aspects_path.exists() {
            let content = fs::read_to_string(&aspects_path)
                .with_context(|| format!("Failed to read {}", aspects_path.display()))?;
            serde_json::from_str(&content)
                .with_context(|| format!("Failed to parse {}", aspects_path.display()))?
        } else {
            AspectStore::default()
        };

        let mut ecosystem = Self {
            graph: DiGraph::new(),
            node_indices: HashMap::new(),
            store,
            aspects,
        };

        // Build petgraph from store
        ecosystem.rebuild_graph();

        Ok(ecosystem)
    }

    /// Save graph to a directory
    pub fn save(&self, dir: &Path) -> Result<()> {
        fs::create_dir_all(dir)
            .with_context(|| format!("Failed to create directory {}", dir.display()))?;

        let graph_path = dir.join("graph.json");
        let aspects_path = dir.join("aspects.json");

        let graph_json = serde_json::to_string_pretty(&self.store)
            .context("Failed to serialize graph")?;
        fs::write(&graph_path, graph_json)
            .with_context(|| format!("Failed to write {}", graph_path.display()))?;

        let aspects_json = serde_json::to_string_pretty(&self.aspects)
            .context("Failed to serialize aspects")?;
        fs::write(&aspects_path, aspects_json)
            .with_context(|| format!("Failed to write {}", aspects_path.display()))?;

        Ok(())
    }

    /// Rebuild the petgraph from the store
    fn rebuild_graph(&mut self) {
        self.graph.clear();
        self.node_indices.clear();

        // Add all repos as nodes
        for repo in &self.store.repos {
            let idx = self.graph.add_node(repo.id.clone());
            self.node_indices.insert(repo.id.clone(), idx);
        }

        // Add all edges
        for edge in &self.store.edges {
            if let (Some(&from_idx), Some(&to_idx)) = (
                self.node_indices.get(&edge.from),
                self.node_indices.get(&edge.to),
            ) {
                self.graph.add_edge(from_idx, to_idx, edge.id.clone());
            }
        }
    }

    /// Add a repository to the graph
    pub fn add_repo(&mut self, repo: Repo) {
        if self.node_indices.contains_key(&repo.id) {
            // Update existing repo
            if let Some(existing) = self.store.repos.iter_mut().find(|r| r.id == repo.id) {
                *existing = repo;
            }
        } else {
            // Add new repo
            let idx = self.graph.add_node(repo.id.clone());
            self.node_indices.insert(repo.id.clone(), idx);
            self.store.repos.push(repo);
        }
    }

    /// Add an edge to the graph
    pub fn add_edge(&mut self, edge: Edge) -> Result<()> {
        // Verify both endpoints exist
        let from_idx = self
            .node_indices
            .get(&edge.from)
            .ok_or_else(|| anyhow::anyhow!("Source node not found: {}", edge.from))?;
        let to_idx = self
            .node_indices
            .get(&edge.to)
            .ok_or_else(|| anyhow::anyhow!("Target node not found: {}", edge.to))?;

        // Check if edge already exists
        if self.store.edges.iter().any(|e| e.id == edge.id) {
            return Ok(()); // Idempotent
        }

        self.graph.add_edge(*from_idx, *to_idx, edge.id.clone());
        self.store.edges.push(edge);

        Ok(())
    }

    /// Add a group
    pub fn add_group(&mut self, group: Group) {
        if let Some(existing) = self.store.groups.iter_mut().find(|g| g.id == group.id) {
            *existing = group;
        } else {
            self.store.groups.push(group);
        }
    }

    /// Get a repo by ID
    #[must_use]
    pub fn get_repo(&self, id: &str) -> Option<&Repo> {
        self.store.repos.iter().find(|r| r.id == id)
    }

    /// Get all repos
    #[must_use]
    pub fn repos(&self) -> &[Repo] {
        &self.store.repos
    }

    /// Get all edges
    #[must_use]
    pub fn edges(&self) -> &[Edge] {
        &self.store.edges
    }

    /// Get all groups
    #[must_use]
    pub fn groups(&self) -> &[Group] {
        &self.store.groups
    }

    /// Get edges from a specific node
    #[must_use]
    pub fn edges_from(&self, repo_id: &str) -> Vec<&Edge> {
        self.store
            .edges
            .iter()
            .filter(|e| e.from == repo_id)
            .collect()
    }

    /// Get edges to a specific node
    #[must_use]
    pub fn edges_to(&self, repo_id: &str) -> Vec<&Edge> {
        self.store
            .edges
            .iter()
            .filter(|e| e.to == repo_id)
            .collect()
    }

    /// Get node count
    #[must_use]
    pub fn node_count(&self) -> usize {
        self.store.repos.len()
    }

    /// Get edge count
    #[must_use]
    pub fn edge_count(&self) -> usize {
        self.store.edges.len()
    }

    /// Check if the graph is empty
    #[must_use]
    pub fn is_empty(&self) -> bool {
        self.store.repos.is_empty()
    }

    /// Find repos in a group
    #[must_use]
    pub fn repos_in_group(&self, group_id: &str) -> Vec<&Repo> {
        let group = self.store.groups.iter().find(|g| g.id == group_id);
        match group {
            Some(g) => self
                .store
                .repos
                .iter()
                .filter(|r| g.members.contains(&r.id))
                .collect(),
            None => vec![],
        }
    }

    /// Export to DOT format for Graphviz
    #[must_use]
    pub fn to_dot(&self) -> String {
        let mut dot = String::from("digraph ecosystem {\n");
        dot.push_str("  rankdir=LR;\n");
        dot.push_str("  node [shape=box, style=rounded];\n\n");

        // Add nodes
        for repo in &self.store.repos {
            let label = format!("{}\\n{}", repo.name, repo.forge.code());
            dot.push_str(&format!("  \"{}\" [label=\"{}\"];\n", repo.id, label));
        }

        dot.push('\n');

        // Add edges
        for edge in &self.store.edges {
            let label = edge.label.as_deref().unwrap_or("");
            dot.push_str(&format!(
                "  \"{}\" -> \"{}\" [label=\"{}\"];\n",
                edge.from, edge.to, label
            ));
        }

        // Add subgraphs for groups
        for group in &self.store.groups {
            dot.push_str(&format!("\n  subgraph cluster_{} {{\n", group.id.replace(':', "_")));
            dot.push_str(&format!("    label=\"{}\";\n", group.name));
            dot.push_str("    style=dashed;\n");
            for member in &group.members {
                dot.push_str(&format!("    \"{}\";\n", member));
            }
            dot.push_str("  }\n");
        }

        dot.push_str("}\n");
        dot
    }

    /// Export to JSON
    pub fn to_json(&self) -> Result<String> {
        serde_json::to_string_pretty(&self.store).context("Failed to serialize graph to JSON")
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::types::{
        Channel, EdgeMeta, Forge, ImportMeta, RelationType, Visibility,
    };
    use chrono::Utc;

    fn make_test_repo(name: &str) -> Repo {
        Repo {
            kind: "Repo".into(),
            id: format!("repo:gh:test/{}", name),
            forge: Forge::GitHub,
            owner: "test".into(),
            name: name.into(),
            default_branch: "main".into(),
            visibility: Visibility::Public,
            tags: vec![],
            imports: ImportMeta {
                source: "test".into(),
                path_hint: None,
                imported_at: Utc::now(),
            },
            local_path: None,
        }
    }

    #[test]
    fn test_add_repo() {
        let mut graph = EcosystemGraph::new();
        let repo = make_test_repo("example");

        graph.add_repo(repo.clone());

        assert_eq!(graph.node_count(), 1);
        assert!(graph.get_repo(&repo.id).is_some());
    }

    #[test]
    fn test_add_edge() {
        let mut graph = EcosystemGraph::new();
        let repo_a = make_test_repo("a");
        let repo_b = make_test_repo("b");

        graph.add_repo(repo_a.clone());
        graph.add_repo(repo_b.clone());

        let edge = Edge {
            kind: "Edge".into(),
            id: "edge:test123".into(),
            from: repo_a.id.clone(),
            to: repo_b.id.clone(),
            rel: RelationType::Uses,
            channel: Channel::Artifact,
            label: Some("test dep".into()),
            evidence: vec![],
            meta: EdgeMeta {
                created_by: "test".into(),
                created_at: Utc::now(),
            },
        };

        graph.add_edge(edge).unwrap();

        assert_eq!(graph.edge_count(), 1);
        assert_eq!(graph.edges_from(&repo_a.id).len(), 1);
        assert_eq!(graph.edges_to(&repo_b.id).len(), 1);
    }

    #[test]
    fn test_to_dot() {
        let mut graph = EcosystemGraph::new();
        graph.add_repo(make_test_repo("example"));

        let dot = graph.to_dot();

        assert!(dot.contains("digraph ecosystem"));
        assert!(dot.contains("example"));
    }
}
