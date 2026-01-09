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
#![allow(clippy::module_name_repetitions)]

pub mod commands;
pub mod config;
pub mod graph;
pub mod scanner;
pub mod tui;

/// Core data types matching DATA-MODEL.adoc specification
pub mod types {
    use chrono::{DateTime, Utc};
    use serde::{Deserialize, Serialize};
    use sha2::{Digest, Sha256};
    use std::collections::HashMap;
    use std::path::PathBuf;

    // =========================================================================
    // Forge Definitions
    // =========================================================================

    /// Supported git forges
    #[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
    #[serde(rename_all = "lowercase")]
    pub enum Forge {
        /// GitHub (gh)
        #[serde(rename = "gh")]
        GitHub,
        /// GitLab (gl)
        #[serde(rename = "gl")]
        GitLab,
        /// Bitbucket (bb)
        #[serde(rename = "bb")]
        Bitbucket,
        /// Codeberg (cb)
        #[serde(rename = "cb")]
        Codeberg,
        /// Sourcehut (sr)
        #[serde(rename = "sr")]
        Sourcehut,
        /// Local filesystem only
        #[serde(rename = "local")]
        Local,
    }

    impl Forge {
        /// Get the short code for this forge
        #[must_use]
        pub fn code(&self) -> &'static str {
            match self {
                Self::GitHub => "gh",
                Self::GitLab => "gl",
                Self::Bitbucket => "bb",
                Self::Codeberg => "cb",
                Self::Sourcehut => "sr",
                Self::Local => "local",
            }
        }

