// SPDX-License-Identifier: PMPL-1.0-or-later
// Type-safe ArangoDB client for graph operations
// Multi-model database: document storage + graph relationships

open Types

// ArangoDB bindings
type database
type collection
type graph
type aqlQuery

@module("arangojs") @new
external createDatabase: {..} => database = "Database"

@send external db: database => database = "db"
@send external useDatabase: (database, string) => database = "useDatabase"
@send external collection: (database, string) => collection = "collection"
@send external graph: (database, string) => graph = "graph"
@send external query: (database, string, {..}) => promise<aqlQuery> = "query"

@send external save: (collection, {..}) => promise<{..}> = "save"
@send external document: (collection, string) => promise<{..}> = "document"
@send external update: (collection, string, {..}) => promise<{..}> = "update"
@send external remove: (collection, string) => promise<{..}> = "remove"

@send external all: aqlQuery => promise<array<{..}>> = "all"

// Client state
type client = {
  db: database,
  config: config,
  collections: {
    documents: collection,
    conflicts: collection,
    resolutions: collection,
  },
  edges: {
    relationships: collection,
  },
}

// Initialize ArangoDB client
let initialize = async (config: config): result<client, string> => {
  try {
    let db = createDatabase({
      "url": config.arangoUrl,
      "databaseName": config.arangoDatabase,
      "auth": {
        "username": config.arangoUsername,
        "password": config.arangoPassword,
      },
    })

    // Get or create collections
    let documentsCol = db->collection("documents")
    let conflictsCol = db->collection("conflicts")
    let resolutionsCol = db->collection("resolutions")
    let relationshipsCol = db->collection("relationships")

    Ok({
      db: db,
      config: config,
      collections: {
        documents: documentsCol,
        conflicts: conflictsCol,
        resolutions: resolutionsCol,
      },
      edges: {
        relationships: relationshipsCol,
      },
    })
  } catch {
  | exn => Error(`Failed to initialize ArangoDB: ${exn->Js.Exn.message->Belt.Option.getWithDefault("Unknown error")}`)
  }
}

// Document serialization
let documentToJson = (doc: document): Js.Json.t => {
  Js.Json.object_(
    Js.Dict.fromArray([
      ("_key", Js.Json.string(doc.hash)),
      ("hash", Js.Json.string(doc.hash)),
      ("content", Js.Json.string(doc.content)),
      ("path", Js.Json.string(doc.metadata.path)),
      (
        "documentType",
        Js.Json.string(documentTypeToString(doc.metadata.documentType)),
      ),
      ("lastModified", Js.Json.number(doc.metadata.lastModified)),
      (
        "version",
        switch doc.metadata.version {
        | None => Js.Json.null
        | Some(v) => Js.Json.string(versionToString(v))
        },
      ),
      ("repository", Js.Json.string(doc.metadata.repository)),
      ("branch", Js.Json.string(doc.metadata.branch)),
      ("createdAt", Js.Json.number(doc.createdAt)),
    ]),
  )
}

// Edge serialization
let edgeToJson = (edge: edge): Js.Json.t => {
  Js.Json.object_(
    Js.Dict.fromArray([
      ("_from", Js.Json.string("documents/" ++ edge.from)),
      ("_to", Js.Json.string("documents/" ++ edge.to)),
      ("type", Js.Json.string(edgeTypeToString(edge.edgeType))),
      ("confidence", Js.Json.number(edge.confidence)),
      ("metadata", edge.metadata),
    ]),
  )
}

// Insert document
let insertDocument = async (client: client, doc: document): result<unit, string> => {
  try {
    let json = documentToJson(doc)
    let _ = await client.collections.documents->save(json->Obj.magic)
    Ok()
  } catch {
  | exn =>
    Error(
      `Failed to insert document: ${exn->Js.Exn.message->Belt.Option.getWithDefault("Unknown error")}`,
    )
  }
}

// Batch insert documents
let insertDocuments = async (
  client: client,
  documents: array<document>,
): result<unit, string> => {
  let results = []
  for i in 0 to Belt.Array.length(documents) - 1 {
    let doc = Belt.Array.getUnsafe(documents, i)
    let result = await insertDocument(client, doc)
    results->Js.Array2.push(result)->ignore
  }

  let errors =
    results->Belt.Array.keepMap(r =>
      switch r {
      | Error(msg) => Some(msg)
      | Ok() => None
      }
    )

  if Belt.Array.length(errors) > 0 {
    Error(`Failed to insert ${errors->Belt.Array.length->Int.toString} documents`)
  } else {
    Ok()
  }
}

// Insert edge
let insertEdge = async (client: client, edge: edge): result<unit, string> => {
  try {
    let json = edgeToJson(edge)
    let _ = await client.edges.relationships->save(json->Obj.magic)
    Ok()
  } catch {
  | exn =>
    Error(`Failed to insert edge: ${exn->Js.Exn.message->Belt.Option.getWithDefault("Unknown error")}`)
  }
}

