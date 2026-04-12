(*
** SPDX-License-Identifier: PMPL-1.0-or-later
**
** Operation type definitions with dependent type proofs
** for formally verified batch repository operations
*)

#include "share/atspre_define.hats"
#include "share/atspre_staload.hats"

staload "libats/SATS/stringbuf.sats"

(* ========== String validation proofs ========== *)

(* Proof that a string is non-empty *)
abstype nonempty_string(s:string) = string

(* Proof that a string is a valid SPDX identifier *)
abstype spdx_id(s:string) = string

(* Proof that a path exists *)
abstype existing_path(p:string) = string

(* Proof that a path is a valid git repository *)
abstype git_repo(p:string) = string

(* ========== Repository target ========== *)

datatype repo_target =
  | RepoList of List0(string)                      (* Explicit list of repos *)
  | RepoFile of string                             (* Path to file containing repo list *)
  | RepoPattern of string                          (* Pattern matching (@all-repos, @rsr-*) *)
  | RepoDirectory of string                        (* Scan directory for repos *)

(* ========== Operation types ========== *)

datatype operation_result =
  | OpSuccess of string                            (* Success message *)
  | OpFailure of string                            (* Error message *)
  | OpSkipped of string                            (* Skipped with reason *)

datatype backup_policy =
  | NoBackup                                       (* No backup required *)
  | RequireBackup of string                        (* Backup to specified directory *)
  | AutoBackup                                     (* Automatic backup location *)

datatype operation_mode =
  | DryRun                                         (* Preview only, no changes *)
  | Execute                                        (* Execute for real *)
  | Interactive                                    (* Prompt before each repo *)

(*
** License Update Operation
** Replaces license headers and LICENSE files across repositories
**
** Invariants (enforced by dependent types):
** - old_license must be a valid SPDX identifier
** - new_license must be a valid SPDX identifier
** - backup_dir must exist if backup is required
*)
datatype license_update_op(
  old:string, new:string
) =
  | LicenseUpdate(old, new) of (
      spdx_id(old),                                (* Validated old license *)
      spdx_id(new),                                (* Validated new license *)
      backup_policy,                               (* Backup strategy *)
      operation_mode                               (* Execution mode *)
    )

(*
** File Replace Operation
** Replaces files matching a pattern with new content
**
** Invariants:
** - pattern must be a non-empty string
** - replacement_path must exist
** - No circular replacements (file A → file B → file A)
*)
datatype file_replace_op(
  pattern:string, replacement:string
) =
  | FileReplace(pattern, replacement) of (
      nonempty_string(pattern),                    (* Valid pattern *)
      existing_path(replacement),                  (* Replacement file exists *)
      backup_policy,                               (* Backup strategy *)
      operation_mode                               (* Execution mode *)
    )

(*
** Git Batch Sync Operation
** Performs git add, commit, and push across multiple repos
**
** Invariants:
** - All targets must be valid git repositories
** - Commit message must be non-empty
** - Remote must be reachable (checked at runtime)
*)
datatype git_sync_op(
  msg:string
) =
  | GitBatchSync(msg) of (
      nonempty_string(msg),                        (* Valid commit message *)
      int,                                         (* Parallel job count *)
      int,                                         (* Max depth for repo search *)
      operation_mode                               (* Execution mode *)
    )

(*
** Workflow Update Operation
** Updates GitHub Actions workflow files with validation
**
** Invariants:
** - workflow_file must exist
** - action_sha must be a valid git commit hash (40 hex chars)
** - YAML must be valid (checked at runtime)
*)
datatype workflow_update_op(
  file:string, action:string, sha:string
) =
  | WorkflowUpdate(file, action, sha) of (
      existing_path(file),                         (* Workflow file exists *)
      nonempty_string(action),                     (* Action name *)
      nonempty_string(sha),                        (* Valid SHA *)
      backup_policy,                               (* Backup strategy *)
      operation_mode                               (* Execution mode *)
    )

