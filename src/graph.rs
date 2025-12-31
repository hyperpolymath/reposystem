// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//! Graph data structures and algorithms

use petgraph::graph::DiGraph;
use serde::{Deserialize, Serialize};

/// Repository node placeholder
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Repo {
    /// Unique identifier
    pub id: String,
    /// Display name
    pub name: String,
    /// File system path
    pub path: std::path::PathBuf,
}

/// Edge between repositories
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Edge {
    /// Edge weight
    pub weight: f64,
}

/// The ecosystem graph type
pub type EcosystemGraph = DiGraph<Repo, Edge>;

/// Create a new empty graph
pub fn new() -> EcosystemGraph {
    DiGraph::new()
}
