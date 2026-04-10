// SPDX-License-Identifier: PMPL-1.0-or-later
// GraphVisualizerTest - Unit tests for graph visualization output
// Tests: generateDot, generateMermaid, generateHTML, node colors, edge styles,
// empty graph, edge confidence styling

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

let sampleDocs = (): (document, document) => {
  let d1 = Deduplicator.createDocument(
    "# README\n\nProject info",
    makeMetadata(~path="README.md", ()),
  )
  let d2 = Deduplicator.createDocument(
    "MIT License",
    makeMetadata(~path="LICENSE", ~docType=LICENSE, ()),
  )
  (d1, d2)
}

let sampleEdge = (d1: document, d2: document): edge => {
  {
    from: d1.hash,
    to: d2.hash,
    edgeType: DuplicateOf,
    confidence: 1.0,
    metadata: Js.Json.object_(Js.Dict.empty()),
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

let run = (): (int, int) => {
  Js.Console.log("\n--- GraphVisualizerTest ---")

  let (d1, d2) = sampleDocs()
  let edges = [sampleEdge(d1, d2)]

  // 1. generateDot contains "digraph"
  test("generateDot output contains digraph", () => {
    let dot = GraphVisualizer.generateDot([d1, d2], edges, GraphVisualizer.defaultConfig)
    assert(Js.String2.includes(dot, "digraph"), "DOT must contain digraph keyword")
  })

  // 2. generateDot contains closing brace
  test("generateDot output ends with closing brace", () => {
    let dot = GraphVisualizer.generateDot([d1, d2], edges, GraphVisualizer.defaultConfig)
    assert(Js.String2.includes(dot, "}"), "DOT must contain closing brace")
  })

  // 3. node colors - README is blue
  test("nodeColor README returns blue", () => {
    let color = GraphVisualizer.nodeColor(README)
    assertEqual(color, "#4a9eff", "README should be blue")
  })

  // 4. node colors - LICENSE is red
  test("nodeColor LICENSE returns red", () => {
    let color = GraphVisualizer.nodeColor(LICENSE)
    assertEqual(color, "#ff6b6b", "LICENSE should be red")
  })

  // 5. node colors - SECURITY is yellow
  test("nodeColor SECURITY returns yellow", () => {
    let color = GraphVisualizer.nodeColor(SECURITY)
    assertEqual(color, "#ffd93d", "SECURITY should be yellow")
  })

  // 6. node colors - Custom is grey
  test("nodeColor Custom returns grey", () => {
    let color = GraphVisualizer.nodeColor(Custom("something"))
    assertEqual(color, "#cccccc", "Custom should be grey")
  })

  // 7. edge styles - high confidence is solid
  test("edgeStyle high confidence is solid", () => {
    assertEqual(GraphVisualizer.edgeStyle(0.95), "solid", ">=0.9 should be solid")
  })

  // 8. edge styles - medium confidence is dashed
  test("edgeStyle medium confidence is dashed", () => {
    assertEqual(GraphVisualizer.edgeStyle(0.75), "dashed", ">=0.7 should be dashed")
  })

  // 9. edge styles - low confidence is dotted
  test("edgeStyle low confidence is dotted", () => {
    assertEqual(GraphVisualizer.edgeStyle(0.5), "dotted", "<0.7 should be dotted")
  })

  // 10. generateMermaid contains "graph"
  test("generateMermaid contains graph keyword", () => {
    let mermaid = GraphVisualizer.generateMermaid([d1, d2], edges)
    assert(Js.String2.includes(mermaid, "graph"), "Mermaid must contain graph keyword")
  })

  // 11. generateMermaid contains LR
  test("generateMermaid uses left-to-right layout", () => {
    let mermaid = GraphVisualizer.generateMermaid([d1, d2], edges)
    assert(Js.String2.includes(mermaid, "LR"), "Mermaid should use LR layout")
  })

  // 12. generateHTML contains DOCTYPE
  test("generateHTML contains DOCTYPE", () => {
    let html = GraphVisualizer.generateHTML([d1, d2], edges, "Test Graph")
    assert(Js.String2.includes(html, "<!DOCTYPE html>"), "HTML should start with DOCTYPE")
  })

  // 13. generateHTML contains title
  test("generateHTML contains provided title", () => {
    let html = GraphVisualizer.generateHTML([d1, d2], edges, "My Documentation Graph")
    assert(
      Js.String2.includes(html, "My Documentation Graph"),
      "HTML should contain the title",
    )
  })

  // 14. generateHTML contains legend
  test("generateHTML contains legend section", () => {
    let html = GraphVisualizer.generateHTML([d1, d2], edges, "Test")
    assert(Js.String2.includes(html, "Legend"), "HTML should contain legend")
  })

  // 15. empty graph produces valid DOT
  test("generateDot with empty graph", () => {
    let dot = GraphVisualizer.generateDot([], [], GraphVisualizer.defaultConfig)
    assert(Js.String2.includes(dot, "digraph"), "even empty graph has digraph")
    assert(Js.String2.includes(dot, "}"), "even empty graph has closing brace")
  })

  // 16. edge color for ConflictsWith
  test("edgeColor ConflictsWith is red", () => {
    assertEqual(GraphVisualizer.edgeColor(ConflictsWith), "#ff6b6b", "conflicts are red")
  })

  // 17. edge color for CanonicalFor
  test("edgeColor CanonicalFor is green", () => {
    assertEqual(GraphVisualizer.edgeColor(CanonicalFor), "#51cf66", "canonical is green")
  })

  // 18. generateDot includes edge label
  test("generateDot includes edge type as label", () => {
    let dot = GraphVisualizer.generateDot([d1, d2], edges, GraphVisualizer.defaultConfig)
    assert(Js.String2.includes(dot, "duplicate_of"), "DOT should contain edge label")
  })

  (passed.contents, failed.contents)
}
