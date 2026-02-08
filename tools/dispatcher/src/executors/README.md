# Executors

Operation executors for git-dispatcher.

## Status: Stub Implementation (v0.0.1)

All executors are currently **stubs** that return `Skipped` results. They serve as:
1. **Type-safe contracts** for operation execution
2. **Documentation** of expected behavior
3. **Integration points** for v0.1.0 implementation

## Integration Operations

### IntegrationOps.res

Executors for ecosystem integration operations:

- **CreateScaffold** - Generate new repository from scaffoldia template
  - Status: Stub
  - Requires: scaffoldia v0.2.0 CLI
  - Blocks: Full implementation on scaffoldia Haskell toolchain

- **UpdateMetadataFromSeo** - Run git-seo and update STATE.scm
  - Status: Stub
  - Requires: git-seo v0.4.0 with JSON output
  - Dependency: git-seo released (ready)

- **RenderDocumentation** - Render templates with gnosis
  - Status: Stub
  - Requires: gnosis with SixSCMEnhanced module
  - Dependency: gnosis ready (compiled successfully)

- **RegisterInReposystem** - Add repo to ecosystem graph
  - Status: Stub
  - Requires: reposystem graph API
  - Blocks: Graph TOML structure needs definition

## Implementation Plan

### v0.1.0 (4-6 weeks)
- Implement IntegrationOps executors
- Wire into main execution engine
- Add error handling and rollback
- Integration tests with real tools

### v0.2.0 (8-10 weeks)
- Parallel execution for independent ops
- Retry logic with exponential backoff
- Operation composition (chains)
- Performance optimization

## Usage

```rescript
open IntegrationOps

let ctx = {
  timestamp: Date.now()->Float.toString,
  botVersion: "0.1.0",
  triggeredBy: "manual",
  metadata: Js.Dict.empty(),
}

let op = CreateScaffold({
  template: "rescript/deno-app",
  destination: "/path/to/new-repo",
  repoName: "my-awesome-project",
  metadata: Js.Dict.fromList([
    ("description", "My awesome project"),
    ("author", "Jonathan D.A. Jewell"),
  ]),
})

executeIntegrationOp(op, ctx)
  ->Promise.then(result => {
    switch result {
    | Success(_) => Console.log("✓ Operation succeeded")
    | Skipped({reason}) => Console.log(`⊘ Skipped: ${reason}`)
    | Failure({error}) => Console.error(`✗ Failed: ${error}`)
    }
    Promise.resolve()
  })
```

## Testing

Run tests with:
```bash
deno test --allow-read --allow-write --allow-env tests/executors/
```

## Architecture

Executors follow a consistent pattern:

1. **Log operation** - Record what's being attempted
2. **Validate prerequisites** - Check tool availability
3. **Execute operation** - Call external tool or API
4. **Parse output** - Extract results
5. **Update state** - Modify STATE.scm or graph
6. **Return result** - Success/Failure/Skipped

Each executor is pure - side effects are isolated to the operation itself.

## Dependencies

| Executor | External Tool | Version | Status |
|----------|---------------|---------|--------|
| CreateScaffold | scaffoldia | ≥0.2.0 | ⏳ Blocked (Haskell toolchain) |
| UpdateMetadataFromSeo | git-seo | ≥0.4.0 | ✅ Ready |
| RenderDocumentation | gnosis | ≥1.0.0 | ✅ Ready |
| RegisterInReposystem | reposystem | ≥0.3.0 | ⏳ Blocked (graph API) |

## Error Handling

Executors never throw exceptions. All errors are captured in `operationResult`:

- **Success** - Operation completed, changes applied
- **Failure** - Operation failed, includes error message and recoverability
- **Skipped** - Operation not executed, includes reason

Recoverable failures can be retried. Non-recoverable failures require manual intervention.
