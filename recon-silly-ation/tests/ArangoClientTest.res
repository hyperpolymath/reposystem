// SPDX-License-Identifier: PMPL-1.0-or-later
// ArangoClientTest - Unit tests for document and edge serialization
// Tests: documentToJson shape, edgeToJson shape, field presence

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
  (),
): documentMetadata => {
  path,
  documentType: docType,
  lastModified,
  version,
  canonicalSource: Inferred,
  repository: "test/repo",
  branch: "main",
}

let sampleDoc = (): document => {
  Deduplicator.createDocument(
    "# Sample README\n\nHello World",
    makeMetadata(~path="README.md", ()),
  )
}

let sampleVersionedDoc = (): document => {
  Deduplicator.createDocument(
    "# Versioned\n\nContent",
    makeMetadata(
      ~path="CHANGELOG.md",
      ~docType=CHANGELOG,
      ~version=Some({major: 2, minor: 1, patch: 0}),
      (),
    ),
  )
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

let run = (): (int, int) => {
  Js.Console.log("\n--- ArangoClientTest ---")

  // 1. documentToJson produces JSON object
  test("documentToJson produces valid JSON", () => {
    let doc = sampleDoc()
    let json = ArangoClient.documentToJson(doc)
    let str = Js.Json.stringify(json)
    assert(Js.String2.length(str) > 0, "JSON string must be non-empty")
  })

  // 2. documentToJson contains _key
  test("documentToJson contains _key field", () => {
    let doc = sampleDoc()
    let json = ArangoClient.documentToJson(doc)
    let str = Js.Json.stringify(json)
    assert(Js.String2.includes(str, "_key"), "must contain _key")
  })

  // 3. documentToJson contains hash
  test("documentToJson contains hash field", () => {
    let doc = sampleDoc()
    let json = ArangoClient.documentToJson(doc)
    let str = Js.Json.stringify(json)
    assert(Js.String2.includes(str, "\"hash\""), "must contain hash")
  })

  // 4. documentToJson contains path
  test("documentToJson contains path field", () => {
    let doc = sampleDoc()
    let json = ArangoClient.documentToJson(doc)
    let str = Js.Json.stringify(json)
    assert(Js.String2.includes(str, "README.md"), "must contain path value")
  })

  // 5. documentToJson contains documentType
  test("documentToJson contains documentType field", () => {
    let doc = sampleDoc()
    let json = ArangoClient.documentToJson(doc)
    let str = Js.Json.stringify(json)
    assert(Js.String2.includes(str, "README"), "must contain documentType value")
  })

  // 6. documentToJson version is null for None
  test("documentToJson version is null when None", () => {
    let doc = sampleDoc()
    let json = ArangoClient.documentToJson(doc)
    let str = Js.Json.stringify(json)
    assert(Js.String2.includes(str, "null"), "version should be null")
  })

  // 7. documentToJson version is string when Some
  test("documentToJson version is string when present", () => {
    let doc = sampleVersionedDoc()
    let json = ArangoClient.documentToJson(doc)
    let str = Js.Json.stringify(json)
    assert(Js.String2.includes(str, "2.1.0"), "must contain version string")
  })

  // 8. edgeToJson produces valid JSON
  test("edgeToJson produces valid JSON", () => {
    let edge: edge = {
      from: "hash_a",
      to: "hash_b",
      edgeType: DuplicateOf,
      confidence: 1.0,
      metadata: Js.Json.object_(Js.Dict.empty()),
    }
    let json = ArangoClient.edgeToJson(edge)
    let str = Js.Json.stringify(json)
    assert(Js.String2.length(str) > 0, "edge JSON must be non-empty")
  })

  // 9. edgeToJson contains _from with documents/ prefix
  test("edgeToJson _from has documents/ prefix", () => {
    let edge: edge = {
      from: "hash_a",
      to: "hash_b",
      edgeType: DuplicateOf,
      confidence: 1.0,
      metadata: Js.Json.object_(Js.Dict.empty()),
    }
    let json = ArangoClient.edgeToJson(edge)
    let str = Js.Json.stringify(json)
    assert(Js.String2.includes(str, "documents/hash_a"), "_from must have documents/ prefix")
  })

  // 10. edgeToJson contains type as string
  test("edgeToJson contains edge type string", () => {
    let edge: edge = {
      from: "h1",
      to: "h2",
      edgeType: SupersededBy,
      confidence: 0.95,
      metadata: Js.Json.object_(Js.Dict.empty()),
    }
    let json = ArangoClient.edgeToJson(edge)
    let str = Js.Json.stringify(json)
    assert(Js.String2.includes(str, "superseded_by"), "must contain edge type string")
  })

  (passed.contents, failed.contents)
}
