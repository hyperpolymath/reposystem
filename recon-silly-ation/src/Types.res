// SPDX-License-Identifier: PMPL-1.0-or-later
// Core domain types for documentation reconciliation system
// Content-addressable storage with graph-based conflict resolution

// Content hash for deduplication
type contentHash = string

// Document types we reconcile
type documentType =
  | README
  | LICENSE
  | SECURITY
  | CONTRIBUTING
  | CODE_OF_CONDUCT
  | FUNDING
  | CITATION
  | CHANGELOG
  | AUTHORS
  | SUPPORT
  | Custom(string)

let documentTypeToString = (dt: documentType): string => {
  switch dt {
  | README => "README"
  | LICENSE => "LICENSE"
  | SECURITY => "SECURITY"
  | CONTRIBUTING => "CONTRIBUTING"
  | CODE_OF_CONDUCT => "CODE_OF_CONDUCT"
  | FUNDING => "FUNDING"
  | CITATION => "CITATION"
  | CHANGELOG => "CHANGELOG"
  | AUTHORS => "AUTHORS"
  | SUPPORT => "SUPPORT"
  | Custom(name) => name
  }
}

let documentTypeFromString = (s: string): documentType => {
  switch s {
  | "README" => README
  | "LICENSE" => LICENSE
  | "SECURITY" => SECURITY
  | "CONTRIBUTING" => CONTRIBUTING
  | "CODE_OF_CONDUCT" => CODE_OF_CONDUCT
  | "FUNDING" => FUNDING
  | "CITATION" => CITATION
  | "CHANGELOG" => CHANGELOG
  | "AUTHORS" => AUTHORS
  | "SUPPORT" => SUPPORT
  | custom => Custom(custom)
  }
}

// Version representation
type version = {
  major: int,
  minor: int,
  patch: int,
}

let versionToString = (v: version): string => {
  `${v.major->Int.toString}.${v.minor->Int.toString}.${v.patch->Int.toString}`
}

let compareVersions = (v1: version, v2: version): int => {
  if v1.major != v2.major {
    v1.major - v2.major
  } else if v1.minor != v2.minor {
    v1.minor - v2.minor
  } else {
    v1.patch - v2.patch
  }
}

// Source of truth for canonical resolution
type canonicalSource =
  | LicenseFile // LICENSE file is canonical for license info
  | FundingYaml // FUNDING.yml is canonical for funding info
  | SecurityMd // SECURITY.md is canonical for security policy
  | CitationCff // CITATION.cff is canonical for citations
  | PackageJson // package.json for Node.js projects
  | CargoToml // Cargo.toml for Rust projects
  | Explicit(string) // Explicitly marked canonical
  | Inferred // Inferred from context

// Document metadata
type documentMetadata = {
  path: string,
  documentType: documentType,
  lastModified: float, // Unix timestamp
  version: option<version>,
  canonicalSource: canonicalSource,
  repository: string,
  branch: string,
}

// Document with content and metadata
type document = {
  hash: contentHash,
  content: string,
  metadata: documentMetadata,
  createdAt: float,
}

// Conflict type
type conflictType =
  | DuplicateContent // Same content, different locations
  | VersionMismatch // Different versions of same doc
  | CanonicalConflict // Multiple canonical sources claim authority
  | StructuralConflict // Structural differences in format
  | SemanticConflict // Semantic differences in content

// Confidence score (0.0 to 1.0)
type confidence = float

// Resolution strategy
type resolutionStrategy =
  | KeepLatest // Keep most recent version
  | KeepCanonical // Keep canonical source
  | KeepHighestVersion // Keep highest version number
  | Merge // Attempt to merge
  | RequireManual // Escalate to human

let resolutionStrategyToString = (rs: resolutionStrategy): string => {
  switch rs {
  | KeepLatest => "keep_latest"
  | KeepCanonical => "keep_canonical"
  | KeepHighestVersion => "keep_highest_version"
  | Merge => "merge"
  | RequireManual => "require_manual"
  }
}

