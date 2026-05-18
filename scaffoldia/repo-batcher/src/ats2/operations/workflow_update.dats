(*
** SPDX-License-Identifier: PMPL-1.0-or-later
**
** Workflow-update operation - IMPLEMENTATION (real Postiats 0.4.2)
**
** CANONICAL BUILD: from src/ats2 with `-IATS .`.
** Shell strings via string_append (freed once); effects via the
** verified effects layer. No `+`, no `prefix` identifier.
*)

#include "share/atspre_define.hats"
#include "share/atspre_staload.hats"

staload "operations/types.sats"
staload "operations/effects.sats"
staload "utils/string_utils.sats"

fn app (acc: Strptr1, tail: string): Strptr1 = let
  val r = string_append($UNSAFE.strptr2string(acc), tail)
  val () = strptr_free(acc)
in
  r
end

fn istr (n: int): Strptr1 = tostring_int(n)

implement execute_workflow_update
  (workflow_src, workflow_name, base_dir, max_depth, dry_run) =
  if dry_run then let
    val ds = istr(max_depth)
    val d0 = string_append("find ", base_dir)
    val d1 = app(d0, " -maxdepth ")
    val d2 = app(d1, $UNSAFE.strptr2string(ds))
    val () = strptr_free(ds)
    val d3 = app(d2, " -type d -name .git 2>/dev/null >/dev/null")
    val rc = sys_run($UNSAFE.strptr2string(d3))
    val () = strptr_free(d3)
  in
    ignoret(rc);
    @{ success_count = 0, failure_count = 0, skipped_count = 1,
       message = "workflow-update: dry-run, no files written" }
  end
  else let
    val ds = istr(max_depth)
    val c0 = string_append(
      "rm -f /tmp/.rb56_wf_ok /tmp/.rb56_wf_bad; find ", base_dir)
    val c1 = app(c0, " -maxdepth ")
    val c2 = app(c1, $UNSAFE.strptr2string(ds))
    val () = strptr_free(ds)
    val c3 = app(c2, " -type d -name .git 2>/dev/null | sed 's@/.git$@@' | while read R; do mkdir -p \"$R/.github/workflows\" && cp ")
    val c4 = app(c3, workflow_src)
    val c5 = app(c4, " \"$R/.github/workflows/")
    val c6 = app(c5, workflow_name)
    val c7 = app(c6, "\" && echo \"$R\" >> /tmp/.rb56_wf_ok || echo \"$R\" >> /tmp/.rb56_wf_bad; done")
    val rc = sys_run($UNSAFE.strptr2string(c7))
    val () = strptr_free(c7)
  in
    if wexit_ok(rc) then @{
      success_count = 1, failure_count = 0, skipped_count = 0,
      message = "workflow-update: workflow copied (see /tmp/.rb56_wf_ok)" }
    else @{
      success_count = 0, failure_count = 1, skipped_count = 0,
      message = "workflow-update: copy pipeline failed (see /tmp/.rb56_wf_bad)" }
  end
