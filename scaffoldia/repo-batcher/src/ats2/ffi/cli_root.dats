(*
** SPDX-License-Identifier: PMPL-1.0-or-later
**
** Layer-7 link root. patscc compiles this unit as the ATS2 program
** entry: that is what emits the comprehensive prelude/libats/runtime
** dynload bootstrap and the exception table. It does no work itself —
** it immediately hands control to the Zig CLI (rb_main, which recovers
** argv from the OS via std.process), so the estate "Zig owns the CLI,
** ATS2 owns the verified core" split is preserved while letting
** patscc (the supported ATS2 linker) assemble the runtime.
*)

#include "share/atspre_define.hats"
#include "share/atspre_staload.hats"

%{^
extern int rb_main(void) ;
%}

extern fun rb_main (): int = "mac#rb_main"

implement main0 () = let
  val _ = rb_main ()
in
  (* rb_main calls std.process.exit; control does not return here. *)
end
