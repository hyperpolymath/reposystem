// SPDX-License-Identifier: PMPL-1.0-or-later
// ProtocolTest - Unit tests for SEAM protocol types and serialization
// Tests: documentEvent construction, documentEventToJson, healthCheckToJson,
// type construction for various protocol types

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
  Js.Console.log("\n--- ProtocolTest ---")

  // 1. documentEvent construction
  test("documentEvent can be constructed", () => {
    let event: Protocol.documentEvent = {
      id: "evt-001",
      eventType: Protocol.Created,
      hash: "abc123",
      oldHash: None,
      path: "README.md",
      format: "md",
      timestamp: 1000.0,
      source: "recon-silly-ation",
    }
    assertEqual(event.id, "evt-001", "event id should match")
    assertEqual(event.path, "README.md", "path should match")
  })

  // 2. documentEventToJson contains id
  test("documentEventToJson contains id field", () => {
    let event: Protocol.documentEvent = {
      id: "evt-test",
      eventType: Protocol.Modified,
      hash: "def456",
      oldHash: Some("abc123"),
      path: "LICENSE",
      format: "txt",
      timestamp: 2000.0,
      source: "formatrix-docs",
    }
    let json = Protocol.documentEventToJson(event)
    let str = Js.Json.stringify(json)
    assert(Js.String2.includes(str, "evt-test"), "JSON should contain event id")
  })

  // 3. documentEventToJson eventType serialization
  test("documentEventToJson serializes eventType correctly", () => {
    let event: Protocol.documentEvent = {
      id: "evt-1",
      eventType: Protocol.Created,
      hash: "h1",
      oldHash: None,
      path: "test.md",
      format: "md",
      timestamp: 1000.0,
      source: "test",
    }
    let json = Protocol.documentEventToJson(event)
    let str = Js.Json.stringify(json)
    assert(Js.String2.includes(str, "created"), "eventType should be 'created'")
  })

  // 4. documentEventToJson Modified event type
  test("documentEventToJson Modified maps to modified", () => {
    let event: Protocol.documentEvent = {
      id: "evt-2",
      eventType: Protocol.Modified,
      hash: "h2",
      oldHash: Some("h1"),
      path: "test.md",
      format: "md",
      timestamp: 2000.0,
      source: "test",
    }
    let json = Protocol.documentEventToJson(event)
    let str = Js.Json.stringify(json)
    assert(Js.String2.includes(str, "modified"), "eventType should be 'modified'")
  })

  // 5. documentEventToJson oldHash None becomes null
  test("documentEventToJson oldHash None is null", () => {
    let event: Protocol.documentEvent = {
      id: "evt-3",
      eventType: Protocol.Deleted,
      hash: "h3",
      oldHash: None,
      path: "old.md",
      format: "md",
      timestamp: 3000.0,
      source: "test",
    }
    let json = Protocol.documentEventToJson(event)
    let str = Js.Json.stringify(json)
    assert(Js.String2.includes(str, "null"), "oldHash None should serialise to null")
  })

  // 6. healthCheckToJson contains componentId
  test("healthCheckToJson contains componentId", () => {
    let check: Protocol.healthCheck = {
      componentId: "recon-silly-ation",
      status: Protocol.Healthy,
      latencyMs: Some(42.0),
      version: Some("1.0.0"),
      checkedAt: 5000.0,
    }
    let json = Protocol.healthCheckToJson(check)
    let str = Js.Json.stringify(json)
    assert(
      Js.String2.includes(str, "recon-silly-ation"),
      "JSON should contain componentId",
    )
  })

  // 7. healthCheckToJson Healthy status
  test("healthCheckToJson Healthy status serialises correctly", () => {
    let check: Protocol.healthCheck = {
      componentId: "test",
      status: Protocol.Healthy,
      latencyMs: None,
      version: None,
      checkedAt: 1000.0,
    }
    let json = Protocol.healthCheckToJson(check)
    let str = Js.Json.stringify(json)
    assert(Js.String2.includes(str, "healthy"), "status should be 'healthy'")
  })

  // 8. healthCheckToJson Degraded status
  test("healthCheckToJson Degraded status includes reason", () => {
    let check: Protocol.healthCheck = {
      componentId: "db",
      status: Protocol.Degraded({reason: "slow queries"}),
      latencyMs: Some(500.0),
      version: None,
      checkedAt: 2000.0,
    }
    let json = Protocol.healthCheckToJson(check)
    let str = Js.Json.stringify(json)
    assert(Js.String2.includes(str, "degraded"), "status should contain 'degraded'")
    assert(Js.String2.includes(str, "slow queries"), "should include reason text")
  })

  // 9. hashAlgorithm constant
  test("hashAlgorithm is sha256", () => {
    assertEqual(Protocol.hashAlgorithm, "sha256", "hash algorithm should be sha256")
  })

  // 10. repoContext construction
  test("repoContext can be constructed", () => {
    let ctx: Protocol.repoContext = {
      name: "recon-silly-ation",
      description: Some("Documentation reconciliation"),
      language: Some("rescript"),
      license: Some("PMPL-1.0-or-later"),
      topics: ["documentation", "reconciliation"],
      existingDocs: ["README.md", "LICENSE"],
      dependencies: None,
      readme: None,
    }
    assertEqual(ctx.name, "recon-silly-ation", "name should match")
    assertEqual(Belt.Array.length(ctx.topics), 2, "should have 2 topics")
  })

  // 11. generationRequest construction
  test("generationRequest can be constructed", () => {
    let req: Protocol.generationRequest = {
      requestId: "req-001",
      documentType: "SECURITY",
      format: "md",
      context: {
        name: "test",
        description: None,
        language: None,
        license: None,
        topics: [],
        existingDocs: [],
        dependencies: None,
        readme: None,
      },
      priority: 1,
      requestedBy: "system",
      requestedAt: 1000.0,
    }
    assertEqual(req.requestId, "req-001", "requestId should match")
    assertEqual(req.documentType, "SECURITY", "documentType should match")
  })

  // 12. healthCheckToJson Unknown status
  test("healthCheckToJson Unknown status", () => {
    let check: Protocol.healthCheck = {
      componentId: "unknown-svc",
      status: Protocol.Unknown,
      latencyMs: None,
      version: None,
      checkedAt: 3000.0,
    }
    let json = Protocol.healthCheckToJson(check)
    let str = Js.Json.stringify(json)
    assert(Js.String2.includes(str, "unknown"), "status should be 'unknown'")
  })

  (passed.contents, failed.contents)
}
