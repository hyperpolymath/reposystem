// SPDX-License-Identifier: PMPL-1.0-or-later
// CCCP Compliance Checker
// Detects Python files and recommends ReScript/Deno migrations
// Issues "Patrojisign/insulti" warnings for Python usage

open Types

@module("fs") @val
external readFileSync: (string, string) => string = "readFileSync"

@module("fs") @val
external existsSync: string => bool = "existsSync"

@module("path") @val
external extname: string => string = "extname"

@module("path") @val
external basename: string => string = "basename"

// Detect Python files and patterns
let isPythonFile = (path: string): bool => {
  let ext = extname(path)
  ext == ".py" || ext == ".pyw" || basename(path) == "setup.py"
}

let detectPythonImports = (content: string): array<string> => {
  let imports = []
  let lines = Js.String2.split(content, "\n")

  lines->Belt.Array.forEach(line => {
    let trimmed = Js.String2.trim(line)

    // Match import statements
    if Js.String2.startsWith(trimmed, "import ") || Js.String2.startsWith(trimmed, "from ") {
      imports->Js.Array2.push(trimmed)->ignore
    }
  })

  imports
}

// Python anti-patterns to detect
let checkPythonAntiPatterns = (content: string): array<string> => {
  let antiPatterns = []

  if Js.String2.includes(content, "eval(") {
    antiPatterns->Js.Array2.push("Uses eval() - dangerous code execution")->ignore
  }

  if Js.String2.includes(content, "exec(") {
    antiPatterns->Js.Array2.push("Uses exec() - dangerous code execution")->ignore
  }

  if Js.String2.includes(content, "pickle") {
    antiPatterns->Js.Array2.push("Uses pickle - insecure serialization")->ignore
  }

  if Js.String2.includes(content, "__import__") {
    antiPatterns->Js.Array2.push("Uses dynamic imports - potential security risk")->ignore
  }

  if Js.String2.includes(content, "os.system") {
    antiPatterns->Js.Array2.push("Uses os.system - command injection risk")->ignore
  }

  antiPatterns
}

// Generate CCCP violation report
let scanFile = (path: string): option<cccpViolation> => {
  if !isPythonFile(path) {
    None
  } else {
    try {
      let content = readFileSync(path, "utf8")
      let antiPatterns = checkPythonAntiPatterns(content)
      let imports = detectPythonImports(content)

      let severity = if Belt.Array.length(antiPatterns) > 0 {
        "error"
      } else {
        "warning"
      }

      let message = if Belt.Array.length(antiPatterns) > 0 {
        `Patrojisign/insulti: Python file with security issues detected:\n${antiPatterns->Js.Array2.joinWith("\n  - ")}`
      } else {
        `Patrojisign/insulti: Python file detected (${imports->Belt.Array.length->Int.toString} imports)`
      }

      Some({
        file: path,
        violationType: "python-usage",
        severity: severity,
        message: message,
        suggestedFix: Some(generateMigrationSuggestion(imports)),
      })
    } catch {
    | _ => None
    }
  }
}

// Generate migration suggestion
let generateMigrationSuggestion = (imports: array<string>): string => {
  let hasDataScience =
    imports->Belt.Array.some(imp => {
      Js.String2.includes(imp, "numpy") ||
      Js.String2.includes(imp, "pandas") ||
      Js.String2.includes(imp, "sklearn")
    })

  let hasWeb =
    imports->Belt.Array.some(imp => {
      Js.String2.includes(imp, "flask") ||
      Js.String2.includes(imp, "django") ||
      Js.String2.includes(imp, "fastapi")
    })

  let hasAsync =
    imports->Belt.Array.some(imp => {
      Js.String2.includes(imp, "asyncio") || Js.String2.includes(imp, "aiohttp")
    })

  let suggestions = []

  if hasWeb {
    suggestions
    ->Js.Array2.push("Consider migrating to ReScript with Melange for web applications")
    ->ignore
    suggestions->Js.Array2.push("Or use Deno for a secure TypeScript runtime")->ignore
  }

  if hasAsync {
    suggestions
    ->Js.Array2.push("ReScript has excellent async support with promises")
    ->ignore
    suggestions->Js.Array2.push("Deno provides native async/await with Web APIs")->ignore
  }

  if hasDataScience {
    suggestions
    ->Js.Array2.push("For data science, consider R or Julia instead of Python")
    ->ignore
    suggestions->Js.Array2.push("Or use ReScript with bindings to WebAssembly modules")->ignore
  }

  if Belt.Array.length(suggestions) == 0 {
    suggestions
    ->Js.Array2.push("Migrate to ReScript for type safety and compile-time guarantees")
    ->ignore
    suggestions->Js.Array2.push("Or use Deno for a secure, modern JavaScript/TypeScript runtime")->ignore
  }

  suggestions->Js.Array2.joinWith("\n")
}

