// SPDX-License-Identifier: PMPL-1.0-or-later
// D3 Drag bindings

type dragBehavior<'a>

type dragEvent = {
  active: int,
  x: float,
  y: float,
}

@module("d3") external drag: unit => dragBehavior<'a> = "drag"
@send external on: (dragBehavior<'a>, string, (dragEvent, 'a) => unit) => dragBehavior<'a> = "on"
@send external applyTo: (D3_Selection.t, dragBehavior<'a>) => D3_Selection.t = "call"
