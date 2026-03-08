// SPDX-License-Identifier: PMPL-1.0-or-later
// IntegrationValidator.res - Validate integration operation prerequisites

open Plan

type validationError = {
  operation: string,
  reason: string,
  missingPrerequisite: string,
}

type validationResult =
  | Valid
  | Invalid(validationError)

// Check if scaffoldia CLI is available
let checkScaffoldiaCLI = (): Promise.t<bool> => {
  // TODO: Execute `which scaffoldia` or check PATH
  Promise.resolve(false) // Scaffoldia CLI not yet built
}

// Check if git-seo is available
let checkGitSeo = (): Promise.t<bool> => {
  // TODO: Execute `which git-seo` or `julia -e 'using GitSEO'`
  Promise.resolve(true) // Git-seo exists but may not be in PATH
}

// Check if gnosis is available
let checkGnosis = (): Promise.t<bool> => {
  // TODO: Execute `which gnosis` or check ~/.ghcup/bin/gnosis
  Promise.resolve(true) // Gnosis compiled successfully
}

// Check if reposystem graph exists
let checkReposystemGraph = (graphPath: option<string>): Promise.t<bool> => {
  // TODO: Check if graph TOML file exists at standard location
  // Default: ~/Documents/hyperpolymath-repos/reposystem/graph.toml
  Promise.resolve(false) // Graph structure not yet defined
}

// Validate CreateScaffold prerequisites
let validateCreateScaffold = (
  template: string,
  destination: string,
): Promise.t<validationResult> => {
  checkScaffoldiaCLI()->Promise.then(available => {
    if available {
      // Additional checks:
      // - Template exists in scaffoldia registry
      // - Destination directory doesn't exist or is empty
      // - Write permissions on parent directory
      Promise.resolve(Valid)
    } else {
      Promise.resolve(
        Invalid({
          operation: "CreateScaffold",
          reason: "Scaffoldia CLI not found in PATH",
          missingPrerequisite: "scaffoldia",
        })
      )
    }
  })
}

// Validate UpdateMetadataFromSeo prerequisites
let validateUpdateMetadataFromSeo = (
  repoPath: string,
  runAnalysis: bool,
): Promise.t<validationResult> => {
  if runAnalysis {
    checkGitSeo()->Promise.then(available => {
      if available {
        // Additional checks:
        // - Repository exists at repoPath
        // - .machine_readable/STATE.scm exists
        // - STATE.scm is valid S-expression
        // - Write permissions on STATE.scm
        Promise.resolve(Valid)
      } else {
        Promise.resolve(
          Invalid({
            operation: "UpdateMetadataFromSeo",
            reason: "git-seo not found - cannot run analysis",
            missingPrerequisite: "git-seo",
          })
        )
      }
    })
  } else {
    // Not running analysis - just need existing SEO report
    // Check for seo-report.json or similar
    Promise.resolve(Valid)
  }
}

// Validate RenderDocumentation prerequisites
let validateRenderDocumentation = (
  repoPath: string,
  templates: array<string>,
): Promise.t<validationResult> => {
  checkGnosis()->Promise.then(available => {
    if available {
      // Additional checks:
      // - Repository exists at repoPath
      // - .machine_readable/ directory exists
      // - At least one *.template.* file exists
      // - All specified templates exist
      Promise.resolve(Valid)
    } else {
      Promise.resolve(
        Invalid({
          operation: "RenderDocumentation",
          reason: "gnosis not found - cannot render templates",
          missingPrerequisite: "gnosis",
        })
      )
    }
  })
}

// Validate RegisterInReposystem prerequisites
let validateRegisterInReposystem = (
  repoPath: string,
  aspects: array<string>,
): Promise.t<validationResult> => {
  checkReposystemGraph(None)->Promise.then(available => {
    if available {
      // Additional checks:
      // - Repository exists at repoPath
      // - Repository is a valid git repo
      // - .machine_readable/STATE.scm exists
      // - All specified aspects are valid
      Promise.resolve(Valid)
    } else {
      Promise.resolve(
        Invalid({
          operation: "RegisterInReposystem",
          reason: "reposystem graph not found or not accessible",
          missingPrerequisite: "reposystem-graph",
        })
      )
    }
  })
}

// Validate any integration operation
let validateIntegrationOp = (op: operationType): Promise.t<validationResult> => {
  switch op {
  | CreateScaffold({template, destination}) =>
    validateCreateScaffold(template, destination)

  | UpdateMetadataFromSeo({repoPath, runAnalysis}) =>
    validateUpdateMetadataFromSeo(repoPath, runAnalysis)

  | RenderDocumentation({repoPath, templates}) =>
    validateRenderDocumentation(repoPath, templates)

  | RegisterInReposystem({repoPath, aspects}) =>
    validateRegisterInReposystem(repoPath, aspects)

  | _ =>
    Promise.resolve(
      Invalid({
        operation: "Unknown",
        reason: "Not an integration operation",
        missingPrerequisite: "none",
      })
    )
  }
}

// Get human-readable description of validation error
let describeValidationError = (err: validationError): string => {
  `Operation ${err.operation} failed validation: ${err.reason}\nMissing: ${err.missingPrerequisite}`
}
