// SPDX-License-Identifier: PMPL-1.0-or-later

/// ForgeOps Engine — Pure computation for compliance evaluation and diff.
///
/// All functions are pure (no side effects, no API calls). They operate on
/// model data to produce audit findings, compliance scores, cross-forge diffs,
/// and repo filter results. Mirrors CloudGuardEngine's pattern exactly.

open ForgeOpsModel

// ============================================================================
// JSON parsing helpers
// ============================================================================

/// Helper: extract a string field from a JSON object dict, with a default.
let jsonStr = (obj: Dict.t<JSON.t>, key: string, default: string): string => {
  switch Dict.get(obj, key) {
  | Some(v) =>
    switch JSON.Classify.classify(v) {
    | String(s) => s
    | _ => default
    }
  | None => default
  }
}

/// Helper: extract a bool field from a JSON object dict, with a default.
let jsonBool = (obj: Dict.t<JSON.t>, key: string, default: bool): bool => {
  switch Dict.get(obj, key) {
  | Some(v) =>
    switch JSON.Classify.classify(v) {
    | Bool(b) => b
    | _ => default
    }
  | None => default
  }
}

/// Helper: extract an int field from a JSON object dict, with a default.
let jsonInt = (obj: Dict.t<JSON.t>, key: string, default: int): int => {
  switch Dict.get(obj, key) {
  | Some(v) =>
    switch JSON.Classify.classify(v) {
    | Number(n) => Float.toInt(n)
    | _ => default
    }
  | None => default
  }
}

/// Helper: extract a string array field from a JSON object dict.
let jsonStrArray = (obj: Dict.t<JSON.t>, key: string): array<string> => {
  switch Dict.get(obj, key) {
  | Some(v) =>
    switch JSON.Classify.classify(v) {
    | Array(arr) =>
      arr->Array.filterMap(item =>
        switch JSON.Classify.classify(item) {
        | String(s) => Some(s)
        | _ => None
        }
      )
    | _ => []
    }
  | None => []
  }
}

// ============================================================================
// JSON → forgeRepo parsing (GitHub API shape)
// ============================================================================

/// Parse a GitHub repo JSON object into a forgeRepo record.
let parseGitHubRepo = (json: JSON.t): option<forgeRepo> => {
  switch JSON.Classify.classify(json) {
  | Object(obj) => {
      let name = jsonStr(obj, "name", "")
      let fullName = jsonStr(obj, "full_name", "")
      if name === "" || fullName === "" {
        None
      } else {
        let visibility = switch jsonStr(obj, "visibility", "public") {
        | "private" => Private
        | "internal" => Internal
        | _ => Public
        }

        let sshUrl = jsonStr(obj, "ssh_url", "")
        let htmlUrl = jsonStr(obj, "html_url", "")
        let cloneUrl = jsonStr(obj, "clone_url", "")

        let license = switch Dict.get(obj, "license") {
        | Some(licJson) =>
          switch JSON.Classify.classify(licJson) {
          | Object(licObj) =>
            let spdx = jsonStr(licObj, "spdx_id", "")
            if spdx !== "" && spdx !== "NOASSERTION" { Some(spdx) } else { None }
          | Null => None
          | _ => None
          }
        | None => None
        }

        let language = switch Dict.get(obj, "language") {
        | Some(langJson) =>
          switch JSON.Classify.classify(langJson) {
          | String(s) => Some(s)
          | _ => None
          }
        | None => None
        }

        Some({
          name,
          fullName,
          description: jsonStr(obj, "description", ""),
          visibility,
          defaultBranch: jsonStr(obj, "default_branch", "main"),
          archived: jsonBool(obj, "archived", false),
          fork: jsonBool(obj, "fork", false),
          template: jsonBool(obj, "is_template", false),
          language,
          topics: jsonStrArray(obj, "topics"),
          license,
          createdAt: jsonStr(obj, "created_at", ""),
          updatedAt: jsonStr(obj, "updated_at", ""),
          pushedAt: jsonStr(obj, "pushed_at", ""),
          gitHub: Some({
            forgeId: GitHub,
            remoteId: jsonStr(obj, "id", ""),
            url: cloneUrl,
            sshUrl,
            webUrl: htmlUrl,
            isMirror: jsonBool(obj, "mirror_url", false),
            lastSyncedAt: None,
          }),
          gitLab: None,
          bitbucket: None,
        })
      }
    }
  | _ => None
  }
}

