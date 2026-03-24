// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//
// D3 Force-directed graph visualization

open D3

// ──────────────────────────────────────────────
// Types
// ──────────────────────────────────────────────

// Graph state (mutable, managed by D3)
type graphState = {
  mutable simulation: option<Force.simulation<Model.graphNode>>,
  mutable svg: option<Selection.t>,
  mutable nodeGroup: option<Selection.t>,
  mutable linkGroup: option<Selection.t>,
}

// ──────────────────────────────────────────────
// Small utilities (no dependencies on later bindings)
// ──────────────────────────────────────────────

// Node color based on kind
let nodeColor = (kind: [#repo | #slot | #provider]) =>
  switch kind {
  | #repo => "#4299e1"
  | #slot => "#ecc94b"
  | #provider => "#48bb78"
  }

// ──────────────────────────────────────────────
// Module-level state and configuration
// Depends on: graphState type (above)
// ──────────────────────────────────────────────

let state: graphState = {
  simulation: None,
  svg: None,
  nodeGroup: None,
  linkGroup: None,
}

// Configuration
let config = {
  "width": 800,
  "height": 600,
  "nodeRadius": 8,
  "linkDistance": 100,
  "chargeStrength": -200.0,
}

// ──────────────────────────────────────────────
// Initialize the graph visualization
// Depends on: state, config, Selection, Zoom, Force
// ──────────────────────────────────────────────

let initGraph = (container: Dom.element) => {
  // Create SVG
  let svg =
    Selection.selectElement(container)
    ->Selection.append("svg")
    ->Selection.attr("width", config["width"])
    ->Selection.attr("height", config["height"])
    ->Selection.attr("viewBox", `0 0 ${config["width"]->Int.toString} ${config["height"]->Int.toString}`)

  // Create groups for links and nodes
  let linkGroup = svg->Selection.append("g")->Selection.attr("class", "links")
  let nodeGroup = svg->Selection.append("g")->Selection.attr("class", "nodes")

  // Create zoom behavior
  let zoomBehavior =
    Zoom.zoom()->Zoom.scaleExtent((0.1, 4.0))->Zoom.on("zoom", (event, _) => {
      linkGroup->Selection.attr("transform", event.transform->Zoom.toString)->ignore
      nodeGroup->Selection.attr("transform", event.transform->Zoom.toString)->ignore
    })

  svg->Zoom.applyTo(zoomBehavior)->ignore

  // Store references
  state.svg = Some(svg)
  state.nodeGroup = Some(nodeGroup)
  state.linkGroup = Some(linkGroup)

  // Create simulation
  let simulation =
    Force.forceSimulationEmpty()
    ->Force.force(
      "charge",
      Force.forceManyBody()
      ->Force.strength(config["chargeStrength"])
      ->Force.manyBodyForceAsForce,
    )
    ->Force.force(
      "center",
      Force.forceCenter(
        config["width"]->Int.toFloat /. 2.0,
        config["height"]->Int.toFloat /. 2.0,
      ),
    )
    ->Force.force(
      "link",
      Force.forceLinkEmpty()
      ->Force.linkDistance(config["linkDistance"]->Int.toFloat)
      ->Force.linkForceAsForce,
    )
    ->Force.force("collide", Force.forceCollide(config["nodeRadius"]->Int.toFloat *. 2.0))

  state.simulation = Some(simulation)
}

// ──────────────────────────────────────────────
// Update the graph with new data
// Depends on: state, config, nodeColor, Force, Selection, Drag
// ──────────────────────────────────────────────

let updateGraph = (nodes: array<Model.graphNode>, links: array<Model.graphLink>) => {
  switch (state.simulation, state.nodeGroup, state.linkGroup) {
  | (Some(simulation), Some(nodeGroup), Some(linkGroup)) => {
      // Convert to D3 node format
      let d3Nodes: array<Force.node<Model.graphNode>> = nodes->Array.map((
        n: Model.graphNode,
      ): Force.node<Model.graphNode> => {
        Force.index: 0,
        x: n.x,
        y: n.y,
        vx: n.vx,
        vy: n.vy,
        fx: n.fx->Nullable.fromOption,
        fy: n.fy->Nullable.fromOption,
        data: n,
      })

      // Convert links to D3 format
      let d3Links: array<Force.linkInput<Model.graphNode>> = links->Array.map((
        l: Model.graphLink,
      ): Force.linkInput<Model.graphNode> => {
        Force.source: l.source,
        target: l.target,
      })

      // Update simulation nodes
      simulation->Force.nodes(d3Nodes)->ignore

      // Update link force
      let linkForce = simulation->Force.getForce("link")
      switch linkForce->Nullable.toOption {
      | Some(f) =>
        f
        ->Force.asLinkForce
        ->Force.links(d3Links)
        ->Force.linkId((link: Force.linkInput<Model.graphNode>, _, _) => link.source)
        ->ignore
      | None => ()
      }

      // Update link visuals
      let linkSelection =
        linkGroup
        ->Selection.selectChildren("line")
        ->Selection.data(d3Links)
        ->Selection.join("line")
        ->Selection.attr("stroke", "#999")
        ->Selection.attr("stroke-opacity", "0.6")
        ->Selection.attr("stroke-width", "1.5")

      // Update node visuals
      let nodeSelection =
        nodeGroup
        ->Selection.selectChildren("circle")
        ->Selection.data(d3Nodes)
        ->Selection.join("circle")
        ->Selection.attr("r", config["nodeRadius"])
        ->Selection.attr("fill", (n: Force.node<Model.graphNode>) => nodeColor(n.data.kind))
        ->Selection.attr("stroke", "#fff")
        ->Selection.attr("stroke-width", "1.5")

      // Add drag behavior
      let dragBehavior =
        Drag.drag()
        ->Drag.on("start", (event: Drag.dragEvent, d: Force.node<Model.graphNode>) => {
          if event.active == 0 {
            simulation->Force.alphaTarget(0.3)->Force.restart->ignore
          }
          d.Force.fx = Nullable.make(event.x)
          d.Force.fy = Nullable.make(event.y)
        })
        ->Drag.on("drag", (event: Drag.dragEvent, d: Force.node<Model.graphNode>) => {
          d.Force.fx = Nullable.make(event.x)
          d.Force.fy = Nullable.make(event.y)
        })
        ->Drag.on("end", (event: Drag.dragEvent, d: Force.node<Model.graphNode>) => {
          if event.active == 0 {
            simulation->Force.alphaTarget(0.0)->ignore
          }
          d.Force.fx = Nullable.null
          d.Force.fy = Nullable.null
        })

      nodeSelection->Drag.applyTo(dragBehavior)->ignore

      // Update positions on tick
      simulation->Force.on("tick", () => {
        linkSelection
        ->Selection.attr("x1", (l: Force.linkInput<Model.graphNode>) => {
          // Find source node position
          switch d3Nodes->Array.find((n: Force.node<Model.graphNode>) => n.data.id == l.source) {
          | Some(n) => n.x
          | None => 0.0
          }
        })
        ->Selection.attr("y1", (l: Force.linkInput<Model.graphNode>) => {
          switch d3Nodes->Array.find((n: Force.node<Model.graphNode>) => n.data.id == l.source) {
          | Some(n) => n.y
          | None => 0.0
          }
        })
        ->Selection.attr("x2", (l: Force.linkInput<Model.graphNode>) => {
          switch d3Nodes->Array.find((n: Force.node<Model.graphNode>) => n.data.id == l.target) {
          | Some(n) => n.x
          | None => 0.0
          }
        })
        ->Selection.attr("y2", (l: Force.linkInput<Model.graphNode>) => {
          switch d3Nodes->Array.find((n: Force.node<Model.graphNode>) => n.data.id == l.target) {
          | Some(n) => n.y
          | None => 0.0
          }
        })
        ->ignore

        nodeSelection
        ->Selection.attr("cx", (n: Force.node<Model.graphNode>) => n.x)
        ->Selection.attr("cy", (n: Force.node<Model.graphNode>) => n.y)
        ->ignore
      })->ignore

      // Restart simulation
      simulation->Force.alpha(1.0)->Force.restart->ignore
    }
  | _ => ()
  }
}
