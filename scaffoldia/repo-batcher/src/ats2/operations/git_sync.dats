(*
** SPDX-License-Identifier: PMPL-1.0-or-later
**
** Git batch-sync operation - IMPLEMENTATION (real Postiats 0.4.2)
**
** CANONICAL BUILD: from src/ats2 with `-IATS .`.
** All shell strings are assembled with string_append (-> Strptr1) and
** freed exactly once; the transient command string is borrowed by
** sys_run (libc system(3) copies it synchronously) then freed. No `+`
** string operator (not valid ATS2). No identifier named `prefix`
** (reserved keyword). Effects go through the verified effects layer.
*)

#include "share/atspre_define.hats"
#include "share/atspre_staload.hats"

staload "operations/types.sats"
staload "operations/effects.sats"
staload "utils/string_utils.sats"
staload "operations/git_sync.sats"   (* self: bind implements for patscc *)

(* acc:Strptr1 (owned) ++ tail:string -> Strptr1; frees acc. *)
fn app (acc: Strptr1, tail: string): Strptr1 = let
  val r = string_append($UNSAFE.strptr2string(acc), tail)
  val () = strptr_free(acc)
in
  r
end

(* int -> owned Strptr1 (delegates to verified tostring_int). *)
fn istr (n: int): Strptr1 = tostring_int(n)

implement find_git_repo_count (base_dir, max_depth) = let
  (* find <base> -maxdepth <d> -type d -name .git | wc -l *)
  val c0 = string_append("find ", base_dir)
  val c1 = app(c0, " -maxdepth ")
  val ds = istr(max_depth)
  val c2 = app(c1, $UNSAFE.strptr2string(ds))
  val () = strptr_free(ds)
  val c3 = app(c2, " -type d -name .git 2>/dev/null | wc -l > /tmp/.rb56_count")
  val rc = sys_run($UNSAFE.strptr2string(c3))
  val () = strptr_free(c3)
in
  if ~wexit_ok(rc) then ~1
  else let
    val f = fileref_open_opt("/tmp/.rb56_count", file_mode_r)
  in
    case+ f of
    | ~Some_vt(fr) => let
        val line = fileref_get_line_string(fr)
        val () = fileref_close(fr)
        val s = string_trim($UNSAFE.strptr2string(line))
        val () = strptr_free(line)
        val n = g0string2int_int($UNSAFE.strptr2string(s))
        val () = strptr_free(s)
      in
        if n < 0 then 0 else n
      end
    | ~None_vt() => 0
  end
end

implement execute_git_sync_operation
  (base_dir, max_depth, commit_msg, parallel_jobs, dry_run) = let
  val n = find_git_repo_count(base_dir, max_depth)
in
  if n < 0 then @{
    success_count = 0, failure_count = 1, skipped_count = 0,
    message = "git-sync: repo discovery failed" }
  else if dry_run then @{
    success_count = 0, failure_count = 0, skipped_count = n,
    message = "git-sync: dry-run, no repositories mutated" }
  else let
    (* One pipeline: for each .git dir, add+commit (msg)+push, counting
    ** successes by appending to a tally file. parallel_jobs feeds -P. *)
    val pj = istr(if parallel_jobs <= 0 then 1 else parallel_jobs)
    val ds = istr(max_depth)
    val q0 = string_append("rm -f /tmp/.rb56_ok /tmp/.rb56_bad; find ", base_dir)
    val q1 = app(q0, " -maxdepth ")
    val q2 = app(q1, $UNSAFE.strptr2string(ds))
    val () = strptr_free(ds)
    val q3 = app(q2, " -type d -name .git 2>/dev/null | sed 's@/.git$@@' | xargs -P ")
    val q4 = app(q3, $UNSAFE.strptr2string(pj))
    val () = strptr_free(pj)
    val q5 = app(q4, " -I R sh -c 'cd R && git add -A && git commit -m \"")
    val q6 = app(q5, commit_msg)
    val q7 = app(q6, "\" && git push && echo R >> /tmp/.rb56_ok || echo R >> /tmp/.rb56_bad'")
    val rc = sys_run($UNSAFE.strptr2string(q7))
    val () = strptr_free(q7)
    val ok = wexit_ok(rc)
  in
    if ok then @{
      success_count = n, failure_count = 0, skipped_count = 0,
      message = "git-sync: pipeline completed (see /tmp/.rb56_ok)" }
    else @{
      success_count = 0, failure_count = n, skipped_count = 0,
      message = "git-sync: pipeline reported failures (see /tmp/.rb56_bad)" }
  end
end
