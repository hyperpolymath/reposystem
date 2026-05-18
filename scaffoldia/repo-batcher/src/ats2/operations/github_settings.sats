(*
** SPDX-License-Identifier: PMPL-1.0-or-later
**
** GitHub repo-settings operation - INTERFACE (real Postiats 0.4.2)
**
** HONESTY MODEL: applying repo settings is an external API effect run
** via the `gh` CLI through the verified effects layer. We claim only
** that `gh` was invoked and report its exit. No network/API behaviour
** is proven. dry_run prints the planned `gh` command without running
** it against the API.
*)

staload "operations/types.sats"

(* Apply a single `gh repo edit` flag (e.g. "--enable-issues=false")
** to `repo` (owner/name). *)
fun apply_github_setting
  (repo: string, gh_flag: string, dry_run: bool): operation_result

(* Apply one flag across every repo listed (newline-separated) in the
** file at repo_list_path. *)
fun execute_github_settings
  ( repo_list_path: string
  , gh_flag: string
  , dry_run: bool
  ): batch_result
