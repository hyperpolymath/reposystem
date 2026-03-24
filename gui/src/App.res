// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//
// Main TEA Application

open Tea

// Initialize the application
let init = () => {
  let model = Model.init()
  // Load data on startup
  (model, Cmd.msg(Msg.LoadAllData))
}

// Subscriptions (none for now, D3 handles its own events)
let subscriptions = (_model: Model.t): Sub.t<Msg.t> => {
  Sub.none
}

// Mount to #app node
@val @scope("document")
external getElementById: string => Js.nullable<Dom.node> = "getElementById"

let main = () => {
  App.standardProgram(
    {
      init: init,
      update: Update.update,
      view: View.view,
      subscriptions: subscriptions,
    },
    getElementById("app"),
    (),
  )
}
