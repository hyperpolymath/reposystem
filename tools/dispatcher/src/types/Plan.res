// SPDX-License-Identifier: PMPL-1.0-or-later
// Plan.res - Core type definitions matching reposystem plan format

// Repository identifier
type repoId = string

// Operation risk level (from reposystem)
type riskLevel =
  | Low
  | Medium
  | High
  | Critical

// Operation types that can be executed
type operationType =
  // Core reposystem operations
  | BindSlot({slotId: string, providerId: string, repoId: repoId})
  | UnbindSlot({slotId: string, repoId: repoId})
  | UpdateMetadata({repoId: repoId, field: string, value: string})
  | RunCommand({repoId: repoId, command: string, args: array<string>})
  | CreateFile({repoId: repoId, path: string, content: string})
  | ModifyFile({repoId: repoId, path: string, operation: string})
  | DeleteFile({repoId: repoId, path: string})
  | GitOperation({repoId: repoId, operation: string, params: Js.Dict.t<string>})
  // Ecosystem integration operations
  | CreateScaffold({
      template: string, // Template name (e.g., "rescript/deno-app")
      destination: string, // Target directory path
      repoName: string, // Repository name
      metadata: Js.Dict.t<string>, // Key-value pairs for template substitution
    })
  | UpdateMetadataFromSeo({
      repoPath: string, // Path to repository
      runAnalysis: bool, // Run git-seo analysis first (vs. read existing report)
    })
  | RenderDocumentation({
      repoPath: string, // Path to repository
      templates: array<string>, // Specific templates to render (empty = all)
    })
  | RegisterInReposystem({
      repoPath: string, // Path to repository
      repoName: string, // Repository name for graph
      aspects: array<string>, // Aspects to register (e.g., ["security", "quality"])
      group: option<string>, // Optional group name
    })

// Single operation in a plan
type planOp = {
  id: string,
  opType: operationType,
  risk: riskLevel,
  description: string,
  requires: array<string>, // IDs of ops that must complete first
  reversible: bool,
}

// Rollback operation
type rollbackOp = {
  originalOpId: string,
  opType: operationType,
  description: string,
}

// Complete plan
type plan = {
  id: string,
  name: string,
  description: string,
  scenarioId: option<string>,
  operations: array<planOp>,
  rollbackPlan: array<rollbackOp>,
  createdAt: string,
  metadata: Js.Dict.t<string>,
}

// Execution status
type executionStatus =
  | Pending
  | InProgress
  | Completed
  | Failed({error: string})
  | Skipped({reason: string})

// Operation execution result
type opResult = {
  opId: string,
  status: executionStatus,
  startedAt: option<string>,
  completedAt: option<string>,
  output: option<string>,
  error: option<string>,
  metadata: Js.Dict.t<string>,
}

// Plan execution context
type executionContext = {
  planId: string,
  dryRun: bool,
  parallel: bool,
  maxRetries: int,
  timeout: int, // seconds
  auditLog: bool,
  requireApproval: bool,
}

// Plan execution result
type executionResult = {
  planId: string,
  status: executionStatus,
  operations: array<opResult>,
  startedAt: string,
  completedAt: option<string>,
  rollbackRequired: bool,
  auditTraceId: option<string>,
}

// Helper functions for risk level
let riskLevelToString = risk =>
  switch risk {
  | Low => "Low"
  | Medium => "Medium"
  | High => "High"
  | Critical => "Critical"
  }

let riskLevelFromString = str =>
  switch str {
  | "Low" => Some(Low)
  | "Medium" => Some(Medium)
  | "High" => Some(High)
  | "Critical" => Some(Critical)
  | _ => None
  }

// Helper functions for execution status
let statusToString = status =>
  switch status {
  | Pending => "Pending"
  | InProgress => "InProgress"
  | Completed => "Completed"
  | Failed(_) => "Failed"
  | Skipped(_) => "Skipped"
  }

let isTerminal = status =>
  switch status {
  | Completed | Failed(_) | Skipped(_) => true
  | Pending | InProgress => false
  }

let isSuccessful = status =>
  switch status {
  | Completed => true
  | _ => false
  }
