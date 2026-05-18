(*
** SPDX-License-Identifier: PMPL-1.0-or-later
**
** GitHub repo-settings operation - IMPLEMENTATION (real Postiats 0.4.2)
**
** CANONICAL BUILD: from src/ats2 with `-IATS .`.
** `gh` invoked via the verified effects layer; shell strings via
** string_append (freed once). No `+`, no `prefix` identifier.
*)

#include "share/atspre_define.hats"
#include "share/atspre_staload.hats"

staload "operations/types.sats"
staload "operations/effects.sats"
staload "utils/string_utils.sats"
staload "operations/github_settings.sats"   (* self: bind implements for patscc *)

fn app (acc: Strptr1, tail: string): Strptr1 = let
  val r = string_append($UNSAFE.strptr2string(acc), tail)
  val () = strptr_free(acc)
in
  r
end

implement apply_github_setting (repo, gh_flag, dry_run) = let
  val c0 = string_append("gh repo edit ", repo)
  val c1 = app(c0, " ")
  val c2 = app(c1, gh_flag)
in
  if dry_run then let
    val () = strptr_free(c2)
  in
    OpSkipped("github-settings: dry-run (gh not invoked)")
  end
  else let
    val rc = sys_run($UNSAFE.strptr2string(c2))
    val () = strptr_free(c2)
  in
    if wexit_ok(rc) then OpSuccess("github-settings: gh repo edit applied")
    else OpFailure("github-settings: gh repo edit failed")
  end
end

implement execute_github_settings (repo_list_path, gh_flag, dry_run) = let
  fun loop (fr: FILEref, acc: batch_result): batch_result = let
    val line = fileref_get_line_string(fr)
    val s = string_trim($UNSAFE.strptr2string(line))
    val () = strptr_free(line)
    val empty = string_is_empty($UNSAFE.strptr2string(s))
  in
    if empty then let val () = strptr_free(s) in acc end
    else let
      val r = apply_github_setting($UNSAFE.strptr2string(s), gh_flag, dry_run)
      val () = strptr_free(s)
    in
      loop(fr, batch_add(acc, r))
    end
  end
  val f = fileref_open_opt(repo_list_path, file_mode_r)
in
  case+ f of
  | ~Some_vt(fr) => let
      val acc0 = empty_batch("github-settings")
      val res = loop(fr, acc0)
      val () = fileref_close(fr)
    in
      res
    end
  | ~None_vt() => @{
      success_count = 0, failure_count = 1, skipped_count = 0,
      message = "github-settings: repo list not readable" }
end
