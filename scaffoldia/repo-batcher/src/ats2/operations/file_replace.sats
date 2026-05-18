(*
** SPDX-License-Identifier: PMPL-1.0-or-later
**
** File-replace operation - INTERFACE (real Postiats 0.4.2)
**
** HONESTY MODEL: copying a replacement file over every match across a
** tree is a filesystem effect, run as a documented shell `find ... |
** xargs cp` pipeline via the verified effects layer. dry_run only
** lists matches. The prior fictional version used non-typechecking
** `+`-string code and `staload` of a .dats.
*)

staload "operations/types.sats"

(* Overwrite every file under base_dir (depth<=max_depth) whose name
** matches `pattern` with the contents of `replacement`.
** backup=true snapshots matches into backup_dir first. *)
fun execute_file_replace
  ( pattern: string
  , replacement: string
  , base_dir: string
  , max_depth: int
  , backup: bool
  , dry_run: bool
  ): batch_result