/// Parse a JSON string (array of repo objects) into forgeRepo records.
let parseGitHubReposJson = (jsonString: string): array<forgeRepo> => {
  try {
    let parsed = JSON.parseExn(jsonString)
    switch JSON.Classify.classify(parsed) {
    | Array(arr) => arr->Array.filterMap(parseGitHubRepo)
    | _ => []
    }
  } catch {
  | _ => []
  }
}

// ============================================================================
// Setting value helpers
// ============================================================================

/// Stringify a settingValue for display.
let settingValueToString = (v: settingValue): string => {
  switch v {
  | BoolValue(b) => b ? "On" : "Off"
  | StringValue(s) => s
  | IntValue(n) => Int.toString(n)
  | ObjectValue(json) => json
  }
}

/// Check if a setting value represents "on" / "enabled" / true.
let isSettingEnabled = (v: settingValue): bool => {
  switch v {
  | BoolValue(b) => b
  | StringValue(s) => s === "on" || s === "true" || s === "1"
  | IntValue(n) => n > 0
  | ObjectValue(_) => true
  }
}

/// Serialise modified settings into a JSON string for batch updates.
let serialiseModifiedSettings = (settings: array<forgeSetting>): string => {
  let modified = settings->Array.filter(s => s.modified)
  let items = modified->Array.map(s => {
    let valueJson = switch s.value {
    | BoolValue(b) => if b { "true" } else { "false" }
    | StringValue(str) => `"${str}"`
    | IntValue(n) => Int.toString(n)
    | ObjectValue(json) => json
    }
    `{"id":"${s.id}","value":${valueJson}}`
  })
  `[${Array.join(items, ",")}]`
}

// ============================================================================
// Compliance evaluation
// ============================================================================

/// Evaluate a single setting against its policy constraint.
let evaluateSetting = (
  repoName: string,
  setting: forgeSetting,
  rule: policyConstraint,
): option<auditFinding> => {
  let currentStr = settingValueToString(setting.value)
  let expectedStr = settingValueToString(setting.defaultValue)

  let matches = switch (setting.value, setting.defaultValue) {
  | (BoolValue(a), BoolValue(b)) => a === b
  | (StringValue(a), StringValue(b)) => a === b
  | (IntValue(a), IntValue(b)) => a === b
  | _ => currentStr === expectedStr
  }

  if matches {
    None
  } else {
    Some({
      repoName,
      settingId: setting.id,
      category: setting.category,
      forgeId: setting.forgeId,
      severity: rule.severity,
      message: `${rule.expression}: expected ${expectedStr}, got ${currentStr}`,
      currentValue: currentStr,
      expectedValue: expectedStr,
      autoFixable: setting.editable,
    })
  }
}

/// Compute the compliance score for settings against constraints.
let computeComplianceScore = (
  settings: array<forgeSetting>,
  constraints: array<policyConstraint>,
): (int, int, float) => {
  let passed = ref(0)
  let failed = ref(0)

  Array.forEach(constraints, rule => {
    let matchingSetting = Array.find(settings, s => s.id === rule.id)
    switch matchingSetting {
    | Some(setting) => {
        let currentStr = settingValueToString(setting.value)
        let expectedStr = settingValueToString(setting.defaultValue)
        if currentStr === expectedStr {
          passed := passed.contents + 1
        } else {
          failed := failed.contents + 1
        }
      }
    | None => failed := failed.contents + 1
    }
  })

  let total = Int.toFloat(passed.contents + failed.contents)
  let score = if total > 0.0 { Int.toFloat(passed.contents) /. total } else { 0.0 }
  (passed.contents, failed.contents, score)
}

// ============================================================================
// Repo filtering and sorting
// ============================================================================

/// Filter repos by search text (matches repo name).
let filterRepos = (repos: array<forgeRepo>, searchText: string): array<forgeRepo> => {
  if String.length(searchText) === 0 {
    repos
  } else {
    let lower = String.toLowerCase(searchText)
    repos->Array.filter(repo => String.includes(String.toLowerCase(repo.name), lower))
  }
}

