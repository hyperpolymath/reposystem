(*
** SPDX-License-Identifier: PMPL-1.0-or-later
**
** Git batch-sync operation - INTERFACE (real Postiats 0.4.2)
**
** HONESTY MODEL
** -------------
** "Sync N repositories" is irreducibly an external effect (git over a
** working tree). We do NOT model it as a pure fold over a fabricated
** in-memory repo list (the prior fictional version did exactly that
** with non-typechecking `+`-string code). Instead:
**   - repo discovery is a shell `find` whose result COUNT is read back
**     (find_git_repo_count); the count is the only thing we claim,
**   - the sync itself is a single documented shell pipeline executed
**     via the verified operations/effects layer,
**   - the returned batch_result reflects that pipeline's exit status.
** The ATS2 type system guarantees ownership/exhaustiveness here, not
** that git behaved correctly. dry_run never executes mutating git.
*)

staload "operations/types.sats"

(* Number of git repos under base_dir within max_depth (shell `find`,
** counted via `wc -l`). ~1 on discovery failure. *)
fun find_git_repo_count (base_dir: string, max_depth: int): int

(* Run add+commit+push across discovered repos via one shell pipeline.
** parallel_jobs is advisory (passed to xargs -P). dry_run lists only. *)
fun execute_git_sync_operation
  ( base_dir: string
  , max_depth: int
  , commit_msg: string
  , parallel_jobs: int
  , dry_run: bool
  ): batch_result
