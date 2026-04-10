// SPDX-License-Identifier: PMPL-1.0-or-later
// TypesTest - Unit tests for core domain types
// Tests: documentTypeToString/fromString roundtrips, version comparison,
// versionToString, edgeTypeToString, resolutionStrategyToString, pipelineStageToString

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
  Js.Console.log("\n--- TypesTest ---")

  // 1. documentType round-trips
  test("documentTypeToString README", () => {
    assertEqual(documentTypeToString(README), "README", "expected README")
  })

  test("documentTypeFromString README", () => {
    assertEqual(documentTypeFromString("README"), README, "expected README variant")
  })

  test("documentType round-trip LICENSE", () => {
    let dt = LICENSE
    assertEqual(documentTypeFromString(documentTypeToString(dt)), dt, "LICENSE round-trip")
  })

  test("documentType round-trip SECURITY", () => {
    let dt = SECURITY
    assertEqual(documentTypeFromString(documentTypeToString(dt)), dt, "SECURITY round-trip")
  })

  test("documentType round-trip CONTRIBUTING", () => {
    assertEqual(
      documentTypeFromString(documentTypeToString(CONTRIBUTING)),
      CONTRIBUTING,
      "CONTRIBUTING round-trip",
    )
  })

  test("documentType round-trip CODE_OF_CONDUCT", () => {
    assertEqual(
      documentTypeFromString(documentTypeToString(CODE_OF_CONDUCT)),
      CODE_OF_CONDUCT,
      "CODE_OF_CONDUCT round-trip",
    )
  })

  test("documentType round-trip FUNDING", () => {
    assertEqual(
      documentTypeFromString(documentTypeToString(FUNDING)),
      FUNDING,
      "FUNDING round-trip",
    )
  })

  test("documentType round-trip CITATION", () => {
    assertEqual(
      documentTypeFromString(documentTypeToString(CITATION)),
      CITATION,
      "CITATION round-trip",
    )
  })

  test("documentType Custom round-trip", () => {
    let dt = Custom("MY_DOC")
    assertEqual(documentTypeFromString(documentTypeToString(dt)), dt, "Custom round-trip")
  })

  // 2. Version comparison
  test("compareVersions equal", () => {
    let v = {major: 1, minor: 2, patch: 3}
    assertEqual(compareVersions(v, v), 0, "equal versions should be 0")
  })

  test("compareVersions major differs", () => {
    let v1 = {major: 2, minor: 0, patch: 0}
    let v2 = {major: 1, minor: 9, patch: 9}
    assert(compareVersions(v1, v2) > 0, "2.0.0 > 1.9.9")
  })

  test("compareVersions minor differs", () => {
    let v1 = {major: 1, minor: 3, patch: 0}
    let v2 = {major: 1, minor: 2, patch: 9}
    assert(compareVersions(v1, v2) > 0, "1.3.0 > 1.2.9")
  })

  test("compareVersions patch differs", () => {
    let v1 = {major: 1, minor: 0, patch: 5}
    let v2 = {major: 1, minor: 0, patch: 3}
    assert(compareVersions(v1, v2) > 0, "1.0.5 > 1.0.3")
  })

  test("compareVersions transitivity", () => {
    let a = {major: 1, minor: 0, patch: 0}
    let b = {major: 1, minor: 1, patch: 0}
    let c = {major: 2, minor: 0, patch: 0}
    assert(
      compareVersions(a, b) < 0 && compareVersions(b, c) < 0 && compareVersions(a, c) < 0,
      "version comparison transitivity a < b < c => a < c",
    )
  })

  // 3. versionToString
  test("versionToString basic", () => {
    let v = {major: 3, minor: 14, patch: 159}
    assertEqual(versionToString(v), "3.14.159", "expected 3.14.159")
  })

  test("versionToString zeroes", () => {
    let v = {major: 0, minor: 0, patch: 0}
    assertEqual(versionToString(v), "0.0.0", "expected 0.0.0")
  })

  // 4. edgeTypeToString
  test("edgeTypeToString ConflictsWith", () => {
    assertEqual(edgeTypeToString(ConflictsWith), "conflicts_with", "expected conflicts_with")
  })

  test("edgeTypeToString DuplicateOf", () => {
    assertEqual(edgeTypeToString(DuplicateOf), "duplicate_of", "expected duplicate_of")
  })

  test("edgeTypeToString SupersededBy", () => {
    assertEqual(edgeTypeToString(SupersededBy), "superseded_by", "expected superseded_by")
  })

  // 5. resolutionStrategyToString
  test("resolutionStrategyToString KeepLatest", () => {
    assertEqual(resolutionStrategyToString(KeepLatest), "keep_latest", "expected keep_latest")
  })

  test("resolutionStrategyToString RequireManual", () => {
    assertEqual(
      resolutionStrategyToString(RequireManual),
      "require_manual",
      "expected require_manual",
    )
  })

  // 6. pipelineStageToString
  test("pipelineStageToString Scan", () => {
    assertEqual(pipelineStageToString(Scan), "scan", "expected scan")
  })

  test("pipelineStageToString Report", () => {
    assertEqual(pipelineStageToString(Report), "report", "expected report")
  })

  (passed.contents, failed.contents)
}
