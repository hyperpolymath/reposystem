// SPDX-License-Identifier: PMPL-1.0-or-later
// Graph visualization for documentation relationships
// Generates DOT format for Graphviz rendering

open Types

// DOT graph configuration
type dotConfig = {
  rankdir: string, // "LR" | "TB" | "RL" | "BT"
  nodeShape: string, // "box" | "circle" | "ellipse"
  fontSize: int,
  showHashes: bool,
}

let defaultConfig: dotConfig = {
  rankdir: "LR",
  nodeShape: "box",
  fontSize: 12,
  showHashes: false,
}

// Escape DOT special characters
let escapeDot = (str: string): string => {
  str
  ->Js.String2.replaceByRe(%re("/\"/g"), "\\\"")
  ->Js.String2.replaceByRe(%re("/\n/g"), "\\n")
}

// Generate node ID
let nodeId = (doc: document): string => {
  if defaultConfig.showHashes {
    Js.String2.slice(doc.hash, ~from=0, ~to_=8)
  } else {
    doc.metadata.path
    ->Js.String2.replaceByRe(%re("/[^a-zA-Z0-9]/g"), "_")
  }
}

// Generate node label
let nodeLabel = (doc: document): string => {
  let docType = documentTypeToString(doc.metadata.documentType)
  let path = doc.metadata.path
  let version = switch doc.metadata.version {
  | None => ""
  | Some(v) => ` v${versionToString(v)}`
  }

  `${docType}\\n${path}${version}`
}

// Get node color based on document type
let nodeColor = (docType: documentType): string => {
  switch docType {
  | README => "#4a9eff"
  | LICENSE => "#ff6b6b"
  | SECURITY => "#ffd93d"
  | CONTRIBUTING => "#95e1d3"
  | CODE_OF_CONDUCT => "#a8e6cf"
  | FUNDING => "#ffaaa5"
  | CITATION => "#b4b4ff"
  | CHANGELOG => "#ffc3a0"
  | AUTHORS => "#c7ceea"
  | SUPPORT => "#e2f0cb"
  | Custom(_) => "#cccccc"
  }
}

// Get edge color based on edge type
let edgeColor = (edgeType: edgeType): string => {
  switch edgeType {
  | ConflictsWith => "#ff6b6b"
  | SupersededBy => "#4a9eff"
  | DuplicateOf => "#ffd93d"
  | CanonicalFor => "#51cf66"
  | DerivedFrom => "#a8e6cf"
  }
}

// Get edge style based on confidence
let edgeStyle = (confidence: float): string => {
  if confidence >= 0.9 {
    "solid"
  } else if confidence >= 0.7 {
    "dashed"
  } else {
    "dotted"
  }
}

// Generate DOT format for documents
let generateDot = (
  documents: array<document>,
  edges: array<edge>,
  config: dotConfig,
): string => {
  let lines = []

  // Header
  lines->Js.Array2.push("digraph Documentation {")->ignore
  lines->Js.Array2.push(`  rankdir=${config.rankdir};`)->ignore
  lines->Js.Array2.push(`  node [shape=${config.nodeShape}, fontsize=${config.fontSize->Int.toString}, style=filled];`)->ignore
  lines->Js.Array2.push(`  edge [fontsize=${(config.fontSize - 2)->Int.toString}];`)->ignore
  lines->Js.Array2.push("")->ignore

  // Nodes
  lines->Js.Array2.push("  // Documents")->ignore
  documents->Belt.Array.forEach(doc => {
    let id = nodeId(doc)
    let label = nodeLabel(doc)
    let color = nodeColor(doc.metadata.documentType)

    lines->Js.Array2.push(
      `  "${id}" [label="${label}", fillcolor="${color}"];`,
    )->ignore
  })

  lines->Js.Array2.push("")->ignore

  // Edges
  lines->Js.Array2.push("  // Relationships")->ignore
  edges->Belt.Array.forEach(edge => {
    // Find documents for this edge
    let fromDoc = documents->Belt.Array.getBy(d => d.hash == edge.from)
    let toDoc = documents->Belt.Array.getBy(d => d.hash == edge.to)

    switch (fromDoc, toDoc) {
    | (Some(from), Some(to)) => {
        let fromId = nodeId(from)
        let toId = nodeId(to)
        let color = edgeColor(edge.edgeType)
        let style = edgeStyle(edge.confidence)
        let label = edgeTypeToString(edge.edgeType)

        lines->Js.Array2.push(
          `  "${fromId}" -> "${toId}" [label="${label}", color="${color}", style=${style}];`,
        )->ignore
      }
    | _ => ()
    }
  })

  // Footer
  lines->Js.Array2.push("}")->ignore

  lines->Js.Array2.joinWith("\n")
}

