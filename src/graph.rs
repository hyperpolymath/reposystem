// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//! Graph data structures and algorithms

use petgraph::graph::DiGraph;
use crate::types::{Repo, Edge};

pub type EcosystemGraph = DiGraph<Repo, Edge>;

pub fn new() -> EcosystemGraph {
    DiGraph::new()
}
