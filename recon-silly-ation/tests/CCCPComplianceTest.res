// SPDX-License-Identifier: PMPL-1.0-or-later
// CCCPComplianceTest - Unit tests for CCCP Python compliance checker
// Tests: isPythonFile, detectPythonImports, checkPythonAntiPatterns,
// generateMigrationSuggestion, report generation

// Note: open Types not needed for CCCPCompliance standalone tests,
// but the module internally uses it
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
// Tests
// ---------------------------------------------------------------------------

let run = (): (int, int) => {
  Js.Console.log("\n--- CCCPComplianceTest ---")

  // 1. isPythonFile .py
  test("isPythonFile detects .py files", () => {
    assert(CCCPCompliance.isPythonFile("script.py"), ".py should be detected")
  })

  // 2. isPythonFile .pyw
  test("isPythonFile detects .pyw files", () => {
    assert(CCCPCompliance.isPythonFile("gui_app.pyw"), ".pyw should be detected")
  })

  // 3. isPythonFile setup.py
  test("isPythonFile detects setup.py", () => {
    assert(CCCPCompliance.isPythonFile("setup.py"), "setup.py should be detected")
  })

  // 4. isPythonFile rejects .js
  test("isPythonFile rejects .js files", () => {
    assert(!CCCPCompliance.isPythonFile("app.js"), ".js should not be Python")
  })

  // 5. isPythonFile rejects .res
  test("isPythonFile rejects .res files", () => {
    assert(!CCCPCompliance.isPythonFile("Types.res"), ".res should not be Python")
  })

  // 6. detectPythonImports finds import statements
  test("detectPythonImports finds import statements", () => {
    let content = "import os\nimport sys\nfrom pathlib import Path\nx = 1"
    let imports = CCCPCompliance.detectPythonImports(content)
    assertEqual(Belt.Array.length(imports), 3, "should find 3 imports")
  })

  // 7. detectPythonImports returns empty for no imports
  test("detectPythonImports empty for no imports", () => {
    let content = "x = 1\ny = 2\nprint(x + y)"
    let imports = CCCPCompliance.detectPythonImports(content)
    assertEqual(Belt.Array.length(imports), 0, "no imports expected")
  })

  // 8. checkPythonAntiPatterns detects eval
  test("checkPythonAntiPatterns detects eval()", () => {
    let content = "result = eval(user_input)"
    let patterns = CCCPCompliance.checkPythonAntiPatterns(content)
    assert(
      patterns->Belt.Array.some(p => Js.String2.includes(p, "eval")),
      "should detect eval()",
    )
  })

  // 9. checkPythonAntiPatterns detects exec
  test("checkPythonAntiPatterns detects exec()", () => {
    let content = "exec(code_string)"
    let patterns = CCCPCompliance.checkPythonAntiPatterns(content)
    assert(
      patterns->Belt.Array.some(p => Js.String2.includes(p, "exec")),
      "should detect exec()",
    )
  })

  // 10. checkPythonAntiPatterns detects pickle
  test("checkPythonAntiPatterns detects pickle", () => {
    let content = "import pickle\ndata = pickle.loads(raw)"
    let patterns = CCCPCompliance.checkPythonAntiPatterns(content)
    assert(
      patterns->Belt.Array.some(p => Js.String2.includes(p, "pickle")),
      "should detect pickle",
    )
  })

  // 11. checkPythonAntiPatterns clean code has no warnings
  test("checkPythonAntiPatterns clean code returns empty", () => {
    let content = "def add(a, b):\n    return a + b"
    let patterns = CCCPCompliance.checkPythonAntiPatterns(content)
    assertEqual(Belt.Array.length(patterns), 0, "clean code should have no anti-patterns")
  })

  // 12. generateMigrationSuggestion default suggestion
  test("generateMigrationSuggestion gives default for no imports", () => {
    let suggestion = CCCPCompliance.generateMigrationSuggestion([])
    assert(
      Js.String2.includes(suggestion, "ReScript"),
      "default suggestion should mention ReScript",
    )
  })

  // 13. generateMigrationSuggestion web framework
  test("generateMigrationSuggestion mentions web for flask imports", () => {
    let suggestion = CCCPCompliance.generateMigrationSuggestion(["import flask"])
    assert(
      Js.String2.includes(suggestion, "web") || Js.String2.includes(suggestion, "Melange"),
      "should suggest web migration",
    )
  })

  // 14. generateMigrationSuggestion data science
  test("generateMigrationSuggestion mentions Julia for numpy imports", () => {
    let suggestion = CCCPCompliance.generateMigrationSuggestion(["import numpy"])
    assert(
      Js.String2.includes(suggestion, "Julia") || Js.String2.includes(suggestion, "R"),
      "should suggest Julia/R for data science",
    )
  })

  // 15. generateReport empty violations is compliant
  test("generateReport reports compliant for empty violations", () => {
    let report = CCCPCompliance.generateReport([])
    assert(
      Js.String2.includes(report, "compliant"),
      "empty violations should report compliant",
    )
  })

  // 16. generateReport non-empty violations shows count
  test("generateReport shows violation count", () => {
    let violation: cccpViolation = {
      file: "test.py",
      violationType: "python-usage",
      severity: "warning",
      message: "Python file detected",
      suggestedFix: None,
    }
    let report = CCCPCompliance.generateReport([violation])
    assert(
      Js.String2.includes(report, "1"),
      "report should mention violation count",
    )
  })

  (passed.contents, failed.contents)
}
