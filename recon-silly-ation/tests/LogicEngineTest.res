// SPDX-License-Identifier: PMPL-1.0-or-later
// LogicEngineTest - Unit tests for miniKanren/Datalog-style logical inference
// Tests: createKnowledgeBase, addFact, addRule, unify, query,
// defineDocumentRules, inferRelationships, findCanonicalForType, reasonAboutConflict

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

let makeDoc = (content: string, path: string): document => {
  Deduplicator.createDocument(content, makeMetadata(~path, ()))
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

let run = (): (int, int) => {
  Js.Console.log("\n--- LogicEngineTest ---")

  // 1. createKnowledgeBase empty
  test("createKnowledgeBase has empty facts and rules", () => {
    let kb = LogicEngine.createKnowledgeBase()
    assertEqual(Belt.Array.length(kb.facts), 0, "facts should be empty")
    assertEqual(Belt.Array.length(kb.rules), 0, "rules should be empty")
  })

  // 2. addFact increments facts count
  test("addFact adds one fact", () => {
    let kb = LogicEngine.createKnowledgeBase()
    let kb = LogicEngine.addFact(kb, LogicEngine.Atom("hello"))
    assertEqual(Belt.Array.length(kb.facts), 1, "should have 1 fact")
  })

  // 3. addFact preserves existing facts
  test("addFact preserves prior facts", () => {
    let kb = LogicEngine.createKnowledgeBase()
    let kb = LogicEngine.addFact(kb, LogicEngine.Atom("a"))
    let kb = LogicEngine.addFact(kb, LogicEngine.Atom("b"))
    assertEqual(Belt.Array.length(kb.facts), 2, "should have 2 facts")
  })

  // 4. addRule increments rules count
  test("addRule adds one rule", () => {
    let kb = LogicEngine.createKnowledgeBase()
    let kb = LogicEngine.addRule(
      kb,
      LogicEngine.Compound("test", [LogicEngine.Var("X")]),
      [LogicEngine.Atom("premise")],
    )
    assertEqual(Belt.Array.length(kb.rules), 1, "should have 1 rule")
  })

  // 5. unify same atoms succeeds
  test("unify same atoms returns Some", () => {
    let result = LogicEngine.unify(
      LogicEngine.Atom("x"),
      LogicEngine.Atom("x"),
      Belt.Map.String.empty,
    )
    switch result {
    | Some(_) => ()
    | None => Js.Exn.raiseError("same atoms should unify")
    }
  })

  // 6. unify different atoms fails
  test("unify different atoms returns None", () => {
    let result = LogicEngine.unify(
      LogicEngine.Atom("x"),
      LogicEngine.Atom("y"),
      Belt.Map.String.empty,
    )
    switch result {
    | None => ()
    | Some(_) => Js.Exn.raiseError("different atoms should not unify")
    }
  })

  // 7. unify variable binding
  test("unify variable binds to term", () => {
    let result = LogicEngine.unify(
      LogicEngine.Var("X"),
      LogicEngine.Atom("hello"),
      Belt.Map.String.empty,
    )
    switch result {
    | Some(sub) => {
        switch sub->Belt.Map.String.get("X") {
        | Some(LogicEngine.Atom("hello")) => ()
        | _ => Js.Exn.raiseError("X should be bound to Atom(hello)")
        }
      }
    | None => Js.Exn.raiseError("variable should unify with atom")
    }
  })

  // 8. unify compound terms same functor
  test("unify compound terms same functor and arity", () => {
    let result = LogicEngine.unify(
      LogicEngine.Compound("f", [LogicEngine.Atom("a")]),
      LogicEngine.Compound("f", [LogicEngine.Atom("a")]),
      Belt.Map.String.empty,
    )
    switch result {
    | Some(_) => ()
    | None => Js.Exn.raiseError("identical compounds should unify")
    }
  })

  // 9. unify compound terms different functor
  test("unify compound terms different functor fails", () => {
    let result = LogicEngine.unify(
      LogicEngine.Compound("f", [LogicEngine.Atom("a")]),
      LogicEngine.Compound("g", [LogicEngine.Atom("a")]),
      Belt.Map.String.empty,
    )
    switch result {
    | None => ()
    | Some(_) => Js.Exn.raiseError("different functors should not unify")
    }
  })

  // 10. query finds matching facts
  test("query finds matching fact", () => {
    let kb = LogicEngine.createKnowledgeBase()
    let kb = LogicEngine.addFact(
      kb,
      LogicEngine.Compound("color", [LogicEngine.Atom("red")]),
    )
    let results = LogicEngine.query(
      kb,
      LogicEngine.Compound("color", [LogicEngine.Atom("red")]),
    )
    assert(Belt.Array.length(results) > 0, "should find matching fact")
  })

  // 11. query returns empty for non-matching
  test("query returns empty for no match", () => {
    let kb = LogicEngine.createKnowledgeBase()
    let kb = LogicEngine.addFact(kb, LogicEngine.Atom("exists"))
    let results = LogicEngine.query(kb, LogicEngine.Atom("missing"))
    assertEqual(Belt.Array.length(results), 0, "no match expected")
  })

  // 12. defineDocumentRules adds rules
  test("defineDocumentRules adds rules to kb", () => {
    let kb = LogicEngine.createKnowledgeBase()
    let kb = LogicEngine.defineDocumentRules(kb)
    assert(Belt.Array.length(kb.rules) >= 4, "should have at least 4 document rules")
  })

  // 13. inferRelationships finds duplicates
  test("inferRelationships detects duplicate docs", () => {
    let d1 = makeDoc("same content", "a.md")
    let d2 = makeDoc("same content", "b.md")
    let rels = LogicEngine.inferRelationships([d1, d2])
    assert(Belt.Array.length(rels) > 0, "should infer duplicate relationship")
    let (_, _, relType) = Belt.Array.getUnsafe(rels, 0)
    assertEqual(relType, "duplicate_of", "relationship type should be duplicate_of")
  })

  // 14. inferRelationships finds supersedes
  test("inferRelationships detects version supersedes", () => {
    let m1 = makeMetadata(
      ~path="a.md",
      ~version=Some({major: 1, minor: 0, patch: 0}),
      (),
    )
    let m2 = makeMetadata(
      ~path="b.md",
      ~version=Some({major: 2, minor: 0, patch: 0}),
      (),
    )
    let d1 = Deduplicator.createDocument("version one", m1)
    let d2 = Deduplicator.createDocument("version two", m2)
    let rels = LogicEngine.inferRelationships([d1, d2])
    let supersedes = rels->Belt.Array.keep(((_, _, t)) => t == "supersedes")
    assert(Belt.Array.length(supersedes) > 0, "should detect supersedes")
  })

  // 15. findCanonicalForType selects correct doc
  test("findCanonicalForType picks highest priority", () => {
    let m1 = makeMetadata(~path="a.md", ~docType=LICENSE, ~canonicalSource=Inferred, ())
    let m2 = makeMetadata(~path="b.md", ~docType=LICENSE, ~canonicalSource=LicenseFile, ())
    let d1 = Deduplicator.createDocument("lic A", m1)
    let d2 = Deduplicator.createDocument("lic B", m2)
    switch LogicEngine.findCanonicalForType([d1, d2], LICENSE) {
    | Some(doc) => assertEqual(doc.metadata.path, "b.md", "LicenseFile should win")
    | None => Js.Exn.raiseError("expected canonical document")
    }
  })

  // 16. findCanonicalForType None for wrong type
  test("findCanonicalForType returns None for unmatched type", () => {
    let d = Deduplicator.createDocument("readme", makeMetadata(~path="r.md", ~docType=README, ()))
    switch LogicEngine.findCanonicalForType([d], LICENSE) {
    | None => ()
    | Some(_) => Js.Exn.raiseError("should return None for wrong type")
    }
  })

  // 17. reasonAboutConflict produces non-empty string
  test("reasonAboutConflict produces reasoning text", () => {
    let d1 = makeDoc("same", "a.md")
    let d2 = makeDoc("same", "b.md")
    let conflict: conflict = {
      id: "test",
      conflictType: DuplicateContent,
      documents: [d1, d2],
      detectedAt: Js.Date.now(),
      confidence: 1.0,
      suggestedStrategy: KeepLatest,
    }
    let reasoning = LogicEngine.reasonAboutConflict(conflict)
    assert(Js.String2.length(reasoning) > 0, "reasoning must be non-empty")
    assert(Js.String2.includes(reasoning, "identical"), "should mention identical content")
  })

  // 18. reasonAboutConflict handles different content
  test("reasonAboutConflict identifies different content", () => {
    let d1 = makeDoc("content A", "a.md")
    let d2 = makeDoc("content B", "b.md")
    let conflict: conflict = {
      id: "test2",
      conflictType: SemanticConflict,
      documents: [d1, d2],
      detectedAt: Js.Date.now(),
      confidence: 0.5,
      suggestedStrategy: Merge,
    }
    let reasoning = LogicEngine.reasonAboutConflict(conflict)
    assert(Js.String2.includes(reasoning, "different content"), "should note different content")
  })

  // 19. inferenceToEdges converts relationships to edges
  test("inferenceToEdges produces correct edge types", () => {
    let d1 = makeDoc("same", "a.md")
    let d2 = makeDoc("same", "b.md")
    let rels = LogicEngine.inferRelationships([d1, d2])
    let edges = LogicEngine.inferenceToEdges(rels)
    assert(Belt.Array.length(edges) > 0, "should produce edges")
    let edge = Belt.Array.getUnsafe(edges, 0)
    assertEqual(edge.edgeType, DuplicateOf, "edge type should be DuplicateOf")
    assertEqual(edge.confidence, 0.85, "inferred edge confidence is 0.85")
  })

  (passed.contents, failed.contents)
}
