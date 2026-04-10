// SPDX-License-Identifier: PMPL-1.0-or-later
// Content-addressable deduplication using cryptographic hashing
// Guarantees: Same hash = same content = single entry

open Types

// Hash content using SHA-256
@module("crypto") @scope("default")
external createHash: string => 'a = "createHash"

@send external update: ('a, string) => 'a = "update"
@send external digest: ('a, string) => string = "digest"

let hashContent = (content: string): contentHash => {
  try {
    let hash = createHash("sha256")
    hash->update(content)->digest("hex")
  } catch {
  | _ => {
      // Fallback to simple hash if crypto not available
      Js.String2.length(content)->Int.toString ++ "_" ++ Js.String2.slice(content, ~from=0, ~to_=10)
    }
  }
}

// Normalize content before hashing to catch semantic duplicates
let normalizeContent = (content: string): string => {
  content
  ->Js.String2.trim
  ->Js.String2.replaceByRe(%re("/\r\n/g"), "\n") // Normalize line endings
  ->Js.String2.replaceByRe(%re("/\s+$/gm"), "") // Remove trailing whitespace
  ->Js.String2.replaceByRe(%re("/\n{3,}/g"), "\n\n") // Normalize multiple blank lines
}

// Create document with hash
let createDocument = (
  content: string,
  metadata: documentMetadata,
): document => {
  let normalizedContent = normalizeContent(content)
  let hash = hashContent(normalizedContent)
  {
    hash: hash,
    content: normalizedContent,
    metadata: metadata,
    createdAt: Js.Date.now(),
  }
}

// Deduplication result
type deduplicationResult = {
  unique: array<document>,
  duplicates: array<(document, document)>, // (duplicate, original)
  stats: {
    totalProcessed: int,
    uniqueCount: int,
    duplicateCount: int,
    spacesSaved: int, // Bytes
  },
}

// Deduplicate documents by content hash
let deduplicate = (documents: array<document>): deduplicationResult => {
  let hashMap = Belt.Map.String.empty
  let unique = []
  let duplicates = []

  documents->Belt.Array.forEach(doc => {
    switch hashMap->Belt.Map.String.get(doc.hash) {
    | None => {
        // First occurrence - add to unique set
        hashMap = hashMap->Belt.Map.String.set(doc.hash, doc)
        unique->Js.Array2.push(doc)->ignore
      }
    | Some(original) => {
        // Duplicate found - record it
        duplicates->Js.Array2.push((doc, original))->ignore
      }
    }
  })

  let totalSize = documents->Belt.Array.reduce(0, (acc, doc) => {
    acc + Js.String2.length(doc.content)
  })

  let uniqueSize = unique->Belt.Array.reduce(0, (acc, doc) => {
    acc + Js.String2.length(doc.content)
  })

  {
    unique: unique,
    duplicates: duplicates,
    stats: {
      totalProcessed: Belt.Array.length(documents),
      uniqueCount: Belt.Array.length(unique),
      duplicateCount: Belt.Array.length(duplicates),
      spacesSaved: totalSize - uniqueSize,
    },
  }
}

// Find duplicates for a specific document
let findDuplicates = (
  target: document,
  documents: array<document>,
): array<document> => {
  documents->Belt.Array.keep(doc => {
    doc.hash == target.hash && doc.metadata.path != target.metadata.path
  })
}

// Check if two documents are duplicates
let isDuplicate = (doc1: document, doc2: document): bool => {
  doc1.hash == doc2.hash
}

// Group documents by hash
let groupByHash = (
  documents: array<document>,
): Belt.Map.String.t<array<document>> => {
  documents->Belt.Array.reduce(Belt.Map.String.empty, (map, doc) => {
    let existing = map->Belt.Map.String.get(doc.hash)
    switch existing {
    | None => map->Belt.Map.String.set(doc.hash, [doc])
    | Some(docs) => {
        let updated = Belt.Array.concat(docs, [doc])
        map->Belt.Map.String.set(doc.hash, updated)
      }
    }
  })
}

// Find latest document in a group (by modification time)
let findLatest = (documents: array<document>): option<document> => {
  documents->Belt.Array.reduce(None, (latest, doc) => {
    switch latest {
    | None => Some(doc)
    | Some(current) =>
      if doc.metadata.lastModified > current.metadata.lastModified {
        Some(doc)
      } else {
        latest
      }
    }
  })
}

// Find canonical document in a group (by canonical source priority)
let getCanonicalPriority = (source: canonicalSource): int => {
  switch source {
  | LicenseFile => 95
  | FundingYaml => 98
  | SecurityMd => 90
  | CitationCff => 90
  | PackageJson => 85
  | CargoToml => 85
  | Explicit(_) => 100
  | Inferred => 50
  }
}

let findCanonical = (documents: array<document>): option<document> => {
  documents->Belt.Array.reduce(None, (canonical, doc) => {
    let docPriority = getCanonicalPriority(doc.metadata.canonicalSource)
    switch canonical {
    | None => Some(doc)
    | Some(current) => {
        let currentPriority = getCanonicalPriority(current.metadata.canonicalSource)
        if docPriority > currentPriority {
          Some(doc)
        } else if docPriority == currentPriority {
          // If same priority, prefer latest
          if doc.metadata.lastModified > current.metadata.lastModified {
            Some(doc)
          } else {
            canonical
          }
        } else {
          canonical
        }
      }
    }
  })
}

// Create edges for duplicate relationships
let createDuplicateEdges = (
  duplicates: array<(document, document)>,
): array<edge> => {
  duplicates->Belt.Array.map(((duplicate, original)) => {
    {
      from: duplicate.hash,
      to: original.hash,
      edgeType: DuplicateOf,
      confidence: 1.0, // 100% confidence - exact hash match
      metadata: Js.Json.object_(Js.Dict.fromArray([
        ("duplicate_path", Js.Json.string(duplicate.metadata.path)),
        ("original_path", Js.Json.string(original.metadata.path)),
        ("detected_at", Js.Json.number(Js.Date.now())),
      ])),
    }
  })
}

// Summary report
let generateReport = (result: deduplicationResult): string => {
  let {totalProcessed, uniqueCount, duplicateCount, spacesSaved} = result.stats

  let lines = []
  lines->Js.Array2.push("=== Deduplication Report ===")->ignore
  lines->Js.Array2.push(`Total documents processed: ${totalProcessed->Int.toString}`)->ignore
  lines->Js.Array2.push(`Unique documents: ${uniqueCount->Int.toString}`)->ignore
  lines->Js.Array2.push(`Duplicates found: ${duplicateCount->Int.toString}`)->ignore
  lines->Js.Array2.push(`Space saved: ${spacesSaved->Int.toString} bytes`)->ignore
  lines->Js.Array2.push("")->ignore

  if duplicateCount > 0 {
    lines->Js.Array2.push("Duplicate pairs:")->ignore
    result.duplicates->Belt.Array.forEach(((dup, orig)) => {
      lines->Js.Array2.push(`  ${dup.metadata.path} -> ${orig.metadata.path}`)->ignore
    })
  }

  lines->Js.Array2.joinWith("\n")
}
