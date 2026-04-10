// SPDX-License-Identifier: PMPL-1.0-or-later
// Conflict resolution with confidence scoring and rule-based strategies
// Auto-resolve when confidence > 0.9, escalate otherwise

open Types

// Resolution rule with priority and confidence
type resolutionRule = {
  name: string,
  priority: int,
  confidence: confidence,
  strategy: resolutionStrategy,
  applies: conflict => bool,
  resolve: conflict => option<document>,
}

// Built-in resolution rules (from highest to lowest priority)
let builtInRules: array<resolutionRule> = [
  // Rule 1: Exact duplicates - keep latest (100% confidence)
  {
    name: "duplicate-keep-latest",
    priority: 100,
    confidence: 1.0,
    strategy: KeepLatest,
    applies: conflict => conflict.conflictType == DuplicateContent,
    resolve: conflict => {
      Deduplicator.findLatest(conflict.documents)
    },
  },
  // Rule 2: LICENSE file is canonical (95% confidence)
  {
    name: "license-file-canonical",
    priority: 95,
    confidence: 0.95,
    strategy: KeepCanonical,
    applies: conflict => {
      conflict.documents->Belt.Array.some(doc => {
        doc.metadata.documentType == LICENSE &&
        doc.metadata.canonicalSource == LicenseFile
      })
    },
    resolve: conflict => {
      conflict.documents->Belt.Array.getBy(doc => {
        doc.metadata.documentType == LICENSE &&
        doc.metadata.canonicalSource == LicenseFile
      })
    },
  },
  // Rule 3: FUNDING.yml is canonical (98% confidence)
  {
    name: "funding-yaml-canonical",
    priority: 98,
    confidence: 0.98,
    strategy: KeepCanonical,
    applies: conflict => {
      conflict.documents->Belt.Array.some(doc => {
        doc.metadata.documentType == FUNDING &&
        doc.metadata.canonicalSource == FundingYaml
      })
    },
    resolve: conflict => {
      conflict.documents->Belt.Array.getBy(doc => {
        doc.metadata.documentType == FUNDING &&
        doc.metadata.canonicalSource == FundingYaml
      })
    },
  },
  // Rule 4: Keep highest semantic version (85% confidence)
  {
    name: "keep-highest-semver",
    priority: 85,
    confidence: 0.85,
    strategy: KeepHighestVersion,
    applies: conflict => {
      conflict.documents->Belt.Array.every(doc => {
        doc.metadata.version->Belt.Option.isSome
      })
    },
    resolve: conflict => {
      conflict.documents->Belt.Array.reduce(None, (highest, doc) => {
        switch (highest, doc.metadata.version) {
        | (None, Some(_)) => Some(doc)
        | (Some(current), Some(version)) => {
            switch current.metadata.version {
            | Some(currentVersion) =>
              if compareVersions(version, currentVersion) > 0 {
                Some(doc)
              } else {
                highest
              }
            | None => Some(doc)
            }
          }
        | _ => highest
        }
      })
    },
  },
  // Rule 5: Explicit canonical source wins (100% confidence)
  {
    name: "explicit-canonical",
    priority: 100,
    confidence: 1.0,
    strategy: KeepCanonical,
    applies: conflict => {
      conflict.documents->Belt.Array.some(doc => {
        switch doc.metadata.canonicalSource {
        | Explicit(_) => true
        | _ => false
        }
      })
    },
    resolve: conflict => {
      conflict.documents->Belt.Array.getBy(doc => {
        switch doc.metadata.canonicalSource {
        | Explicit(_) => true
        | _ => false
        }
      })
    },
  },
  // Rule 6: Prefer canonical source over inferred (80% confidence)
  {
    name: "canonical-over-inferred",
    priority: 80,
    confidence: 0.80,
    strategy: KeepCanonical,
    applies: conflict => {
      conflict.documents->Belt.Array.some(doc => {
        doc.metadata.canonicalSource != Inferred
      })
    },
    resolve: conflict => {
      Deduplicator.findCanonical(conflict.documents)
    },
  },
]

// Find applicable rule for conflict
let findApplicableRule = (
  conflict: conflict,
  rules: array<resolutionRule>,
): option<resolutionRule> => {
  rules
  ->Belt.Array.keep(rule => rule.applies(conflict))
  ->Belt.SortArray.stableSortBy((r1, r2) => r2.priority - r1.priority)
  ->Belt.Array.get(0)
}

// Resolve conflict using rules
let resolveConflict = (
  conflict: conflict,
  autoResolveThreshold: float,
): resolutionResult => {
  let applicableRule = findApplicableRule(conflict, builtInRules)

  switch applicableRule {
  | None => {
      // No rule applies - require manual resolution
      {
        conflictId: conflict.id,
        strategy: RequireManual,
        selectedDocument: None,
        confidence: 0.0,
        requiresApproval: true,
        reasoning: "No automatic resolution rule applies to this conflict",
        timestamp: Js.Date.now(),
      }
    }
  | Some(rule) => {
      let selectedDoc = rule.resolve(conflict)
      let requiresApproval = rule.confidence < autoResolveThreshold

      {
        conflictId: conflict.id,
        strategy: rule.strategy,
        selectedDocument: selectedDoc,
        confidence: rule.confidence,
        requiresApproval: requiresApproval,
        reasoning: `Applied rule: ${rule.name} (confidence: ${rule.confidence
          ->Belt.Float.toString})`,
        timestamp: Js.Date.now(),
      }
    }
  }
}

