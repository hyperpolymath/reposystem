// SPDX-License-Identifier: PMPL-1.0-or-later
// Protocol - Shared types for component integration (SEAM requirements)

// =============================================================================
// SEAM-1: Formatrix ↔ RSA Protocol
// =============================================================================

// SEAM-1A: Document event protocol
type documentEventType =
  | Created
  | Modified
  | Deleted
  | Converted

type documentEvent = {
  id: string,
  eventType: documentEventType,
  hash: string,
  oldHash: option<string>,
  path: string,
  format: string,
  timestamp: float,
  source: string, // "formatrix-docs" | "recon-silly-ation"
}

// SEAM-1C: AST interchange format
type inlineElement =
  | Text(string)
  | Emphasis(string)
  | Strong(string)
  | Code(string)
  | Link({text: string, url: string})
  | Image({alt: string, url: string})

type blockElement =
  | Paragraph(array<inlineElement>)
  | Heading({level: int, content: array<inlineElement>})
  | CodeBlock({language: option<string>, content: string})
  | List({ordered: bool, items: array<array<inlineElement>>})
  | Quote(array<blockElement>)
  | ThematicBreak
  | Raw(string)

type documentAst = {
  title: option<string>,
  blocks: array<blockElement>,
  format: string,
  hash: string,
}

// SEAM-1D: Hash algorithm (SHA-256)
let hashAlgorithm = "sha256"

// =============================================================================
// SEAM-2: RSA ↔ Docubot Protocol
// =============================================================================

// SEAM-2A: Generation request protocol
type generationRequest = {
  requestId: string,
  documentType: string, // "README", "SECURITY", etc.
  format: string, // "md", "adoc", "org"
  context: repoContext,
  priority: int,
  requestedBy: string,
  requestedAt: float,
}

// SEAM-2A: Repository context - aligned with Docubot.res
and repoContext = {
  name: string,
  description: option<string>,
  language: option<string>,
  license: option<string>,
  topics: array<string>,
  existingDocs: array<string>,
  // Additional fields for Docubot integration
  dependencies: option<array<string>>,
  readme: option<string>,
}

type generationResponse = {
  requestId: string,
  content: string,
  documentType: string,
  format: string,
  requiresApproval: bool, // MUST always be true
  confidence: float,
  generatedAt: float,
  auditId: string,
  warnings: array<string>,
}

// SEAM-2B: Approval callback mechanism
type approvalRequest = {
  auditId: string,
  content: string,
  documentType: string,
  format: string,
  requestedBy: string,
  expiresAt: float,
}

type approvalResponse = {
  auditId: string,
  approved: bool,
  approvedBy: option<string>,
  approvedAt: option<float>,
  reason: option<string>,
}

// SEAM-2C: Audit event format
type auditEventType =
  | GenerationStarted
  | GenerationCompleted
  | GenerationFailed
  | ApprovalRequested
  | ApprovalGranted
  | ApprovalRejected
  | ApprovalExpired

type auditEvent = {
  id: string,
  eventType: auditEventType,
  auditId: string,
  timestamp: float,
  details: Js.Dict.t<string>,
}

// =============================================================================
// SEAM-3: RSA ↔ Docudactyl Protocol
// =============================================================================

// SEAM-3A: Pipeline trigger protocol
type pipelineTrigger = {
  triggerId: string,
  pipelineId: string,
  params: Js.Dict.t<string>,
  triggeredBy: string,
  triggeredAt: float,
  priority: int,
}

type pipelineAck = {
  triggerId: string,
  executionId: string,
  accepted: bool,
  reason: option<string>,
}

// SEAM-3B: Status reporting format
type pipelineStatus =
  | Queued
  | Running
  | Completed
  | Failed
  | Cancelled

type stepStatus =
  | StepPending
  | StepRunning
  | StepCompleted({duration: float})
  | StepFailed({error: string, duration: float})
  | StepSkipped({reason: string})

type statusReport = {
  executionId: string,
  pipelineId: string,
  status: pipelineStatus,
  progress: float, // 0.0 to 1.0
  currentStep: option<string>,
  stepStatuses: Js.Dict.t<stepStatus>,
  startedAt: float,
  updatedAt: float,
  completedAt: option<float>,
  error: option<string>,
}

// SEAM-3C: Enforcement result format
type violationSeverity =
  | ViolationError
  | ViolationWarning
  | ViolationInfo

type enforcementViolation = {
  id: string,
  ruleId: string,
  ruleName: string,
  severity: violationSeverity,
  message: string,
  path: option<string>,
  line: option<int>,
  suggestion: option<string>,
}

type enforcementResult = {
  executionId: string,
  packSpec: string,
  bundleId: string,
  success: bool,
  violations: array<enforcementViolation>,
  checkedAt: float,
  duration: float,
}

// SEAM-3D: Pack shipping completion event
type shippingDestination =
  | GitRepo({url: string, branch: string})
  | FileSystem({path: string})
  | ArangoDB({collection: string})
  | Archive({path: string, format: string})

