(*
** SPDX-License-Identifier: PMPL-1.0-or-later
**
** C FFI export surface - Layer 5 (real Postiats 0.4.2)
**
** CANONICAL BUILD: from src/ats2 with `-IATS .`. This is the ONLY
** boundary the Zig CLI links against. Every export is a real
**   extern fun c_... (...) : ... = "ext#c_..."
** so `patscc -c` emits a C symbol `c_...`. Strings cross as ATS
** `string` (NUL-terminated char*, ABI-compatible with C `const char*`).
** Results cross as flat int-only structs (no dependent refinement
** claimed across the C ABI). Operations staload their .sats INTERFACES
** only (never a .dats — that was prior fiction); implementations are
** linked from the per-module objects. No `+`, no `prefix` identifier.
*)

#define ATS_DYNLOADFLAG 0 // L5 link-completeness: self-contained static-lib TU; sound here (no effectful top-level vals), no runtime dynload needed
#include "share/atspre_define.hats"
#include "share/atspre_staload.hats"

staload "operations/types.sats"
staload "operations/git_sync.sats"
staload "operations/license_update.sats"
staload "operations/file_replace.sats"
staload "operations/spdx_audit.sats"

(* ---- C-ABI result struct (flat ints + message pointer) ---- *)

typedef c_batch_result = @{
  success_count = int,
  failure_count = int,
  skipped_count = int,
  message       = string
}

fn to_c (b: batch_result): c_batch_result = @{
  success_count = b.success_count,
  failure_count = b.failure_count,
  skipped_count = b.skipped_count,
  message       = b.message
}

(* ---- Version ---- *)

extern fun c_get_version (): string = "ext#c_get_version"
implement c_get_version () = "0.1.0"

(* ---- SPDX validation (Layer 2/3) ---- *)

extern fun c_validate_spdx (license: string): int = "ext#c_validate_spdx"
implement c_validate_spdx (license) =
  if is_valid_spdx(license) then 1 else 0

(* ---- git-sync (Layer 4) ---- *)

extern fun c_git_sync
  ( base_dir: string
  , max_depth: int
  , commit_msg: string
  , parallel_jobs: int
  , dry_run: int
  ): c_batch_result = "ext#c_git_sync"
implement c_git_sync (base_dir, max_depth, commit_msg, parallel_jobs, dry_run) =
  to_c(execute_git_sync_operation
         (base_dir, max_depth, commit_msg, parallel_jobs, dry_run = 1))

(* ---- license-update (Layer 4) ---- *)

extern fun c_license_update
  ( old_license: string
  , new_license: string
  , base_dir: string
  , max_depth: int
  , dry_run: int
  , backup: int
  ): c_batch_result = "ext#c_license_update"
implement c_license_update
  (old_license, new_license, base_dir, max_depth, dry_run, backup) =
  to_c(execute_license_update
         (old_license, new_license, base_dir, max_depth,
          backup = 1, dry_run = 1))

(* ---- file-replace (Layer 4) ---- *)

extern fun c_file_replace
  ( pattern: string
  , replacement: string
  , base_dir: string
  , max_depth: int
  , dry_run: int
  , backup: int
  ): c_batch_result = "ext#c_file_replace"
implement c_file_replace
  (pattern, replacement, base_dir, max_depth, dry_run, backup) =
  to_c(execute_file_replace
         (pattern, replacement, base_dir, max_depth,
          backup = 1, dry_run = 1))

(* ---- spdx-audit (Layer 4) ---- *)

extern fun c_spdx_audit
  (base_dir: string, max_depth: int): c_batch_result = "ext#c_spdx_audit"
implement c_spdx_audit (base_dir, max_depth) =
  to_c(execute_spdx_audit(base_dir, max_depth))
