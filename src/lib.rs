// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//
//! Reposystem library - Railway yard for your repository ecosystem
//!
//! This crate provides the core functionality for managing multi-repo
//! ecosystems with visual wiring, aspect tagging, and scenario comparison.

#![warn(missing_docs)]
#![warn(clippy::all)]
#![warn(clippy::pedantic)]

pub mod commands;
pub mod config;
pub mod graph;
pub mod scanner;
pub mod tui;

/// Core data types for the ecosystem graph
pub mod types {
    use serde::{Deserialize, Serialize};

    /// Repository node in the ecosystem
    #[derive(Debug, Clone, Serialize, Deserialize)]
    pub struct Repo {
        /// Unique identifier
        pub id: String,
        /// File system path
        pub path: std::path::PathBuf,
        /// Display name
        pub name: String,
        /// Repository kind
        pub kind: RepoKind,
        /// Available channels
        pub channels: std::collections::HashMap<String, String>,
        /// Additional metadata
        pub metadata: std::collections::HashMap<String, String>,
    }

    /// Repository classification
    #[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
    #[serde(rename_all = "lowercase")]
    pub enum RepoKind {
        /// A library/package
        Library,
        /// An application
        Application,
        /// A service
        Service,
        /// A tool/utility
        Tool,
        /// Documentation only
        Documentation,
        /// Data files
        Data,
        /// Configuration
        Config,
    }

    /// Edge between repositories
    #[derive(Debug, Clone, Serialize, Deserialize)]
    pub struct Edge {
        /// Source repository ID
        pub from: String,
        /// Target repository ID
        pub to: String,
        /// Edge type
        pub kind: EdgeKind,
        /// Channel name
        pub channel: String,
        /// Edge weight (0.0 to 1.0)
        pub weight: f64,
    }

    /// Dependency type
    #[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
    #[serde(rename_all = "lowercase")]
    pub enum EdgeKind {
        /// Build-time artifact dependency
        Artifact,
        /// Runtime dependency
        Runtime,
        /// Development dependency
        DevDep,
        /// Peer dependency
        Peer,
        /// Optional dependency
        Optional,
        /// Build tool dependency
        Build,
        /// Test dependency
        Test,
    }

    /// Aspect tag for visualization
    #[derive(Debug, Clone, Serialize, Deserialize)]
    pub struct AspectTag {
        /// Unique identifier
        pub id: String,
        /// Display name
        pub name: String,
        /// Color for visualization
        pub color: String,
        /// Description
        pub description: Option<String>,
    }

    /// Scenario for comparison
    #[derive(Debug, Clone, Serialize, Deserialize)]
    pub struct Scenario {
        /// Unique identifier
        pub id: String,
        /// Display name
        pub name: String,
        /// Base scenario ID
        pub base: Option<String>,
        /// Changes from base
        pub changes: Vec<Change>,
    }

    /// A change in a scenario
    #[derive(Debug, Clone, Serialize, Deserialize)]
    pub struct Change {
        /// Repository ID
        pub repo: String,
        /// Field to change
        pub field: String,
        /// New value
        pub value: serde_json::Value,
    }
}

/// Prelude for common imports
pub mod prelude {
    pub use crate::types::*;
    pub use anyhow::{Context, Result};
}