type packShipmentResult = {
  shipmentId: string,
  packName: string,
  destination: shippingDestination,
  success: bool,
  documentCount: int,
  totalSize: int,
  shippedAt: float,
  error: option<string>,
  manifest: option<string>,
}

// =============================================================================
// SEAM-4: Docubot ↔ Docudactyl Protocol
// =============================================================================

// SEAM-4A: Generation scheduling
type generationSchedule = {
  scheduleId: string,
  documentType: string,
  format: string,
  repoPath: string,
  interval: option<int>, // seconds, None = one-time
  priority: int,
  enabled: bool,
}

// SEAM-4B: Approval workflow routing
type approvalWorkflow = {
  workflowId: string,
  auditId: string,
  content: string,
  documentType: string,
  approvers: array<string>,
  requiredApprovals: int,
  currentApprovals: int,
  status: string, // "pending", "approved", "rejected", "expired"
  expiresAt: float,
}

// SEAM-4C: Cost budget integration
type costBudget = {
  daily: float,
  monthly: float,
  dailyUsed: float,
  monthlyUsed: float,
  dailyRemaining: float,
  monthlyRemaining: float,
}

// SEAM-4D: Health check protocol
type healthStatus =
  | Healthy
  | Degraded({reason: string})
  | Unhealthy({reason: string})
  | Unknown

type healthCheck = {
  componentId: string,
  status: healthStatus,
  latencyMs: option<float>,
  version: option<string>,
  checkedAt: float,
}

// =============================================================================
// SEAM-5: All ↔ ArangoDB Protocol
// =============================================================================

// SEAM-5A: Document collection schema
type arangoDocument = {
  _key: string, // hash
  _id: option<string>,
  _rev: option<string>,
  content: string,
  format: string,
  path: string,
  repository: string,
  branch: string,
  createdAt: float,
  modifiedAt: float,
  metadata: Js.Dict.t<string>,
}

// SEAM-5B: Edge collection schema
type edgeType =
  | Supersedes
  | Duplicates
  | References
  | DependsOn
  | GeneratedFrom

type arangoEdge = {
  _key: option<string>,
  _id: option<string>,
  _from: string,
  _to: string,
  edgeType: edgeType,
  confidence: float,
  createdAt: float,
  metadata: Js.Dict.t<string>,
}

// SEAM-5C: Pack manifest collection schema
type packManifest = {
  _key: string,
  name: string,
  version: string,
  documents: array<string>, // document _keys
  required: array<string>,
  optional: array<string>,
  validationResult: option<{
    success: bool,
    errors: array<string>,
    warnings: array<string>,
  }>,
  createdAt: float,
  shippedTo: array<string>,
}

// SEAM-5D: Audit log collection schema
type auditLogEntry = {
  _key: string,
  component: string,
  action: string,
  entityType: string,
  entityId: string,
  userId: option<string>,
  timestamp: float,
  details: Js.Dict.t<Js.Json.t>,
  success: bool,
  errorMessage: option<string>,
}

// =============================================================================
// Serialization helpers
// =============================================================================

let documentEventToJson = (event: documentEvent): Js.Json.t => {
  Js.Json.object_(Js.Dict.fromArray([
    ("id", Js.Json.string(event.id)),
    ("eventType", Js.Json.string(switch event.eventType {
    | Created => "created"
    | Modified => "modified"
    | Deleted => "deleted"
    | Converted => "converted"
    })),
    ("hash", Js.Json.string(event.hash)),
    ("oldHash", switch event.oldHash {
    | Some(h) => Js.Json.string(h)
    | None => Js.Json.null
    }),
    ("path", Js.Json.string(event.path)),
    ("format", Js.Json.string(event.format)),
    ("timestamp", Js.Json.number(event.timestamp)),
    ("source", Js.Json.string(event.source)),
  ]))
}

let healthCheckToJson = (check: healthCheck): Js.Json.t => {
  Js.Json.object_(Js.Dict.fromArray([
    ("componentId", Js.Json.string(check.componentId)),
    ("status", Js.Json.string(switch check.status {
    | Healthy => "healthy"
    | Degraded({reason}) => `degraded: ${reason}`
    | Unhealthy({reason}) => `unhealthy: ${reason}`
    | Unknown => "unknown"
    })),
    ("latencyMs", switch check.latencyMs {
    | Some(l) => Js.Json.number(l)
    | None => Js.Json.null
    }),
    ("version", switch check.version {
    | Some(v) => Js.Json.string(v)
    | None => Js.Json.null
    }),
    ("checkedAt", Js.Json.number(check.checkedAt)),
  ]))
}

// Message queue interface
type messageQueue = {
  publish: (string, Js.Json.t) => unit,
  subscribe: (string, Js.Json.t => unit) => unit,
  unsubscribe: string => unit,
}