        /// Parse a forge from a remote URL
        #[must_use]
        pub fn from_url(url: &str) -> Option<Self> {
            if url.contains("github.com") {
                Some(Self::GitHub)
            } else if url.contains("gitlab.com") {
                Some(Self::GitLab)
            } else if url.contains("bitbucket.org") {
                Some(Self::Bitbucket)
            } else if url.contains("codeberg.org") {
                Some(Self::Codeberg)
            } else if url.contains("sr.ht") || url.contains("git.sr.ht") {
                Some(Self::Sourcehut)
            } else {
                None
            }
        }
    }

    // =========================================================================
    // Repo (Node Subtype)
    // =========================================================================

    /// Import metadata for a repository
    #[derive(Debug, Clone, Serialize, Deserialize)]
    pub struct ImportMeta {
        /// How this repo was imported
        pub source: String,
        /// Path hint for local repos
        pub path_hint: Option<PathBuf>,
        /// When the import occurred
        pub imported_at: DateTime<Utc>,
    }

    /// Repository node in the ecosystem graph
    #[derive(Debug, Clone, Serialize, Deserialize)]
    pub struct Repo {
        /// Always "Repo"
        pub kind: String,
        /// Unique identifier: repo:<forge>:<owner>/<name> or repo:local:<hash>
        pub id: String,
        /// Git forge
        pub forge: Forge,
        /// Repository owner/namespace
        pub owner: String,
        /// Repository name
        pub name: String,
        /// Default branch
        pub default_branch: String,
        /// Visibility
        pub visibility: Visibility,
        /// Tags for classification
        #[serde(default)]
        pub tags: Vec<String>,
        /// Import metadata
        pub imports: ImportMeta,
        /// Local filesystem path (runtime, not persisted)
        #[serde(skip)]
        pub local_path: Option<PathBuf>,
    }

    impl Repo {
        /// Generate a deterministic ID for a forge-hosted repo
        #[must_use]
        pub fn forge_id(forge: Forge, owner: &str, name: &str) -> String {
            format!("repo:{}:{}/{}", forge.code(), owner, name)
        }

        /// Generate a deterministic ID for a local-only repo
        #[must_use]
        pub fn local_id(path: &std::path::Path) -> String {
            let canonical = path
                .canonicalize()
                .unwrap_or_else(|_| path.to_path_buf());
            let mut hasher = Sha256::new();
            hasher.update(canonical.to_string_lossy().as_bytes());
            let hash = hex::encode(hasher.finalize());
            format!("repo:local:{}", &hash[..12])
        }
    }

    /// Repository visibility
    #[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
    #[serde(rename_all = "lowercase")]
    pub enum Visibility {
        /// Public repository
        Public,
        /// Private repository
        Private,
        /// Internal (org-visible)
        Internal,
    }

    // =========================================================================
    // Component (Node Subtype, Optional in v1)
    // =========================================================================

    /// A logical component provided by or consumed by a repo
    #[derive(Debug, Clone, Serialize, Deserialize)]
    pub struct Component {
        /// Always "Component"
        pub kind: String,
        /// Unique identifier: comp:<repo_id>#<name>
        pub id: String,
        /// Parent repository ID
        pub repo_id: String,
        /// Component name
        pub name: String,
        /// Component type (e.g., "router", "runtime")
        #[serde(rename = "type")]
        pub component_type: String,
        /// Version
        pub version: Option<String>,
        /// Implemented interfaces
        #[serde(default)]
        pub interfaces: Vec<String>,
    }

    // =========================================================================
    // Group (Cluster)
    // =========================================================================

    /// A group/cluster of repositories
    #[derive(Debug, Clone, Serialize, Deserialize)]
    pub struct Group {
        /// Always "Group"
        pub kind: String,
        /// Unique identifier: group:<name>
        pub id: String,
        /// Display name
        pub name: String,
        /// Description
        pub description: Option<String>,
        /// Member repository IDs (repos can belong to multiple groups)
        #[serde(default)]
        pub members: Vec<String>,
    }

    // =========================================================================
    // Edge (Relationship)
    // =========================================================================

    /// Evidence for an edge or annotation
    #[derive(Debug, Clone, Serialize, Deserialize)]
    pub struct Evidence {
        /// Evidence type: file, ci, manual, inferred
        #[serde(rename = "type")]
        pub evidence_type: String,
        /// Reference (file path, rule id, URL)
        #[serde(rename = "ref")]
        pub reference: String,
        /// Excerpt or description
        pub excerpt: Option<String>,
        /// Confidence score (0.0 to 1.0)
        pub confidence: f64,
    }

    /// Edge metadata
    #[derive(Debug, Clone, Serialize, Deserialize)]
    pub struct EdgeMeta {
        /// Who created this edge (manual, auto-detect, import)
        pub created_by: String,
        /// When the edge was created
        pub created_at: DateTime<Utc>,
    }

    /// Relationship channel types
    #[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
    #[serde(rename_all = "lowercase")]
    pub enum Channel {
        /// REST/GraphQL/gRPC endpoint consumption
        Api,
        /// Build output, binary, package
        Artifact,
        /// Configuration file or environment variable
        Config,
        /// Container, process, service dependency
        Runtime,
        /// Documentation, manual process handoff
        Human,
        /// Detected but unclassified
        Unknown,
    }

    /// Relationship types
    #[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
    #[serde(rename_all = "lowercase")]
    pub enum RelationType {
        /// A depends on B
        Uses,
        /// A implements interface for B
        Provides,
        /// A builds on B
        Extends,
        /// A is a mirror/fork of B
        Mirrors,
        /// A can substitute for B
        Replaces,
    }

    /// Edge between repositories (or components)
    #[derive(Debug, Clone, Serialize, Deserialize)]
    pub struct Edge {
        /// Always "Edge"
        pub kind: String,
        /// Content-hash ID: edge:<hash of (from, to, rel, channel, label)>
        pub id: String,
        /// Source node ID
        pub from: String,
        /// Target node ID
        pub to: String,
        /// Relationship type
        pub rel: RelationType,
        /// Channel type
        pub channel: Channel,
        /// Human-readable label
        pub label: Option<String>,
        /// Evidence for this edge
        #[serde(default)]
        pub evidence: Vec<Evidence>,
        /// Metadata
        pub meta: EdgeMeta,
    }

    impl Edge {
        /// Generate a deterministic ID for an edge
        #[must_use]
        pub fn generate_id(from: &str, to: &str, rel: RelationType, channel: Channel, label: Option<&str>) -> String {
            let mut hasher = Sha256::new();
            hasher.update(from.as_bytes());
            hasher.update(to.as_bytes());
            hasher.update(format!("{rel:?}").as_bytes());
            hasher.update(format!("{channel:?}").as_bytes());
            if let Some(l) = label {
                hasher.update(l.as_bytes());
            }
            let hash = hex::encode(hasher.finalize());
            format!("edge:{}", &hash[..8])
        }
    }

    // =========================================================================
    // Aspect Tagging
    // =========================================================================

    /// Aspect definition
    #[derive(Debug, Clone, Serialize, Deserialize)]
    pub struct Aspect {
        /// Always "Aspect"
        pub kind: String,
        /// Unique identifier: aspect:<name>
        pub id: String,
        /// Display name
        pub name: String,
        /// Description
        pub description: String,
    }

    /// Default aspects from DATA-MODEL.adoc
    impl Aspect {
        /// Get the initial curated aspect set
        #[must_use]
        pub fn defaults() -> Vec<Self> {
            vec![
                Self { kind: "Aspect".into(), id: "aspect:security".into(), name: "Security".into(), description: "Authentication, authorization, vulnerability exposure".into() },
                Self { kind: "Aspect".into(), id: "aspect:reliability".into(), name: "Reliability".into(), description: "Uptime, fault tolerance, recovery".into() },
                Self { kind: "Aspect".into(), id: "aspect:maintainability".into(), name: "Maintainability".into(), description: "Code quality, test coverage, documentation".into() },
                Self { kind: "Aspect".into(), id: "aspect:portability".into(), name: "Portability".into(), description: "Cross-platform, containerization, dependencies".into() },
                Self { kind: "Aspect".into(), id: "aspect:performance".into(), name: "Performance".into(), description: "Speed, resource usage, scalability".into() },
                Self { kind: "Aspect".into(), id: "aspect:observability".into(), name: "Observability".into(), description: "Logging, metrics, tracing".into() },
                Self { kind: "Aspect".into(), id: "aspect:ux".into(), name: "UX".into(), description: "User experience, accessibility".into() },
                Self { kind: "Aspect".into(), id: "aspect:docs".into(), name: "Docs".into(), description: "Documentation quality and coverage".into() },
                Self { kind: "Aspect".into(), id: "aspect:supply-chain".into(), name: "Supply Chain".into(), description: "Dependency provenance, SBOM, signing".into() },
                Self { kind: "Aspect".into(), id: "aspect:automation".into(), name: "Automation".into(), description: "CI/CD, deployment, testing automation".into() },
            ]
        }
    }

    /// Annotation source metadata
    #[derive(Debug, Clone, Serialize, Deserialize)]
    pub struct AnnotationSource {
        /// How created: manual, inferred, imported
        pub mode: String,
        /// Who created it
        pub who: String,
        /// When created
        pub when: DateTime<Utc>,
        /// Rule ID if inferred
        pub rule_id: Option<String>,
    }

    /// Polarity of an annotation
    #[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
    #[serde(rename_all = "lowercase")]
    pub enum Polarity {
        /// This is a weakness/concern
        Risk,
        /// This is a strength
        Strength,
        /// Neutral observation
        Neutral,
    }

    /// Aspect annotation on a node or edge
    #[derive(Debug, Clone, Serialize, Deserialize)]
    pub struct AspectAnnotation {
        /// Always "AspectAnnotation"
        pub kind: String,
        /// Unique identifier
        pub id: String,
        /// Target node or edge ID
        pub target: String,
        /// Aspect ID
        pub aspect_id: String,
        /// Weight (0-3, coarse importance)
        pub weight: u8,
        /// Is this a risk, strength, or neutral?
        pub polarity: Polarity,
        /// Reason for this annotation
        pub reason: String,
        /// Supporting evidence
        #[serde(default)]
        pub evidence: Vec<Evidence>,
        /// Source metadata
        pub source: AnnotationSource,
    }

    // =========================================================================
    // Scenarios
    // =========================================================================

    /// Scenario definition
    #[derive(Debug, Clone, Serialize, Deserialize)]
    pub struct Scenario {
        /// Always "Scenario"
        pub kind: String,
        /// Unique identifier: scenario:<name>
        pub id: String,
        /// Display name
        pub name: String,
        /// Base scenario ID (baseline has no base)
        pub base: Option<String>,
        /// Description
        pub description: Option<String>,
        /// When created
        pub created_at: DateTime<Utc>,
    }

    /// Operation type for change sets
    #[derive(Debug, Clone, Serialize, Deserialize)]
    #[serde(tag = "op", rename_all = "snake_case")]
    pub enum ChangeOp {
        /// Add a new edge
        AddEdge {
            /// Edge to add
            edge: Edge,
        },
        /// Remove an edge by ID
        RemoveEdge {
            /// Edge ID to remove
            edge_id: String,
        },
        /// Add an annotation
        AddAnnotation {
            /// Annotation to add
            annotation: AspectAnnotation,
        },
        /// Remove an annotation by ID
        RemoveAnnotation {
            /// Annotation ID to remove
            annotation_id: String,
        },
        /// Set group membership
        SetGroupMembership {
            /// Group ID
            group_id: String,
            /// New member list
            members: Vec<String>,
        },
    }

    /// Change set for a scenario
    #[derive(Debug, Clone, Serialize, Deserialize)]
    pub struct ChangeSet {
        /// Always "ChangeSet"
        pub kind: String,
        /// Parent scenario ID
        pub scenario_id: String,
        /// List of operations
        pub ops: Vec<ChangeOp>,
    }

    // =========================================================================
    // Layout (Optional UI Metadata)
    // =========================================================================

    /// Position in 2D space
    #[derive(Debug, Clone, Copy, Serialize, Deserialize)]
    pub struct Position {
        /// X coordinate
        pub x: f64,
        /// Y coordinate
        pub y: f64,
    }

    /// Layout metadata for visualization
    #[derive(Debug, Clone, Serialize, Deserialize)]
    pub struct Layout {
        /// Always "Layout"
        pub kind: String,
        /// Unique identifier
        pub id: String,
        /// Which scenario this layout applies to
        pub applies_to: String,
        /// Node positions
        #[serde(default)]
        pub positions: HashMap<String, Position>,
    }

    // =========================================================================
    // Graph Store
    // =========================================================================

    /// The complete graph store
    #[derive(Debug, Clone, Default, Serialize, Deserialize)]
    pub struct GraphStore {
        /// All repositories
        #[serde(default)]
        pub repos: Vec<Repo>,
        /// All components
        #[serde(default)]
        pub components: Vec<Component>,
        /// All groups
        #[serde(default)]
        pub groups: Vec<Group>,
        /// All edges
        #[serde(default)]
        pub edges: Vec<Edge>,
        /// All scenarios
        #[serde(default)]
        pub scenarios: Vec<Scenario>,
        /// All change sets (one per scenario)
        #[serde(default)]
        pub changesets: Vec<ChangeSet>,
    }

    /// Aspect store
    #[derive(Debug, Clone, Serialize, Deserialize)]
    pub struct AspectStore {
        /// Aspect definitions
        #[serde(default)]
        pub aspects: Vec<Aspect>,
        /// Aspect annotations
        #[serde(default)]
        pub annotations: Vec<AspectAnnotation>,
    }

    impl Default for AspectStore {
        fn default() -> Self {
            Self {
                aspects: Aspect::defaults(),
                annotations: Vec::new(),
            }
        }
    }
}

/// Prelude for common imports
pub mod prelude {
    pub use crate::types::*;
    pub use anyhow::{Context, Result};
}
