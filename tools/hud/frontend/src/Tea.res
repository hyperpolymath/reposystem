// SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

/**
 * The Elm Architecture (TEA) implementation for ReScript.
 *
 * Based on hyperpolymath/rescript-tea patterns.
 * Provides a functional, predictable state management system.
 */

module Cmd = {
  type t<'msg> =
    | None
    | Batch(array<t<'msg>>)
    | Perform(unit => promise<'msg>)
    | Attempt(unit => promise<result<'msg, exn>>)

  let none = None

  let batch = cmds => Batch(cmds)

  let perform = (task: unit => promise<'a>, toMsg: 'a => 'msg): t<'msg> => {
    Perform(async () => {
      let result = await task()
      toMsg(result)
    })
  }

  let attempt = (task: unit => promise<'a>, toMsg: result<'a, exn> => 'msg): t<'msg> => {
    Attempt(async () => {
      try {
        let result = await task()
        Ok(toMsg(Ok(result)))
      } catch {
      | exn => Ok(toMsg(Error(exn)))
      }
    })
  }
}

module Sub = {
  type t<'msg> =
    | None
    | Batch(array<t<'msg>>)
    | Interval(int, unit => 'msg)
    | OnKeyDown(string => option<'msg>)
    | OnKeyUp(string => option<'msg>)
    | OnResize((int, int) => 'msg)

  let none = None

  let batch = subs => Batch(subs)

  let every = (ms, toMsg) => Interval(ms, toMsg)

  let onKeyDown = handler => OnKeyDown(handler)

  let onKeyUp = handler => OnKeyUp(handler)

  let onResize = handler => OnResize(handler)
}

type app<'model, 'msg> = {
  init: unit => ('model, Cmd.t<'msg>),
  update: ('msg, 'model) => ('model, Cmd.t<'msg>),
  view: ('model, 'msg => unit) => React.element,
  subscriptions: 'model => Sub.t<'msg>,
}

type program<'model, 'msg> = {
  model: 'model,
  dispatch: 'msg => unit,
}

/**
 * Run command side effects
 */
let rec runCmd = (cmd: Cmd.t<'msg>, dispatch: 'msg => unit): unit => {
  switch cmd {
  | Cmd.None => ()
  | Cmd.Batch(cmds) => cmds->Array.forEach(c => runCmd(c, dispatch))
  | Cmd.Perform(task) => {
      let _ = task()->Promise.then(msg => {
        dispatch(msg)
        Promise.resolve()
      })
    }
  | Cmd.Attempt(task) => {
      let _ = task()->Promise.then(result => {
        switch result {
        | Ok(msg) => dispatch(msg)
        | Error(_) => ()
        }
        Promise.resolve()
      })
    }
  }
}

/**
 * Setup subscription handlers
 */
let setupSub = (sub: Sub.t<'msg>, dispatch: 'msg => unit): array<unit => unit> => {
  let cleanups = []

  let rec setup = (s: Sub.t<'msg>) => {
    switch s {
    | Sub.None => ()
    | Sub.Batch(subs) => subs->Array.forEach(setup)
    | Sub.Interval(ms, toMsg) => {
        let id = Js.Global.setInterval(() => dispatch(toMsg()), ms)
        cleanups->Array.push(() => Js.Global.clearInterval(id))->ignore
      }
    | Sub.OnKeyDown(handler) => {
        let listener = (e: Dom.keyboardEvent) => {
          let key = e->Webapi.Dom.KeyboardEvent.key
          switch handler(key) {
          | Some(msg) => dispatch(msg)
          | None => ()
          }
        }
        Webapi.Dom.Window.addEventListener(Webapi.Dom.window, "keydown", listener->Obj.magic)
        cleanups->Array.push(() =>
          Webapi.Dom.Window.removeEventListener(Webapi.Dom.window, "keydown", listener->Obj.magic)
        )->ignore
      }
    | Sub.OnKeyUp(handler) => {
        let listener = (e: Dom.keyboardEvent) => {
          let key = e->Webapi.Dom.KeyboardEvent.key
          switch handler(key) {
          | Some(msg) => dispatch(msg)
          | None => ()
          }
        }
        Webapi.Dom.Window.addEventListener(Webapi.Dom.window, "keyup", listener->Obj.magic)
        cleanups->Array.push(() =>
          Webapi.Dom.Window.removeEventListener(Webapi.Dom.window, "keyup", listener->Obj.magic)
        )->ignore
      }
    | Sub.OnResize(toMsg) => {
        let listener = () => {
          let width = Webapi.Dom.Window.innerWidth(Webapi.Dom.window)
          let height = Webapi.Dom.Window.innerHeight(Webapi.Dom.window)
          dispatch(toMsg((width, height)))
        }
        Webapi.Dom.Window.addEventListener(Webapi.Dom.window, "resize", listener->Obj.magic)
        cleanups->Array.push(() =>
          Webapi.Dom.Window.removeEventListener(Webapi.Dom.window, "resize", listener->Obj.magic)
        )->ignore
      }
    }
  }

  setup(sub)
  cleanups
}