/// Filter repos by forge presence.
let filterByForge = (repos: array<forgeRepo>, forge: forgeId): array<forgeRepo> => {
  repos->Array.filter(repo => {
    switch forge {
    | GitHub => Option.isSome(repo.gitHub)
    | GitLab => Option.isSome(repo.gitLab)
    | Bitbucket => Option.isSome(repo.bitbucket)
    }
  })
}

/// Sort repos alphabetically by name.
let sortReposByName = (repos: array<forgeRepo>): array<forgeRepo> => {
  let copy = Array.copy(repos)
  Array.sort(copy, (a, b) => String.compare(a.name, b.name))
  copy
}

/// Get repos that are missing on one or more forges (not fully mirrored).
let unmirroredRepos = (repos: array<forgeRepo>): array<forgeRepo> => {
  repos->Array.filter(repo =>
    Option.isNone(repo.gitHub)
    || Option.isNone(repo.gitLab)
    || Option.isNone(repo.bitbucket)
  )
}

// ============================================================================
// Mirror status helpers
// ============================================================================

/// Get the sync status label for display.
let mirrorStatusLabel = (status: mirrorSyncStatus): string => {
  switch status {
  | InSync => "In Sync"
  | Behind(n) => `${Int.toString(n)} behind`
  | Ahead(n) => `${Int.toString(n)} ahead`
  | Diverged(behind, ahead) => `${Int.toString(behind)} behind, ${Int.toString(ahead)} ahead`
  | SyncFailed(err) => `Failed: ${err}`
  | NeverSynced => "Never synced"
  | Syncing => "Syncing..."
  }
}

/// CSS colour class for mirror status.
let mirrorStatusColour = (status: mirrorSyncStatus): string => {
  switch status {
  | InSync => "text-green-400"
  | Behind(_) => "text-yellow-400"
  | Ahead(_) => "text-blue-400"
  | Diverged(_, _) => "text-orange-400"
  | SyncFailed(_) => "text-red-400"
  | NeverSynced => "text-gray-500"
  | Syncing => "text-indigo-400"
  }
}

/// Count how many forges a repo is present on.
let forgeCount = (repo: forgeRepo): int => {
  let gh = if Option.isSome(repo.gitHub) { 1 } else { 0 }
  let gl = if Option.isSome(repo.gitLab) { 1 } else { 0 }
  let bb = if Option.isSome(repo.bitbucket) { 1 } else { 0 }
  gh + gl + bb
}

// ============================================================================
// Severity helpers (same as CloudGuardEngine)
// ============================================================================

/// Severity label for display.
let severityLabel = (sev: auditSeverity): string => {
  switch sev {
  | Critical => "CRITICAL"
  | High => "HIGH"
  | Medium => "MEDIUM"
  | Low => "LOW"
  | Info => "INFO"
  }
}

/// CSS colour class for a severity level.
let severityColour = (sev: auditSeverity): string => {
  switch sev {
  | Critical => "text-red-400"
  | High => "text-orange-400"
  | Medium => "text-yellow-400"
  | Low => "text-blue-400"
  | Info => "text-gray-400"
  }
}

/// Sort audit findings by severity (Critical first).
let sortFindingsBySeverity = (findings: array<auditFinding>): array<auditFinding> => {
  let severityOrder = (sev: auditSeverity): int => {
    switch sev {
    | Critical => 0
    | High => 1
    | Medium => 2
    | Low => 3
    | Info => 4
    }
  }
  let copy = Array.copy(findings)
  Array.sort(copy, (a, b) => Int.compare(severityOrder(a.severity), severityOrder(b.severity)))
  copy
}

// ============================================================================
// Per-repo exception helpers
// ============================================================================

/// Find the exception for a specific repo + setting, if any.
let findException = (
  exceptions: array<repoException>,
  repoName: string,
  settingId: string,
): option<repoException> => {
  exceptions->Array.find(e => e.repoName === repoName && e.settingId === settingId)
}

/// Apply exceptions to a setting for a given repo.
let applyException = (
  setting: forgeSetting,
  exceptions: array<repoException>,
  repoName: string,
): forgeSetting => {
  switch findException(exceptions, repoName, setting.id) {
  | Some(exc) => {...setting, value: exc.overrideValue, modified: true}
  | None => setting
  }
}

