// SPDX-License-Identifier: PMPL-1.0-or-later
// Idempotent orchestration pipeline
// Scan → Normalize → Dedupe → Detect → Resolve → Ingest → Report
// Each stage is rerunnable and atomic

open Types

// Node.js file system bindings
@module("fs") @val
external readFileSync: (string, string) => string = "readFileSync"

@module("fs") @val
external existsSync: string => bool = "existsSync"

@module("fs") @val
external readdirSync: string => array<string> = "readdirSync"

@module("fs") @val
external statSync: string => 'a = "statSync"

@send external isDirectory: 'a => bool = "isDirectory"
@send external isFile: 'a => bool = "isFile"

@module("path") @val
external join: (string, string) => string = "join"

@module("path") @val
external basename: string => string = "basename"

@module("path") @val
external extname: string => string = "extname"

@module("child_process") @val
external execSync: (string, 'a) => string = "execSync"

// Parse version from content (e.g., "v1.2.3", "version 2.0.0", "Version: 3.1.4")
let parseVersionFromContent = (content: string): option<version> => {
  let re = %re("/(?:v|version[:\s]+)(\d+)\.(\d+)\.(\d+)/i")
  switch re->Js.Re.exec_(content) {
  | None => None
  | Some(result) => {
      let captures = Js.Re.captures(result)
      switch (
        captures->Belt.Array.get(1)->Belt.Option.flatMap(Js.Nullable.toOption),
        captures->Belt.Array.get(2)->Belt.Option.flatMap(Js.Nullable.toOption),
        captures->Belt.Array.get(3)->Belt.Option.flatMap(Js.Nullable.toOption),
      ) {
      | (Some(major), Some(minor), Some(patch)) =>
        switch (
          Belt.Int.fromString(major),
          Belt.Int.fromString(minor),
          Belt.Int.fromString(patch),
        ) {
        | (Some(maj), Some(min), Some(pat)) => Some({major: maj, minor: min, patch: pat})
        | _ => None
        }
      | _ => None
      }
    }
  }
}

// Detect current git branch, fallback to "main"
let detectGitBranch = (repoPath: string): string => {
  try {
    let result = execSync(
      "git rev-parse --abbrev-ref HEAD",
      {"cwd": repoPath, "encoding": "utf8"},
    )
    let trimmed = result->Js.String2.trim
    if Js.String2.length(trimmed) > 0 {
      trimmed
    } else {
      "main"
    }
  } catch {
  | _ => "main"
  }
}

// Stage: Scan repositories for documentation files
let scanRepository = (repoPath: string): result<array<document>, string> => {
  try {
    let documents = []

    let rec scanDir = (path: string) => {
      if !existsSync(path) {
        ()
      } else {
        let stat = statSync(path)
        if stat->isDirectory {
          let entries = readdirSync(path)
          entries->Belt.Array.forEach(entry => {
            let fullPath = join(path, entry)
            scanDir(fullPath)
          })
        } else if stat->isFile {
          let filename = basename(path)
          let ext = extname(path)

          // Identify documentation files
          let docType = switch filename->Js.String2.toUpperCase {
          | "README.MD" | "README" => Some(README)
          | "LICENSE.MD" | "LICENSE" | "LICENSE.TXT" => Some(LICENSE)
          | "SECURITY.MD" => Some(SECURITY)
          | "CONTRIBUTING.MD" => Some(CONTRIBUTING)
          | "CODE_OF_CONDUCT.MD" => Some(CODE_OF_CONDUCT)
          | "FUNDING.YML" | ".GITHUB/FUNDING.YML" => Some(FUNDING)
          | "CITATION.CFF" => Some(CITATION)
          | "CHANGELOG.MD" => Some(CHANGELOG)
          | "AUTHORS.MD" | "AUTHORS" => Some(AUTHORS)
          | "SUPPORT.MD" => Some(SUPPORT)
          | _ => None
          }

          switch docType {
          | None => ()
          | Some(dt) => {
              try {
                let content = readFileSync(path, "utf8")

                // Determine canonical source
                let canonicalSource = switch dt {
                | LICENSE => LicenseFile
                | FUNDING => FundingYaml
                | SECURITY => SecurityMd
                | CITATION => CitationCff
                | _ => Inferred
                }

                let metadata: documentMetadata = {
                  path: path,
                  documentType: dt,
                  lastModified: Js.Date.now(),
                  version: parseVersionFromContent(content),
                  canonicalSource: canonicalSource,
                  repository: repoPath,
                  branch: detectGitBranch(repoPath),
                }

                let doc = Deduplicator.createDocument(content, metadata)
                documents->Js.Array2.push(doc)->ignore
              } catch {
              | _ => () // Skip unreadable files
              }
            }
          }
        }
      }
    }

    scanDir(repoPath)
    Ok(documents)
  } catch {
  | exn =>
    Error(
      `Failed to scan repository: ${exn->Js.Exn.message->Belt.Option.getWithDefault("Unknown error")}`,
    )
  }
}

// Stage: Normalize documents (format standardization)
let normalizeDocuments = (documents: array<document>): array<document> => {
  documents->Belt.Array.map(doc => {
    // Content is already normalized in Deduplicator.createDocument
    doc
  })
}

// Create initial pipeline state
let createPipelineState = (): pipelineState => {
  {
    stage: Scan,
    documents: [],
    conflicts: [],
    resolutions: [],
    errors: [],
    startedAt: Js.Date.now(),
    completedAt: None,
  }
}

// Execute a single pipeline stage
let executeStage = async (
  state: pipelineState,
  config: config,
  client: option<ArangoClient.client>,
): result<pipelineState, string> => {
  switch state.stage {
  | Scan => {
      Js.Console.log("Stage: Scan repositories")

      let allDocuments = []
      let errors = []

      config.repositoryPaths->Belt.Array.forEach(repoPath => {
        switch scanRepository(repoPath) {
        | Ok(docs) => {
            allDocuments->Js.Array2.pushMany(docs)->ignore
          }
        | Error(msg) => {
            errors->Js.Array2.push(msg)->ignore
          }
        }
      })

      Js.Console.log(`Scanned ${allDocuments->Belt.Array.length->Int.toString} documents`)

      Ok({
        ...state,
        stage: Normalize,
        documents: allDocuments,
        errors: errors,
      })
    }

  | Normalize => {
      Js.Console.log("Stage: Normalize documents")
      let normalized = normalizeDocuments(state.documents)

      Ok({
        ...state,
        stage: Deduplicate,
        documents: normalized,
      })
    }

  | Deduplicate => {
      Js.Console.log("Stage: Deduplicate")
      let result = Deduplicator.deduplicate(state.documents)

      Js.Console.log(
        `Found ${result.stats.duplicateCount->Int.toString} duplicates, ${result.stats.uniqueCount->Int.toString} unique`,
      )

      // Create duplicate edges
      let edges = Deduplicator.createDuplicateEdges(result.duplicates)

      // Store edges in database if client available
      switch client {
      | None => ()
      | Some(c) => {
          let _ = await ArangoClient.insertEdges(c, edges)
          ()
        }
      }

      Ok({
        ...state,
        stage: DetectConflicts,
        documents: result.unique,
      })
    }

  | DetectConflicts => {
      Js.Console.log("Stage: Detect conflicts")
      let conflicts = ConflictResolver.detectConflicts(state.documents)

      Js.Console.log(`Detected ${conflicts->Belt.Array.length->Int.toString} conflicts`)

      // Store conflicts in database if client available
      switch client {
      | None => ()
      | Some(c) => {
          for i in 0 to Belt.Array.length(conflicts) - 1 {
            let conflict = Belt.Array.getUnsafe(conflicts, i)
            let _ = await ArangoClient.storeConflict(c, conflict)
            ()
          }
        }
      }

      Ok({
        ...state,
        stage: ResolveConflicts,
        conflicts: conflicts,
      })
    }

  | ResolveConflicts => {
      Js.Console.log("Stage: Resolve conflicts")
      let resolutions = ConflictResolver.resolveConflicts(
        state.conflicts,
        config.autoResolveThreshold,
      )

      let autoResolved =
        resolutions->Belt.Array.keep(r => !r.requiresApproval)->Belt.Array.length
      let manual = resolutions->Belt.Array.keep(r => r.requiresApproval)->Belt.Array.length

      Js.Console.log(
        `Resolved: ${autoResolved->Int.toString} auto, ${manual->Int.toString} require approval`,
      )

      // Store resolutions in database if client available
      switch client {
      | None => ()
      | Some(c) => {
          for i in 0 to Belt.Array.length(resolutions) - 1 {
            let resolution = Belt.Array.getUnsafe(resolutions, i)
            let _ = await ArangoClient.storeResolution(c, resolution)
            ()
          }

          // Create superseded edges
          let edges = ConflictResolver.createSupersededEdges(resolutions)
          let _ = await ArangoClient.insertEdges(c, edges)
          ()
        }
      }

      Ok({
        ...state,
        stage: Ingest,
        resolutions: resolutions,
      })
    }

  | Ingest => {
      Js.Console.log("Stage: Ingest into ArangoDB")

      switch client {
      | None => {
          let msg = "No ArangoDB client available - skipping ingest"
          Js.Console.warn(msg)
          Ok({
            ...state,
            stage: Report,
            errors: Belt.Array.concat(state.errors, [msg]),
          })
        }
      | Some(c) => {
          let result = await ArangoClient.insertDocuments(c, state.documents)

          switch result {
          | Ok() => {
              Js.Console.log(
                `Ingested ${state.documents->Belt.Array.length->Int.toString} documents`,
              )
              Ok({
                ...state,
                stage: Report,
              })
            }
          | Error(msg) =>
            Ok({
              ...state,
              stage: Report,
              errors: Belt.Array.concat(state.errors, [msg]),
            })
          }
        }
      }
    }

  | Report => {
      Js.Console.log("Stage: Generate report")

      let dedupeReport = Deduplicator.generateReport({
        unique: state.documents,
        duplicates: [], // Already processed
        stats: {
          totalProcessed: state.documents->Belt.Array.length,
          uniqueCount: state.documents->Belt.Array.length,
          duplicateCount: 0,
          spacesSaved: 0,
        },
      })

      let conflictReport = ConflictResolver.generateReport(
        state.resolutions,
        state.conflicts,
      )

      Js.Console.log("\n" ++ dedupeReport)
      Js.Console.log("\n" ++ conflictReport)

      if Belt.Array.length(state.errors) > 0 {
        Js.Console.log("\nErrors:")
        state.errors->Belt.Array.forEach(err => {
          Js.Console.log(`  - ${err}`)
        })
      }

      Ok({
        ...state,
        completedAt: Some(Js.Date.now()),
      })
    }
  }
}

// Execute entire pipeline
let rec executePipeline = async (
  state: pipelineState,
  config: config,
  client: option<ArangoClient.client>,
): result<pipelineState, string> => {
  let result = await executeStage(state, config, client)

  switch result {
  | Error(msg) => Error(msg)
  | Ok(newState) => {
      switch newState.stage {
      | Report =>
        switch newState.completedAt {
        | Some(_) => Ok(newState) // Pipeline complete
        | None => await executePipeline(newState, config, client) // Continue
        }
      | _ => await executePipeline(newState, config, client) // Continue
      }
    }
  }
}

// Run complete reconciliation pipeline
let run = async (config: config): result<pipelineState, string> => {
  Js.Console.log("=== Documentation Reconciliation Pipeline ===\n")

  // Initialize ArangoDB client
  let clientResult = await ArangoClient.initialize(config)

  let client = switch clientResult {
  | Ok(c) => {
      Js.Console.log("ArangoDB client initialized")
      Some(c)
    }
  | Error(msg) => {
      Js.Console.warn(`Failed to initialize ArangoDB: ${msg}`)
      Js.Console.warn("Continuing without database persistence")
      None
    }
  }

  // Create initial state and execute pipeline
  let initialState = createPipelineState()
  let result = await executePipeline(initialState, config, client)

  switch result {
  | Ok(finalState) => {
      let duration = switch finalState.completedAt {
      | None => 0.0
      | Some(completed) => completed -. finalState.startedAt
      }

      Js.Console.log(`\nPipeline completed in ${duration->Belt.Float.toString}ms`)
      Ok(finalState)
    }
  | Error(msg) => {
      Js.Console.error(`Pipeline failed: ${msg}`)
      Error(msg)
    }
  }
}

// Run pipeline continuously (for daemon mode)
let runContinuous = async (config: config): unit => {
  let rec loop = async () => {
    let _ = await run(config)

    switch config.scanInterval {
    | None => () // Run once and exit
    | Some(interval) => {
        Js.Console.log(`\nWaiting ${interval->Int.toString} seconds until next scan...`)
        // Note: In real implementation, use proper async sleep
        await Js.Promise.make((~resolve, ~reject as _) => {
          let _ = Js.Global.setTimeout(() => resolve(.), interval * 1000)
        })
        await loop()
      }
    }
  }

  await loop()
}
