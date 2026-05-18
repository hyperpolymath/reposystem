(*
** SPDX-License-Identifier: PMPL-1.0-or-later
**
** Operation type definitions - INTERFACE (real Postiats 0.4.2)
**
** HONESTY NOTE ON THE "PROOF" TYPES
** ---------------------------------
** The prior fictional version declared types indexed by a *string value*
** (e.g. `spdx_id(s:string)`). Postiats `string(n)` is indexed by LENGTH
** (an int sort); there is no `string` index sort, so a value-indexed
** dependent witness is NOT expressible in real Postiats 0.4.2 and was
** never sound.
**
** What IS soundly established here: each witness is an `abstype` whose
** representation is hidden. The ONLY way to obtain one is via the
** corresponding `validate_*` smart constructor, which performs the runtime
** check and returns `None` on failure. So possession of an `spdx_id`
** value is a machine-enforced certificate that "this string passed
** is_valid_spdx at construction time" — a constructor-controlled
** invariant, not a dependent-type theorem. We do not claim more.
*)

(* ========== Validated-string witnesses (opaque) ========== *)

abstype spdx_id       = string   (* constructed only by validate_spdx_id   *)
abstype nonempty_string = string (* constructed only by validate_nonempty  *)
abstype existing_path = string   (* constructed only by validate_path_exists*)
abstype git_repo      = string   (* constructed only by validate_git_repo  *)

(* ========== Repository target ========== *)

datatype repo_target =
  | RepoList      of List0(string)
  | RepoFile      of string
  | RepoPattern   of string
  | RepoDirectory of string

(* ========== Operation result ========== *)

datatype operation_result =
  | OpSuccess of string
  | OpFailure of string
  | OpSkipped of string

datatype backup_policy =
  | NoBackup
  | RequireBackup of string
  | AutoBackup

datatype operation_mode =
  | DryRun
  | Execute
  | Interactive

(* ========== C-marshallable batch result ========== *)
(* Plain ints (no dependent refinement claimed) so it crosses the C ABI. *)

typedef batch_result = @{
  success_count = int,
  failure_count = int,
  skipped_count = int,
  message       = string
}

(* ========== Smart constructors / validators ========== *)

fun is_valid_spdx (s: string): bool

fun validate_spdx_id    (s: string): Option(spdx_id)
fun validate_nonempty   (s: string): Option(nonempty_string)
fun validate_path_exists(p: string): Option(existing_path)
fun validate_git_repo   (p: string): Option(git_repo)

(* Witness projections (safe: the abstype was checked at construction). *)
fun spdx_unwrap     (x: spdx_id): string
fun nonempty_unwrap (x: nonempty_string): string
fun path_unwrap     (x: existing_path): string
fun gitrepo_unwrap  (x: git_repo): string

(* ========== Result helpers ========== *)

fun result_message (r: operation_result): string
fun result_is_ok   (r: operation_result): bool
fun empty_batch    (msg: string): batch_result
fun batch_add      (acc: batch_result, r: operation_result): batch_result