// Generate HTML with embedded SVG
let generateHTML = (
  documents: array<document>,
  edges: array<edge>,
  title: string,
): string => {
  let dot = generateDot(documents, edges, defaultConfig)

  `<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>${title}</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
            background: #f5f5f5;
        }
        .container {
            max-width: 1400px;
            margin: 0 auto;
            background: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
            margin-bottom: 20px;
        }
        .graph-container {
            overflow: auto;
            border: 1px solid #ddd;
            border-radius: 4px;
            padding: 20px;
        }
        .legend {
            margin-top: 20px;
            padding: 15px;
            background: #f9f9f9;
            border-radius: 4px;
        }
        .legend-item {
            display: inline-block;
            margin-right: 20px;
            margin-bottom: 10px;
        }
        .legend-color {
            display: inline-block;
            width: 20px;
            height: 20px;
            margin-right: 5px;
            vertical-align: middle;
            border-radius: 3px;
        }
        .stats {
            margin-top: 20px;
            padding: 15px;
            background: #e3f2fd;
            border-radius: 4px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>${title}</h1>

        <div class="stats">
            <strong>Statistics:</strong><br>
            Documents: ${documents->Belt.Array.length->Int.toString}<br>
            Relationships: ${edges->Belt.Array.length->Int.toString}
        </div>

        <div class="graph-container">
            <pre>${escapeDot(dot)}</pre>
        </div>

        <div class="legend">
            <strong>Legend:</strong><br>
            <div class="legend-item">
                <span class="legend-color" style="background: #ff6b6b"></span>
                Conflicts
            </div>
            <div class="legend-item">
                <span class="legend-color" style="background: #4a9eff"></span>
                Supersedes
            </div>
            <div class="legend-item">
                <span class="legend-color" style="background: #ffd93d"></span>
                Duplicates
            </div>
            <div class="legend-item">
                <span class="legend-color" style="background: #51cf66"></span>
                Canonical
            </div>
        </div>

        <div style="margin-top: 20px; color: #666; font-size: 12px;">
            Generated: ${Js.Date.make()->Js.Date.toISOString}<br>
            To render: Save DOT content and run <code>dot -Tsvg -o output.svg</code>
        </div>
    </div>
</body>
</html>`
}

// Generate Mermaid diagram (alternative to DOT)
let generateMermaid = (documents: array<document>, edges: array<edge>): string => {
  let lines = []

  lines->Js.Array2.push("graph LR")->ignore

  // Nodes
  documents->Belt.Array.forEach(doc => {
    let id = nodeId(doc)
    let label = documentTypeToString(doc.metadata.documentType)
    lines->Js.Array2.push(`  ${id}[${label}]`)->ignore
  })

  // Edges
  edges->Belt.Array.forEach(edge => {
    let fromDoc = documents->Belt.Array.getBy(d => d.hash == edge.from)
    let toDoc = documents->Belt.Array.getBy(d => d.hash == edge.to)

    switch (fromDoc, toDoc) {
    | (Some(from), Some(to)) => {
        let fromId = nodeId(from)
        let toId = nodeId(to)
        let label = edgeTypeToString(edge.edgeType)
        lines->Js.Array2.push(`  ${fromId} -->|${label}| ${toId}`)->ignore
      }
    | _ => ()
    }
  })

  lines->Js.Array2.joinWith("\n")
}

// Export to file
let exportDot = (
  documents: array<document>,
  edges: array<edge>,
  filePath: string,
): result<unit, string> => {
  try {
    let dot = generateDot(documents, edges, defaultConfig)
    Node.Fs.writeFileSyncWith(filePath, dot, #utf8)
    Ok()
  } catch {
  | exn =>
    Error(
      `Failed to export DOT: ${exn->Js.Exn.message->Belt.Option.getWithDefault("Unknown error")}`,
    )
  }
}

let exportHTML = (
  documents: array<document>,
  edges: array<edge>,
  filePath: string,
  title: string,
): result<unit, string> => {
  try {
    let html = generateHTML(documents, edges, title)
    Node.Fs.writeFileSyncWith(filePath, html, #utf8)
    Ok()
  } catch {
  | exn =>
    Error(
      `Failed to export HTML: ${exn->Js.Exn.message->Belt.Option.getWithDefault("Unknown error")}`,
    )
  }
}
