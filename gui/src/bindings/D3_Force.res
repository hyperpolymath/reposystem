// SPDX-License-Identifier: PMPL-1.0-or-later
// D3 Force simulation bindings

type simulation<'a>
type force
type manyBodyForce
type linkForce<'a>

type node<'a> = {
  mutable index: int,
  mutable x: float,
  mutable y: float,
  mutable vx: float,
  mutable vy: float,
  mutable fx: Js.Nullable.t<float>,
  mutable fy: Js.Nullable.t<float>,
  data: 'a,
}

type linkInput<'a> = {
  source: string,
  target: string,
}

// Simulation
@module("d3") external forceSimulationEmpty: unit => simulation<'a> = "forceSimulation"
@send external force: (simulation<'a>, string, 'f) => simulation<'a> = "force"
@send external nodes: (simulation<'a>, array<node<'a>>) => simulation<'a> = "nodes"
@send external alpha: (simulation<'a>, float) => simulation<'a> = "alpha"
@send external alphaTarget: (simulation<'a>, float) => simulation<'a> = "alphaTarget"
@send external restart: simulation<'a> => simulation<'a> = "restart"
@send external on: (simulation<'a>, string, unit => unit) => simulation<'a> = "on"
@send external getForce: (simulation<'a>, string) => Js.Nullable.t<force> = "force"

// Forces
@module("d3") external forceManyBody: unit => manyBodyForce = "forceManyBody"
@module("d3") external forceCenter: (float, float) => force = "forceCenter"
@module("d3") external forceCollide: float => force = "forceCollide"
@module("d3") external forceLinkEmpty: unit => linkForce<'a> = "forceLink"

// Many-body force
external asManyBodyForce: force => manyBodyForce = "%identity"
external manyBodyForceAsForce: manyBodyForce => force = "%identity"
@send external strength: (manyBodyForce, float) => manyBodyForce = "strength"

// Link force
external asLinkForce: force => linkForce<'a> = "%identity"
external linkForceAsForce: linkForce<'a> => force = "%identity"
@send external linkDistance: (linkForce<'a>, float) => linkForce<'a> = "distance"
@send external links: (linkForce<'a>, array<linkInput<'a>>) => linkForce<'a> = "links"
@send external linkId: (linkForce<'a>, (linkInput<'a>, int, array<linkInput<'a>>) => string) => linkForce<'a> = "id"
