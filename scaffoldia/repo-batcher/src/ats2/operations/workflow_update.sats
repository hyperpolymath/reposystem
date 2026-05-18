(*
** SPDX-License-Identifier: PMPL-1.0-or-later
**
** Workflow-update operation - INTERFACE (real Postiats 0.4.2)
**
** HONESTY MODEL: replacing a CI workflow file across repos is a
** filesystem effect run as a documented shell pipeline via the
** verified effects layer. dry_run only lists target paths.
*)

staload "operations/types.sats"

(* Copy `workflow_src` to <repo>/.github/workflows/<workflow_name> for
** every git repo under base_dir (depth<=max_depth). *)
fun execute_workflow_update
  ( workflow_src: string
  , workflow_name: string
  , base_dir: string
  , max_depth: int
  , dry_run: bool
  ): batch_result
