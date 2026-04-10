// SPDX-License-Identifier: PMPL-1.0-or-later
// ReScript bridge to Haskell validator
// Calls Haskell validator for schema enforcement

open Types

@module("child_process") @val
external execFileSync: (string, array<string>, {..}) => Buffer.t = "execFileSync"

type validationResult = {
  isValid: bool,
  violations: array<schemaViolation>,
  confidence: float,
}

type schemaViolation = {
  violationField: string,
  violationMessage: string,
  violationSeverity: string,
  violationLine: option<int>,
}

// Call Haskell validator
let validateDocument = (
  doc: document,
  validatorPath: string,
): result<validationResult, string> => {
  try {
    let docTypeStr = documentTypeToString(doc.metadata.documentType)

    // Write content to temp file
    let tempFile = "/tmp/doc_" ++ doc.hash ++ ".tmp"
    Node.Fs.writeFileSyncWith(tempFile, doc.content, #utf8)

    // Call Haskell validator
    let output = execFileSync(
      validatorPath,
      [docTypeStr, tempFile],
      {"encoding": "utf8"},
    )

    // Parse JSON output
    let json = output->Buffer.toString->Js.Json.parseExn

    // Decode validation result
    let isValid = json
    ->Js.Json.decodeObject
    ->Belt.Option.flatMap(obj => Js.Dict.get(obj, "isValid"))
    ->Belt.Option.flatMap(Js.Json.decodeBoolean)
    ->Belt.Option.getWithDefault(false)

    let confidence = json
    ->Js.Json.decodeObject
    ->Belt.Option.flatMap(obj => Js.Dict.get(obj, "confidence"))
    ->Belt.Option.flatMap(Js.Json.decodeNumber)
    ->Belt.Option.getWithDefault(0.0)

    let violations = json
    ->Js.Json.decodeObject
    ->Belt.Option.flatMap(obj => Js.Dict.get(obj, "violations"))
    ->Belt.Option.flatMap(Js.Json.decodeArray)
    ->Belt.Option.getWithDefault([])

    let parsedViolations =
      violations->Belt.Array.map(v => {
        let obj = v->Js.Json.decodeObject->Belt.Option.getExn

        {
          violationField: obj
          ->Js.Dict.get("violationField")
          ->Belt.Option.flatMap(Js.Json.decodeString)
          ->Belt.Option.getWithDefault(""),
          violationMessage: obj
          ->Js.Dict.get("violationMessage")
          ->Belt.Option.flatMap(Js.Json.decodeString)
          ->Belt.Option.getWithDefault(""),
          violationSeverity: obj
          ->Js.Dict.get("violationSeverity")
          ->Belt.Option.flatMap(Js.Json.decodeString)
          ->Belt.Option.getWithDefault("warning"),
          violationLine: None,
        }
      })

    // Clean up temp file
    try {
      Node.Fs.unlinkSync(tempFile)
    } catch {
    | _ => ()
    }

    Ok({
      isValid: isValid,
      violations: parsedViolations,
      confidence: confidence,
    })
  } catch {
  | exn =>
    Error(
      `Haskell validator failed: ${exn->Js.Exn.message->Belt.Option.getWithDefault("Unknown error")}`,
    )
  }
}

// Batch validate documents
let validateDocuments = (
  documents: array<document>,
  validatorPath: string,
): array<(document, validationResult)> => {
  documents
  ->Belt.Array.map(doc => {
    switch validateDocument(doc, validatorPath) {
    | Ok(result) => Some((doc, result))
    | Error(_) => None
    }
  })
  ->Belt.Array.keepMap(x => x)
}

// Generate validation report
let generateValidationReport = (
  results: array<(document, validationResult)>,
): string => {
  let lines = []

  lines->Js.Array2.push("=== Schema Validation Report ===")->ignore
  lines->Js.Array2.push(`Total documents validated: ${results->Belt.Array.length->Int.toString}`)->ignore

  let valid = results->Belt.Array.keep(((_, r)) => r.isValid)->Belt.Array.length
  let invalid = results->Belt.Array.length - valid

  lines->Js.Array2.push(`Valid: ${valid->Int.toString}`)->ignore
  lines->Js.Array2.push(`Invalid: ${invalid->Int.toString}`)->ignore
  lines->Js.Array2.push("")->ignore

  results->Belt.Array.forEach(((doc, result)) => {
    if !result.isValid {
      lines->Js.Array2.push(`❌ ${doc.metadata.path}`)->ignore
      lines->Js.Array2.push(`   Confidence: ${result.confidence->Belt.Float.toString}`)->ignore

      result.violations->Belt.Array.forEach(v => {
        let marker = v.violationSeverity == "error" ? "ERROR" : "WARNING"
        lines->Js.Array2.push(`   [${marker}] ${v.violationField}: ${v.violationMessage}`)->ignore
      })

      lines->Js.Array2.push("")->ignore
    }
  })

  lines->Js.Array2.joinWith("\n")
}

// Check if validator is available
let checkValidatorAvailable = (validatorPath: string): bool => {
  try {
    Node.Fs.accessSync(validatorPath)
    true
  } catch {
  | _ => false
  }
}