// Batch resolve multiple conflicts
let resolveConflicts = (
  conflicts: array<conflict>,
  autoResolveThreshold: float,
): array<resolutionResult> => {
  conflicts->Belt.Array.map(conflict => {
    resolveConflict(conflict, autoResolveThreshold)
  })
}

// Detect conflicts between documents
let detectConflicts = (documents: array<document>): array<conflict> => {
  let conflicts = []
  let grouped = Deduplicator.groupByHash(documents)

  // Detect duplicate content conflicts
  grouped->Belt.Map.String.forEach((hash, docs) => {
    if Belt.Array.length(docs) > 1 {
      // Multiple documents with same hash but different paths
      let paths = docs->Belt.Array.map(d => d.metadata.path)
      let allSamePath = paths->Belt.Array.every(p => p == Belt.Array.getUnsafe(paths, 0))

      if !allSamePath {
        conflicts
        ->Js.Array2.push({
          id: hash ++ "_duplicate",
          conflictType: DuplicateContent,
          documents: docs,
          detectedAt: Js.Date.now(),
          confidence: 1.0,
          suggestedStrategy: KeepLatest,
        })
        ->ignore
      }
    }
  })

  // Detect version conflicts (same type, different versions)
  let byType = Belt.Map.String.empty
  documents->Belt.Array.forEach(doc => {
    let typeStr = documentTypeToString(doc.metadata.documentType)
    let existing = byType->Belt.Map.String.get(typeStr)
    byType = switch existing {
    | None => byType->Belt.Map.String.set(typeStr, [doc])
    | Some(docs) => byType->Belt.Map.String.set(typeStr, Belt.Array.concat(docs, [doc]))
    }
  })

  byType->Belt.Map.String.forEach((typeStr, docs) => {
    if Belt.Array.length(docs) > 1 {
      // Check if versions differ
      let versions = docs->Belt.Array.keepMap(d => d.metadata.version)
      if Belt.Array.length(versions) > 1 {
        let allSame = versions->Belt.Array.every(v => {
          compareVersions(v, Belt.Array.getUnsafe(versions, 0)) == 0
        })

        if !allSame {
          conflicts
          ->Js.Array2.push({
            id: typeStr ++ "_version_conflict",
            conflictType: VersionMismatch,
            documents: docs,
            detectedAt: Js.Date.now(),
            confidence: 0.8,
            suggestedStrategy: KeepHighestVersion,
          })
          ->ignore
        }
      }
    }
  })

  // Detect canonical conflicts (multiple canonical sources for same type)
  byType->Belt.Map.String.forEach((typeStr, docs) => {
    let canonicals = docs->Belt.Array.keep(doc => {
      switch doc.metadata.canonicalSource {
      | Inferred => false
      | _ => true
      }
    })

    if Belt.Array.length(canonicals) > 1 {
      conflicts
      ->Js.Array2.push({
        id: typeStr ++ "_canonical_conflict",
        conflictType: CanonicalConflict,
        documents: canonicals,
        detectedAt: Js.Date.now(),
        confidence: 0.7,
        suggestedStrategy: KeepCanonical,
      })
      ->ignore
    }
  })

  conflicts
}

// Generate resolution report
let generateReport = (
  resolutions: array<resolutionResult>,
  conflicts: array<conflict>,
): string => {
  let lines = []
  lines->Js.Array2.push("=== Conflict Resolution Report ===")->ignore
  lines->Js.Array2.push(`Total conflicts: ${conflicts->Belt.Array.length->Int.toString}`)->ignore
  lines
  ->Js.Array2.push(`Resolutions: ${resolutions->Belt.Array.length->Int.toString}`)
  ->ignore

  let autoResolved =
    resolutions->Belt.Array.keep(r => !r.requiresApproval)->Belt.Array.length
  let requireApproval =
    resolutions->Belt.Array.keep(r => r.requiresApproval)->Belt.Array.length

  lines
  ->Js.Array2.push(`Auto-resolved: ${autoResolved->Int.toString} (confidence > threshold)`)
  ->ignore
  lines
  ->Js.Array2.push(`Require approval: ${requireApproval->Int.toString} (confidence < threshold)`)
  ->ignore
  lines->Js.Array2.push("")->ignore

  resolutions->Belt.Array.forEach(resolution => {
    let status = resolution.requiresApproval ? "[MANUAL]" : "[AUTO]"
    let strategy = resolutionStrategyToString(resolution.strategy)
    lines
    ->Js.Array2.push(
      `${status} ${resolution.conflictId}: ${strategy} (confidence: ${resolution.confidence->Belt.Float.toString})`,
    )
    ->ignore
    lines->Js.Array2.push(`  Reasoning: ${resolution.reasoning}`)->ignore
  })

  lines->Js.Array2.joinWith("\n")
}

// Create superseded-by edges for resolved conflicts
let createSupersededEdges = (resolutions: array<resolutionResult>): array<edge> => {
  resolutions
  ->Belt.Array.keepMap(resolution => {
    switch resolution.selectedDocument {
    | None => None
    | Some(selected) => {
        Some({
          from: resolution.conflictId,
          to: selected.hash,
          edgeType: SupersededBy,
          confidence: resolution.confidence,
          metadata: Js.Json.object_(
            Js.Dict.fromArray([
              ("strategy", Js.Json.string(resolutionStrategyToString(resolution.strategy))),
              ("reasoning", Js.Json.string(resolution.reasoning)),
              ("timestamp", Js.Json.number(resolution.timestamp)),
            ]),
          ),
        })
      }
    }
  })
}
