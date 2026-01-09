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
    // Slots and Providers (f2)
    // =========================================================================

    /// A slot represents a swappable capability in the ecosystem.
    /// Examples: container.runtime, router.core, auth.provider
    #[derive(Debug, Clone, Serialize, Deserialize)]
    pub struct Slot {
        /// Always "Slot"
        pub kind: String,
        /// Unique identifier: slot:<category>.<name>
        pub id: String,
        /// Human-readable name
        pub name: String,
        /// Slot category (e.g., "container", "router", "auth")
        pub category: String,
        /// Description of what this slot provides
        pub description: String,
        /// Interface version pattern (e.g., "v1", ">=1.0")
        #[serde(default)]
        pub interface_version: Option<String>,
        /// Required capabilities
        #[serde(default)]
        pub required_capabilities: Vec<String>,
    }

    impl Slot {
        /// Generate a deterministic slot ID
        #[must_use]
        pub fn generate_id(category: &str, name: &str) -> String {
            format!("slot:{}.{}", category.to_lowercase(), name.to_lowercase())
        }
    }

    /// A provider implements a slot's capability.
    /// Can be local (repo-based) or external (ecosystem service)
    #[derive(Debug, Clone, Serialize, Deserialize)]
    pub struct Provider {
        /// Always "Provider"
        pub kind: String,
        /// Unique identifier: provider:<slot_id>:<name>
        pub id: String,
        /// Human-readable name
        pub name: String,
        /// Which slot this provider satisfies
        pub slot_id: String,
        /// Provider type
        pub provider_type: ProviderType,
        /// Repository that implements this provider (if local)
        pub repo_id: Option<String>,
        /// External URI (if ecosystem/external)
        pub external_uri: Option<String>,
        /// Interface version this provider implements
        #[serde(default)]
        pub interface_version: Option<String>,
        /// Capabilities this provider offers
        #[serde(default)]
        pub capabilities: Vec<String>,
        /// Priority for auto-selection (higher = preferred)
        #[serde(default)]
        pub priority: i32,
        /// Whether this is a fallback provider
        #[serde(default)]
        pub is_fallback: bool,
    }

    impl Provider {
        /// Generate a deterministic provider ID
        #[must_use]
        pub fn generate_id(slot_id: &str, name: &str) -> String {
            let slot_short = slot_id.replace("slot:", "");
            format!("provider:{}:{}", slot_short, name.to_lowercase())
        }
    }

    /// Provider type classification
    #[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
    #[serde(rename_all = "lowercase")]
    pub enum ProviderType {
        /// Provided by a local repository
        Local,
        /// Provided by an ecosystem service
        Ecosystem,
        /// External service (not in ecosystem)
        External,
        /// Stub/mock for testing
        Stub,
    }

    /// A binding connects a consumer (repo) to a slot via a specific provider.
    /// This represents "repo X uses provider Y for slot Z"
    #[derive(Debug, Clone, Serialize, Deserialize)]
    pub struct SlotBinding {
        /// Always "SlotBinding"
        pub kind: String,
        /// Unique identifier: binding:<consumer_id>:<slot_id>
        pub id: String,
        /// Consumer repository ID
        pub consumer_id: String,
        /// Slot being consumed
        pub slot_id: String,
        /// Currently bound provider
        pub provider_id: String,
        /// Binding mode
        pub mode: BindingMode,
        /// When this binding was created
        pub created_at: DateTime<Utc>,
        /// Who created this binding
        pub created_by: String,
    }

    impl SlotBinding {
        /// Generate a deterministic binding ID
        #[must_use]
        pub fn generate_id(consumer_id: &str, slot_id: &str) -> String {
            let consumer_short = consumer_id.replace("repo:", "").replace('/', "-").replace(':', "-");
            let slot_short = slot_id.replace("slot:", "");
            format!("binding:{}:{}", consumer_short, slot_short)
        }
    }

    /// How a slot binding was established
    #[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
    #[serde(rename_all = "lowercase")]
    pub enum BindingMode {
        /// Explicitly set by user
        Manual,
        /// Auto-selected based on priority/compatibility
        Auto,
        /// Inherited from scenario
        Scenario,
        /// Default/fallback binding
        Default,
    }

    /// Compatibility check result
    #[derive(Debug, Clone, Serialize, Deserialize)]
    pub struct CompatibilityResult {
        /// Whether compatible
        pub compatible: bool,
        /// Version match status
        pub version_match: bool,
        /// Capabilities satisfied
        pub capabilities_satisfied: Vec<String>,
        /// Capabilities missing
        pub capabilities_missing: Vec<String>,
        /// Human-readable reason
        pub reason: String,
    }

    /// Slot registry store
    #[derive(Debug, Clone, Default, Serialize, Deserialize)]
    pub struct SlotStore {
        /// All slot definitions
        #[serde(default)]
        pub slots: Vec<Slot>,
        /// All provider definitions
        #[serde(default)]
        pub providers: Vec<Provider>,
        /// All slot bindings
        #[serde(default)]
        pub bindings: Vec<SlotBinding>,
    }

    impl SlotStore {
        /// Get providers for a slot
        #[must_use]
        pub fn providers_for_slot(&self, slot_id: &str) -> Vec<&Provider> {
            self.providers.iter().filter(|p| p.slot_id == slot_id).collect()
        }

        /// Get binding for a consumer and slot
        #[must_use]
        pub fn get_binding(&self, consumer_id: &str, slot_id: &str) -> Option<&SlotBinding> {
            self.bindings
                .iter()
                .find(|b| b.consumer_id == consumer_id && b.slot_id == slot_id)
        }

        /// Get all bindings for a consumer
        #[must_use]
        pub fn bindings_for_consumer(&self, consumer_id: &str) -> Vec<&SlotBinding> {
            self.bindings.iter().filter(|b| b.consumer_id == consumer_id).collect()
        }

        /// Get all bindings using a specific provider
        #[must_use]
        pub fn bindings_for_provider(&self, provider_id: &str) -> Vec<&SlotBinding> {
            self.bindings.iter().filter(|b| b.provider_id == provider_id).collect()
        }

        /// Check if a provider is compatible with a slot
        #[must_use]
        pub fn check_compatibility(&self, slot_id: &str, provider_id: &str) -> CompatibilityResult {
            let slot = self.slots.iter().find(|s| s.id == slot_id);
            let provider = self.providers.iter().find(|p| p.id == provider_id);

            match (slot, provider) {
                (Some(slot), Some(provider)) => {
                    // Check if provider is for this slot
                    if provider.slot_id != slot_id {
                        return CompatibilityResult {
                            compatible: false,
                            version_match: false,
                            capabilities_satisfied: vec![],
                            capabilities_missing: slot.required_capabilities.clone(),
                            reason: format!("Provider {} is for slot {}, not {}", provider_id, provider.slot_id, slot_id),
                        };
                    }

                    // Check version compatibility
                    let version_match = match (&slot.interface_version, &provider.interface_version) {
                        (Some(sv), Some(pv)) => sv == pv, // Simple equality for now
                        (None, _) | (_, None) => true,    // No version requirement
                    };

                    // Check capabilities
                    let caps_satisfied: Vec<_> = slot.required_capabilities
                        .iter()
                        .filter(|c| provider.capabilities.contains(c))
                        .cloned()
                        .collect();
                    let caps_missing: Vec<_> = slot.required_capabilities
                        .iter()
                        .filter(|c| !provider.capabilities.contains(c))
                        .cloned()
                        .collect();

                    let compatible = version_match && caps_missing.is_empty();
                    let reason = if compatible {
                        "Compatible".into()
                    } else if !version_match {
                        format!("Version mismatch: slot requires {:?}, provider offers {:?}",
                                slot.interface_version, provider.interface_version)
                    } else {
                        format!("Missing capabilities: {:?}", caps_missing)
                    };

                    CompatibilityResult {
                        compatible,
                        version_match,
                        capabilities_satisfied: caps_satisfied,
                        capabilities_missing: caps_missing,
                        reason,
                    }
                }
                (None, _) => CompatibilityResult {
                    compatible: false,
                    version_match: false,
                    capabilities_satisfied: vec![],
                    capabilities_missing: vec![],
                    reason: format!("Slot not found: {}", slot_id),
                },
                (_, None) => CompatibilityResult {
                    compatible: false,
                    version_match: false,
                    capabilities_satisfied: vec![],
                    capabilities_missing: vec![],
                    reason: format!("Provider not found: {}", provider_id),
                },
            }
        }
    }

    // =========================================================================
    // Plans (f3)
    // =========================================================================

    /// Risk level for plan operations
    #[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
    #[serde(rename_all = "lowercase")]
    pub enum RiskLevel {
        /// Low risk - safe to apply
        Low,
        /// Medium risk - review recommended
        Medium,
        /// High risk - careful review required
        High,
        /// Critical risk - may cause breakage
        Critical,
    }

    impl Default for RiskLevel {
        fn default() -> Self {
            RiskLevel::Low
        }
    }

    /// Individual operation in a plan
    #[derive(Debug, Clone, Serialize, Deserialize)]
    #[serde(tag = "op", rename_all = "snake_case")]
    pub enum PlanOp {
        /// Switch a binding from one provider to another
        SwitchBinding {
            /// Binding ID being modified
            binding_id: String,
            /// Consumer repo ID
            consumer_id: String,
            /// Slot being rebound
            slot_id: String,
            /// Current provider (for rollback)
            from_provider_id: String,
            /// New provider
            to_provider_id: String,
            /// Risk level for this operation
            risk: RiskLevel,
            /// Reason for this switch
            reason: String,
        },
        /// Create a new binding
        CreateBinding {
            /// Consumer repo ID
            consumer_id: String,
            /// Slot to bind
            slot_id: String,
            /// Provider to bind to
            provider_id: String,
            /// Risk level
            risk: RiskLevel,
            /// Reason
            reason: String,
        },
        /// Remove a binding
        RemoveBinding {
            /// Binding ID to remove
            binding_id: String,
            /// Consumer repo ID (for reference)
            consumer_id: String,
            /// Slot ID (for reference)
            slot_id: String,
            /// Provider ID (for rollback)
            provider_id: String,
            /// Risk level
            risk: RiskLevel,
            /// Reason
            reason: String,
        },
        /// Describes intended file changes
        FileChange {
            /// Repository ID
            repo_id: String,
            /// File path within repo
            file_path: String,
            /// Type of change
            change_type: FileChangeType,
            /// Content changes (for preview)
            diff: Option<String>,
            /// Risk level
            risk: RiskLevel,
        },
    }

    impl PlanOp {
        /// Get the risk level for this operation
        #[must_use]
        pub fn risk(&self) -> RiskLevel {
            match self {
                PlanOp::SwitchBinding { risk, .. } => *risk,
                PlanOp::CreateBinding { risk, .. } => *risk,
                PlanOp::RemoveBinding { risk, .. } => *risk,
                PlanOp::FileChange { risk, .. } => *risk,
            }
        }

        /// Get a human-readable description of this operation
        #[must_use]
        pub fn description(&self) -> String {
            match self {
                PlanOp::SwitchBinding { consumer_id, slot_id, from_provider_id, to_provider_id, .. } => {
                    format!("Switch {}'s {} binding: {} → {}", consumer_id, slot_id, from_provider_id, to_provider_id)
                }
                PlanOp::CreateBinding { consumer_id, slot_id, provider_id, .. } => {
                    format!("Create binding: {} uses {} via {}", consumer_id, slot_id, provider_id)
                }
                PlanOp::RemoveBinding { consumer_id, slot_id, .. } => {
                    format!("Remove binding: {} no longer uses {}", consumer_id, slot_id)
                }
                PlanOp::FileChange { repo_id, file_path, change_type, .. } => {
                    format!("{:?} {} in {}", change_type, file_path, repo_id)
                }
            }
        }
    }

    /// Type of file change
    #[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
    #[serde(rename_all = "lowercase")]
    pub enum FileChangeType {
        /// Create a new file
        Create,
        /// Modify existing file
        Modify,
        /// Delete a file
        Delete,
    }

    /// Plan status
    #[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
    #[serde(rename_all = "lowercase")]
    pub enum PlanStatus {
        /// Plan is being drafted
        Draft,
        /// Plan is ready for review
        Ready,
        /// Plan has been applied
        Applied,
        /// Plan was rolled back
        RolledBack,
        /// Plan was cancelled
        Cancelled,
    }

    impl Default for PlanStatus {
        fn default() -> Self {
            PlanStatus::Draft
        }
    }

    /// A plan for making changes to the ecosystem
    #[derive(Debug, Clone, Serialize, Deserialize)]
    pub struct Plan {
        /// Always "Plan"
        pub kind: String,
        /// Unique identifier: plan:<scenario>:<timestamp>
        pub id: String,
        /// Display name
        pub name: String,
        /// Scenario this plan is based on
        pub scenario_id: String,
        /// Description of what this plan does
        pub description: Option<String>,
        /// Operations in this plan (in order)
        pub operations: Vec<PlanOp>,
        /// Overall risk assessment
        pub overall_risk: RiskLevel,
        /// Status of this plan
        pub status: PlanStatus,
        /// When this plan was created
        pub created_at: DateTime<Utc>,
        /// Who created this plan
        pub created_by: String,
        /// When this plan was applied (if applied)
        pub applied_at: Option<DateTime<Utc>>,
        /// Rollback plan ID (if this plan was applied)
        pub rollback_plan_id: Option<String>,
    }

    impl Plan {
        /// Generate a deterministic plan ID
        #[must_use]
        pub fn generate_id(scenario_id: &str) -> String {
            let scenario_short = scenario_id.replace("scenario:", "");
            let timestamp = Utc::now().format("%Y%m%d%H%M%S");
            format!("plan:{}:{}", scenario_short, timestamp)
        }

        /// Calculate overall risk from operations
        #[must_use]
        pub fn calculate_overall_risk(operations: &[PlanOp]) -> RiskLevel {
            operations
                .iter()
                .map(PlanOp::risk)
                .max_by_key(|r| match r {
                    RiskLevel::Low => 0,
                    RiskLevel::Medium => 1,
                    RiskLevel::High => 2,
                    RiskLevel::Critical => 3,
                })
                .unwrap_or(RiskLevel::Low)
        }

        /// Get count of operations by risk level
        #[must_use]
        pub fn risk_summary(&self) -> HashMap<String, usize> {
            let mut summary = HashMap::new();
            for op in &self.operations {
                let key = format!("{:?}", op.risk()).to_lowercase();
                *summary.entry(key).or_insert(0) += 1;
            }
            summary
        }
    }

    /// Summary of a diff for dry-run preview
    #[derive(Debug, Clone, Serialize, Deserialize)]
    pub struct PlanDiff {
        /// Plan this diff is for
        pub plan_id: String,
        /// Number of bindings changed
        pub bindings_changed: usize,
        /// Number of bindings created
        pub bindings_created: usize,
        /// Number of bindings removed
        pub bindings_removed: usize,
        /// Number of files affected
        pub files_affected: usize,
        /// Individual file diffs (unified format)
        pub file_diffs: Vec<FileDiff>,
    }

    /// Diff for a single file
    #[derive(Debug, Clone, Serialize, Deserialize)]
    pub struct FileDiff {
        /// Repository ID
        pub repo_id: String,
        /// File path
        pub file_path: String,
        /// Change type
        pub change_type: FileChangeType,
        /// Unified diff content
        pub diff: String,
        /// Number of lines added
        pub lines_added: usize,
        /// Number of lines removed
        pub lines_removed: usize,
    }

    /// Plan store - persists plans to plans.json
    #[derive(Debug, Clone, Default, Serialize, Deserialize)]
    pub struct PlanStore {
        /// All plans
        #[serde(default)]
        pub plans: Vec<Plan>,
        /// All diffs (cached)
        #[serde(default)]
        pub diffs: Vec<PlanDiff>,
    }

    impl PlanStore {
        /// Get a plan by ID
        #[must_use]
        pub fn get_plan(&self, plan_id: &str) -> Option<&Plan> {
            self.plans.iter().find(|p| p.id == plan_id)
        }

        /// Get plans for a scenario
        #[must_use]
        pub fn plans_for_scenario(&self, scenario_id: &str) -> Vec<&Plan> {
            self.plans.iter().filter(|p| p.scenario_id == scenario_id).collect()
        }

        /// Get the most recent plan for a scenario
        #[must_use]
        pub fn latest_plan_for_scenario(&self, scenario_id: &str) -> Option<&Plan> {
            self.plans
                .iter()
                .filter(|p| p.scenario_id == scenario_id)
                .max_by_key(|p| p.created_at)
        }

        /// Get diff for a plan
        #[must_use]
        pub fn get_diff(&self, plan_id: &str) -> Option<&PlanDiff> {
            self.diffs.iter().find(|d| d.plan_id == plan_id)
        }

        /// Generate a rollback plan from an existing plan
        #[must_use]
        pub fn generate_rollback(plan: &Plan) -> Plan {
            let rollback_ops: Vec<PlanOp> = plan.operations.iter().rev().filter_map(|op| {
                match op {
                    PlanOp::SwitchBinding { binding_id, consumer_id, slot_id, from_provider_id, to_provider_id, risk, .. } => {
                        Some(PlanOp::SwitchBinding {
                            binding_id: binding_id.clone(),
                            consumer_id: consumer_id.clone(),
                            slot_id: slot_id.clone(),
                            from_provider_id: to_provider_id.clone(),
                            to_provider_id: from_provider_id.clone(),
                            risk: *risk,
                            reason: format!("Rollback of plan {}", plan.id),
                        })
                    }
                    PlanOp::CreateBinding { consumer_id, slot_id, provider_id, risk, .. } => {
                        Some(PlanOp::RemoveBinding {
                            binding_id: SlotBinding::generate_id(consumer_id, slot_id),
                            consumer_id: consumer_id.clone(),
                            slot_id: slot_id.clone(),
                            provider_id: provider_id.clone(),
                            risk: *risk,
                            reason: format!("Rollback of plan {}", plan.id),
                        })
                    }
                    PlanOp::RemoveBinding { consumer_id, slot_id, provider_id, risk, .. } => {
                        Some(PlanOp::CreateBinding {
                            consumer_id: consumer_id.clone(),
                            slot_id: slot_id.clone(),
                            provider_id: provider_id.clone(),
                            risk: *risk,
                            reason: format!("Rollback of plan {}", plan.id),
                        })
                    }
                    PlanOp::FileChange { .. } => {
                        // File changes need more complex rollback logic
                        // For now, we skip them - f4 will handle this
                        None
                    }
                }
            }).collect();

            Plan {
                kind: "Plan".into(),
                id: format!("plan:rollback:{}", plan.id.replace("plan:", "")),
                name: format!("Rollback: {}", plan.name),
                scenario_id: plan.scenario_id.clone(),
                description: Some(format!("Rollback plan for {}", plan.id)),
                operations: rollback_ops,
                overall_risk: plan.overall_risk,
                status: PlanStatus::Draft,
                created_at: Utc::now(),
                created_by: "system".into(),
                applied_at: None,
                rollback_plan_id: None,
            }
        }
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
