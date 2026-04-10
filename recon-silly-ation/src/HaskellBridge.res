// SPDX-License-Identifier: PMPL-1.0-or-later
// ReScript bridge to Haskell validator
// Calls Haskell validator for schema enforcement

open Types

// execFileSync returns a string when called with `{"encoding": "utf8"}`.
// The original binding declared the return as Buffer.t, which forced a
// Buffer.toString call that the current rescript Buffer bindings don't expose.
@module("child_process") @val
external execFileSync: (string, array<string>, {..}) => string = "execFileSync"

// Direct fs bindings. The rescript Node.Fs module is not available in this
// repo's bindings configuration, so we bind the JS APIs directly.
@module("fs") @val
external writeFileSyncUtf8: (string, string, string) => unit = "writeFileSync"

@module("fs") @val
external unlinkSync: string => unit = "unlinkSync"

@module("fs") @val
external accessSync: string => unit = "accessSync"

// schemaViolation must be declared before validationResult because the latter
// references it in its `violations` field — non-recursive types can't
// forward-reference.
type schemaViolation = {
  violationField: string,
  violationMessage: string,
  violationSeverity: string,
  violationLine: option<int>,
}

type validationResult = {
  isValid: bool,
  violations: array<schemaViolation>,
  confidence: float,
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
    // Direct fs.writeFileSync binding — the Node.Fs helpers in the current
    // rescript node bindings don't include a UTF-8 convenience wrapper.
    writeFileSyncUtf8(tempFile, doc.content, "utf8")

    // Call Haskell validator
    let output = execFileSync(
      validatorPath,
      [docTypeStr, tempFile],
      {"encoding": "utf8"},
    )

    // Parse JSON output — `output` is already a UTF-8 string because
    // execFileSync was called with `{"encoding": "utf8"}`.
    let json = Js.Json.parseExn(output)

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

    // Drop any array element that isn't a JSON object instead of crashing on
    // the first bad one. keepMap returns Some values and skips Nones.
    let parsedViolations =
      violations->Belt.Array.keepMap(v => {
        switch v->Js.Json.decodeObject {
        | None => None
        | Some(obj) =>
          Some({
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
          })
        }
      })

    // Clean up temp file
    try {
      unlinkSync(tempFile)
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
      `Haskell validator failed: ${Js.Exn.asJsExn(exn)->Belt.Option.flatMap(Js.Exn.message)->Belt.Option.getWithDefault("Unknown error")}`,
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
  lines->Js.Array2.push(`Total documents validated: ${results->Belt.Array.length->Belt.Int.toString}`)->ignore

  let valid = results->Belt.Array.keep(((_, r)) => r.isValid)->Belt.Array.length
  let invalid = results->Belt.Array.length - valid

  lines->Js.Array2.push(`Valid: ${valid->Belt.Int.toString}`)->ignore
  lines->Js.Array2.push(`Invalid: ${invalid->Belt.Int.toString}`)->ignore
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
    accessSync(validatorPath)
    true
  } catch {
  | _ => false
  }
}
