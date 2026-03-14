// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell

/// Reposystem Module Registration — Capability-driven module protocol.
///
/// Registers Reposystem as a PanLL panel module with its capabilities,
/// configuration, and metadata. Follows the ForgeOpsModule.res pattern.
///
/// Three-panel model (PanLL integration):
///   Panel-L → Ecosystem constraints (slot policies, edge cardinality limits,
///             aspect rules, governance invariants)
///   Panel-N → Ecosystem health reasoning (dependency analysis, vulnerability
///             propagation, slot coverage gaps, orphan detection)
///   Panel-W → Ecosystem graph visualization, scan results, health dashboard,
///             scenario planning output

/// Capabilities that Reposystem provides to the PanLL ecosystem.
type reposystemCapability =
  | GraphVisualization     // Force-directed, hierarchical, circular, grid layouts
  | EcosystemScanning      // Discover repos from filesystem or forges
  | EdgeManagement         // Create, remove, annotate relationships between repos
  | GroupManagement        // Organize repos into named collections
  | AspectAnnotation       // Tag repos/edges with weighted aspect scores
  | SlotBindingSystem      // Declare required capabilities and bind providers
  | ScenarioPlanning       // Multi-repo change coordination with risk assessment
  | ExportMultiFormat      // Export to JSON, YAML, TOML, DOT
  | ConstraintEvaluation   // Evaluate ecosystem against governance rules
  | HealthDashboard        // Aggregate health metrics across the ecosystem

/// Reposystem module configuration.
type reposystemModuleConfig = {
  id: string,
  name: string,
  version: string,
  description: string,
  capabilities: array<reposystemCapability>,
  icon: option<string>,
}

/// The Reposystem module registration.
let config: reposystemModuleConfig = {
  id: "reposystem",
  name: "Reposystem",
  version: "0.1.0",
  description: "Railway yard for repository ecosystems. Visualises repo relationships, manages slots and providers, annotates aspects, and coordinates multi-repo changes with scenario planning.",
  capabilities: [
    GraphVisualization,
    EcosystemScanning,
    EdgeManagement,
    GroupManagement,
    AspectAnnotation,
    SlotBindingSystem,
    ScenarioPlanning,
    ExportMultiFormat,
    ConstraintEvaluation,
    HealthDashboard,
  ],
  icon: Some("railway"),
}

/// Check if Reposystem has a specific capability.
let hasCapability = (cap: reposystemCapability): bool => {
  config.capabilities->Array.includes(cap)
}

/// Human-readable label for a Reposystem capability.
let capabilityLabel = (cap: reposystemCapability): string => {
  switch cap {
  | GraphVisualization => "Graph Visualization"
  | EcosystemScanning => "Ecosystem Scanning"
  | EdgeManagement => "Edge Management"
  | GroupManagement => "Group Management"
  | AspectAnnotation => "Aspect Annotation"
  | SlotBindingSystem => "Slot Binding System"
  | ScenarioPlanning => "Scenario Planning"
  | ExportMultiFormat => "Multi-Format Export"
  | ConstraintEvaluation => "Constraint Evaluation"
  | HealthDashboard => "Health Dashboard"
  }
}

/// Short description for each capability.
let capabilityDescription = (cap: reposystemCapability): string => {
  switch cap {
  | GraphVisualization => "Force-directed, hierarchical, circular, and grid graph layouts with D3 rendering"
  | EcosystemScanning => "Discover repos from local filesystem or forge APIs, build initial graph"
  | EdgeManagement => "Create and remove typed, channelled relationships between repos with metadata"
  | GroupManagement => "Organize repos into named groups for filtering and batch operations"
  | AspectAnnotation => "Tag repos and edges with weighted aspect scores (security, reliability, etc.)"
  | SlotBindingSystem => "Declare required capabilities as slots and bind provider repos to fulfil them"
  | ScenarioPlanning => "Coordinate multi-repo changes with risk assessment and rollback planning"
  | ExportMultiFormat => "Export ecosystem graph to JSON, YAML, TOML, and Graphviz DOT formats"
  | ConstraintEvaluation => "Evaluate the ecosystem against governance rules and RSR policy"
  | HealthDashboard => "Aggregate health metrics, slot coverage, aspect scores across the ecosystem"
  }
}
