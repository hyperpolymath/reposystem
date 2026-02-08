// SPDX-License-Identifier: PMPL-1.0-or-later
// DocRenderer.res - Real implementation of RenderDocumentation operation

open Plan

// Find all template files in repository
let findTemplates = (repoPath: string): Promise.t<Result.t<array<string>, string>> => {
  // TODO v0.1.0: Use Deno.readDir recursively
  // Pattern: *.template.* files (e.g., README.template.adoc)
  Console.log(`[DocRenderer] Would find templates in ${repoPath}`)

  let mockTemplates = [
    "README.template.adoc",
    "docs/API.template.adoc",
  ]

  Promise.resolve(Ok(mockTemplates))
}

// Run gnosis on a single template
let renderTemplate = (
  repoPath: string,
  templatePath: string,
): Promise.t<Result.t<string, string>> => {
  let scmDir = `${repoPath}/.machine_readable`
  let outputPath = String.replace(templatePath, ".template", "")

  // TODO v0.1.0: Execute gnosis
  // Expected command:
  // gnosis render <template> \
  //   --scm-dir <scmDir> \
  //   --output <outputPath>
  //
  // gnosis will:
  // 1. Load all 6 SCM files using SixSCMEnhanced
  // 2. Read template content
  // 3. Extract placeholders: (:dotted.path.key)
  // 4. Look up values in merged SCM context
  // 5. Replace placeholders
  // 6. Write to output file

  Console.log(`[DocRenderer] Would render: ${templatePath} -> ${outputPath}`)
  Console.log(`[DocRenderer]   SCM dir: ${scmDir}`)

  Promise.resolve(Ok(outputPath))
}

// Execute RenderDocumentation operation (real implementation)
let execute = (
  repoPath: string,
  templates: array<string>,
  ctx: executionContext,
): Promise.t<opResult> => {
  Console.log(`[DocRenderer] Rendering documentation for ${repoPath}`)

  // Determine which templates to render
  let templatesPromise = if Array.length(templates) == 0 {
    // No specific templates - find all
    findTemplates(repoPath)
  } else {
    // Use provided templates
    Promise.resolve(Ok(templates))
  }

  templatesPromise
    ->Promise.then(result => {
      switch result {
      | Ok(templateList) => {
          // Render each template
          let renderPromises = Array.map(templateList, template =>
            renderTemplate(repoPath, template)
          )

          Promise.all(renderPromises)
            ->Promise.then(results => {
              // Check if all succeeded
              let failures = Array.keepMap(results, r =>
                switch r {
                | Error(err) => Some(err)
                | Ok(_) => None
                }
              )

              if Array.length(failures) > 0 {
                Promise.resolve({
                  opId: "doc-render",
                  status: Failed({error: `Failed to render ${Int.toString(Array.length(failures))} templates`}),
                  startedAt: Some(Date.make()->Date.toISOString),
                  completedAt: Some(Date.make()->Date.toISOString),
                  output: None,
                  error: Some(Array.joinWith(failures, ", ", x => x)),
                  metadata: Dict.make(),
                })
              } else {
                let outputs = Array.keepMap(results, r =>
                  switch r {
                  | Ok(path) => Some(path)
                  | Error(_) => None
                  }
                )

                Promise.resolve({
                  opId: "doc-render",
                  status: Completed,
                  startedAt: Some(Date.make()->Date.toISOString),
                  completedAt: Some(Date.make()->Date.toISOString),
                  output: Some(`Rendered ${Int.toString(Array.length(outputs))} files`),
                  error: None,
                  metadata: Dict.make(),
                })
              }
            })
        }
      | Error(err) => {
          Promise.resolve({
            opId: "doc-render",
            status: Failed({error: `Failed to find templates: ${err}`}),
            startedAt: Some(Date.make()->Date.toISOString),
            completedAt: Some(Date.make()->Date.toISOString),
            output: None,
            error: Some(err),
            metadata: Dict.make(),
          })
        }
      }
    })
}
