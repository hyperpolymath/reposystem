(*
** SPDX-License-Identifier: PMPL-1.0-or-later
**
** C FFI Exports
** Exports ATS2 functions to C for V interop
*)

#include "share/atspre_define.hats"
#include "share/atspre_staload.hats"

staload "../operations/types.dats"
staload "../operations/license_update.dats"
staload "../operations/git_sync.dats"
staload "../validation/spdx.dats"

(* ========== Type Marshalling ========== *)

(*
** C-compatible result structure
*)
typedef c_operation_result = @{
  status = int,     // 0=success, 1=failure, 2=skipped
  message = string
}

(*
** C-compatible batch result structure
*)
typedef c_batch_result = @{
  success_count = int,
  failure_count = int,
  skipped_count = int,
  message = string
}

(*
** Converts operation_result to C-compatible structure
*)
fun operation_result_to_c(result: operation_result): c_operation_result =
  case+ result of
  | OpSuccess(msg) => @{ status = 0, message = msg }
  | OpFailure(msg) => @{ status = 1, message = msg }
  | OpSkipped(msg) => @{ status = 2, message = msg }

(*
** Converts batch_result to C-compatible structure
*)
fun batch_result_to_c(result: batch_result): c_batch_result = @{
  success_count = result.success_count,
  failure_count = result.failure_count,
  skipped_count = result.skipped_count,
  message = "Batch operation completed"
}

(* ========== Exported C Functions ========== *)

(*
** Validates SPDX identifier
** Returns 1 if valid, 0 if invalid
*)
extern
fun c_validate_spdx(license: string): int = "ext#"
implement c_validate_spdx(license) =
  if is_valid_spdx(license) then 1 else 0

(*
** Performs license update operation
** Returns C-compatible batch result
**
** Parameters:
**   old_license: Old SPDX identifier
**   new_license: New SPDX identifier
**   base_dir: Base directory to scan
**   max_depth: Maximum recursion depth
**   dry_run: 1 for dry-run, 0 for real
**   backup: 1 to create backups, 0 to skip
*)
extern
fun c_license_update(
  old_license: string,
  new_license: string,
  base_dir: string,
  max_depth: int,
  dry_run: int,
  backup: int
): c_batch_result = "ext#"

implement c_license_update(
  old_license,
  new_license,
  base_dir,
  max_depth,
  dry_run,
  backup
) = let
  // Validate SPDX identifiers
  val old_valid = is_valid_spdx(old_license)
  val new_valid = is_valid_spdx(new_license)
in
  if ~old_valid then
    @{
      success_count = 0,
      failure_count = 1,
      skipped_count = 0,
      message = "Invalid old license: " + old_license
    }
  else if ~new_valid then
    @{
      success_count = 0,
      failure_count = 1,
      skipped_count = 0,
      message = "Invalid new license: " + new_license
    }
  else let
    // Find repositories
    val repos = find_git_repos(base_dir, max_depth)

    // Process each repository
    val do_dry_run = dry_run = 1
    val do_backup = backup = 1
    val backup_dir = "/tmp/repo-batcher-backups"

    fun process_all(
      repos: List0(string),
      total_success: int,
      total_failure: int,
      total_skipped: int
    ): @(int, int, int) =
      case+ repos of
      | list_nil() => @(total_success, total_failure, total_skipped)
      | list_cons(repo, rest) => let
          val result = update_license_in_repo(
            repo,
            old_license,
            new_license,
            do_backup,
            backup_dir,
            do_dry_run
          )
        in
          process_all(
            rest,
            total_success + result.success_count,
            total_failure + result.failure_count,
            total_skipped + result.skipped_count
          )
        end

    val @(s, f, sk) = process_all(repos, 0, 0, 0)
  in
    @{
      success_count = s,
      failure_count = f,
      skipped_count = sk,
      message = "License update completed"
    }
  end
end

(*
** Performs git sync operation
** Returns C-compatible batch result
**
** Parameters:
**   base_dir: Base directory to scan
**   max_depth: Maximum recursion depth
**   commit_msg: Commit message
**   parallel_jobs: Number of parallel jobs (handled in V)
**   dry_run: 1 for dry-run, 0 for real
*)
extern
fun c_git_sync(
  base_dir: string,
  max_depth: int,
  commit_msg: string,
  parallel_jobs: int,
  dry_run: int
): c_batch_result = "ext#"

implement c_git_sync(
  base_dir,
  max_depth,
  commit_msg,
  parallel_jobs,
  dry_run
) = let
  val do_dry_run = dry_run = 1
  val result = execute_git_sync_operation(
    base_dir,
    max_depth,
    commit_msg,
    parallel_jobs,
    do_dry_run
  )
in
  batch_result_to_c(result)
end

(*
** Performs file replace operation
** Returns C-compatible batch result
**
** Parameters:
**   pattern: File pattern to match
**   replacement: Path to replacement file
**   base_dir: Base directory to scan
**   max_depth: Maximum recursion depth
**   dry_run: 1 for dry-run, 0 for real
**   backup: 1 to create backups, 0 to skip
*)
extern
fun c_file_replace(
  pattern: string,
  replacement: string,
  base_dir: string,
  max_depth: int,
  dry_run: int,
  backup: int
): c_batch_result = "ext#"

implement c_file_replace(
  pattern,
  replacement,
  base_dir,
  max_depth,
  dry_run,
  backup
) = let
  // TODO: Implement file replace operation
in
  @{
    success_count = 0,
    failure_count = 0,
    skipped_count = 0,
    message = "File replace not yet implemented"
  }
end

(*
** Gets version string
*)
extern
fun c_get_version(): string = "ext#"
implement c_get_version() = "0.1.0"
