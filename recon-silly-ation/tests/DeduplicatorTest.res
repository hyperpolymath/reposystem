// SPDX-License-Identifier: PMPL-1.0-or-later
// DeduplicatorTest - Unit tests for content-addressable deduplication
// Tests: hashContent, normalizeContent, createDocument, deduplicate,
// findDuplicates, isDuplicate, groupByHash, findLatest, findCanonical,
// createDuplicateEdges, normalization idempotency

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
  ~version: option<version>=None,
  ~canonicalSource: canonicalSource=Inferred,
  ~repository: string="test/repo",
  ~branch: string="main",
  (),
): documentMetadata => {
  path,
  documentType: docType,
  lastModified,
  version,
  canonicalSource,
  repository,
  branch,
}

let makeDoc = (content: string, path: string): document => {
  Deduplicator.createDocument(
    content,
    makeMetadata(~path, ()),
  )
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

let run = (): (int, int) => {
  Js.Console.log("\n--- DeduplicatorTest ---")

  // 1. hashContent determinism
  test("hashContent determinism - same input same output", () => {
    let h1 = Deduplicator.hashContent("hello world")
    let h2 = Deduplicator.hashContent("hello world")
    assertEqual(h1, h2, "same content must produce same hash")
  })

  // 2. hash uniqueness
  test("hashContent uniqueness - different inputs differ", () => {
    let h1 = Deduplicator.hashContent("alpha")
    let h2 = Deduplicator.hashContent("beta")
    assert(h1 != h2, "different content must produce different hash")
  })

  // 3. hash non-empty
  test("hashContent produces non-empty string", () => {
    let h = Deduplicator.hashContent("test")
    assert(Js.String2.length(h) > 0, "hash must be non-empty")
  })

  // 4. CRLF normalisation
  test("normalizeContent CRLF to LF", () => {
    let input = "line1\r\nline2\r\nline3"
    let normalized = Deduplicator.normalizeContent(input)
    assert(
      !Js.String2.includes(normalized, "\r\n"),
      "normalised content should not contain CRLF",
    )
    assert(Js.String2.includes(normalized, "\n"), "normalised content should contain LF")
  })

  // 5. trailing whitespace stripping
  test("normalizeContent trailing whitespace strip", () => {
    let input = "line1   \nline2\t\nline3"
    let normalized = Deduplicator.normalizeContent(input)
    let lines = Js.String2.split(normalized, "\n")
    lines->Belt.Array.forEach(line => {
      assert(
        line == Js.String2.trimEnd(line),
        "each line must not have trailing whitespace",
      )
    })
  })

  // 6. blank line collapse
  test("normalizeContent blank line collapse", () => {
    let input = "first\n\n\n\n\nsecond"
    let normalized = Deduplicator.normalizeContent(input)
    assert(
      !Js.String2.includes(normalized, "\n\n\n"),
      "three or more consecutive newlines should be collapsed to two",
    )
  })

  // 7. createDocument sets hash
  test("createDocument sets non-empty hash", () => {
    let doc = makeDoc("# README", "README.md")
    assert(Js.String2.length(doc.hash) > 0, "hash must be set")
  })

  // 8. createDocument normalises content
  test("createDocument normalises content", () => {
    let doc = Deduplicator.createDocument(
      "hello\r\nworld   \n\n\n\nfin",
      makeMetadata(~path="test.md", ()),
    )
    assert(!Js.String2.includes(doc.content, "\r"), "content must be normalised")
  })

  // 9. deduplicate - all unique
  test("deduplicate all unique docs", () => {
    let d1 = makeDoc("content A", "a.md")
    let d2 = makeDoc("content B", "b.md")
    let d3 = makeDoc("content C", "c.md")
    let result = Deduplicator.deduplicate([d1, d2, d3])
    assertEqual(result.stats.uniqueCount, 3, "expected 3 unique docs")
    assertEqual(result.stats.duplicateCount, 0, "expected 0 duplicates")
  })

  // 10. deduplicate - finds duplicates
  test("deduplicate finds duplicate content", () => {
    let d1 = makeDoc("same content", "a.md")
    let d2 = makeDoc("same content", "b.md")
    let d3 = makeDoc("different", "c.md")
    let result = Deduplicator.deduplicate([d1, d2, d3])
    assertEqual(result.stats.uniqueCount, 2, "expected 2 unique")
    assertEqual(result.stats.duplicateCount, 1, "expected 1 duplicate")
  })

  // 11. deduplicate preserves original
  test("deduplicate unique array has first occurrence", () => {
    let d1 = makeDoc("identical", "first.md")
    let d2 = makeDoc("identical", "second.md")
    let result = Deduplicator.deduplicate([d1, d2])
    assertEqual(Belt.Array.length(result.unique), 1, "one unique")
    assertEqual(
      (Belt.Array.getUnsafe(result.unique, 0)).metadata.path,
      "first.md",
      "first occurrence kept",
    )
  })

  // 12. findDuplicates
  test("findDuplicates locates copies", () => {
    let d1 = makeDoc("shared", "a.md")
    let d2 = makeDoc("shared", "b.md")
    let d3 = makeDoc("other", "c.md")
    let dupes = Deduplicator.findDuplicates(d1, [d1, d2, d3])
    assertEqual(Belt.Array.length(dupes), 1, "expected 1 duplicate")
    assertEqual(
      (Belt.Array.getUnsafe(dupes, 0)).metadata.path,
      "b.md",
      "duplicate is b.md",
    )
  })

  // 13. isDuplicate true
  test("isDuplicate returns true for same content", () => {
    let d1 = makeDoc("twin", "a.md")
    let d2 = makeDoc("twin", "b.md")
    assert(Deduplicator.isDuplicate(d1, d2), "should be duplicates")
  })

  // 14. isDuplicate false
  test("isDuplicate returns false for different content", () => {
    let d1 = makeDoc("alpha", "a.md")
    let d2 = makeDoc("beta", "b.md")
    assert(!Deduplicator.isDuplicate(d1, d2), "should not be duplicates")
  })

  // 15. groupByHash
  test("groupByHash groups correctly", () => {
    let d1 = makeDoc("X", "a.md")
    let d2 = makeDoc("X", "b.md")
    let d3 = makeDoc("Y", "c.md")
    let groups = Deduplicator.groupByHash([d1, d2, d3])
    assertEqual(Belt.Map.String.size(groups), 2, "two groups")
    let xGroup = groups->Belt.Map.String.get(d1.hash)
    switch xGroup {
    | Some(arr) => assertEqual(Belt.Array.length(arr), 2, "X group has 2 docs")
    | None => Js.Exn.raiseError("missing group for hash")
    }
  })

  // 16. findLatest normal
  test("findLatest returns most recent", () => {
    let meta1 = makeMetadata(~path="old.md", ~lastModified=1000.0, ())
    let meta2 = makeMetadata(~path="new.md", ~lastModified=5000.0, ())
    let d1 = Deduplicator.createDocument("content", meta1)
    let d2 = Deduplicator.createDocument("content", meta2)
    switch Deduplicator.findLatest([d1, d2]) {
    | Some(latest) => assertEqual(latest.metadata.path, "new.md", "newest doc")
    | None => Js.Exn.raiseError("expected Some")
    }
  })

  // 17. findLatest empty
  test("findLatest on empty returns None", () => {
    switch Deduplicator.findLatest([]) {
    | None => ()
    | Some(_) => Js.Exn.raiseError("expected None for empty array")
    }
  })

  // 18. findCanonical priority ordering
  test("findCanonical prefers LicenseFile over Inferred", () => {
    let m1 = makeMetadata(~path="a.md", ~canonicalSource=Inferred, ())
    let m2 = makeMetadata(~path="b.md", ~canonicalSource=LicenseFile, ())
    let d1 = Deduplicator.createDocument("c", m1)
    let d2 = Deduplicator.createDocument("c", m2)
    switch Deduplicator.findCanonical([d1, d2]) {
    | Some(canon) => assertEqual(canon.metadata.path, "b.md", "LicenseFile wins")
    | None => Js.Exn.raiseError("expected Some")
    }
  })

  // 19. findCanonical Explicit highest
  test("findCanonical Explicit beats all", () => {
    let m1 = makeMetadata(~path="a.md", ~canonicalSource=FundingYaml, ())
    let m2 = makeMetadata(~path="b.md", ~canonicalSource=Explicit("owner"), ())
    let d1 = Deduplicator.createDocument("c", m1)
    let d2 = Deduplicator.createDocument("c", m2)
    switch Deduplicator.findCanonical([d1, d2]) {
    | Some(canon) => assertEqual(canon.metadata.path, "b.md", "Explicit wins")
    | None => Js.Exn.raiseError("expected Some")
    }
  })

  // 20. getCanonicalPriority ordering
  test("getCanonicalPriority Explicit > LicenseFile > Inferred", () => {
    let pExplicit = Deduplicator.getCanonicalPriority(Explicit("x"))
    let pLicense = Deduplicator.getCanonicalPriority(LicenseFile)
    let pInferred = Deduplicator.getCanonicalPriority(Inferred)
    assert(pExplicit > pLicense, "Explicit > LicenseFile")
    assert(pLicense > pInferred, "LicenseFile > Inferred")
  })

  // 21. createDuplicateEdges
  test("createDuplicateEdges produces correct edges", () => {
    let d1 = makeDoc("same", "a.md")
    let d2 = makeDoc("same", "b.md")
    let edges = Deduplicator.createDuplicateEdges([(d2, d1)])
    assertEqual(Belt.Array.length(edges), 1, "one edge")
    let edge = Belt.Array.getUnsafe(edges, 0)
    assertEqual(edge.edgeType, DuplicateOf, "edge type is DuplicateOf")
    assertEqual(edge.confidence, 1.0, "confidence is 1.0")
  })

  // 22. createDuplicateEdges empty
  test("createDuplicateEdges empty input yields empty output", () => {
    let edges = Deduplicator.createDuplicateEdges([])
    assertEqual(Belt.Array.length(edges), 0, "no edges for empty input")
  })

  // 23. normalization idempotency
  test("normalizeContent is idempotent", () => {
    let input = "hello\r\n  world   \n\n\n\n\nfoo  "
    let once = Deduplicator.normalizeContent(input)
    let twice = Deduplicator.normalizeContent(once)
    assertEqual(once, twice, "normalising twice should equal normalising once")
  })

  // 24. hash after normalisation is identical
  test("hashContent on normalised content is same as normalise+hash", () => {
    let raw = "test\r\ncontent   \n\n\n\nend"
    let n = Deduplicator.normalizeContent(raw)
    let h1 = Deduplicator.hashContent(n)
    let h2 = Deduplicator.hashContent(Deduplicator.normalizeContent(raw))
    assertEqual(h1, h2, "hash of normalised must be deterministic")
  })

  // 25. deduplicate stats totalProcessed
  test("deduplicate stats totalProcessed is correct", () => {
    let docs = [
      makeDoc("a", "a.md"),
      makeDoc("b", "b.md"),
      makeDoc("a", "a2.md"),
    ]
    let result = Deduplicator.deduplicate(docs)
    assertEqual(result.stats.totalProcessed, 3, "totalProcessed is 3")
  })

  (passed.contents, failed.contents)
}
