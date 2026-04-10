// SPDX-License-Identifier: PMPL-1.0-or-later
//
// PackShipper - Document bundle packaging and distribution
//
// This module handles creating, validating, and shipping document bundles
// according to pack specifications. It ensures bundles meet requirements
// before distribution.

open Types

// ============================================================================
// Types
// ============================================================================

// Pack manifest
type packManifest = {
  name: string,
  version: string,
  description: string,
  author: string,
  license: string,
  created: float,
  documents: array<documentManifestEntry>,
  validation: packValidation,
}

// Document entry in manifest
and documentManifestEntry = {
  path: string,
  docType: string,
  hash: string,
  size: int,
  required: bool,
}

// Validation section in manifest
and packValidation = {
  packSpec: string,
  validated: bool,
  validatedAt: float,
  errors: array<string>,
  warnings: array<string>,
}

// Shipping destination
type shippingDestination =
  | GitRepository(string, string) // url, branch
  | FileSystem(string) // path
  | ArangoDb(string, string) // url, database
  | Archive(string) // path to archive

// Shipping options
type shippingOptions = {
  destination: shippingDestination,
  dryRun: bool,
  force: bool,
  createPR: bool,
  prTitle: option<string>,
  prBody: option<string>,
}

// Shipping result
type shippingResult = {
  success: bool,
  destination: string,
  manifest: packManifest,
  timestamp: float,
  errors: array<string>,
  prUrl: option<string>,
}

// ============================================================================
// Pack Specifications
// ============================================================================

// Standard Hyperpolymath pack
let hyperpolymathPackSpec = `
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

  -- Validation rules
  "license-check" [
    "LICENSE" bundle-get-type nil <>
    [
      "LICENSE" bundle-get-type doc-content
      "Palimpsest" str-contains?
      "License must be PMPL-1.0-or-later (Palimpsest)" require!
    ] when
  ] pack-rule

  "spdx-headers" [
    bundle-docs [
      dup doc-path ".res" str-ends?
      over doc-path ".rs" str-ends? or
      [
        dup doc-content "SPDX-License-Identifier" str-contains? not
        [ doc-path " missing SPDX header" error! ] when
      ] when
    ] each
  ] pack-rule

  bundle-validate
`

// Minimal pack (just essentials)
let minimalPackSpec = `
  "minimal" pack-new
  "README" pack-require
  "LICENSE" pack-require
  bundle-validate
`

// Security-focused pack
let securityPackSpec = `
  "security" pack-new
  "README" pack-require
  "LICENSE" pack-require
  "SECURITY" pack-require
  "CONTRIBUTING" pack-require

  "security-content" [
    "SECURITY" bundle-get-type nil <>
    [
      "SECURITY" bundle-get-type doc-content
      "vulnerability" str-lower str-contains? not
      [ "SECURITY.md should describe vulnerability reporting" warn! ] when
    ] when
  ] pack-rule

  bundle-validate
`

// OSS pack (open source focused)
let ossPackSpec = `
  "oss" pack-new
  "README" pack-require
  "LICENSE" pack-require
  "CONTRIBUTING" pack-require
  "CODE_OF_CONDUCT" pack-require
  "CHANGELOG" pack-optional
  "AUTHORS" pack-optional

  "readme-quality" [
    "README" bundle-get-type doc-content
    dup "## " str-contains? not
    [ "README should have sections" warn! ] when
    str-len 500 <
    [ "README seems too short" warn! ] when
  ] pack-rule

  bundle-validate
`

// ============================================================================
// Pack Building
// ============================================================================

// Create a manifest from a bundle
let createManifest = (
  bundle: ReconForth.bundle,
  name: string,
  version: string,
  ~description: string="",
  ~author: string="",
  ~packSpec: string=hyperpolymathPackSpec,
  (),
): packManifest => {
  // Validate bundle against pack spec
  let validationResult = ReconForth.validateBundle(bundle, packSpec)

  let documents = bundle.documents->Belt.Array.map((doc): documentManifestEntry => {
    {
      path: doc.metadata.path,
      docType: doc.metadata.document_type,
      hash: doc.hash,
      size: String.length(doc.content),
      required: true, // Could be enhanced to check against pack spec
    }
  })

  {
    name,
    version,
    description,
    author,
    license: "PMPL-1.0-or-later",
    created: Js.Date.now(),
    documents,
    validation: {
      packSpec,
      validated: validationResult.success,
      validatedAt: Js.Date.now(),
      errors: validationResult.errors->Belt.Array.map(e => e.message),
      warnings: validationResult.warnings->Belt.Array.map(w => w.message),
    },
  }
}

// Validate a manifest
let validateManifest = (manifest: packManifest): bool => {
  manifest.validation.validated && Belt.Array.length(manifest.validation.errors) == 0
}

