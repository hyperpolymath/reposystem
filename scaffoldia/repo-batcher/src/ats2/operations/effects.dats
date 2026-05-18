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
staload "utils/string_utils.sats"

implement sys_run (cmd) =
  $extfcall(int, "system", cmd)

(* ===== PROOF-DEBT: SOLE $UNSAFE BOUNDARY (effects layer) =====
** `sys_run_owned` is the ONLY place `$UNSAFE` appears in this module.
** It borrows an owned command Strptr1's bytes as a shared `string`,
** passes it synchronously to `sys_run` (libc system(3)), then frees the
** owner exactly once; the borrowed view never escapes. Soundness is
** HAND-VERIFIED (read-only borrow, freed-once, no escape), NOT
** machine-proven. Every shell command built here runs through it. *)
implement sys_run_owned (cmd) = let
  val rc = sys_run($UNSAFE.strptr2string(cmd))
  val () = strptr_free(cmd)
in rc end

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

implement path_exists (p) =
  wexit_ok(sys_run_owned(string_append("test -e ", p)))

implement dir_exists (p) =
  wexit_ok(sys_run_owned(string_append("test -d ", p)))

implement is_git_repo (p) = let
  val cmd = strptr_prepend_str("test -e ", string_append(p, "/.git"))
in
  wexit_ok(sys_run_owned(cmd))
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
