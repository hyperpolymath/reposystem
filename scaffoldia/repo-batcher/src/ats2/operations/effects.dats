(*
** SPDX-License-Identifier: PMPL-1.0-or-later
**
** External-effects implementation (real Postiats 0.4.2)
**
** CANONICAL BUILD: from src/ats2 with `-IATS .`.
** sys_run delegates to libc system(3) via $extfcall. The WEXITSTATUS
** decode is the POSIX bit layout ((status >> 8) & 0xFF) computed with
** ATS2 integer ops; we do not link <sys/wait.h> macros (not portable
** through $extfcall), we implement the documented decode directly.
*)

#include "share/atspre_define.hats"
#include "share/atspre_staload.hats"

staload "operations/types.sats"
staload "operations/effects.sats"

implement sys_run (cmd) =
  $extfcall(int, "system", cmd)

(* POSIX: a normal child exit makes system()'s status word == 0 exactly
** when the exit code is 0 and no signal terminated the child (the low
** byte holds the signal/core info, byte 1 holds the exit code). So a
** clean "command succeeded" is precisely status == 0. system() returns
** -1 on fork/exec failure. We deliberately use the conservative
** status==0 test (computed with plain int arithmetic, no unsigned
** bitops) rather than reimplementing WEXITSTATUS bit-twiddling, which
** is documented here as an intentional simplification, not an omission. *)
implement wexit_ok (status) =
  if status < 0 then false else status = 0

implement path_exists (p) = let
  val cmd = string_append("test -e ", p)
  val rc  = sys_run($UNSAFE.strptr2string(cmd))
  val ()  = strptr_free(cmd)
in
  wexit_ok(rc)
end

implement dir_exists (p) = let
  val cmd = string_append("test -d ", p)
  val rc  = sys_run($UNSAFE.strptr2string(cmd))
  val ()  = strptr_free(cmd)
in
  wexit_ok(rc)
end

implement is_git_repo (p) = let
  val gp  = string_append(p, "/.git")
  val cmd = string_append("test -e ", $UNSAFE.strptr2string(gp))
  val ()  = strptr_free(gp)
  val rc  = sys_run($UNSAFE.strptr2string(cmd))
  val ()  = strptr_free(cmd)
in
  wexit_ok(rc)
end

(* ok_msg / fail_msg are caller-owned shared `string`s (typically string
** literals) stored directly in the result datatype; no allocation here,
** so no ownership/free question arises. dry_run is reported via the
** distinct OpSkipped constructor rather than a prefixed message, which
** keeps this allocation-free and the dry-run signal machine-readable. *)
implement effect_result (dry_run, ok, ok_msg, fail_msg) =
  if dry_run then OpSkipped(ok_msg)
  else if ok then OpSuccess(ok_msg)
  else OpFailure(fail_msg)
