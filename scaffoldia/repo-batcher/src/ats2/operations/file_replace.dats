(*
** SPDX-License-Identifier: PMPL-1.0-or-later
**
** File-replace operation - IMPLEMENTATION (real Postiats 0.4.2)
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

implement execute_file_replace
  (pattern, replacement, base_dir, max_depth, backup, dry_run) =
  if dry_run then let
    val ds = istr(max_depth)
    val d0 = string_append("find ", base_dir)
    val d1 = app(d0, " -maxdepth ")
    val d2 = app(d1, $UNSAFE.strptr2string(ds))
    val () = strptr_free(ds)
    val d3 = app(d2, " -type f -name ")
    val d4 = app(d3, pattern)
    val d5 = app(d4, " 2>/dev/null >/dev/null")
    val rc = sys_run($UNSAFE.strptr2string(d5))
    val () = strptr_free(d5)
  in
    ignoret(rc);
    @{ success_count = 0, failure_count = 0, skipped_count = 1,
       message = "file-replace: dry-run, no files mutated" }
  end
  else let
    val () =
      if backup then let
        val b0 = string_append("mkdir -p /tmp/.rb56_fr_bak; ", "")
        val br = sys_run($UNSAFE.strptr2string(b0))
        val () = strptr_free(b0)
      in ignoret(br) end
      else ()
    val ds = istr(max_depth)
    val c0 = string_append("find ", base_dir)
    val c1 = app(c0, " -maxdepth ")
    val c2 = app(c1, $UNSAFE.strptr2string(ds))
    val () = strptr_free(ds)
    val c3 = app(c2, " -type f -name ")
    val c4 = app(c3, pattern)
    val c5 = app(c4, " 2>/dev/null | xargs -r -I T cp ")
    val c6 = app(c5, replacement)
    val c7 = app(c6, " T")
    val rc = sys_run($UNSAFE.strptr2string(c7))
    val () = strptr_free(c7)
  in
    if wexit_ok(rc) then @{
      success_count = 1, failure_count = 0, skipped_count = 0,
      message = "file-replace: matches overwritten" }
    else @{
      success_count = 0, failure_count = 1, skipped_count = 0,
      message = "file-replace: copy pipeline failed" }
  end
