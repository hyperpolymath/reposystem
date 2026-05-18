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

#define ATS_DYNLOADFLAG 0 // L5 link-completeness: self-contained static-lib TU; sound here (no effectful top-level vals), no runtime dynload needed
#include "share/atspre_define.hats"
#include "share/atspre_staload.hats"

staload "operations/types.sats"
staload "operations/effects.sats"
staload "utils/string_utils.sats"
staload "operations/license_update.sats"   (* self: bind implements for patscc *)

(* No `$UNSAFE` in this module: ownership goes through the single
** audited boundaries (string_utils combinators, sys_run_owned). *)

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
        val br = sys_run_owned(string_append("mkdir -p ", backup_dir))
        val t0 = string_append("tar czf ", backup_dir)
        val t1 = strptr_append_str(t0, "/backup.tgz ")
        val t2 = strptr_append_str(t1, repo)
        val tr = sys_run_owned(t2)
      in
        ignoret(br); ignoret(tr)
      end
      else ()
  in
    if dry_run then let
      (* Non-mutating: just list files that would change. *)
      val d0 = string_append("grep -rl 'SPDX-License-Identifier: ", repo)
      val d1 = strptr_append_str(d0, "' ")
      val d2 = strptr_append_str(d1, repo)
      val d3 = strptr_append_str(d2, " 2>/dev/null >/dev/null")
      val rc = sys_run_owned(d3)
    in
      ignoret(rc);
      @{ success_count = 0, failure_count = 0, skipped_count = 1,
         message = "license-update: dry-run, no files mutated" }
    end
    else let
      (* sed -i over files containing the old id. *)
      val s0 = string_append(
        "grep -rl 'SPDX-License-Identifier: ", old_spdx)
      val s1 = strptr_append_str(s0, "' ")
      val s2 = strptr_append_str(s1, repo)
      val s3 = strptr_append_str(s2, " 2>/dev/null | xargs -r sed -i 's@SPDX-License-Identifier: ")
      val s4 = strptr_append_str(s3, old_spdx)
      val s5 = strptr_append_str(s4, "@SPDX-License-Identifier: ")
      val s6 = strptr_append_str(s5, new_spdx)
      val s7 = strptr_append_str(s6, "@g'")
      val rc = sys_run_owned(s7)
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
    val p0 = string_append("find ", base_dir)
    val p1 = strptr_append_str(p0, " -maxdepth ")
    val p2 = strptr_append_strptr(p1, istr(max_depth))
    val p3 = strptr_append_str(p2, " -type d -name .git 2>/dev/null | sed 's@/.git$@@' >/dev/null")
    val rc = sys_run_owned(p3)
  in
    ignoret(rc);
    @{ success_count = 0, failure_count = 0, skipped_count = 1,
       message = "license-update: dry-run over discovered repos" }
  end
  else let
    (* One pipeline over discovered repos; per-repo tallies in files. *)
    val p0 = string_append(
      "rm -f /tmp/.rb56_lu_ok /tmp/.rb56_lu_bad; find ", base_dir)
    val p1 = strptr_append_str(p0, " -maxdepth ")
    val p2 = strptr_append_strptr(p1, istr(max_depth))
    val p3 = strptr_append_str(p2, " -type d -name .git 2>/dev/null | sed 's@/.git$@@' | while read R; do grep -rl 'SPDX-License-Identifier: ")
    val a1 = strptr_append_str(p3, old_spdx)
    val a2 = strptr_append_str(a1, "' \"$R\" 2>/dev/null | xargs -r sed -i 's@SPDX-License-Identifier: ")
    val a3 = strptr_append_str(a2, old_spdx)
    val a4 = strptr_append_str(a3, "@SPDX-License-Identifier: ")
    val a5 = strptr_append_str(a4, new_spdx)
    val a6 = strptr_append_str(a5, "@g' && echo \"$R\" >> /tmp/.rb56_lu_ok || echo \"$R\" >> /tmp/.rb56_lu_bad; done")
    val rc = sys_run_owned(a6)
  in
    if wexit_ok(rc) then @{
      success_count = 1, failure_count = 0, skipped_count = 0,
      message = "license-update: completed (see /tmp/.rb56_lu_ok)" }
    else @{
      success_count = 0, failure_count = 1, skipped_count = 0,
      message = "license-update: failures (see /tmp/.rb56_lu_bad)" }
  end
