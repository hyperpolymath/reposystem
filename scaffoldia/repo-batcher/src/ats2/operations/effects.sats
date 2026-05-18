(*
** SPDX-License-Identifier: PMPL-1.0-or-later
**
** External-effects interface (real Postiats 0.4.2)
**
** HONESTY NOTE
** ------------
** Every function here is an EFFECT, not a pure proof. The repo-batcher
** drives git/gh/filesystem mutations that cannot be modelled as total
** pure functions. We do not pretend otherwise: each effect is declared
** as an opaque action whose only guarantee is "the underlying C call
** ran and we report its exit/return faithfully". The ATS2 type system
** here buys us:
**   - exhaustive handling of the three-way operation_result outcome,
**   - explicit ownership of every allocated string (Strptr1, freed once),
**   - no implicit GC and no value-indexed dependent fiction.
** It does NOT buy us a proof that git did the right thing; that is
** delegated honestly to the external process and its exit code.
**
** All shell strings are built with `string_append` (Layer-1 idiom) and
** freed via `strptr_free` exactly once by the caller of the builder.
*)

staload "operations/types.sats"

(* ---- Raw process effect (documented extern C) ---- *)

(* Runs `cmd` via libc system(3). Returns the raw status word; callers
** normalise with `wexit_ok`. This is the ONLY shell entry point. *)
fun sys_run (cmd: string): int

(* True iff a system(3) status word denotes child exit code 0. *)
fun wexit_ok (status: int): bool

(* ---- Filesystem predicates (effectful, trust the OS) ---- *)

fun path_exists (p: string): bool
fun dir_exists  (p: string): bool
fun is_git_repo (p: string): bool

(* ---- Outcome smart helpers ---- *)

(* Map a normalised shell success/failure to an operation_result with a
** caller-supplied human message. dry_run short-circuits to OpSkipped. *)
fun effect_result
  (dry_run: bool, ok: bool, ok_msg: string, fail_msg: string)
  : operation_result
