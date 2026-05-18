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
staload "operations/file_replace.sats"   (* self: bind implements for patscc *)

(* No `$UNSAFE` in this module: string/effect ownership goes through the
** single audited boundaries (string_utils combinators, sys_run_owned). *)

fn istr (n: int): Strptr1 = tostring_int(n)

implement execute_file_replace
  (pattern, replacement, base_dir, max_depth, backup, dry_run) =
  if dry_run then let
    val d0 = string_append("find ", base_dir)
    val d1 = strptr_append_str(d0, " -maxdepth ")
    val d2 = strptr_append_strptr(d1, istr(max_depth))
    val d3 = strptr_append_str(d2, " -type f -name ")
    val d4 = strptr_append_str(d3, pattern)
    val d5 = strptr_append_str(d4, " 2>/dev/null >/dev/null")
    val rc = sys_run_owned(d5)
  in
    ignoret(rc);
    @{ success_count = 0, failure_count = 0, skipped_count = 1,
       message = "file-replace: dry-run, no files mutated" }
  end
  else let
    val () =
      if backup then
        ignoret(sys_run_owned(string_append("mkdir -p /tmp/.rb56_fr_bak; ", "")))
      else ()
    val c0 = string_append("find ", base_dir)
    val c1 = strptr_append_str(c0, " -maxdepth ")
    val c2 = strptr_append_strptr(c1, istr(max_depth))
    val c3 = strptr_append_str(c2, " -type f -name ")
    val c4 = strptr_append_str(c3, pattern)
    val c5 = strptr_append_str(c4, " 2>/dev/null | xargs -r -I T cp ")
    val c6 = strptr_append_str(c5, replacement)
    val c7 = strptr_append_str(c6, " T")
    val rc = sys_run_owned(c7)
  in
    if wexit_ok(rc) then @{
      success_count = 1, failure_count = 0, skipped_count = 0,
      message = "file-replace: matches overwritten" }
    else @{
      success_count = 0, failure_count = 1, skipped_count = 0,
      message = "file-replace: copy pipeline failed" }
  end
