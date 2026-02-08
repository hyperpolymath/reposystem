// SPDX-License-Identifier: PMPL-1.0-or-later
// Audit.res - Audit logging types

// Audit event type
type eventType =
  | PlanLoaded
  | PlanValidated
  | ExecutionStarted
  | OperationStarted
  | OperationCompleted
  | OperationFailed
  | BotDispatched
  | BotResponseReceived
  | RollbackTriggered
  | RollbackCompleted
  | ExecutionCompleted
  | ExecutionFailed

// Audit entry
type auditEntry = {
  id: string,
  timestamp: string, // ISO 8601
  eventType: eventType,
  planId: string,
  operationId: option<string>,
  botDispatchId: option<string>,
  actor: string, // Who/what triggered this (user, system, bot)
  details: Js.Dict.t<string>,
  metadata: Js.Dict.t<string>,
}

// Audit trace (collection of related entries)
type auditTrace = {
  traceId: string,
  planId: string,
  startedAt: string,
  completedAt: option<string>,
  entries: array<auditEntry>,
  summary: Js.Dict.t<string>,
}

// Audit query filter
type auditFilter = {
  planId: option<string>,
  eventType: option<eventType>,
  startDate: option<string>,
  endDate: option<string>,
  limit: int,
}

// Helper functions
let eventTypeToString = eventType =>
  switch eventType {
  | PlanLoaded => "PlanLoaded"
  | PlanValidated => "PlanValidated"
  | ExecutionStarted => "ExecutionStarted"
  | OperationStarted => "OperationStarted"
  | OperationCompleted => "OperationCompleted"
  | OperationFailed => "OperationFailed"
  | BotDispatched => "BotDispatched"
  | BotResponseReceived => "BotResponseReceived"
  | RollbackTriggered => "RollbackTriggered"
  | RollbackCompleted => "RollbackCompleted"
  | ExecutionCompleted => "ExecutionCompleted"
  | ExecutionFailed => "ExecutionFailed"
  }

let eventTypeFromString = str =>
  switch str {
  | "PlanLoaded" => Some(PlanLoaded)
  | "PlanValidated" => Some(PlanValidated)
  | "ExecutionStarted" => Some(ExecutionStarted)
  | "OperationStarted" => Some(OperationStarted)
  | "OperationCompleted" => Some(OperationCompleted)
  | "OperationFailed" => Some(OperationFailed)
  | "BotDispatched" => Some(BotDispatched)
  | "BotResponseReceived" => Some(BotResponseReceived)
  | "RollbackTriggered" => Some(RollbackTriggered)
  | "RollbackCompleted" => Some(RollbackCompleted)
  | "ExecutionCompleted" => Some(ExecutionCompleted)
  | "ExecutionFailed" => Some(ExecutionFailed)
  | _ => None
  }

// Create audit entry
let createEntry = (
  ~eventType: eventType,
  ~planId: string,
  ~operationId: option<string>=?,
  ~botDispatchId: option<string>=?,
  ~actor: string,
  ~details: Js.Dict.t<string>,
  ~metadata: Js.Dict.t<string>=Js.Dict.empty(),
  (),
): auditEntry => {
  id: Js.Date.now()->Float.toString ++ "-" ++ Js.Math.random()->Float.toString,
  timestamp: Js.Date.make()->Js.Date.toISOString,
  eventType,
  planId,
  operationId,
  botDispatchId,
  actor,
  details,
  metadata,
}