// Batch insert edges
let insertEdges = async (client: client, edges: array<edge>): result<unit, string> => {
  let results = []
  for i in 0 to Belt.Array.length(edges) - 1 {
    let edge = Belt.Array.getUnsafe(edges, i)
    let result = await insertEdge(client, edge)
    results->Js.Array2.push(result)->ignore
  }

  let errors =
    results->Belt.Array.keepMap(r =>
      switch r {
      | Error(msg) => Some(msg)
      | Ok() => None
      }
    )

  if Belt.Array.length(errors) > 0 {
    Error(`Failed to insert ${errors->Belt.Array.length->Int.toString} edges`)
  } else {
    Ok()
  }
}

// Store conflict
let storeConflict = async (client: client, conflict: conflict): result<unit, string> => {
  try {
    let docHashes = conflict.documents->Belt.Array.map(d => Js.Json.string(d.hash))

    let json = Js.Json.object_(
      Js.Dict.fromArray([
        ("_key", Js.Json.string(conflict.id)),
        ("id", Js.Json.string(conflict.id)),
        ("documents", Js.Json.array(docHashes)),
        ("detectedAt", Js.Json.number(conflict.detectedAt)),
        ("confidence", Js.Json.number(conflict.confidence)),
        (
          "suggestedStrategy",
          Js.Json.string(resolutionStrategyToString(conflict.suggestedStrategy)),
        ),
      ]),
    )

    let _ = await client.collections.conflicts->save(json->Obj.magic)
    Ok()
  } catch {
  | exn =>
    Error(
      `Failed to store conflict: ${exn->Js.Exn.message->Belt.Option.getWithDefault("Unknown error")}`,
    )
  }
}

// Store resolution
let storeResolution = async (
  client: client,
  resolution: resolutionResult,
): result<unit, string> => {
  try {
    let json = Js.Json.object_(
      Js.Dict.fromArray([
        ("_key", Js.Json.string(resolution.conflictId ++ "_resolution")),
        ("conflictId", Js.Json.string(resolution.conflictId)),
        (
          "strategy",
          Js.Json.string(resolutionStrategyToString(resolution.strategy)),
        ),
        (
          "selectedDocument",
          switch resolution.selectedDocument {
          | None => Js.Json.null
          | Some(doc) => Js.Json.string(doc.hash)
          },
        ),
        ("confidence", Js.Json.number(resolution.confidence)),
        ("requiresApproval", Js.Json.boolean(resolution.requiresApproval)),
        ("reasoning", Js.Json.string(resolution.reasoning)),
        ("timestamp", Js.Json.number(resolution.timestamp)),
      ]),
    )

    let _ = await client.collections.resolutions->save(json->Obj.magic)
    Ok()
  } catch {
  | exn =>
    Error(
      `Failed to store resolution: ${exn->Js.Exn.message->Belt.Option.getWithDefault("Unknown error")}`,
    )
  }
}

// Query documents by hash
let findDocumentByHash = async (
  client: client,
  hash: contentHash,
): result<option<Js.Json.t>, string> => {
  try {
    let result = await client.collections.documents->document(hash)
    Ok(Some(result->Obj.magic))
  } catch {
  | _ => Ok(None) // Document not found
  }
}

// Query for duplicates
let findDuplicates = async (client: client): result<array<Js.Json.t>, string> => {
  try {
    let aql = `
      FOR doc IN documents
      COLLECT hash = doc.hash WITH COUNT INTO count
      FILTER count > 1
      RETURN { hash, count }
    `
    let result = await client.db->query(aql, Js.Dict.empty()->Obj.magic)
    let data = await result->all
    Ok(data->Obj.magic)
  } catch {
  | exn =>
    Error(
      `Failed to find duplicates: ${exn->Js.Exn.message->Belt.Option.getWithDefault("Unknown error")}`,
    )
  }
}

// Graph traversal: Find all related documents
let findRelatedDocuments = async (
  client: client,
  hash: contentHash,
): result<array<Js.Json.t>, string> => {
  try {
    let aql = `
      FOR v, e, p IN 1..3 OUTBOUND @start relationships
      RETURN { vertex: v, edge: e, path: p }
    `
    let bindVars = Js.Dict.fromArray([("start", Js.Json.string("documents/" ++ hash))])
    let result = await client.db->query(aql, bindVars->Obj.magic)
    let data = await result->all
    Ok(data->Obj.magic)
  } catch {
  | exn =>
    Error(
      `Failed to find related documents: ${exn->Js.Exn.message->Belt.Option.getWithDefault("Unknown error")}`,
    )
  }
}

// Health check
let healthCheck = async (client: client): result<bool, string> => {
  try {
    let aql = "RETURN 1"
    let _ = await client.db->query(aql, Js.Dict.empty()->Obj.magic)
    Ok(true)
  } catch {
  | exn =>
    Error(
      `Health check failed: ${exn->Js.Exn.message->Belt.Option.getWithDefault("Unknown error")}`,
    )
  }
}
