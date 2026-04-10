// SPDX-License-Identifier: PMPL-1.0-or-later
//
// EnforcementBot - Automated document bundle enforcement and cleanup
//
// This module provides scheduled enforcement of document policies using
// ReconForth rules. It integrates with the reconciliation pipeline to
// automatically detect and report violations.

open Types

// ============================================================================
// Types
// ============================================================================

// Enforcement rule with schedule
type enforcementRule = {
  name: string,
  description: string,
  reconforthCode: string,
  severity: string, // "error" | "warning" | "info"
  autoFix: bool,
  fixAction: option<string>, // ReconForth code to apply fix
}

// Enforcement schedule
type schedule =
  | Immediate
  | Interval(int) // seconds
  | Cron(string) // cron expression
  | OnPush // git push hook
  | OnPR // pull request check

// Enforcement job
type enforcementJob = {
  id: string,
  rule: enforcementRule,
  schedule: schedule,
  repository: string,
  branch: option<string>,
  lastRun: option<float>,
  nextRun: option<float>,
  enabled: bool,
}

// Enforcement result
type enforcementResult = {
  jobId: string,
  ruleName: string,
  repository: string,
  timestamp: float,
  passed: bool,
  violations: array<ReconForth.validationMessage>,
  fixesApplied: array<string>,
}

// Bot state
type botState = {
  jobs: array<enforcementJob>,
  results: array<enforcementResult>,
  running: bool,
}

// ============================================================================
// Standard Enforcement Rules
// ============================================================================

// RSR (Rhodium Standard Repositories) compliance
let rsrComplianceRule: enforcementRule = {
  name: "rsr-compliance",
  description: "Ensure repository follows Rhodium Standard Repositories guidelines",
  reconforthCode: `
    -- Check required files
    "README" bundle-has-type? not
    [ "Missing README file (RSR requirement)" error! ] when

    "LICENSE" bundle-has-type? not
    [ "Missing LICENSE file (RSR requirement)" error! ] when

    "SECURITY" bundle-has-type? not
    [ "Missing SECURITY.md (RSR requirement)" error! ] when

    -- Check for banned patterns
    bundle-docs [
      dup doc-path ".ts" str-ends?
      [ doc-path " is TypeScript - use ReScript per RSR" error! ] when
    ] each

    -- Check SPDX headers
    bundle-docs [
      dup doc-path ".res" str-ends?
      over doc-path ".rs" str-ends? or
      [
        dup doc-content "SPDX-License-Identifier" str-contains? not
        [ doc-path " missing SPDX header" error! ] when
      ] when
    ] each
  `,
  severity: "error",
  autoFix: false,
  fixAction: None,
}

// License compliance
let licenseComplianceRule: enforcementRule = {
  name: "license-pmpl",
  description: "Ensure PMPL-1.0-or-later (Palimpsest) license is used",
  reconforthCode: `
    "LICENSE" bundle-get-type nil <>
    [
      "LICENSE" bundle-get-type doc-content
      dup "Palimpsest" str-contains? not
      [ drop "License must be PMPL-1.0-or-later (Palimpsest)" error! ]
      [
        "1.0" str-contains? not
        [ "License should specify version 1.0" warn! ] when
      ]
      if
    ]
    [ "Missing LICENSE file" error! ]
    if
  `,
  severity: "error",
  autoFix: false,
  fixAction: None,
}

// Documentation quality
let docQualityRule: enforcementRule = {
  name: "doc-quality",
  description: "Check documentation quality and completeness",
  reconforthCode: `
    "README" bundle-get-type nil <>
    [
      "README" bundle-get-type doc-content

      -- Check minimum length
      dup str-len 200 <
      [ "README is too short (< 200 chars)" warn! ] when

      -- Check for sections
      dup "## " str-contains? not
      [ "README should have sections" suggest! ] when

      -- Check for badges
      dup "![" str-contains? not
      [ "Consider adding badges to README" suggest! ] when

      drop
    ]
    [ "Missing README" error! ]
    if
  `,
  severity: "warning",
  autoFix: false,
  fixAction: None,
}

// Security policy check
let securityPolicyRule: enforcementRule = {
  name: "security-policy",
  description: "Verify security policy exists and is complete",
  reconforthCode: `
    "SECURITY" bundle-get-type nil <>
    [
      "SECURITY" bundle-get-type doc-content

      -- Check for vulnerability reporting section
      dup "vulnerabilit" str-lower str-contains? not
      [ "SECURITY.md should describe vulnerability reporting" warn! ] when

      -- Check for contact info
      dup "@" str-contains? not
      over "email" str-lower str-contains? not and
      [ "SECURITY.md should include contact information" warn! ] when

      drop
    ]
    [ "Missing SECURITY.md" error! ]
    if
  `,
  severity: "error",
  autoFix: false,
  fixAction: None,
}

// SCM files check (STATE.scm, META.scm, ECOSYSTEM.scm)
let scmFilesRule: enforcementRule = {
  name: "scm-files",
  description: "Check for Guile Scheme checkpoint files",
  reconforthCode: `
    -- Check for STATE.scm
    bundle-docs [ doc-path "STATE.scm" str-ends? ] filter
    list-len 0 =
    [ "Missing STATE.scm checkpoint file" warn! ] when

    -- Check for META.scm
    bundle-docs [ doc-path "META.scm" str-ends? ] filter
    list-len 0 =
    [ "Missing META.scm checkpoint file" suggest! ] when

    -- Check for ECOSYSTEM.scm
    bundle-docs [ doc-path "ECOSYSTEM.scm" str-ends? ] filter
    list-len 0 =
    [ "Missing ECOSYSTEM.scm checkpoint file" suggest! ] when
  `,
  severity: "warning",
  autoFix: false,
  fixAction: None,
}

