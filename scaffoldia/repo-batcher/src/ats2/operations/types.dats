(*
** SPDX-License-Identifier: PMPL-1.0-or-later
**
** Operation type definitions - IMPLEMENTATION (real Postiats 0.4.2)
**
** CANONICAL BUILD: invoked from src/ats2 root via the Justfile with
** `-IATS .` so that root-relative staload paths resolve regardless of
** the compiler's CWD. Witness abstypes are `assume`d equal to `string`;
** the only constructors are the validators.
*)

#define ATS_DYNLOADFLAG 0 // L5 link-completeness: self-contained static-lib TU; sound here (no effectful top-level vals), no runtime dynload needed
#include "share/atspre_define.hats"
#include "share/atspre_staload.hats"

staload "operations/types.sats"
staload "utils/string_utils.sats"

assume spdx_id         = string
assume nonempty_string = string
assume existing_path   = string
assume git_repo        = string

(* ===== PROOF-DEBT: SOLE $UNSAFE BOUNDARY (types layer) =====
** `system_owned` is the ONLY place `$UNSAFE` appears in this module.
** It borrows an owned command Strptr1's bytes as a shared `string`,
** passes it synchronously to libc system(3) via $extfcall, then frees
** the owner exactly once; the borrowed view never escapes. Soundness
** is HAND-VERIFIED (read-only borrow, freed-once, no escape), NOT
** machine-proven. All command strings reach system(3) only through it. *)
fn system_owned (cmd: Strptr1): int = let
  val rc = $extfcall(int, "system", $UNSAFE.strptr2string(cmd))
  val () = strptr_free(cmd)
in rc end

(* ========== SPDX license set ========== *)
(* Common SPDX identifiers; full list at https://spdx.org/licenses/ *)

fn spdx_list (): List0(string) =
  $list{string}(
    "PMPL-1.0-or-later", "MIT", "Apache-2.0",
    "GPL-3.0-only", "GPL-3.0-or-later",
    "LGPL-3.0-only", "LGPL-3.0-or-later",
    "BSD-2-Clause", "BSD-3-Clause", "ISC",
    "MPL-2.0", "AGPL-3.0-only", "Unlicense", "0BSD"
  )

implement is_valid_spdx(s) = let
  fun mem (xs: List0(string)): bool =
    case+ xs of
    | list_nil() => false
    | list_cons(x, rest) => if x = s then true else mem(rest)
in
  if string_is_empty(s) then false else mem(spdx_list())
end

(* ========== Smart constructors ========== *)

implement validate_spdx_id(s) =
  if is_valid_spdx(s) then Some(s) else None()

implement validate_nonempty(s) =
  if string_is_nonempty(s) then Some(s) else None()

(* Filesystem existence is an EFFECT, not a pure proof. We do not pretend
** otherwise: this calls `test -e` via the shell and trusts its exit code.
** The witness only certifies "test -e succeeded at construction time". *)
implement validate_path_exists(p) = let
  val rc = system_owned(string_append("test -e ", p))
in
  if rc = 0 then Some(p) else None()
end

implement validate_git_repo(p) = let
  val cmd = strptr_prepend_str("test -d ", string_append(p, "/.git"))
  val rc  = system_owned(cmd)
in
  if rc = 0 then Some(p) else None()
end

(* ========== Witness projections ========== *)

implement spdx_unwrap(x)     = x
implement nonempty_unwrap(x) = x
implement path_unwrap(x)     = x
implement gitrepo_unwrap(x)  = x

(* ========== Result helpers ========== *)

implement result_message(r) =
  case+ r of
  | OpSuccess(m) => m
  | OpFailure(m) => m
  | OpSkipped(m) => m

implement result_is_ok(r) =
  case+ r of
  | OpSuccess _ => true
  | _ => false

implement empty_batch(msg) = @{
  success_count = 0,
  failure_count = 0,
  skipped_count = 0,
  message = msg
}

implement batch_add(acc, r) =
  case+ r of
  | OpSuccess _ => @{
      success_count = acc.success_count + 1,
      failure_count = acc.failure_count,
      skipped_count = acc.skipped_count,
      message = acc.message }
  | OpFailure _ => @{
      success_count = acc.success_count,
      failure_count = acc.failure_count + 1,
      skipped_count = acc.skipped_count,
      message = acc.message }
  | OpSkipped _ => @{
      success_count = acc.success_count,
      failure_count = acc.failure_count,
      skipped_count = acc.skipped_count + 1,
      message = acc.message }
