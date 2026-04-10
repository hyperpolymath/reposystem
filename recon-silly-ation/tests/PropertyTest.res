// SPDX-License-Identifier: PMPL-1.0-or-later
// PropertyTest - Property-based tests (pseudo-generative)
// Tests: hash determinism (100 iterations), normalization idempotency (100),
// version comparison transitivity, dedup count invariant

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
// Pseudo-random data generators
// ---------------------------------------------------------------------------

// Simple LCG for deterministic pseudo-random integers
let seedRef = ref(42)

let nextInt = (): int => {
  // Park-Miller LCG
  seedRef := mod(seedRef.contents * 48271, 2147483647)
  seedRef.contents
}

let nextString = (~len: int=20, ()): string => {
  let chars = "abcdefghijklmnopqrstuvwxyz0123456789 \n\r\t"
  let buf = Belt.Array.makeBy(len, _ => {
    let idx = mod(nextInt(), Js.String2.length(chars))
    Js.String2.charAt(chars, idx)
  })
  buf->Js.Array2.joinWith("")
}

let makeMetadata = (~path: string, ()): documentMetadata => {
  path,
  documentType: README,
  lastModified: 1000.0,
  version: None,
  canonicalSource: Inferred,
  repository: "test/repo",
  branch: "main",
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

let run = (): (int, int) => {
  Js.Console.log("\n--- PropertyTest ---")

  // Reset seed for reproducibility
  seedRef := 42

  // 1. Hash determinism: 100 iterations
  test("property: hash determinism (100 iterations)", () => {
    for _ in 1 to 100 {
      let content = nextString()
      let h1 = Deduplicator.hashContent(content)
      let h2 = Deduplicator.hashContent(content)
      assertEqual(h1, h2, "hash must be deterministic for same input")
    }
  })

  // Reset seed
  seedRef := 123

  // 2. Normalisation idempotency: 100 iterations
  test("property: normalisation idempotency (100 iterations)", () => {
    for _ in 1 to 100 {
      let content = nextString(~len=50, ())
      let once = Deduplicator.normalizeContent(content)
      let twice = Deduplicator.normalizeContent(once)
      assertEqual(once, twice, "normalise(normalise(x)) == normalise(x)")
    }
  })

  // 3. Version comparison transitivity
  test("property: version comparison transitivity", () => {
    // Generate 50 random version triples and check transitivity
    seedRef := 999
    for _ in 1 to 50 {
      let a = {major: mod(nextInt(), 10), minor: mod(nextInt(), 20), patch: mod(nextInt(), 100)}
      let b = {major: mod(nextInt(), 10), minor: mod(nextInt(), 20), patch: mod(nextInt(), 100)}
      let c = {major: mod(nextInt(), 10), minor: mod(nextInt(), 20), patch: mod(nextInt(), 100)}

      let ab = compareVersions(a, b)
      let bc = compareVersions(b, c)
      let ac = compareVersions(a, c)

      // If a <= b and b <= c then a <= c
      if ab <= 0 && bc <= 0 {
        assert(ac <= 0, "transitivity: a<=b && b<=c => a<=c")
      }
      // If a >= b and b >= c then a >= c
      if ab >= 0 && bc >= 0 {
        assert(ac >= 0, "transitivity: a>=b && b>=c => a>=c")
      }
    }
  })

  // 4. Version comparison reflexivity
  test("property: version comparison reflexivity", () => {
    seedRef := 777
    for _ in 1 to 50 {
      let v = {major: mod(nextInt(), 10), minor: mod(nextInt(), 20), patch: mod(nextInt(), 100)}
      assertEqual(compareVersions(v, v), 0, "v == v must hold")
    }
  })

  // 5. Version comparison anti-symmetry
  test("property: version comparison anti-symmetry", () => {
    seedRef := 333
    for _ in 1 to 50 {
      let a = {major: mod(nextInt(), 10), minor: mod(nextInt(), 20), patch: mod(nextInt(), 100)}
      let b = {major: mod(nextInt(), 10), minor: mod(nextInt(), 20), patch: mod(nextInt(), 100)}
      let ab = compareVersions(a, b)
      let ba = compareVersions(b, a)
      // sign(compare(a,b)) == -sign(compare(b,a))
      assert(
        (ab > 0 && ba < 0) || (ab < 0 && ba > 0) || (ab == 0 && ba == 0),
        "anti-symmetry must hold",
      )
    }
  })

  // 6. Dedup count invariant: unique + duplicate == total
  test("property: dedup count invariant (50 iterations)", () => {
    seedRef := 555
    for _ in 1 to 50 {
      // Create 2-5 documents, some possibly sharing content
      let numDocs = 2 + mod(nextInt(), 4)
      // Use a small pool of contents so duplicates are likely
      let contentPool = ["alpha", "beta", "gamma"]
      let docs = Belt.Array.makeBy(numDocs, i => {
        let contentIdx = mod(nextInt(), 3)
        let content = Belt.Array.getUnsafe(contentPool, contentIdx)
        Deduplicator.createDocument(
          content,
          makeMetadata(~path=`doc${i->Int.toString}.md`, ()),
        )
      })
      let result = Deduplicator.deduplicate(docs)
      assertEqual(
        result.stats.uniqueCount + result.stats.duplicateCount,
        result.stats.totalProcessed,
        "unique + duplicate == total",
      )
    }
  })

  // 7. Hash non-empty for any input
  test("property: hash is non-empty for all inputs (100 iterations)", () => {
    seedRef := 888
    for _ in 1 to 100 {
      let content = nextString(~len=1 + mod(nextInt(), 200), ())
      let hash = Deduplicator.hashContent(content)
      assert(Js.String2.length(hash) > 0, "hash must be non-empty")
    }
  })

  // 8. Normalised content never has CRLF
  test("property: normalised content never contains CRLF (100 iterations)", () => {
    seedRef := 444
    for _ in 1 to 100 {
      let content = nextString(~len=50, ())
      let normalised = Deduplicator.normalizeContent(content)
      assert(!Js.String2.includes(normalised, "\r\n"), "no CRLF after normalisation")
    }
  })

  // 9. Document type roundtrip for all known types
  test("property: documentType roundtrip for all known types", () => {
    let types: array<documentType> = [
      README, LICENSE, SECURITY, CONTRIBUTING, CODE_OF_CONDUCT,
      FUNDING, CITATION, CHANGELOG, AUTHORS, SUPPORT,
    ]
    types->Belt.Array.forEach(dt => {
      let str = documentTypeToString(dt)
      let back = documentTypeFromString(str)
      assertEqual(back, dt, "roundtrip must hold for " ++ str)
    })
  })

  // 10. Dedup of single document: unique=1, dup=0
  test("property: single document dedup has unique=1 dup=0", () => {
    seedRef := 111
    for _ in 1 to 20 {
      let content = nextString()
      let doc = Deduplicator.createDocument(content, makeMetadata(~path="solo.md", ()))
      let result = Deduplicator.deduplicate([doc])
      assertEqual(result.stats.uniqueCount, 1, "single doc is unique")
      assertEqual(result.stats.duplicateCount, 0, "single doc has no duplicates")
    }
  })

  (passed.contents, failed.contents)
}
