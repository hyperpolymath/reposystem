// SPDX-License-Identifier: PMPL-1.0-or-later
//
// ReconForth - ReScript bindings for the ReconForth DSL
//
// This module provides type-safe bindings to the Rust/WASM ReconForth interpreter
// for document bundle validation and reconciliation.

// ============================================================================
// Types
// ============================================================================

// Validation message from ReconForth
type validationMessage = {
  message: string,
  path: option<string>,
  rule: option<string>,
}

// Validation result from ReconForth evaluation
type validationResult = {
  success: bool,
  errors: array<validationMessage>,
  warnings: array<validationMessage>,
  suggestions: array<validationMessage>,
}

// Document metadata
type documentMetadata = {
  path: string,
  document_type: string,
  last_modified: float,
  version: option<string>,
  canonical_source: string,
  repository: string,
  branch: string,
}

// A document in the reconciliation system
type document = {
  hash: string,
  content: string,
  metadata: documentMetadata,
  created_at: float,
}

// A bundle of documents
type bundle = {documents: array<document>}

// ============================================================================
// WASM Bindings (external)
// ============================================================================

// These will be loaded from the compiled WASM module
@module("../wasm-modules/pkg/recon_wasm.js")
external wasmHashContent: string => string = "hash_content"

@module("../wasm-modules/pkg/recon_wasm.js")
external wasmNormalizeContent: string => string = "normalize_content"

@module("../wasm-modules/pkg/recon_wasm.js")
external wasmBatchHash: array<string> => array<string> = "batch_hash"

@module("../wasm-modules/pkg/recon_wasm.js")
external wasmReconforthEval: string => validationResult = "reconforth_eval"

@module("../wasm-modules/pkg/recon_wasm.js")
external wasmReconforthEvalBundle: (string, bundle) => validationResult = "reconforth_eval_bundle"

@module("../wasm-modules/pkg/recon_wasm.js")
external wasmValidateBundle: (bundle, string) => validationResult = "validate_bundle"

@module("../wasm-modules/pkg/recon_wasm.js")
external wasmCreateDocument: (string, string, string) => document = "create_document"

@module("../wasm-modules/pkg/recon_wasm.js")
external wasmCreateBundle: unit => bundle = "create_bundle"

@module("../wasm-modules/pkg/recon_wasm.js")
external wasmBundleAddDocument: (bundle, document) => bundle = "bundle_add_document"

// ============================================================================
// High-level API
// ============================================================================

// Hash content using SHA-256
let hashContent = wasmHashContent

// Normalize whitespace in content
let normalizeContent = wasmNormalizeContent

// Batch hash multiple documents
let batchHash = wasmBatchHash

// Evaluate a ReconForth program
let eval = wasmReconforthEval

// Evaluate a ReconForth program with a bundle
let evalBundle = wasmReconforthEvalBundle

// Validate a bundle against a pack specification
let validateBundle = wasmValidateBundle

// Create a document from content
let createDocument = (content: string, path: string, docType: string): document => {
  wasmCreateDocument(content, path, docType)
}

// Create an empty bundle
let createBundle = (): bundle => {
  wasmCreateBundle()
}

// Add a document to a bundle
let addDocument = (bundle: bundle, doc: document): bundle => {
  wasmBundleAddDocument(bundle, doc)
}

// ============================================================================
// Pack Specification Builders
// ============================================================================

// Standard Hyperpolymath pack specification
let standardPack = `
  "hyperpolymath-standard" pack-new

  -- Required documents
  "README" pack-require
  "LICENSE" pack-require
  "SECURITY" pack-require
  "CONTRIBUTING" pack-require
  "CODE_OF_CONDUCT" pack-require

  -- Optional documents
  "FUNDING" pack-optional
  "CITATION" pack-optional
  "CHANGELOG" pack-optional
  "AUTHORS" pack-optional
  "SUPPORT" pack-optional

  -- Custom validation rules
  "license-pmpl" [
    "LICENSE" bundle-get-type nil <>
    [ "LICENSE" bundle-get-type doc-content "Palimpsest" str-contains?
      "License must be PMPL-1.0-or-later (Palimpsest)" require!
    ] when
  ] pack-rule

  bundle-validate
`

