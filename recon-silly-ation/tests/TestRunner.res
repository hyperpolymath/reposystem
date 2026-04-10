// SPDX-License-Identifier: PMPL-1.0-or-later
// TestRunner - Orchestrator for the recon-silly-ation test suite
// Imports and runs all test modules, prints summary with pass/fail counts

// ---------------------------------------------------------------------------
// Run all test modules
// ---------------------------------------------------------------------------

let runAllTests = (): unit => {
  Js.Console.log("========================================")
  Js.Console.log("  recon-silly-ation Test Suite")
  Js.Console.log("========================================")

  let totalPassed = ref(0)
  let totalFailed = ref(0)

  let recordResults = ((p, f): (int, int)): unit => {
    totalPassed := totalPassed.contents + p
    totalFailed := totalFailed.contents + f
  }

  // 1. Types
  TypesTest.run()->recordResults

  // 2. Deduplicator
  DeduplicatorTest.run()->recordResults

  // 3. ConflictResolver
  ConflictResolverTest.run()->recordResults

  // 4. Pipeline
  PipelineTest.run()->recordResults

  // 5. ArangoClient
  ArangoClientTest.run()->recordResults

  // 6. LogicEngine
  LogicEngineTest.run()->recordResults

  // 7. GraphVisualizer
  GraphVisualizerTest.run()->recordResults

  // 8. CCCPCompliance
  CCCPComplianceTest.run()->recordResults

  // 9. EnforcementBot
  EnforcementBotTest.run()->recordResults

  // 10. PackShipper
  PackShipperTest.run()->recordResults

  // 11. Protocol
  ProtocolTest.run()->recordResults

  // 12. SecurityScheme
  SecuritySchemeTest.run()->recordResults

  // 13. Integration
  IntegrationTest.run()->recordResults

  // 14. Property
  PropertyTest.run()->recordResults

  // ---------------------------------------------------------------------------
  // Summary
  // ---------------------------------------------------------------------------

  let total = totalPassed.contents + totalFailed.contents

  Js.Console.log("\n========================================")
  Js.Console.log("  Test Summary")
  Js.Console.log("========================================")
  Js.Console.log(`  Total:  ${total->Int.toString}`)
  Js.Console.log(`  Passed: ${totalPassed.contents->Int.toString}`)
  Js.Console.log(`  Failed: ${totalFailed.contents->Int.toString}`)
  Js.Console.log("========================================")

  if totalFailed.contents > 0 {
    Js.Console.log(`\n  RESULT: FAILED (${totalFailed.contents->Int.toString} failures)`)
    %raw(`process.exit(1)`)
  } else {
    Js.Console.log("\n  RESULT: ALL TESTS PASSED")
    %raw(`process.exit(0)`)
  }
}

// Auto-run
let _ = runAllTests()
