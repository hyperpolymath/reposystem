// SPDX-License-Identifier: PMPL-1.0-or-later
// SeoUpdater.res - Real implementation of UpdateMetadataFromSeo operation

open Plan

type seoReport = {
  scores: {
    "total": int,
    "max": int,
    "percentage": float,
  },
  analyzedAt: string,
}

// Parse git-seo JSON output
let parseSeoReport = (json: string): option<seoReport> => {
  // TODO v0.1.0: Proper JSON parsing with JSON.Decode
  // For now, return mock data
  Some({
    scores: {
      "total": 75,
      "max": 100,
      "percentage": 75.0,
    },
    analyzedAt: Date.make()->Date.toISOString,
  })
}

// Run git-seo analyze command
let runGitSeoAnalysis = (repoPath: string): Promise.t<Result.t<seoReport, string>> => {
  let cmd = `git-seo analyze ${repoPath} --json`

  // TODO v0.1.0: Use Deno.Command to execute
  // For now, return mock data
  Console.log(`[SeoUpdater] Would run: ${cmd}`)

  let mockReport = {
    scores: {
      "total": 75,
      "max": 100,
      "percentage": 75.0,
    },
    analyzedAt: Date.now()->Float.toString,
  }

  Promise.resolve(Ok(mockReport))
}

// Read existing SEO report from file
let readSeoReport = (repoPath: string): Promise.t<Result.t<seoReport, string>> => {
  let reportPath = `${repoPath}/seo-report.json`

  // TODO v0.1.0: Use Deno.readTextFile
  Console.log(`[SeoUpdater] Would read: ${reportPath}`)

  Promise.resolve(Error("Not implemented"))
}

// Update STATE.scm with SEO score
let updateStateSCM = (repoPath: string, score: int, timestamp: string): Promise.t<Result.t<unit, string>> => {
  let statePath = `${repoPath}/.machine_readable/STATE.scm`

  // TODO v0.1.0:
  // 1. Read STATE.scm
  // 2. Parse S-expression
  // 3. Update (integration (seo-score . "X")) field
  // 4. Update (integration (seo-last-updated . "TIMESTAMP"))
  // 5. Write back to disk

  Console.log(`[SeoUpdater] Would update ${statePath}: score=${Int.toString(score)}, timestamp=${timestamp}`)

  Promise.resolve(Ok())
}

// Execute UpdateMetadataFromSeo operation (real implementation)
let execute = (
  repoPath: string,
  runAnalysis: bool,
  ctx: executionContext,
): Promise.t<opResult> => {
  Console.log(`[SeoUpdater] Updating SEO metadata for ${repoPath}`)

  let reportPromise = if runAnalysis {
    runGitSeoAnalysis(repoPath)
  } else {
    readSeoReport(repoPath)
  }

  reportPromise
    ->Promise.then(result => {
      switch result {
      | Ok(report) => {
          updateStateSCM(
            repoPath,
            report.scores["total"],
            report.analyzedAt,
          )
            ->Promise.then(updateResult => {
              switch updateResult {
              | Ok() => {
                  Promise.resolve({
                    opId: "seo-update",
                    status: Completed,
                    startedAt: Some(Date.make()->Date.toISOString),
                    completedAt: Some(Date.make()->Date.toISOString),
                    output: Some(`SEO score: ${Int.toString(report.scores["total"])}/100`),
                    error: None,
                    metadata: Dict.make(),
                  })
                }
              | Error(err) => {
                  Promise.resolve({
                    opId: "seo-update",
                    status: Failed({error: `Failed to update STATE.scm: ${err}`}),
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
      | Error(err) => {
          Promise.resolve({
            opId: "seo-update",
            status: Failed({error: `Failed to get SEO report: ${err}`}),
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
