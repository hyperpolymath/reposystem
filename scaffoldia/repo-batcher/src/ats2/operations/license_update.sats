(*
** SPDX-License-Identifier: PMPL-1.0-or-later
**
** License-update operation - INTERFACE (real Postiats 0.4.2)
**
** HONESTY MODEL: rewriting SPDX headers across a tree is a filesystem
** effect. We use a single documented `grep -rl` + `sed -i` shell
** pipeline per repo via the verified effects layer rather than a
** fabricated pure file walk. SPDX ids are validated (Layer 2/3) before
** any mutation; an invalid id short-circuits with a failure result and
** performs no writes. dry_run substitutes a non-mutating `grep -rl`.
*)

staload "operations/types.sats"

(* Replace old_spdx -> new_spdx in source headers under `repo`.
** Returns a one-repo batch_result. backup=true tars the repo first. *)
fun update_license_in_repo
  ( repo: string
  , old_spdx: string
  , new_spdx: string
  , backup: bool
  , backup_dir: string
  , dry_run: bool
  ): batch_result

(* Discover repos under base_dir (shell find) and apply the update to
** each via update_license_in_repo, summing the per-repo results. *)
fun execute_license_update
  ( old_spdx: string
  , new_spdx: string
  , base_dir: string
  , max_depth: int
  , backup: bool
  , dry_run: bool
  ): batch_result
