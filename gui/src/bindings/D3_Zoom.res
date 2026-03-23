// SPDX-License-Identifier: PMPL-1.0-or-later
// D3 Zoom bindings

type zoomBehavior<'a>
type zoomTransform

type zoomEvent = {
  transform: zoomTransform,
}

@module("d3") external zoom: unit => zoomBehavior<'a> = "zoom"
@send external scaleExtent: (zoomBehavior<'a>, (float, float)) => zoomBehavior<'a> = "scaleExtent"
@send external on: (zoomBehavior<'a>, string, (zoomEvent, 'a) => unit) => zoomBehavior<'a> = "on"
@send external applyTo: (D3_Selection.t, zoomBehavior<'a>) => D3_Selection.t = "call"
external toString: zoomTransform => string = "String"