// ============================================================================
// Forge presence badge helpers
// ============================================================================

/// Get a compact string showing which forges a repo is on.
let forgePresenceBadge = (repo: forgeRepo): string => {
  let parts = []
  let parts = if Option.isSome(repo.gitHub) { Array.concat(parts, ["GH"]) } else { parts }
  let parts = if Option.isSome(repo.gitLab) { Array.concat(parts, ["GL"]) } else { parts }
  let parts = if Option.isSome(repo.bitbucket) { Array.concat(parts, ["BB"]) } else { parts }
  Array.join(parts, "+")
}

/// CSS colour for a forge badge.
let forgeBadgeColour = (forge: forgeId): string => {
  switch forge {
  | GitHub => "text-gray-200 bg-gray-800"
  | GitLab => "text-orange-300 bg-orange-900/30"
  | Bitbucket => "text-blue-300 bg-blue-900/30"
  }
}

// ============================================================================
// CI/CD status helpers
// ============================================================================

/// Label for a CI run status.
let ciStatusLabel = (status: ciRunStatus): string => {
  switch status {
  | CiSuccess => "Success"
  | CiFailure => "Failed"
  | CiPending => "Pending"
  | CiRunning => "Running"
  | CiCancelled => "Cancelled"
  | CiSkipped => "Skipped"
  | CiUnknown => "Unknown"
  }
}

/// CSS colour for a CI run status.
let ciStatusColour = (status: ciRunStatus): string => {
  switch status {
  | CiSuccess => "text-green-400"
  | CiFailure => "text-red-400"
  | CiPending => "text-yellow-400"
  | CiRunning => "text-indigo-400"
  | CiCancelled => "text-gray-500"
  | CiSkipped => "text-gray-600"
  | CiUnknown => "text-gray-600"
  }
}

// ============================================================================
// Cross-forge diff computation
// ============================================================================

/// Compute a cross-forge diff for a set of settings.
/// Compares values of the same setting across GitHub, GitLab, and Bitbucket.
let computeForgeDiff = (
  repoName: string,
  ghSettings: array<forgeSetting>,
  glSettings: array<forgeSetting>,
  bbSettings: array<forgeSetting>,
): forgeDiff => {
  // Collect all unique setting IDs across all forges
  let allIds: Dict.t<bool> = Dict.make()
  Array.forEach(ghSettings, s => Dict.set(allIds, s.id, true))
  Array.forEach(glSettings, s => Dict.set(allIds, s.id, true))
  Array.forEach(bbSettings, s => Dict.set(allIds, s.id, true))

  let entries = Dict.keysToArray(allIds)->Array.map(id => {
    let ghVal = ghSettings->Array.find(s => s.id === id)->Option.map(s => settingValueToString(s.value))
    let glVal = glSettings->Array.find(s => s.id === id)->Option.map(s => settingValueToString(s.value))
    let bbVal = bbSettings->Array.find(s => s.id === id)->Option.map(s => settingValueToString(s.value))

    let catalogEntry = ForgeOpsCatalog.findById(id)
    let policyVal = catalogEntry->Option.map(e => settingValueToString(e.defaultValue))
    let cat = switch catalogEntry {
    | Some(e) => e.category
    | None => Repos
    }

    // Check consistency: all present values must match
    let presentValues = [ghVal, glVal, bbVal]->Array.filterMap(v => v)
    let consistent = switch Array.get(presentValues, 0) {
    | Some(first) => presentValues->Array.every(v => v === first)
    | None => true
    }

    {
      settingId: id,
      repoName,
      category: cat,
      gitHubValue: ghVal,
      gitLabValue: glVal,
      bitbucketValue: bbVal,
      policyValue: policyVal,
      consistent,
    }
  })

  let inconsistentCount = entries->Array.filter(e => !e.consistent)->Array.length
  let missingCount = entries->Array.filter(e =>
    Option.isNone(e.gitHubValue) || Option.isNone(e.gitLabValue) || Option.isNone(e.bitbucketValue)
  )->Array.length

  {
    timestamp: "now", // TODO: use Date.now() ISO 8601
    entries,
    inconsistentCount,
    missingCount,
  }
}
