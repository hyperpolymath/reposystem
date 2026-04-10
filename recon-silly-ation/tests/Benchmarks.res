// SPDX-License-Identifier: PMPL-1.0-or-later
// Benchmarks - Performance benchmark harness for recon-silly-ation
// Measures: hash throughput, normalisation throughput, batch dedup,
// conflict detection, graph generation, version comparison, logic inference
// Outputs: markdown table with timing results

open Types

// ---------------------------------------------------------------------------
// Benchmark harness
// ---------------------------------------------------------------------------

type benchmarkResult = {
  name: string,
  iterations: int,
  totalMs: float,
  avgMs: float,
  opsPerSec: float,
}

let runBenchmark = (name: string, iterations: int, fn: unit => unit): benchmarkResult => {
  // Warm-up phase
  for _ in 1 to 10 {
    fn()
  }

  let start = Js.Date.now()
  for _ in 1 to iterations {
    fn()
  }
  let elapsed = Js.Date.now() -. start

  let avgMs = elapsed /. Int.toFloat(iterations)
  let opsPerSec = if elapsed > 0.0 {
    Int.toFloat(iterations) /. (elapsed /. 1000.0)
  } else {
    0.0
  }

  {name, iterations, totalMs: elapsed, avgMs, opsPerSec}
}

let formatResult = (r: benchmarkResult): string => {
  let totalStr = r.totalMs->Js.Float.toFixedWithPrecision(~digits=2)
  let avgStr = r.avgMs->Js.Float.toFixedWithPrecision(~digits=4)
  let opsStr = r.opsPerSec->Js.Math.round->Belt.Float.toString
  `| ${r.name} | ${r.iterations->Int.toString} | ${totalStr} | ${avgStr} | ${opsStr} |`
}

// ---------------------------------------------------------------------------
// Test data generators
// ---------------------------------------------------------------------------

let generateContent = (size: int): string => {
  let chunk = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. "
  let chunkLen = Js.String2.length(chunk)
  let repeats = size / chunkLen + 1
  let buf = ref("")
  for _ in 1 to repeats {
    buf := buf.contents ++ chunk
  }
  Js.String2.slice(buf.contents, ~from=0, ~to_=size)
}

let makeMetadata = (~path: string, ()): documentMetadata => {
  path,
  documentType: README,
  lastModified: 1000.0,
  version: None,
  canonicalSource: Inferred,
  repository: "bench/repo",
  branch: "main",
}

let generateDocs = (count: int): array<document> => {
  Belt.Array.makeBy(count, i => {
    let content = if mod(i, 10) == 0 {
      "duplicate content body for benchmarking"
    } else {
      `unique document content number ${i->Int.toString} for benchmark suite`
    }
    Deduplicator.createDocument(content, makeMetadata(~path=`bench-${i->Int.toString}.md`, ()))
  })
}

// ---------------------------------------------------------------------------
// Benchmark suite
// ---------------------------------------------------------------------------

