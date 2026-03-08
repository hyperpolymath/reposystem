// SPDX-License-Identifier: PMPL-1.0-or-later
// Executor.res - Core execution engine for operations

open Plan

// Execute a single operation
let executeOperation = (
  op: planOp,
  ctx: executionContext,
): Promise.t<opResult> => {
  let startTime = Date.now()->Float.toString

  Console.log(`[Executor] Starting operation ${op.id}: ${op.description}`)

  // Create result builder
  let makeResult = (status, output, error) => {
    {
      opId: op.id,
      status,
      startedAt: Some(startTime),
      completedAt: Some(Date.now()->Float.toString),
      output,
      error,
      metadata: Js.Dict.empty(),
    }
  }

  // Validate before execution
  let validationPromise = switch op.opType {
  | UpdateMetadataFromSeo({repoPath, runAnalysis}) =>
    IntegrationValidator.validateUpdateMetadataFromSeo(repoPath, runAnalysis)
  | RenderDocumentation({repoPath, templates}) =>
    IntegrationValidator.validateRenderDocumentation(repoPath, templates)
  | CreateScaffold({template, destination}) =>
    IntegrationValidator.validateCreateScaffold(template, destination)
  | RegisterInReposystem({repoPath, aspects}) =>
    IntegrationValidator.validateRegisterInReposystem(repoPath, aspects)
  | _ =>
    Promise.resolve(IntegrationValidator.Valid)
  }

  validationPromise
    ->Promise.then(validation => {
      switch validation {
      | IntegrationValidator.Invalid(err) => {
          Console.error(`[Executor] Validation failed: ${err.reason}`)
          Promise.resolve(
            makeResult(
              Failed({error: `Validation failed: ${err.reason}`}),
              None,
              Some(`Missing prerequisite: ${err.missingPrerequisite}`),
            )
          )
        }
      | IntegrationValidator.Valid => {
          // Execute based on operation type
          let executionPromise = switch op.opType {
          | UpdateMetadataFromSeo({repoPath, runAnalysis}) =>
            SeoUpdater.execute(repoPath, runAnalysis, ctx)

          | RenderDocumentation({repoPath, templates}) =>
            DocRenderer.execute(repoPath, templates, ctx)

          | CreateScaffold(_) | RegisterInReposystem(_) =>
            // Still using stubs from IntegrationOps
            IntegrationOps.executeIntegrationOp(op.opType, ctx)

          | _ =>
            // Core operations not yet implemented
            Promise.resolve({
              opId: op.id,
              status: Skipped({reason: "Core operations not yet implemented"}),
              startedAt: None,
              completedAt: None,
              output: None,
              error: None,
              metadata: Dict.make(),
            })
          }

          executionPromise
            ->Promise.then(result => {
              // Log the result
              switch result.status {
              | Completed => Console.log(`[Executor] ✓ ${op.id}: Completed`)
              | Failed({error}) => Console.error(`[Executor] ✗ ${op.id}: ${error}`)
              | Skipped({reason}) => Console.log(`[Executor] ⊘ ${op.id}: ${reason}`)
              | _ => ()
              }
              Promise.resolve(result)
            })
        }
      }
    })
}

// Execute a plan
let executePlan = (
  plan: plan,
  ctx: executionContext,
): Promise.t<executionResult> => {
  let startTime = Date.now()->Float.toString

  Console.log(`[Executor] Starting plan ${plan.id}: ${plan.name}`)
  Console.log(`[Executor] Operations: ${Int.toString(Array.length(plan.operations))}`)

  if ctx.dryRun {
    Console.log(`[Executor] DRY RUN - No changes will be made`)
  }

  // Execute operations sequentially (TODO: respect dependency graph)
  let executeSequentially = (ops: array<planOp>): Promise.t<array<opResult>> => {
    Array.reduce(
      ops,
      Promise.resolve([]),
      (accPromise, op) => {
        accPromise->Promise.then(acc => {
          executeOperation(op, ctx)
            ->Promise.then(result => {
              Promise.resolve(Array.concat(acc, [result]))
            })
        })
      },
    )
  }

  executeSequentially(plan.operations)
    ->Promise.then(results => {
      let completedAt = Date.now()->Float.toString

      // Check if any operations failed
      let failures = Array.keep(results, r =>
        switch r.status {
        | Failed(_) => true
        | _ => false
        }
      )

      let status = if Array.length(failures) > 0 {
        Failed({error: `${Int.toString(Array.length(failures))} operations failed`})
      } else {
        Completed
      }

      Console.log(`[Executor] Plan ${plan.id} complete: ${statusToString(status)}`)

      Promise.resolve({
        planId: plan.id,
        status,
        operations: results,
        startedAt: startTime,
        completedAt: Some(completedAt),
        rollbackRequired: Array.length(failures) > 0,
        auditTraceId: None,
      })
    })
}
