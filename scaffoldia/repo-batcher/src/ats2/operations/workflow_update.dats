(*
** SPDX-License-Identifier: PMPL-1.0-or-later
**
** Workflow-update operation - IMPLEMENTATION (real Postiats 0.4.2)
**
** CANONICAL BUILD: from src/ats2 with `-IATS .`.
** Shell strings via string_append (freed once); effects via the
** verified effects layer. No `+`, no `prefix` identifier.
*)

#define ATS_DYNLOADFLAG 0 // L5 link-completeness: self-contained static-lib TU; sound here (no effectful top-level vals), no runtime dynload needed
#include "share/atspre_define.hats"
#include "share/atspre_staload.hats"

staload "operations/types.sats"
staload "operations/effects.sats"
staload "utils/string_utils.sats"
staload "operations/workflow_update.sats"   (* self: bind implements for patscc *)

(* No `$UNSAFE` in this module: ownership goes through the single
** audited boundaries (string_utils combinators, sys_run_owned). *)

fn istr (n: int): Strptr1 = tostring_int(n)

implement execute_workflow_update
  (workflow_src, workflow_name, base_dir, max_depth, dry_run) =
  if dry_run then let
    val d0 = string_append("find ", base_dir)
    val d1 = strptr_append_str(d0, " -maxdepth ")
    val d2 = strptr_append_strptr(d1, istr(max_depth))
    val d3 = strptr_append_str(d2, " -type d -name .git 2>/dev/null >/dev/null")
    val rc = sys_run_owned(d3)
  in
    ignoret(rc);
    @{ success_count = 0, failure_count = 0, skipped_count = 1,
       message = "workflow-update: dry-run, no files written" }
  end
  else let
    val c0 = string_append(
      "rm -f /tmp/.rb56_wf_ok /tmp/.rb56_wf_bad; find ", base_dir)
    val c1 = strptr_append_str(c0, " -maxdepth ")
    val c2 = strptr_append_strptr(c1, istr(max_depth))
    val c3 = strptr_append_str(c2, " -type d -name .git 2>/dev/null | sed 's@/.git$@@' | while read R; do mkdir -p \"$R/.github/workflows\" && cp ")
    val c4 = strptr_append_str(c3, workflow_src)
    val c5 = strptr_append_str(c4, " \"$R/.github/workflows/")
    val c6 = strptr_append_str(c5, workflow_name)
    val c7 = strptr_append_str(c6, "\" && echo \"$R\" >> /tmp/.rb56_wf_ok || echo \"$R\" >> /tmp/.rb56_wf_bad; done")
    val rc = sys_run_owned(c7)
  in
    if wexit_ok(rc) then @{
      success_count = 1, failure_count = 0, skipped_count = 0,
      message = "workflow-update: workflow copied (see /tmp/.rb56_wf_ok)" }
    else @{
      success_count = 0, failure_count = 1, skipped_count = 0,
      message = "workflow-update: copy pipeline failed (see /tmp/.rb56_wf_bad)" }
  end
