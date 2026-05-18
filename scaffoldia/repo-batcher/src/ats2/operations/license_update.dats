(*
** SPDX-License-Identifier: PMPL-1.0-or-later
**
** License-update operation - IMPLEMENTATION (real Postiats 0.4.2)
**
** CANONICAL BUILD: from src/ats2 with `-IATS .`.
** SPDX ids validated via is_valid_spdx (Layer 2/3) before any write.
** Shell strings assembled with string_append and freed once; effects
** via the verified effects layer. No `+`, no `prefix` identifier.
*)

#include "share/atspre_define.hats"
#include "share/atspre_staload.hats"

staload "operations/types.sats"
staload "operations/effects.sats"
staload "utils/string_utils.sats"
staload "operations/license_update.sats"   (* self: bind implements for patscc *)

fn app (acc: Strptr1, tail: string): Strptr1 = let
  val r = string_append($UNSAFE.strptr2string(acc), tail)
  val () = strptr_free(acc)
in
  r
end

fn istr (n: int): Strptr1 = tostring_int(n)

implement update_license_in_repo
  (repo, old_spdx, new_spdx, backup, backup_dir, dry_run) =
  if ~is_valid_spdx(old_spdx) then @{
    success_count = 0, failure_count = 1, skipped_count = 0,
    message = "license-update: invalid old SPDX id" }
  else if ~is_valid_spdx(new_spdx) then @{
    success_count = 0, failure_count = 1, skipped_count = 0,
    message = "license-update: invalid new SPDX id" }
  else let
    (* Optional backup: tar the repo into backup_dir. *)
    val () =
      if backup then let
        val b0 = string_append("mkdir -p ", backup_dir)
        val br = sys_run($UNSAFE.strptr2string(b0))
        val () = strptr_free(b0)
        val t0 = string_append("tar czf ", backup_dir)
        val t1 = app(t0, "/backup.tgz ")
        val t2 = app(t1, repo)
        val tr = sys_run($UNSAFE.strptr2string(t2))
        val () = strptr_free(t2)
      in
        ignoret(br); ignoret(tr)
      end
      else ()
  in
    if dry_run then let
      (* Non-mutating: just list files that would change. *)
      val d0 = string_append("grep -rl 'SPDX-License-Identifier: ", repo)
      val d1 = app(d0, "' ")
      val d2 = app(d1, repo)
      val d3 = app(d2, " 2>/dev/null >/dev/null")
      val rc = sys_run($UNSAFE.strptr2string(d3))
      val () = strptr_free(d3)
    in
      ignoret(rc);
      @{ success_count = 0, failure_count = 0, skipped_count = 1,
         message = "license-update: dry-run, no files mutated" }
    end
    else let
      (* sed -i over files containing the old id. *)
      val s0 = string_append(
        "grep -rl 'SPDX-License-Identifier: ", old_spdx)
      val s1 = app(s0, "' ")
      val s2 = app(s1, repo)
      val s3 = app(s2, " 2>/dev/null | xargs -r sed -i 's@SPDX-License-Identifier: ")
      val s4 = app(s3, old_spdx)
      val s5 = app(s4, "@SPDX-License-Identifier: ")
      val s6 = app(s5, new_spdx)
      val s7 = app(s6, "@g'")
      val rc = sys_run($UNSAFE.strptr2string(s7))
      val () = strptr_free(s7)
    in
      if wexit_ok(rc) then @{
        success_count = 1, failure_count = 0, skipped_count = 0,
        message = "license-update: headers rewritten" }
      else @{
        success_count = 0, failure_count = 1, skipped_count = 0,
        message = "license-update: sed pipeline failed" }
    end
  end

implement execute_license_update
  (old_spdx, new_spdx, base_dir, max_depth, backup, dry_run) =
  if ~is_valid_spdx(old_spdx) orelse ~is_valid_spdx(new_spdx) then @{
    success_count = 0, failure_count = 1, skipped_count = 0,
    message = "license-update: invalid SPDX id (no files touched)" }
  else if dry_run then let
    (* Non-mutating discovery walk. Build + run fully in this branch so
    ** no Strptr1 crosses an if-boundary (keeps linear typing simple). *)
    val ds = istr(max_depth)
    val p0 = string_append("find ", base_dir)
    val p1 = app(p0, " -maxdepth ")
    val p2 = app(p1, $UNSAFE.strptr2string(ds))
    val () = strptr_free(ds)
    val p3 = app(p2, " -type d -name .git 2>/dev/null | sed 's@/.git$@@' >/dev/null")
    val rc = sys_run($UNSAFE.strptr2string(p3))
    val () = strptr_free(p3)
  in
    ignoret(rc);
    @{ success_count = 0, failure_count = 0, skipped_count = 1,
       message = "license-update: dry-run over discovered repos" }
  end
  else let
    (* One pipeline over discovered repos; per-repo tallies in files. *)
    val ds = istr(max_depth)
    val p0 = string_append(
      "rm -f /tmp/.rb56_lu_ok /tmp/.rb56_lu_bad; find ", base_dir)
    val p1 = app(p0, " -maxdepth ")
    val p2 = app(p1, $UNSAFE.strptr2string(ds))
    val () = strptr_free(ds)
    val p3 = app(p2, " -type d -name .git 2>/dev/null | sed 's@/.git$@@' | while read R; do grep -rl 'SPDX-License-Identifier: ")
    val a1 = app(p3, old_spdx)
    val a2 = app(a1, "' \"$R\" 2>/dev/null | xargs -r sed -i 's@SPDX-License-Identifier: ")
    val a3 = app(a2, old_spdx)
    val a4 = app(a3, "@SPDX-License-Identifier: ")
    val a5 = app(a4, new_spdx)
    val a6 = app(a5, "@g' && echo \"$R\" >> /tmp/.rb56_lu_ok || echo \"$R\" >> /tmp/.rb56_lu_bad; done")
    val rc = sys_run($UNSAFE.strptr2string(a6))
    val () = strptr_free(a6)
  in
    if wexit_ok(rc) then @{
      success_count = 1, failure_count = 0, skipped_count = 0,
      message = "license-update: completed (see /tmp/.rb56_lu_ok)" }
    else @{
      success_count = 0, failure_count = 1, skipped_count = 0,
      message = "license-update: failures (see /tmp/.rb56_lu_bad)" }
  end
