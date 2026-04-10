// SPDX-License-Identifier: PMPL-1.0-or-later
// EnforcementBotTest - Unit tests for the enforcement bot
// Tests: createBotState, addJob, removeJob, setJobEnabled,
// rule names, createRsrBot, createMinimalBot

open Types

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

let passed = ref(0)
let failed = ref(0)

let test = (name: string, fn: unit => unit): unit => {
  try {
    fn()
    passed := passed.contents + 1
    Js.Console.log(`  PASS ${name}`)
  } catch {
  | _ => {
      failed := failed.contents + 1
      Js.Console.error(`  FAIL ${name}`)
    }
  }
}

let assert = (cond: bool, msg: string): unit => {
  if !cond {
    Js.Exn.raiseError(msg)
  }
}

let assertEqual = (a: 'a, b: 'a, msg: string): unit => {
  if a != b {
    Js.Exn.raiseError(msg)
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

let run = (): (int, int) => {
  Js.Console.log("\n--- EnforcementBotTest ---")

  // 1. createBotState empty
  test("createBotState has empty jobs", () => {
    let state = EnforcementBot.createBotState()
    assertEqual(Belt.Array.length(state.jobs), 0, "jobs should be empty")
  })

  // 2. createBotState empty results
  test("createBotState has empty results", () => {
    let state = EnforcementBot.createBotState()
    assertEqual(Belt.Array.length(state.results), 0, "results should be empty")
  })

  // 3. createBotState not running
  test("createBotState is not running", () => {
    let state = EnforcementBot.createBotState()
    assertEqual(state.running, false, "should not be running")
  })

  // 4. addJob increases job count
  test("addJob increases job count", () => {
    let state = EnforcementBot.createBotState()
    let state = EnforcementBot.addJob(
      state,
      EnforcementBot.rsrComplianceRule,
      EnforcementBot.Immediate,
      "test/repo",
      (),
    )
    assertEqual(Belt.Array.length(state.jobs), 1, "should have 1 job")
  })

  // 5. addJob job is enabled by default
  test("addJob creates enabled job", () => {
    let state = EnforcementBot.createBotState()
    let state = EnforcementBot.addJob(
      state,
      EnforcementBot.rsrComplianceRule,
      EnforcementBot.Immediate,
      "test/repo",
      (),
    )
    let job = Belt.Array.getUnsafe(state.jobs, 0)
    assertEqual(job.enabled, true, "job should be enabled by default")
  })

  // 6. removeJob decreases job count
  test("removeJob removes the specified job", () => {
    let state = EnforcementBot.createBotState()
    let state = EnforcementBot.addJob(
      state,
      EnforcementBot.rsrComplianceRule,
      EnforcementBot.Immediate,
      "test/repo",
      (),
    )
    let jobId = (Belt.Array.getUnsafe(state.jobs, 0)).id
    let state = EnforcementBot.removeJob(state, jobId)
    assertEqual(Belt.Array.length(state.jobs), 0, "job should be removed")
  })

  // 7. setJobEnabled disables job
  test("setJobEnabled disables a job", () => {
    let state = EnforcementBot.createBotState()
    let state = EnforcementBot.addJob(
      state,
      EnforcementBot.rsrComplianceRule,
      EnforcementBot.Immediate,
      "test/repo",
      (),
    )
    let jobId = (Belt.Array.getUnsafe(state.jobs, 0)).id
    let state = EnforcementBot.setJobEnabled(state, jobId, false)
    let job = Belt.Array.getUnsafe(state.jobs, 0)
    assertEqual(job.enabled, false, "job should be disabled")
  })

  // 8. setJobEnabled re-enables job
  test("setJobEnabled re-enables a job", () => {
    let state = EnforcementBot.createBotState()
    let state = EnforcementBot.addJob(
      state,
      EnforcementBot.rsrComplianceRule,
      EnforcementBot.Immediate,
      "test/repo",
      (),
    )
    let jobId = (Belt.Array.getUnsafe(state.jobs, 0)).id
    let state = EnforcementBot.setJobEnabled(state, jobId, false)
    let state = EnforcementBot.setJobEnabled(state, jobId, true)
    let job = Belt.Array.getUnsafe(state.jobs, 0)
    assertEqual(job.enabled, true, "job should be re-enabled")
  })

  // 9. license-pmpl rule name
  test("licenseComplianceRule has name license-pmpl", () => {
    assertEqual(
      EnforcementBot.licenseComplianceRule.name,
      "license-pmpl",
      "rule name should be license-pmpl",
    )
  })

  // 10. rsrComplianceRule name
  test("rsrComplianceRule has name rsr-compliance", () => {
    assertEqual(
      EnforcementBot.rsrComplianceRule.name,
      "rsr-compliance",
      "rule name should be rsr-compliance",
    )
  })

  // 11. createRsrBot has 5 rules
  test("createRsrBot has 5 jobs", () => {
    let state = EnforcementBot.createRsrBot()
    assertEqual(Belt.Array.length(state.jobs), 5, "RSR bot should have 5 jobs")
  })

  // 12. createMinimalBot has 2 rules
  test("createMinimalBot has 2 jobs", () => {
    let state = EnforcementBot.createMinimalBot()
    assertEqual(Belt.Array.length(state.jobs), 2, "minimal bot should have 2 jobs")
  })

  // 13. createRsrBot all jobs are enabled
  test("createRsrBot all jobs enabled", () => {
    let state = EnforcementBot.createRsrBot()
    let allEnabled = state.jobs->Belt.Array.every(j => j.enabled)
    assert(allEnabled, "all RSR bot jobs should be enabled")
  })

  // 14. removeJob non-existent id is no-op
  test("removeJob with non-existent id is no-op", () => {
    let state = EnforcementBot.createRsrBot()
    let before = Belt.Array.length(state.jobs)
    let state = EnforcementBot.removeJob(state, "nonexistent-id-xyz")
    let after = Belt.Array.length(state.jobs)
    assertEqual(before, after, "count should not change")
  })

  (passed.contents, failed.contents)
}
