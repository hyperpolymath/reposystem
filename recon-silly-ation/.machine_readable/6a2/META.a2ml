;; SPDX-License-Identifier: PMPL-1.0-or-later
;; META.scm - Meta-level information for recon-silly-ation
;; Media-Type: application/meta+scheme

(meta
  (architecture-decisions
    (adr (id 1) (title "ReScript as primary language")
      (status "accepted") (date "2025-11-22")
      (context "Need type-safe application code that compiles to JavaScript for Deno runtime")
      (decision "Use ReScript for all application logic, compiling to ES modules consumed by Deno")
      (consequences "Type safety at compile time, functional patterns, Belt stdlib, interop with JS ecosystem"))

    (adr (id 2) (title "Rust WASM for performance-critical paths")
      (status "accepted") (date "2025-11-22")
      (context "SHA-256 hashing and content normalization are hot paths in deduplication")
      (decision "Implement hashing and normalization in Rust, compile to WASM, call from ReScript via external bindings")
      (consequences "10-100x speedup for hash-intensive operations, adds Rust build dependency"))

    (adr (id 3) (title "ArangoDB for graph storage")
      (status "accepted") (date "2025-11-22")
      (context "Need both document storage and graph relationships for conflict tracking")
      (decision "Use ArangoDB as multi-model database: documents for storage, edges for relationships, AQL for queries")
      (consequences "Single database for all data, native graph traversal, AQL query language"))

    (adr (id 4) (title "ReconForth DSL for rules")
      (status "accepted") (date "2025-11-22")
      (context "Need user-definable reconciliation and enforcement rules")
      (decision "Create stack-based Forth-like DSL (ReconForth) with WASM VM for bundle validation")
      (consequences "Extensible rule system, safe sandboxed execution, domain-specific operations"))

    (adr (id 5) (title "Idempotent pipeline architecture")
      (status "accepted") (date "2025-11-22")
      (context "Pipeline must be rerunnable without side effects")
      (decision "7-stage pipeline (Scan→Normalize→Dedupe→Detect→Resolve→Ingest→Report), each stage atomic and rerunnable")
      (consequences "Safe to retry on failure, deterministic results, easy debugging")))

  (development-practices
    (code-style
      ("ReScript: functional, immutable-first, Belt stdlib")
      ("Rust: safe only, WASM-compatible, no_std where possible")
      ("Haskell: pure functions, strong types, no partial functions"))
    (security
      (principle "Defense in depth")
      (principle "LLM output always requires approval")
      (principle "Content-addressable storage prevents tampering")
      (principle "Post-quantum crypto for future-proofing"))
    (testing
      ("Unit tests for all modules")
      ("Property-based tests for invariants")
      ("Integration tests for pipeline flow")
      ("Benchmarks for WASM vs JS comparison"))
    (versioning "SemVer")
    (documentation "AsciiDoc for prose, Guile Scheme for machine-readable")
    (branching "main for stable, feature branches for development"))

  (design-rationale
    ("Content-addressable storage ensures deduplication is exact and verifiable")
    ("Graph database enables traversal of document relationships")
    ("Stack-based DSL provides safe, sandboxed rule execution")
    ("Confidence scoring enables automatic vs manual resolution decisions")
    ("Post-quantum cryptography future-proofs against quantum attacks")))
