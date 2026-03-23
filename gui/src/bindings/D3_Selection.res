// SPDX-License-Identifier: PMPL-1.0-or-later
// D3 Selection bindings

type t

@module("d3") external select: string => t = "select"
@module("d3") external selectElement: Dom.element => t = "select"
@send external append: (t, string) => t = "append"
@send external attr: (t, string, 'a) => t = "attr"
@send external selectChildren: (t, string) => t = "selectAll"
@send external data: (t, array<'a>) => t = "data"
@send external join: (t, string) => t = "join"
@send external on: (t, string, 'a) => t = "on"