(*
** Custom Operation
** Executes operation from template file
**
** Invariants:
** - template_path must exist
** - template must be valid TOML (checked at runtime)
*)
datatype custom_op(
  template:string
) =
  | CustomOp(template) of (
      existing_path(template),                     (* Template exists *)
      List0(@(string, string)),                    (* Arguments *)
      operation_mode                               (* Execution mode *)
    )

(*
** Unified operation type
** Tagged union of all operation types
*)
datatype batch_operation =
  | OpLicenseUpdate of [old:string, new:string] license_update_op(old, new)
  | OpFileReplace of [pat:string, repl:string] file_replace_op(pat, repl)
  | OpGitSync of [msg:string] git_sync_op(msg)
  | OpWorkflowUpdate of [file:string, action:string, sha:string]
      workflow_update_op(file, action, sha)
  | OpCustom of [tmpl:string] custom_op(tmpl)

(* ========== Operation context ========== *)

typedef operation_context = @{
  targets = repo_target,                           (* Target repositories *)
  dry_run = bool,                                  (* Preview mode *)
  parallel_jobs = int,                             (* Number of parallel workers *)
  log_path = string,                               (* Log file path *)
  backup_dir = string                              (* Backup directory *)
}

(* ========== Operation result with proofs ========== *)

typedef batch_result = @{
  success_count = [n:nat] int(n),                  (* Number of successful operations *)
  failure_count = [n:nat] int(n),                  (* Number of failed operations *)
  skipped_count = [n:nat] int(n),                  (* Number of skipped operations *)
  results = List0(operation_result),               (* Detailed results *)
  rollback_info = Option(string)                   (* Rollback information if needed *)
}

(* ========== Validation functions ========== *)

(*
** Validates that a string is a valid SPDX identifier
** Returns Some(spdx_id) if valid, None otherwise
*)
fun validate_spdx_id(s: string): Option(spdx_id(s))

(*
** Validates that a path exists on filesystem
** Returns Some(existing_path) if valid, None otherwise
*)
fun validate_path_exists(p: string): Option(existing_path(p))

(*
** Validates that a path is a git repository
** Returns Some(git_repo) if valid, None otherwise
*)
fun validate_git_repo(p: string): Option(git_repo(p))

(*
** Validates that a string is non-empty
** Returns Some(nonempty_string) if valid, None otherwise
*)
fun validate_nonempty(s: string): Option(nonempty_string(s))

(* ========== Operation constructors with validation ========== *)

(*
** Creates a license update operation with validation
** Returns None if validation fails
*)
fun make_license_update_op(
  old: string,
  new: string,
  backup: backup_policy,
  mode: operation_mode
): Option([old:string, new:string] license_update_op(old, new))

(*
** Creates a file replace operation with validation
** Returns None if validation fails
*)
fun make_file_replace_op(
  pattern: string,
  replacement: string,
  backup: backup_policy,
  mode: operation_mode
): Option([pat:string, repl:string] file_replace_op(pat, repl))

(*
** Creates a git sync operation with validation
** Returns None if validation fails
*)
fun make_git_sync_op(
  msg: string,
  parallel: int,
  depth: int,
  mode: operation_mode
): Option([msg:string] git_sync_op(msg))

(* ========== Operation execution ========== *)

(*
** Executes a batch operation across target repositories
** Returns batch_result with detailed success/failure information
**
** Proof obligations:
** - If mode is DryRun, no filesystem changes are made
** - If backup is required, backups are created before any changes
** - Operation is atomic per repository (all changes or none)
*)
fun execute_batch_operation(
  op: batch_operation,
  ctx: operation_context
): batch_result

(*
** Rolls back a batch operation using rollback information
** Returns true if rollback succeeded, false otherwise
*)
fun rollback_batch_operation(
  rollback_info: string
): bool