let run = (): unit => {
  Js.Console.log("\n=== Performance Benchmarks ===\n")
  Js.Console.log("Running benchmarks (this may take a moment)...\n")
  Js.Console.log("| Benchmark | Iterations | Total (ms) | Avg (ms) | Ops/sec |")
  Js.Console.log("|-----------|-----------|------------|----------|---------|")

  let results = []

  // 1. SHA-256 hashing - small content (100 bytes)
  let smallContent = generateContent(100)
  let r1 = runBenchmark("hash-100B", 10000, () => {
    let _ = Deduplicator.hashContent(smallContent)
  })
  results->Js.Array2.push(r1)->ignore
  Js.Console.log(formatResult(r1))

  // 2. SHA-256 hashing - 10KB content
  let content10k = generateContent(10240)
  let r2 = runBenchmark("hash-10KB", 1000, () => {
    let _ = Deduplicator.hashContent(content10k)
  })
  results->Js.Array2.push(r2)->ignore
  Js.Console.log(formatResult(r2))

  // 3. SHA-256 hashing - 100KB content
  let content100k = generateContent(102400)
  let r3 = runBenchmark("hash-100KB", 100, () => {
    let _ = Deduplicator.hashContent(content100k)
  })
  results->Js.Array2.push(r3)->ignore
  Js.Console.log(formatResult(r3))

  // 4. Normalisation - small dirty content
  let dirtySmall = "line1\r\n  line2   \r\n\r\n\r\n\r\nline3\t  \nend"
  let r4 = runBenchmark("normalise-small", 10000, () => {
    let _ = Deduplicator.normalizeContent(dirtySmall)
  })
  results->Js.Array2.push(r4)->ignore
  Js.Console.log(formatResult(r4))

  // 5. Normalisation - 10KB dirty content
  let dirty10k = generateContent(5000) ++ "\r\n" ++ generateContent(5000)
  let r5 = runBenchmark("normalise-10KB", 1000, () => {
    let _ = Deduplicator.normalizeContent(dirty10k)
  })
  results->Js.Array2.push(r5)->ignore
  Js.Console.log(formatResult(r5))

  // 6. Document creation
  let r6 = runBenchmark("create-document", 5000, () => {
    let _ = Deduplicator.createDocument(smallContent, makeMetadata(~path="bench.md", ()))
  })
  results->Js.Array2.push(r6)->ignore
  Js.Console.log(formatResult(r6))

  // 7. Batch dedup - 10 docs
  let docs10 = generateDocs(10)
  let r7 = runBenchmark("dedup-10-docs", 1000, () => {
    let _ = Deduplicator.deduplicate(docs10)
  })
  results->Js.Array2.push(r7)->ignore
  Js.Console.log(formatResult(r7))

  // 8. Batch dedup - 100 docs
  let docs100 = generateDocs(100)
  let r8 = runBenchmark("dedup-100-docs", 100, () => {
    let _ = Deduplicator.deduplicate(docs100)
  })
  results->Js.Array2.push(r8)->ignore
  Js.Console.log(formatResult(r8))

  // 9. Batch dedup - 1000 docs
  let docs1000 = generateDocs(1000)
  let r9 = runBenchmark("dedup-1000-docs", 10, () => {
    let _ = Deduplicator.deduplicate(docs1000)
  })
  results->Js.Array2.push(r9)->ignore
  Js.Console.log(formatResult(r9))

  // 10. Conflict detection - 100 docs
  let r10 = runBenchmark("conflicts-100", 100, () => {
    let _ = ConflictResolver.detectConflicts(docs100)
  })
  results->Js.Array2.push(r10)->ignore
  Js.Console.log(formatResult(r10))

  // 11. Conflict resolution - batch
  let conflicts = ConflictResolver.detectConflicts(docs100)
  let r11 = runBenchmark("resolve-batch", 100, () => {
    let _ = ConflictResolver.resolveConflicts(conflicts, 0.9)
  })
  results->Js.Array2.push(r11)->ignore
  Js.Console.log(formatResult(r11))

  // 12. Graph DOT generation - 20 nodes
  let docs20 = generateDocs(20)
  let emptyEdges: array<edge> = []
  let r12 = runBenchmark("dot-20-nodes", 1000, () => {
    let _ = GraphVisualizer.generateDot(docs20, emptyEdges, GraphVisualizer.defaultConfig)
  })
  results->Js.Array2.push(r12)->ignore
  Js.Console.log(formatResult(r12))

  // 13. Version comparison
  let v1: version = {major: 1, minor: 0, patch: 0}
  let v2: version = {major: 2, minor: 5, patch: 3}
  let r13 = runBenchmark("version-compare", 100000, () => {
    let _ = compareVersions(v1, v2)
  })
  results->Js.Array2.push(r13)->ignore
  Js.Console.log(formatResult(r13))

  // 14. Logic engine inference - 10 docs
  let r14 = runBenchmark("logic-infer-10", 100, () => {
    let _ = LogicEngine.inferRelationships(docs10)
  })
  results->Js.Array2.push(r14)->ignore
  Js.Console.log(formatResult(r14))

  // 15. Mermaid generation - 20 nodes
  let r15 = runBenchmark("mermaid-20-nodes", 1000, () => {
    let _ = GraphVisualizer.generateMermaid(docs20, emptyEdges)
  })
  results->Js.Array2.push(r15)->ignore
  Js.Console.log(formatResult(r15))

  // 16. ArangoDB document serialization
  let sampleDoc = Belt.Array.getUnsafe(docs10, 0)
  let r16 = runBenchmark("arango-doc-json", 10000, () => {
    let _ = ArangoClient.documentToJson(sampleDoc)
  })
  results->Js.Array2.push(r16)->ignore
  Js.Console.log(formatResult(r16))

  Js.Console.log("")
  Js.Console.log(`Total benchmarks: ${Belt.Array.length(results)->Int.toString}`)
  Js.Console.log("Note: WASM benchmarks require wasm-pack build. Run:")
  Js.Console.log("  cd wasm-modules && cargo build --release --target wasm32-unknown-unknown")
  Js.Console.log("  Then compare WASM hash/normalize against JS results above.")
}
