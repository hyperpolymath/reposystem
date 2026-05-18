(*
** SPDX-License-Identifier: PMPL-1.0-or-later
**
** SPDX-audit operation - INTERFACE (real Postiats 0.4.2)
**
** HONESTY MODEL: scanning a tree for files missing an SPDX header is a
** filesystem effect (shell `grep -rL`). We report the COUNT of source
** files lacking the header; that count is the only claim. No proof
** that every reported file truly should carry a header.
*)

staload "operations/types.sats"

(* Count source files under base_dir (depth<=max_depth) that do NOT
** contain an "SPDX-License-Identifier:" line. ~1 on scan failure. *)
fun count_missing_spdx (base_dir: string, max_depth: int): int

(* Audit wrapper: returns a batch_result whose failure_count is the
** number of files missing an SPDX header (0 => clean). *)
fun execute_spdx_audit
  (base_dir: string, max_depth: int): batch_result
