// SPDX-License-Identifier: PMPL-1.0-or-later
// IntegrationTest - End-to-end integration tests
// Tests: full pipeline flow (create -> dedup -> detect -> resolve -> report),
// normalisation+dedup idempotency, fixture-based scenarios

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
// Fixture data
// ---------------------------------------------------------------------------

let makeMetadata = (
  ~path: string,
  ~docType: documentType=README,
  ~lastModified: float=1000.0,
  ~version: option<version>=None,
  ~canonicalSource: canonicalSource=Inferred,
  (),
): documentMetadata => {
  path,
  documentType: docType,
  lastModified,
  version,
  canonicalSource,
  repository: "test/repo",
  branch: "main",
}

let fixtureReadme = "# My Project\n\nA documentation reconciliation tool.\n\n## Features\n\n- Deduplication\n- Conflict resolution\n- Graph storage"

let fixtureLicense = "Palimpsest License (PMPL-1.0-or-later)\n\nCopyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)\n\nPermission is hereby granted..."

let fixtureSecurity = "# Security Policy\n\n## Supported Versions\n\n| Version | Supported |\n|---|---|\n| 1.x | Yes |\n\n## Reporting a Vulnerability\n\nPlease email j.d.a.jewell@open.ac.uk"

let fixtureContributing = "# Contributing\n\nWe welcome contributions!\n\n## Process\n\n1. Fork the repository\n2. Create a branch\n3. Submit a PR"

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

