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

#define ATS_DYNLOADFLAG 0 // L5 link-completeness: self-contained static-lib TU; sound here (no effectful top-level vals), no runtime dynload needed
#include "share/atspre_define.hats"
#include "share/atspre_staload.hats"

staload "operations/types.sats"
staload "operations/effects.sats"
staload "utils/string_utils.sats"
staload "operations/git_sync.sats"   (* self: bind implements for patscc *)

(* String/effect ownership goes through the single audited boundaries in
** utils/string_utils ($UNSAFE-confined) and effects.sys_run_owned. This
** module contains NO `$UNSAFE`. *)

(* int -> owned Strptr1 (delegates to verified tostring_int). *)
fn istr (n: int): Strptr1 = tostring_int(n)

implement find_git_repo_count (base_dir, max_depth) = let
  (* find <base> -maxdepth <d> -type d -name .git | wc -l *)
  val c0 = string_append("find ", base_dir)
  val c1 = strptr_append_str(c0, " -maxdepth ")
  val c2 = strptr_append_strptr(c1, istr(max_depth))
  val c3 = strptr_append_str(c2, " -type d -name .git 2>/dev/null | wc -l > /tmp/.rb56_count")
  val rc = sys_run_owned(c3)
in
  if ~wexit_ok(rc) then ~1
  else let
    val f = fileref_open_opt("/tmp/.rb56_count", file_mode_r)
  in
    case+ f of
    | ~Some_vt(fr) => let
        val line = fileref_get_line_string(fr)
        val () = fileref_close(fr)
        val n = strptr_parse_int_free(strptr_trim_free(line))
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
    val q1 = strptr_append_str(q0, " -maxdepth ")
    val q2 = strptr_append_strptr(q1, ds)
    val q3 = strptr_append_str(q2, " -type d -name .git 2>/dev/null | sed 's@/.git$@@' | xargs -P ")
    val q4 = strptr_append_strptr(q3, pj)
    val q5 = strptr_append_str(q4, " -I R sh -c 'cd R && git add -A && git commit -m \"")
    val q6 = strptr_append_str(q5, commit_msg)
    val q7 = strptr_append_str(q6, "\" && git push && echo R >> /tmp/.rb56_ok || echo R >> /tmp/.rb56_bad'")
    val ok = wexit_ok(sys_run_owned(q7))
  in
    if ok then @{
      success_count = n, failure_count = 0, skipped_count = 0,
      message = "git-sync: pipeline completed (see /tmp/.rb56_ok)" }
    else @{
      success_count = 0, failure_count = n, skipped_count = 0,
      message = "git-sync: pipeline reported failures (see /tmp/.rb56_bad)" }
  end
end
