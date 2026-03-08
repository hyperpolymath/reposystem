// SPDX-License-Identifier: PMPL-1.0-or-later
// BotDispatch.res - Types for gitbot-fleet communication

// Bot types from gitbot-fleet
type botType =
  | Rhodibot // Repository standards enforcement
  | Echidnabot // Security scanning
  | Sustainabot // Dependency health
  | Glambot // Code quality (includes GitSeoAnalyzer)
  | Seambot // Seam analysis and invariants
  | Finishbot // Task completion

// Bot capability
type botCapability =
  | FileModification
  | MetadataUpdate
  | SecurityScan
  | QualityAnalysis
  | DependencyCheck
  | StandardsEnforcement

// Bot dispatch message
type dispatchMessage = {
  id: string,
  botType: botType,
  operation: Plan.operationType,
  repoId: Plan.repoId,
  priority: int, // 1-10
  timeout: int, // seconds
  retries: int,
  metadata: Js.Dict.t<string>,
}

// Bot response
type botResponse = {
  dispatchId: string,
  status: Plan.executionStatus,
  output: option<string>,
  findings: array<string>, // Bot-specific findings
  recommendations: array<string>,
  metadata: Js.Dict.t<string>,
}

// Bot dispatch result
type dispatchResult = {
  dispatchId: string,
  botType: botType,
  response: option<botResponse>,
  error: option<string>,
  duration: int, // milliseconds
}

// Dispatch strategy
type dispatchStrategy =
  | Sequential // Execute one at a time
  | Parallel // Execute all at once
  | Throttled({maxConcurrent: int}) // Execute with concurrency limit

// Helper functions
let botTypeToString = botType =>
  switch botType {
  | Rhodibot => "rhodibot"
  | Echidnabot => "echidnabot"
  | Sustainabot => "sustainabot"
  | Glambot => "glambot"
  | Seambot => "seambot"
  | Finishbot => "finishbot"
  }

let botTypeFromString = str =>
  switch str {
  | "rhodibot" => Some(Rhodibot)
  | "echidnabot" => Some(Echidnabot)
  | "sustainabot" => Some(Sustainabot)
  | "glambot" => Some(Glambot)
  | "seambot" => Some(Seambot)
  | "finishbot" => Some(Finishbot)
  | _ => None
  }

// Determine which bot to use for an operation
let selectBotForOperation = (opType: Plan.operationType): option<botType> =>
  switch opType {
  | BindSlot(_) | UnbindSlot(_) => Some(Rhodibot)
  | UpdateMetadata(_) => Some(Rhodibot)
  | CreateFile(_) | ModifyFile(_) | DeleteFile(_) => Some(Rhodibot)
  | RunCommand({command}) =>
    switch command {
    | "git-seo" => Some(Glambot)
    | "security-scan" => Some(Echidnabot)
    | "dependency-check" => Some(Sustainabot)
    | _ => Some(Rhodibot)
    }
  | GitOperation(_) => Some(Rhodibot)
  }

// Check if bot has required capability
let hasCapability = (botType: botType, capability: botCapability): bool =>
  switch (botType, capability) {
  | (Rhodibot, FileModification | MetadataUpdate | StandardsEnforcement) => true
  | (Echidnabot, SecurityScan) => true
  | (Sustainabot, DependencyCheck) => true
  | (Glambot, QualityAnalysis) => true
  | (Seambot, StandardsEnforcement) => true
  | (Finishbot, StandardsEnforcement) => true
  | _ => false
  }