// Conflict between documents
type conflict = {
  id: string,
  conflictType: conflictType,
  documents: array<document>,
  detectedAt: float,
  confidence: confidence,
  suggestedStrategy: resolutionStrategy,
}

// Resolution result
type resolutionResult = {
  conflictId: string,
  strategy: resolutionStrategy,
  selectedDocument: option<document>,
  confidence: confidence,
  requiresApproval: bool,
  reasoning: string,
  timestamp: float,
}

// Pipeline stage
type pipelineStage =
  | Scan // Scan repositories for documents
  | Normalize // Normalize document formats
  | Deduplicate // Remove duplicates via content hashing
  | DetectConflicts // Detect conflicts between documents
  | ResolveConflicts // Resolve conflicts automatically
  | Ingest // Ingest into ArangoDB
  | Report // Generate reconciliation report

let pipelineStageToString = (stage: pipelineStage): string => {
  switch stage {
  | Scan => "scan"
  | Normalize => "normalize"
  | Deduplicate => "deduplicate"
  | DetectConflicts => "detect_conflicts"
  | ResolveConflicts => "resolve_conflicts"
  | Ingest => "ingest"
  | Report => "report"
  }
}

// Pipeline state
type pipelineState = {
  stage: pipelineStage,
  documents: array<document>,
  conflicts: array<conflict>,
  resolutions: array<resolutionResult>,
  errors: array<string>,
  startedAt: float,
  completedAt: option<float>,
}

// Graph edge types for ArangoDB
type edgeType =
  | ConflictsWith // Document conflicts with another
  | SupersededBy // Document is superseded by another
  | DuplicateOf // Document is duplicate of another
  | CanonicalFor // Document is canonical for a type
  | DerivedFrom // Document derived from another

let edgeTypeToString = (et: edgeType): string => {
  switch et {
  | ConflictsWith => "conflicts_with"
  | SupersededBy => "superseded_by"
  | DuplicateOf => "duplicate_of"
  | CanonicalFor => "canonical_for"
  | DerivedFrom => "derived_from"
  }
}

// Graph edge
type edge = {
  from: string, // Document hash
  to: string, // Document hash
  edgeType: edgeType,
  confidence: confidence,
  metadata: Js.Json.t,
}

// Configuration
type config = {
  arangoUrl: string,
  arangoDatabase: string,
  arangoUsername: string,
  arangoPassword: string,
  autoResolveThreshold: float, // Auto-resolve if confidence > this
  repositoryPaths: array<string>,
  scanInterval: option<int>, // Seconds, None = run once
}

// LLM integration types (Phase 2)
type llmProvider =
  | Anthropic(string) // API key
  | OpenAI(string) // API key
  | Local(string) // Local model path

type llmPromptType =
  | GenerateSecurityMd
  | GenerateContributing
  | GenerateSupport
  | SuggestConflictResolution
  | ImproveDocumentation

type llmResponse = {
  content: string,
  confidence: confidence,
  requiresApproval: bool, // Always true for LLM output
  reasoning: string,
  model: string,
}

// CCCP compliance types
type cccpViolation = {
  file: string,
  violationType: string,
  severity: string, // "warning" | "error"
  message: string,
  suggestedFix: option<string>,
}

// Export all types
module Export = {
  type t_contentHash = contentHash
  type t_documentType = documentType
  type t_version = version
  type t_canonicalSource = canonicalSource
  type t_documentMetadata = documentMetadata
  type t_document = document
  type t_conflictType = conflictType
  type t_confidence = confidence
  type t_resolutionStrategy = resolutionStrategy
  type t_conflict = conflict
  type t_resolutionResult = resolutionResult
  type t_pipelineStage = pipelineStage
  type t_pipelineState = pipelineState
  type t_edgeType = edgeType
  type t_edge = edge
  type t_config = config
  type t_llmProvider = llmProvider
  type t_llmPromptType = llmPromptType
  type t_llmResponse = llmResponse
  type t_cccpViolation = cccpViolation
}
