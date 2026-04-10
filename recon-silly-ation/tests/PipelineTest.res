// SPDX-License-Identifier: PMPL-1.0-or-later
// PipelineTest - Unit tests for the orchestration pipeline
// Tests: createPipelineState, scanRepository, normalizeDocuments

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
// Fixture helpers
// ---------------------------------------------------------------------------

let makeMetadata = (
  ~path: string,
  ~docType: documentType=README,
  ~lastModified: float=1000.0,
  (),
): documentMetadata => {
  path,
  documentType: docType,
  lastModified,
  version: None,
  canonicalSource: Inferred,
  repository: "test/repo",
  branch: "main",
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

let run = (): (int, int) => {
  Js.Console.log("\n--- PipelineTest ---")

  // 1. createPipelineState initial stage
  test("createPipelineState starts at Scan", () => {
    let state = Pipeline.createPipelineState()
    assertEqual(state.stage, Scan, "initial stage should be Scan")
  })

  // 2. createPipelineState empty docs
  test("createPipelineState has empty documents", () => {
    let state = Pipeline.createPipelineState()
    assertEqual(Belt.Array.length(state.documents), 0, "no documents initially")
  })

  // 3. createPipelineState empty conflicts
  test("createPipelineState has empty conflicts", () => {
    let state = Pipeline.createPipelineState()
    assertEqual(Belt.Array.length(state.conflicts), 0, "no conflicts initially")
  })

  // 4. createPipelineState empty resolutions
  test("createPipelineState has empty resolutions", () => {
    let state = Pipeline.createPipelineState()
    assertEqual(Belt.Array.length(state.resolutions), 0, "no resolutions initially")
  })

  // 5. createPipelineState empty errors
  test("createPipelineState has empty errors", () => {
    let state = Pipeline.createPipelineState()
    assertEqual(Belt.Array.length(state.errors), 0, "no errors initially")
  })

  // 6. createPipelineState has startedAt
  test("createPipelineState has positive startedAt", () => {
    let state = Pipeline.createPipelineState()
    assert(state.startedAt > 0.0, "startedAt should be a positive timestamp")
  })

  // 7. createPipelineState has no completedAt
  test("createPipelineState completedAt is None", () => {
    let state = Pipeline.createPipelineState()
    switch state.completedAt {
    | None => ()
    | Some(_) => Js.Exn.raiseError("completedAt should be None initially")
    }
  })

  // 8. scanRepository on existing directory
  test("scanRepository returns Ok for existing directory", () => {
    // Use the project root itself, which should exist
    switch Pipeline.scanRepository("/var$REPOS_DIR/recon-silly-ation") {
    | Ok(_) => () // success
    | Error(msg) => Js.Exn.raiseError("expected Ok, got Error: " ++ msg)
    }
  })

  // 9. scanRepository on missing directory
  test("scanRepository handles missing directory gracefully", () => {
    // A non-existent path: scanRepository should return Ok([]) since
    // the inner scanDir checks existsSync and just returns empty
    switch Pipeline.scanRepository("/tmp/nonexistent_test_path_xyz_42") {
    | Ok(docs) => assertEqual(Belt.Array.length(docs), 0, "no docs for missing path")
    | Error(_) => () // Also acceptable
    }
  })

  // 10. normalizeDocuments count preservation
  test("normalizeDocuments preserves document count", () => {
    let d1 = Deduplicator.createDocument("# A", makeMetadata(~path="a.md", ()))
    let d2 = Deduplicator.createDocument("# B", makeMetadata(~path="b.md", ()))
    let d3 = Deduplicator.createDocument("# C", makeMetadata(~path="c.md", ()))
    let result = Pipeline.normalizeDocuments([d1, d2, d3])
    assertEqual(Belt.Array.length(result), 3, "normalise should not change count")
  })

  // 11. normalizeDocuments empty
  test("normalizeDocuments on empty returns empty", () => {
    let result = Pipeline.normalizeDocuments([])
    assertEqual(Belt.Array.length(result), 0, "empty in empty out")
  })

  // 12. normalizeDocuments preserves hashes
  test("normalizeDocuments preserves existing hashes", () => {
    let doc = Deduplicator.createDocument("content", makeMetadata(~path="x.md", ()))
    let hashBefore = doc.hash
    let result = Pipeline.normalizeDocuments([doc])
    let hashAfter = (Belt.Array.getUnsafe(result, 0)).hash
    assertEqual(hashBefore, hashAfter, "hash should not change after normalise")
  })

  // 13. pipeline stage toString round-trip coverage
  test("all pipeline stages have string representation", () => {
    let stages: array<pipelineStage> = [
      Scan,
      Normalize,
      Deduplicate,
      DetectConflicts,
      ResolveConflicts,
      Ingest,
      Report,
    ]
    stages->Belt.Array.forEach(stage => {
      let str = pipelineStageToString(stage)
      assert(Js.String2.length(str) > 0, "stage toString must be non-empty")
    })
  })

  // 14. scanRepository finds docs in project directory
  test("scanRepository finds at least one doc in project root", () => {
    switch Pipeline.scanRepository("/var$REPOS_DIR/recon-silly-ation") {
    | Ok(docs) =>
      // The project root should have README, LICENSE, SECURITY, etc.
      assert(Belt.Array.length(docs) >= 1, "should find at least 1 doc file")
    | Error(_) => Js.Exn.raiseError("expected Ok for existing directory")
    }
  })

  // 15. createPipelineState two calls produce independent states
  test("createPipelineState produces independent states", () => {
    let s1 = Pipeline.createPipelineState()
    let s2 = Pipeline.createPipelineState()
    // They should both start at Scan and be independent objects
    assertEqual(s1.stage, s2.stage, "both should start at Scan")
    assertEqual(Belt.Array.length(s1.documents), 0, "s1 empty")
    assertEqual(Belt.Array.length(s2.documents), 0, "s2 empty")
  })

  (passed.contents, failed.contents)
}
