// SPDX-License-Identifier: PMPL-1.0-or-later
// IntegrationOps.res - Executors for ecosystem integration operations

open Plan

// Execute CreateScaffold operation
let executeCreateScaffold = (
  template: string,
  destination: string,
  repoName: string,
  metadata: Js.Dict.t<string>,
  ctx: executionContext,
): Promise.t<opResult> => {
  Console.log(`[CreateScaffold] template=${template}, dest=${destination}, repo=${repoName}`)

  // TODO v0.1.0: Call scaffoldia CLI
  // Expected flow:
  // 1. Resolve template path from scaffoldia registry
  // 2. Load template Nickel file
  // 3. Substitute metadata placeholders
  // 4. Generate directory structure
  // 5. Create files with processed content
  // 6. Initialize git repository
  // 7. Create initial commit

  Promise.resolve({
    opId: "create-scaffold",
    status: Skipped({reason: "CreateScaffold not implemented - requires scaffoldia v0.2.0 CLI"}),
    startedAt: None,
    completedAt: None,
    output: None,
    error: None,
    metadata: Dict.make(),
  })
}

// Execute UpdateMetadataFromSeo operation
let executeUpdateMetadataFromSeo = (
  repoPath: string,
  runAnalysis: bool,
  ctx: executionContext,
): Promise.t<opResult> => {
  Console.log(`[UpdateMetadataFromSeo] repo=${repoPath}, analyze=${Bool.toString(runAnalysis)}`)

  // TODO v0.1.0: Integrate with git-seo
  // Expected flow:
  // 1. If runAnalysis=true, execute: git-seo analyze <repo> --json
  // 2. Parse JSON output to extract SEO score
  // 3. Read .machine_readable/STATE.scm
  // 4. Update (integration (seo-score . "X")) field
  // 5. Update (integration (seo-last-updated . "TIMESTAMP"))
  // 6. Write updated STATE.scm back to disk
  // 7. Return changes summary

  Promise.resolve({
    opId: "update-seo",
    status: Skipped({reason: "UpdateMetadataFromSeo not implemented - requires git-seo v0.4.0 JSON output"}),
    startedAt: None,
    completedAt: None,
    output: None,
    error: None,
    metadata: Dict.make(),
  })
}

// Execute RenderDocumentation operation
let executeRenderDocumentation = (
  repoPath: string,
  templates: array<string>,
  ctx: executionContext,
): Promise.t<opResult> => {
  let templateList = Array.length(templates) == 0
    ? "all"
    : Array.joinWith(templates, ", ", x => x)

  Console.log(`[RenderDocumentation] repo=${repoPath}, templates=${templateList}`)

  // TODO v0.1.0: Call gnosis renderer
  // Expected flow:
  // 1. Load all 6 SCM files using SixSCMEnhanced
  // 2. If templates=[], find all *.template.* files
  // 3. For each template:
  //    a. Read template content
  //    b. Extract placeholders: (:dotted.path.key)
  //    c. Look up values in SCM contexts
  //    d. Replace placeholders with values
  //    e. Write rendered output (strip .template from name)
  // 4. Return list of rendered files

  Promise.resolve({
    opId: "render-docs",
    status: Skipped({reason: "RenderDocumentation not implemented - requires gnosis SixSCMEnhanced integration"}),
    startedAt: None,
    completedAt: None,
    output: None,
    error: None,
    metadata: Dict.make(),
  })
}

// Execute RegisterInReposystem operation
let executeRegisterInReposystem = (
  repoPath: string,
  repoName: string,
  aspects: array<string>,
  group: option<string>,
  ctx: executionContext,
): Promise.t<opResult> => {
  let aspectList = Array.joinWith(aspects, ", ", x => x)
  let groupStr = Option.mapWithDefault(group, "none", g => g)

  Console.log(`[RegisterInReposystem] name=${repoName}, aspects=${aspectList}, group=${groupStr}`)

  // TODO v0.1.0: Add repo to reposystem graph
  // Expected flow:
  // 1. Read reposystem graph TOML file
  // 2. Create new [[repositories]] entry with:
  //    - name = repoName
  //    - path = repoPath
  //    - aspects = aspects array
  //    - group = group (if specified)
  // 3. Detect relationships by scanning:
  //    - Cargo.toml dependencies
  //    - package.json dependencies
  //    - Project.toml dependencies
  //    - Import statements
  // 4. Add relationships to graph
  // 5. Write updated graph back to disk
  // 6. Update .machine_readable/STATE.scm:
  //    (integration (reposystem-registered . "true"))

  Promise.resolve({
    opId: "register-reposystem",
    status: Skipped({reason: "RegisterInReposystem not implemented - requires reposystem graph API"}),
    startedAt: None,
    completedAt: None,
    output: None,
    error: None,
    metadata: Dict.make(),
  })
}

// Dispatch integration operation to appropriate executor
let executeIntegrationOp = (
  op: operationType,
  ctx: executionContext,
): Promise.t<opResult> => {
  switch op {
  | CreateScaffold({template, destination, repoName, metadata}) =>
    executeCreateScaffold(template, destination, repoName, metadata, ctx)

  | UpdateMetadataFromSeo({repoPath, runAnalysis}) =>
    executeUpdateMetadataFromSeo(repoPath, runAnalysis, ctx)

  | RenderDocumentation({repoPath, templates}) =>
    executeRenderDocumentation(repoPath, templates, ctx)

  | RegisterInReposystem({repoPath, repoName, aspects, group}) =>
    executeRegisterInReposystem(repoPath, repoName, aspects, group, ctx)

  | _ =>
    Promise.resolve({
      opId: "unknown",
      status: Failed({error: "Not an integration operation"}),
      startedAt: None,
      completedAt: None,
      output: None,
      error: Some("Not an integration operation"),
      metadata: Dict.make(),
    })
  }
}
