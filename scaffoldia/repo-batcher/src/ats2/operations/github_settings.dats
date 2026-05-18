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

(* ===== PROOF-DEBT: SOLE $UNSAFE BOUNDARY (github_settings layer) =====
** `gh_setting_owned` is the ONLY place `$UNSAFE` appears in this module.
** It borrows an owned repo-name Strptr1 (a trimmed line) as a shared
** `string`, passes it synchronously to `apply_github_setting` (which
** copies it immediately via string_append), then frees the owner
** exactly once; the borrowed view never escapes. Soundness is
** HAND-VERIFIED (read-only borrow, freed-once, no escape), NOT
** machine-proven. All other strings/effects here route through the
** string_utils combinators and sys_run_owned. *)
fn gh_setting_owned
  (s: Strptr1, gh_flag: string, dry_run: bool): operation_result = let
  val r = apply_github_setting($UNSAFE.strptr2string(s), gh_flag, dry_run)
  val () = strptr_free(s)
in r end

implement apply_github_setting (repo, gh_flag, dry_run) = let
  val c0 = string_append("gh repo edit ", repo)
  val c1 = strptr_append_str(c0, " ")
  val c2 = strptr_append_str(c1, gh_flag)
in
  if dry_run then let
    val () = strptr_free(c2)
  in
    OpSkipped("github-settings: dry-run (gh not invoked)")
  end
  else
    if wexit_ok(sys_run_owned(c2))
      then OpSuccess("github-settings: gh repo edit applied")
      else OpFailure("github-settings: gh repo edit failed")
end

implement execute_github_settings (repo_list_path, gh_flag, dry_run) = let
  fun loop (fr: FILEref, acc: batch_result): batch_result = let
    val line = fileref_get_line_string(fr)
    val s = strptr_trim_free(line)
    val empty = strptr_peek_is_empty(s)
  in
    if empty then let val () = strptr_free(s) in acc end
    else
      loop(fr, batch_add(acc, gh_setting_owned(s, gh_flag, dry_run)))
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