// Minimal pack specification (just LICENSE and README)
let minimalPack = `
  "minimal" pack-new
  "README" pack-require
  "LICENSE" pack-require
  bundle-validate
`

// Security-focused pack specification
let securityPack = `
  "security-focused" pack-new
  "README" pack-require
  "LICENSE" pack-require
  "SECURITY" pack-require
  "CONTRIBUTING" pack-require

  "has-security-policy" [
    "SECURITY" bundle-get-type nil <>
    "Security policy is required" require!
  ] pack-rule

  "security-content-check" [
    "SECURITY" bundle-get-type nil <>
    [
      "SECURITY" bundle-get-type doc-content
      "vulnerability" str-lower str-contains?
      "Security policy should describe vulnerability reporting" suggest!
    ] when
  ] pack-rule

  bundle-validate
`

// ============================================================================
// Enforcement Rules
// ============================================================================

// Check for SPDX headers in source files
let checkSpdxHeaders = `
  : has-spdx? ( doc -- bool )
    doc-content "SPDX-License-Identifier" str-contains? ;

  : check-source-file ( doc -- )
    dup doc-path ".res" str-ends?
    over doc-path ".rs" str-ends? or
    over doc-path ".ts" str-ends? or
    over doc-path ".js" str-ends? or
    [
      dup has-spdx? not
      [ doc-path " missing SPDX header" str-concat error! ]
      [ drop ]
      if
    ]
    [ drop ]
    if ;

  bundle-docs [ check-source-file ] each
`

// Check for banned languages (TypeScript when ReScript should be used)
let checkBannedLanguages = `
  : is-typescript? ( doc -- bool )
    doc-path ".ts" str-ends?
    swap doc-path ".tsx" str-ends? or ;

  : count-typescript ( bundle -- n )
    bundle-docs [ is-typescript? ] filter list-len nip ;

  dup count-typescript 0 >
  [ "TypeScript files detected - use ReScript instead per RSR" error! ]
  when
`

// Check for proper README structure
let checkReadmeStructure = `
  "README" bundle-get-type nil <>
  [
    "README" bundle-get-type doc-content

    -- Check for required sections
    dup "## " str-contains? not
    [ "README should have sections (## headers)" warn! ] when

    dup "Install" str-contains? not
    over "Getting Started" str-contains? not and
    [ "README should have installation instructions" suggest! ] when

    drop
  ]
  [ "Missing README file" error! ]
  if
`

// ============================================================================
// Helper Functions
// ============================================================================

// Check if a bundle is valid according to standard pack
let isValidStandardBundle = (bundle: bundle): bool => {
  let result = validateBundle(bundle, standardPack)
  result.success
}

// Get all validation errors from a bundle
let getErrors = (bundle: bundle, packSpec: string): array<string> => {
  let result = validateBundle(bundle, packSpec)
  result.errors->Belt.Array.map(e => e.message)
}

// Get all warnings from a bundle
let getWarnings = (bundle: bundle, packSpec: string): array<string> => {
  let result = validateBundle(bundle, packSpec)
  result.warnings->Belt.Array.map(w => w.message)
}

// Create a bundle from a list of file paths and contents
let bundleFromFiles = (files: array<(string, string, string)>): bundle => {
  files->Belt.Array.reduce(createBundle(), (bundle, (path, content, docType)) => {
    let doc = createDocument(content, path, docType)
    addDocument(bundle, doc)
  })
}

// Run all enforcement checks
let runEnforcementChecks = (bundle: bundle): validationResult => {
  let checkScript = `
    ${checkSpdxHeaders}
    ${checkBannedLanguages}
    ${checkReadmeStructure}
  `
  evalBundle(checkScript, bundle)
}