let run = (): (int, int) => {
  Js.Console.log("\n--- IntegrationTest ---")

  // 1. End-to-end: create documents
  test("e2e: create documents from fixtures", () => {
    let docs = [
      Deduplicator.createDocument(
        fixtureReadme,
        makeMetadata(~path="README.md", ()),
      ),
      Deduplicator.createDocument(
        fixtureLicense,
        makeMetadata(~path="LICENSE", ~docType=LICENSE, ~canonicalSource=LicenseFile, ()),
      ),
      Deduplicator.createDocument(
        fixtureSecurity,
        makeMetadata(~path="SECURITY.md", ~docType=SECURITY, ~canonicalSource=SecurityMd, ()),
      ),
      Deduplicator.createDocument(
        fixtureContributing,
        makeMetadata(~path="CONTRIBUTING.md", ~docType=CONTRIBUTING, ()),
      ),
    ]
    assertEqual(Belt.Array.length(docs), 4, "should create 4 documents")
    docs->Belt.Array.forEach(doc => {
      assert(Js.String2.length(doc.hash) > 0, "each doc should have a hash")
    })
  })

  // 2. End-to-end: dedup unique fixture docs
  test("e2e: dedup unique fixtures yields no duplicates", () => {
    let docs = [
      Deduplicator.createDocument(fixtureReadme, makeMetadata(~path="README.md", ())),
      Deduplicator.createDocument(fixtureLicense, makeMetadata(~path="LICENSE", ~docType=LICENSE, ())),
      Deduplicator.createDocument(fixtureSecurity, makeMetadata(~path="SECURITY.md", ~docType=SECURITY, ())),
    ]
    let result = Deduplicator.deduplicate(docs)
    assertEqual(result.stats.duplicateCount, 0, "no duplicates in unique fixtures")
    assertEqual(result.stats.uniqueCount, 3, "all 3 unique")
  })

  // 3. End-to-end: dedup with duplicate README
  test("e2e: dedup detects duplicate README", () => {
    let docs = [
      Deduplicator.createDocument(fixtureReadme, makeMetadata(~path="README.md", ())),
      Deduplicator.createDocument(fixtureReadme, makeMetadata(~path="docs/README.md", ())),
      Deduplicator.createDocument(fixtureLicense, makeMetadata(~path="LICENSE", ~docType=LICENSE, ())),
    ]
    let result = Deduplicator.deduplicate(docs)
    assertEqual(result.stats.duplicateCount, 1, "one duplicate README")
    assertEqual(result.stats.uniqueCount, 2, "2 unique docs")
  })

  // 4. End-to-end: detect conflicts from duplicates
  test("e2e: detect conflicts from duplicate docs", () => {
    let docs = [
      Deduplicator.createDocument(fixtureReadme, makeMetadata(~path="README.md", ~lastModified=1000.0, ())),
      Deduplicator.createDocument(fixtureReadme, makeMetadata(~path="docs/README.md", ~lastModified=2000.0, ())),
    ]
    let conflicts = ConflictResolver.detectConflicts(docs)
    assert(Belt.Array.length(conflicts) > 0, "should detect duplicate conflict")
  })

  // 5. End-to-end: resolve duplicate conflict
  test("e2e: resolve duplicate picks latest", () => {
    let docs = [
      Deduplicator.createDocument(fixtureReadme, makeMetadata(~path="old/README.md", ~lastModified=1000.0, ())),
      Deduplicator.createDocument(fixtureReadme, makeMetadata(~path="new/README.md", ~lastModified=5000.0, ())),
    ]
    let conflicts = ConflictResolver.detectConflicts(docs)
    let resolutions = ConflictResolver.resolveConflicts(conflicts, 0.9)
    assert(Belt.Array.length(resolutions) > 0, "should have resolutions")
    let res = Belt.Array.getUnsafe(resolutions, 0)
    switch res.selectedDocument {
    | Some(doc) =>
      assertEqual(doc.metadata.path, "new/README.md", "latest doc should win")
    | None => Js.Exn.raiseError("expected selected document")
    }
  })

  // 6. End-to-end: generate report
  test("e2e: generate conflict report", () => {
    let docs = [
      Deduplicator.createDocument(fixtureReadme, makeMetadata(~path="a.md", ())),
      Deduplicator.createDocument(fixtureReadme, makeMetadata(~path="b.md", ())),
    ]
    let conflicts = ConflictResolver.detectConflicts(docs)
    let resolutions = ConflictResolver.resolveConflicts(conflicts, 0.9)
    let report = ConflictResolver.generateReport(resolutions, conflicts)
    assert(Js.String2.length(report) > 0, "report must not be empty")
    assert(
      Js.String2.includes(report, "Conflict Resolution Report"),
      "report must contain header",
    )
  })

  // 7. Normalisation -> dedup idempotency
  test("normalise -> dedup is idempotent", () => {
    let rawContent = "# Hello\r\n\r\n\r\n\r\nWorld   \n  trailing  "
    let doc1 = Deduplicator.createDocument(rawContent, makeMetadata(~path="a.md", ()))
    let doc2 = Deduplicator.createDocument(rawContent, makeMetadata(~path="b.md", ()))
    // Both should normalise identically
    assert(Deduplicator.isDuplicate(doc1, doc2), "same raw content should be duplicates")
    // Normalise again and dedup
    let normalized = Pipeline.normalizeDocuments([doc1, doc2])
    let result = Deduplicator.deduplicate(normalized)
    assertEqual(result.stats.duplicateCount, 1, "still one duplicate after normalise")
  })

  // 8. Full pipeline: create -> dedup -> conflict -> resolve -> edge
  test("e2e: full pipeline produces edges", () => {
    let docs = [
      Deduplicator.createDocument(fixtureReadme, makeMetadata(~path="a/README.md", ~lastModified=100.0, ())),
      Deduplicator.createDocument(fixtureReadme, makeMetadata(~path="b/README.md", ~lastModified=200.0, ())),
      Deduplicator.createDocument(fixtureLicense, makeMetadata(~path="LICENSE", ~docType=LICENSE, ())),
    ]

    // Dedup
    let dedupResult = Deduplicator.deduplicate(docs)
    let dupEdges = Deduplicator.createDuplicateEdges(dedupResult.duplicates)
    assert(Belt.Array.length(dupEdges) >= 1, "should have duplicate edges")

    // Detect conflicts on all docs
    let conflicts = ConflictResolver.detectConflicts(docs)

    // Resolve
    let resolutions = ConflictResolver.resolveConflicts(conflicts, 0.9)
    let supersededEdges = ConflictResolver.createSupersededEdges(resolutions)

    // Total edges
    let totalEdges = Belt.Array.length(dupEdges) + Belt.Array.length(supersededEdges)
    assert(totalEdges >= 1, "should produce at least 1 total edge")
  })

  // 9. Graph visualisation from pipeline output
  test("e2e: graph visualisation from pipeline output", () => {
    let docs = [
      Deduplicator.createDocument(fixtureReadme, makeMetadata(~path="README.md", ())),
      Deduplicator.createDocument(fixtureLicense, makeMetadata(~path="LICENSE", ~docType=LICENSE, ())),
    ]
    let edges = Deduplicator.createDuplicateEdges([])
    let dot = GraphVisualizer.generateDot(docs, edges, GraphVisualizer.defaultConfig)
    assert(Js.String2.includes(dot, "digraph"), "DOT output should be valid")
  })

  // 10. Logic engine integration with pipeline docs
  test("e2e: logic engine infers relationships from pipeline docs", () => {
    let docs = [
      Deduplicator.createDocument(fixtureReadme, makeMetadata(~path="a.md", ())),
      Deduplicator.createDocument(fixtureReadme, makeMetadata(~path="b.md", ())),
    ]
    let rels = LogicEngine.inferRelationships(docs)
    assert(Belt.Array.length(rels) > 0, "should infer duplicate relationship")
  })

  // 11. CCCP compliance in pipeline context
  test("e2e: CCCP compliance on non-Python docs", () => {
    assert(!CCCPCompliance.isPythonFile("README.md"), "README.md is not Python")
    assert(!CCCPCompliance.isPythonFile("LICENSE"), "LICENSE is not Python")
  })

  // 12. Version conflict end-to-end
  test("e2e: version conflict detection and resolution", () => {
    let v1 = {major: 1, minor: 0, patch: 0}
    let v2 = {major: 2, minor: 0, patch: 0}
    let d1 = Deduplicator.createDocument(
      "Version 1 content",
      makeMetadata(~path="doc-v1.md", ~version=Some(v1), ()),
    )
    let d2 = Deduplicator.createDocument(
      "Version 2 content",
      makeMetadata(~path="doc-v2.md", ~version=Some(v2), ()),
    )
    let conflicts = ConflictResolver.detectConflicts([d1, d2])
    let versionConflicts = conflicts->Belt.Array.keep(c => c.conflictType == VersionMismatch)
    assert(Belt.Array.length(versionConflicts) > 0, "should detect version conflict")
    let resolutions = ConflictResolver.resolveConflicts(versionConflicts, 0.5)
    assert(Belt.Array.length(resolutions) > 0, "should resolve version conflict")
  })

  // 13. Canonical conflict end-to-end
  test("e2e: canonical conflict resolution", () => {
    let d1 = Deduplicator.createDocument(
      "License A",
      makeMetadata(~path="LICENSE", ~docType=LICENSE, ~canonicalSource=LicenseFile, ()),
    )
    let d2 = Deduplicator.createDocument(
      "License B",
      makeMetadata(~path="pkg/license", ~docType=LICENSE, ~canonicalSource=CargoToml, ()),
    )
    let conflicts = ConflictResolver.detectConflicts([d1, d2])
    let canonConflicts = conflicts->Belt.Array.keep(c => c.conflictType == CanonicalConflict)
    assert(Belt.Array.length(canonConflicts) > 0, "should detect canonical conflict")
  })

  // 14. ArangoDB serialisation in pipeline context
  test("e2e: document serialisation for ArangoDB", () => {
    let doc = Deduplicator.createDocument(fixtureReadme, makeMetadata(~path="README.md", ()))
    let json = ArangoClient.documentToJson(doc)
    let str = Js.Json.stringify(json)
    assert(Js.String2.includes(str, "README.md"), "serialised doc should contain path")
    assert(Js.String2.includes(str, "_key"), "serialised doc should contain _key")
  })

  // 15. Dedup report in pipeline context
  test("e2e: dedup report generation", () => {
    let docs = [
      Deduplicator.createDocument(fixtureReadme, makeMetadata(~path="a.md", ())),
      Deduplicator.createDocument(fixtureReadme, makeMetadata(~path="b.md", ())),
      Deduplicator.createDocument(fixtureLicense, makeMetadata(~path="LICENSE", ~docType=LICENSE, ())),
    ]
    let result = Deduplicator.deduplicate(docs)
    let report = Deduplicator.generateReport(result)
    assert(Js.String2.includes(report, "Deduplication Report"), "report header")
    assert(Js.String2.includes(report, "1"), "should mention duplicate count")
  })

  (passed.contents, failed.contents)
}