// ============================================================================
// Bot Operations
// ============================================================================

// Create initial bot state
let createBotState = (): botState => {
  {
    jobs: [],
    results: [],
    running: false,
  }
}

// Add a job to the bot
let addJob = (
  state: botState,
  rule: enforcementRule,
  schedule: schedule,
  repository: string,
  ~branch: option<string>=?,
  (),
): botState => {
  let job: enforcementJob = {
    id: `job-${Js.Date.now()->Float.toString}`,
    rule,
    schedule,
    repository,
    branch,
    lastRun: None,
    nextRun: Some(Js.Date.now()),
    enabled: true,
  }
  {
    ...state,
    jobs: Belt.Array.concat(state.jobs, [job]),
  }
}

// Remove a job from the bot
let removeJob = (state: botState, jobId: string): botState => {
  {
    ...state,
    jobs: state.jobs->Belt.Array.keep(j => j.id != jobId),
  }
}

// Enable/disable a job
let setJobEnabled = (state: botState, jobId: string, enabled: bool): botState => {
  {
    ...state,
    jobs: state.jobs->Belt.Array.map(j =>
      if j.id == jobId {
        {...j, enabled}
      } else {
        j
      }
    ),
  }
}

// Run a single enforcement job
let runJob = (job: enforcementJob, bundle: ReconForth.bundle): enforcementResult => {
  let result = ReconForth.evalBundle(job.rule.reconforthCode, bundle)

  {
    jobId: job.id,
    ruleName: job.rule.name,
    repository: job.repository,
    timestamp: Js.Date.now(),
    passed: result.success,
    violations: Belt.Array.concat(result.errors, result.warnings),
    fixesApplied: [],
  }
}

// Run all enabled jobs
let runAllJobs = (state: botState, bundleProvider: string => ReconForth.bundle): botState => {
  let results = state.jobs
    ->Belt.Array.keep(j => j.enabled)
    ->Belt.Array.map(job => {
      let bundle = bundleProvider(job.repository)
      runJob(job, bundle)
    })

  let updatedJobs = state.jobs->Belt.Array.map(j => {
    if j.enabled {
      {
        ...j,
        lastRun: Some(Js.Date.now()),
        nextRun: switch j.schedule {
        | Immediate => None
        | Interval(seconds) => Some(Js.Date.now() +. Float.fromInt(seconds * 1000))
        | Cron(_) => Some(Js.Date.now() +. 3600000.0) // Placeholder: 1 hour
        | OnPush => None
        | OnPR => None
        },
      }
    } else {
      j
    }
  })

  {
    ...state,
    jobs: updatedJobs,
    results: Belt.Array.concat(state.results, results),
  }
}

// Get all violations from recent results
let getViolations = (state: botState): array<ReconForth.validationMessage> => {
  state.results
  ->Belt.Array.keep(r => !r.passed)
  ->Belt.Array.flatMap(r => r.violations)
}

// Generate enforcement report
let generateReport = (state: botState): string => {
  let totalJobs = Belt.Array.length(state.jobs)
  let enabledJobs = state.jobs->Belt.Array.keep(j => j.enabled)->Belt.Array.length
  let passedResults = state.results->Belt.Array.keep(r => r.passed)->Belt.Array.length
  let failedResults = state.results->Belt.Array.keep(r => !r.passed)->Belt.Array.length
  let totalViolations = getViolations(state)->Belt.Array.length

  `# Enforcement Report

## Summary
- Total Jobs: ${Int.toString(totalJobs)}
- Enabled Jobs: ${Int.toString(enabledJobs)}
- Passed: ${Int.toString(passedResults)}
- Failed: ${Int.toString(failedResults)}
- Total Violations: ${Int.toString(totalViolations)}

## Job Details
${state.jobs
    ->Belt.Array.map(j =>
      `- ${j.rule.name} (${j.enabled ? "enabled" : "disabled"})
  Repository: ${j.repository}
  Last Run: ${j.lastRun->Belt.Option.mapWithDefault("never", f => Float.toString(f))}`
    )
    ->Belt.Array.joinWith("\n")}

## Recent Violations
${state.results
    ->Belt.Array.keep(r => !r.passed)
    ->Belt.Array.flatMap(r => r.violations)
    ->Belt.Array.map(v => `- ${v.message}`)
    ->Belt.Array.joinWith("\n")}
`
}

// ============================================================================
// Preset Configurations
// ============================================================================

// Create bot with all standard RSR rules
let createRsrBot = (): botState => {
  let state = createBotState()
  let state = addJob(state, rsrComplianceRule, Interval(3600), "*", ())
  let state = addJob(state, licenseComplianceRule, OnPR, "*", ())
  let state = addJob(state, docQualityRule, Interval(86400), "*", ())
  let state = addJob(state, securityPolicyRule, OnPR, "*", ())
  let state = addJob(state, scmFilesRule, Interval(86400), "*", ())
  state
}

// Create minimal enforcement bot
let createMinimalBot = (): botState => {
  let state = createBotState()
  let state = addJob(state, rsrComplianceRule, OnPR, "*", ())
  let state = addJob(state, licenseComplianceRule, OnPR, "*", ())
  state
}