// Scan entire repository for CCCP violations
let scanRepository = (repoPath: string): array<cccpViolation> => {
  let violations = []

  let rec scanDir = (path: string) => {
    if existsSync(path) {
      try {
        // Note: Would need proper directory traversal in real implementation
        switch scanFile(path) {
        | None => ()
        | Some(violation) => violations->Js.Array2.push(violation)->ignore
        }
      } catch {
      | _ => ()
      }
    }
  }

  scanDir(repoPath)
  violations
}

// Generate CCCP compliance report
let generateReport = (violations: array<cccpViolation>): string => {
  let lines = []

  lines->Js.Array2.push("=== CCCP Compliance Report ===")->ignore
  lines->Js.Array2.push("Patrojisign/insulti: Python Usage Detection")->ignore
  lines->Js.Array2.push("")->ignore

  if Belt.Array.length(violations) == 0 {
    lines->Js.Array2.push("✓ No Python files detected - repository is CCCP compliant")->ignore
  } else {
    let errors = violations->Belt.Array.keep(v => v.severity == "error")->Belt.Array.length
    let warnings = violations->Belt.Array.keep(v => v.severity == "warning")->Belt.Array.length

    lines
    ->Js.Array2.push(`Found ${violations->Belt.Array.length->Int.toString} violations:`)
    ->ignore
    lines->Js.Array2.push(`  Errors: ${errors->Int.toString}`)->ignore
    lines->Js.Array2.push(`  Warnings: ${warnings->Int.toString}`)->ignore
    lines->Js.Array2.push("")->ignore

    violations->Belt.Array.forEach(violation => {
      let marker = violation.severity == "error" ? "❌" : "⚠️"
      lines->Js.Array2.push(`${marker} ${violation.file}`)->ignore
      lines->Js.Array2.push(`   ${violation.message}`)->ignore

      switch violation.suggestedFix {
      | None => ()
      | Some(fix) => {
          lines->Js.Array2.push("   Suggested migrations:")->ignore
          fix
          ->Js.String2.split("\n")
          ->Belt.Array.forEach(line => {
            lines->Js.Array2.push(`     - ${line}`)->ignore
          })
        }
      }

      lines->Js.Array2.push("")->ignore
    })

    lines->Js.Array2.push("Recommended Actions:")->ignore
    lines->Js.Array2.push("  1. Migrate Python code to ReScript for type safety")->ignore
    lines->Js.Array2.push("  2. Or use Deno for secure TypeScript/JavaScript runtime")->ignore
    lines->Js.Array2.push("  3. Remove Python dependencies from repository")->ignore
    lines->Js.Array2.push("  4. Update CI/CD to prevent Python code introduction")->ignore
  }

  lines->Js.Array2.joinWith("\n")
}

// Create GitHub issue template for Python removal
let generateIssueTemplate = (violations: array<cccpViolation>): string => {
  let fileList =
    violations->Belt.Array.map(v => `- [ ] ${v.file}`)->Js.Array2.joinWith("\n")

  `## Python Removal Task

**Patrojisign/insulti Warning**: Python files detected in repository

### Files to migrate or remove:
${fileList}

### Migration Strategy:
1. **Assess each Python file's purpose**
2. **Choose migration target:**
   - ReScript: For type-safe, functional programming
   - Deno: For secure TypeScript/JavaScript runtime
   - Alternative: R/Julia for data science
3. **Implement migration**
4. **Add tests for migrated code**
5. **Remove Python files**
6. **Update documentation**

### CCCP Compliance Checklist:
- [ ] All Python files identified
- [ ] Migration plan approved
- [ ] Code migrated to ReScript/Deno
- [ ] Tests passing
- [ ] Python files removed
- [ ] CI/CD updated to prevent Python
- [ ] Documentation updated

### Resources:
- [ReScript Documentation](https://rescript-lang.org/)
- [Deno Manual](https://deno.land/manual)
- [Migration Guide](./docs/python-migration.md)
`
}

// Export compliance status as JSON
let exportComplianceJSON = (violations: array<cccpViolation>): Js.Json.t => {
  Js.Json.object_(
    Js.Dict.fromArray([
      (
        "compliant",
        Js.Json.boolean(Belt.Array.length(violations) == 0),
      ),
      (
        "violations",
        Js.Json.array(
          violations->Belt.Array.map(v => {
            Js.Json.object_(
              Js.Dict.fromArray([
                ("file", Js.Json.string(v.file)),
                ("type", Js.Json.string(v.violationType)),
                ("severity", Js.Json.string(v.severity)),
                ("message", Js.Json.string(v.message)),
                (
                  "suggestedFix",
                  switch v.suggestedFix {
                  | None => Js.Json.null
                  | Some(fix) => Js.Json.string(fix)
                  },
                ),
              ]),
            )
          }),
        ),
      ),
      ("timestamp", Js.Json.number(Js.Date.now())),
    ]),
  )
}