// Convert manifest to JSON string
let manifestToJson = (manifest: packManifest): string => {
  // Using manual JSON construction for simplicity
  let docsJson = manifest.documents
    ->Belt.Array.map(d =>
      `{"path":"${d.path}","docType":"${d.docType}","hash":"${d.hash}","size":${Int.toString(d.size)},"required":${d.required ? "true" : "false"}}`
    )
    ->Belt.Array.joinWith(",")

  let errorsJson = manifest.validation.errors->Belt.Array.map(e => `"${e}"`)->Belt.Array.joinWith(",")

  let warningsJson =
    manifest.validation.warnings->Belt.Array.map(w => `"${w}"`)->Belt.Array.joinWith(",")

  `{
  "name": "${manifest.name}",
  "version": "${manifest.version}",
  "description": "${manifest.description}",
  "author": "${manifest.author}",
  "license": "${manifest.license}",
  "created": ${Float.toString(manifest.created)},
  "documents": [${docsJson}],
  "validation": {
    "validated": ${manifest.validation.validated ? "true" : "false"},
    "validatedAt": ${Float.toString(manifest.validation.validatedAt)},
    "errors": [${errorsJson}],
    "warnings": [${warningsJson}]
  }
}`
}

// ============================================================================
// Shipping Operations
// ============================================================================

// Ship a bundle to a destination
let ship = (
  bundle: ReconForth.bundle,
  manifest: packManifest,
  options: shippingOptions,
): shippingResult => {
  // Validate manifest first
  if !validateManifest(manifest) && !options.force {
    {
      success: false,
      destination: switch options.destination {
      | GitRepository(url, _) => url
      | FileSystem(path) => path
      | ArangoDb(url, _) => url
      | Archive(path) => path
      },
      manifest,
      timestamp: Js.Date.now(),
      errors: Belt.Array.concat(
        ["Pack validation failed"],
        manifest.validation.errors,
      ),
      prUrl: None,
    }
  } else if options.dryRun {
    // Dry run - just report what would happen
    {
      success: true,
      destination: switch options.destination {
      | GitRepository(url, branch) => `${url}#${branch} (dry run)`
      | FileSystem(path) => `${path} (dry run)`
      | ArangoDb(url, db) => `${url}/${db} (dry run)`
      | Archive(path) => `${path} (dry run)`
      },
      manifest,
      timestamp: Js.Date.now(),
      errors: [],
      prUrl: None,
    }
  } else {
    // Actual shipping would happen here
    // For now, just return success
    {
      success: true,
      destination: switch options.destination {
      | GitRepository(url, branch) => `${url}#${branch}`
      | FileSystem(path) => path
      | ArangoDb(url, db) => `${url}/${db}`
      | Archive(path) => path
      },
      manifest,
      timestamp: Js.Date.now(),
      errors: [],
      prUrl: options.createPR ? Some("https://github.com/owner/repo/pull/1") : None,
    }
  }
}

// ============================================================================
// Convenience Functions
// ============================================================================

// Create and ship in one operation
let createAndShip = (
  bundle: ReconForth.bundle,
  name: string,
  version: string,
  destination: shippingDestination,
  ~packSpec: string=hyperpolymathPackSpec,
  ~dryRun: bool=false,
  (),
): shippingResult => {
  let manifest = createManifest(bundle, name, version, ~packSpec, ())
  let options = {
    destination,
    dryRun,
    force: false,
    createPR: false,
    prTitle: None,
    prBody: None,
  }
  ship(bundle, manifest, options)
}

// Ship to a Git repository with PR
let shipWithPR = (
  bundle: ReconForth.bundle,
  manifest: packManifest,
  repoUrl: string,
  branch: string,
  ~title: string="Update documentation bundle",
  ~body: string="Automated documentation update via PackShipper",
  (),
): shippingResult => {
  let options = {
    destination: GitRepository(repoUrl, branch),
    dryRun: false,
    force: false,
    createPR: true,
    prTitle: Some(title),
    prBody: Some(body),
  }
  ship(bundle, manifest, options)
}

// Generate shipping report
let generateShippingReport = (result: shippingResult): string => {
  `# Shipping Report

## Summary
- **Success**: ${result.success ? "Yes" : "No"}
- **Destination**: ${result.destination}
- **Timestamp**: ${Float.toString(result.timestamp)}
${result.prUrl->Belt.Option.mapWithDefault("", url => `- **Pull Request**: ${url}`)}

## Manifest
- **Name**: ${result.manifest.name}
- **Version**: ${result.manifest.version}
- **Documents**: ${Int.toString(Belt.Array.length(result.manifest.documents))}
- **Validated**: ${result.manifest.validation.validated ? "Yes" : "No"}

## Documents
${result.manifest.documents
    ->Belt.Array.map(d =>
      `- ${d.path} (${d.docType}, ${Int.toString(d.size)} bytes)`
    )
    ->Belt.Array.joinWith("\n")}

## Validation
${if Belt.Array.length(result.manifest.validation.errors) > 0 {
    `### Errors
${result.manifest.validation.errors->Belt.Array.map(e => `- ${e}`)->Belt.Array.joinWith("\n")}`
  } else {
    "No errors"
  }}

${if Belt.Array.length(result.manifest.validation.warnings) > 0 {
    `### Warnings
${result.manifest.validation.warnings->Belt.Array.map(w => `- ${w}`)->Belt.Array.joinWith("\n")}`
  } else {
    "No warnings"
  }}

${if Belt.Array.length(result.errors) > 0 {
    `## Shipping Errors
${result.errors->Belt.Array.map(e => `- ${e}`)->Belt.Array.joinWith("\n")}`
  } else {
    ""
  }}
`
}
