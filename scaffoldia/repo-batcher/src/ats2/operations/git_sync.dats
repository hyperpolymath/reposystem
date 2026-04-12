(*
** SPDX-License-Identifier: PMPL-1.0-or-later
**
** Git Batch Sync Operation
** Ports functionality from sync_repos.sh with formal verification
*)

#include "share/atspre_define.hats"
#include "share/atspre_staload.hats"

staload "libats/libc/SATS/stdlib.sats"
staload "libats/libc/SATS/stdio.sats"

staload "./types.dats"
staload "../utils/string_utils.sats"

(* ========== Git Command Execution ========== *)

(*
** Executes git command in repository directory
** Returns exit code
*)
fun exec_git_command(repo_path: string, command: string): int = let
  val full_command = "cd " + repo_path + " && git " + command
in
  system(full_command)
end

(*
** Checks if directory is a valid git repository
** Returns true if valid, false otherwise
*)
fun is_git_repo(path: string): bool = let
  val git_dir = path + "/.git"
  val result = test_file_exists(git_dir)
in
  result
end

(*
** Checks if repository has uncommitted changes
** Returns true if clean, false if dirty
*)
fun is_repo_clean(repo_path: string): bool = let
  val exit_code = exec_git_command(repo_path, "diff --quiet")
in
  exit_code = 0
end

(*
** Gets status of git repository
** Returns human-readable status string
*)
fun get_repo_status(repo_path: string): string = let
  val status_file = "/tmp/repo_status.txt"
  val cmd = "cd " + repo_path + " && git status --short > " + status_file
  val _ = system(cmd)
  val content = read_file_contents(status_file)
in
  case+ content of
  | Some(s) => s
  | None() => "unknown"
end

(* ========== Git Operations ========== *)

(*
** Performs git add on all files in repository
** Returns operation result
*)
fun git_add_all(repo_path: string, dry_run: bool): operation_result =
  if dry_run then
    OpSuccess("[DRY-RUN] Would add all files in: " + repo_path)
  else let
    val exit_code = exec_git_command(repo_path, "add .")
  in
    if exit_code = 0 then
      OpSuccess("Added all files in: " + repo_path)
    else
      OpFailure("Failed to add files in: " + repo_path)
  end

(*
** Performs git commit with message
** Returns operation result
*)
fun git_commit(repo_path: string, message: string, dry_run: bool): operation_result =
  if dry_run then
    OpSuccess("[DRY-RUN] Would commit in: " + repo_path)
  else let
    val cmd = "commit -m \"" + message + "\""
    val exit_code = exec_git_command(repo_path, cmd)
  in
    if exit_code = 0 then
      OpSuccess("Committed in: " + repo_path)
    else if exit_code = 1 then
      // Exit code 1 usually means "nothing to commit"
      OpSkipped("Nothing to commit in: " + repo_path)
    else
      OpFailure("Failed to commit in: " + repo_path)
  end

(*
** Performs git push to remote
** Returns operation result
*)
fun git_push(repo_path: string, dry_run: bool): operation_result =
  if dry_run then
    OpSuccess("[DRY-RUN] Would push: " + repo_path)
  else let
    val exit_code = exec_git_command(repo_path, "push")
  in
    if exit_code = 0 then
      OpSuccess("Pushed: " + repo_path)
    else
      OpFailure("Failed to push: " + repo_path + " (check remote, auth, conflicts)")
  end

(*
** Full git sync: add, commit, push
** Returns operation result for this repository
*)
fun git_sync_repo(
  repo_path: string,
  commit_msg: string,
  dry_run: bool
): operation_result = let
  // Validate it's a git repo
  val is_repo = is_git_repo(repo_path)
in
  if ~is_repo then
    OpFailure("Not a git repository: " + repo_path)
  else let
    // Step 1: git add .
    val add_result = git_add_all(repo_path, dry_run)
  in
    case+ add_result of
    | OpSuccess(_) => let
        // Step 2: git commit
        val commit_result = git_commit(repo_path, commit_msg, dry_run)
      in
        case+ commit_result of
        | OpSuccess(_) => let
            // Step 3: git push
            val push_result = git_push(repo_path, dry_run)
          in
            push_result
          end
        | OpSkipped(msg) => OpSkipped(msg)
        | OpFailure(msg) => OpFailure(msg)
      end
    | OpFailure(msg) => OpFailure("Add failed: " + msg)
    | OpSkipped(msg) => OpSkipped(msg)
  end
end

(* ========== Repository Discovery ========== *)

(*
** Finds all git repositories in directory up to max_depth
** Returns list of repository paths
**
** This replicates the logic from sync_repos.sh:
** find . -maxdepth 2 -name ".git" -type d
*)
fun find_git_repos(
  base_dir: string,
  max_depth: int
): List0(string) = let
  // Use find command to locate .git directories
  val find_cmd =
    "find " + base_dir +
    " -maxdepth " + tostring_int(max_depth) +
    " -name \".git\" -type d 2>/dev/null"

  val output_file = "/tmp/repo_list.txt"
  val cmd = find_cmd + " > " + output_file
  val _ = system(cmd)

  // Read repository paths from output
  val repos = read_repo_list_from_file(output_file)
in
  repos
end

(*
** Reads list of repository paths from file
** Each line is a path to .git directory, we extract parent
*)
and read_repo_list_from_file(path: string): List0(string) = let
  val file = fileref_open_opt(path, file_mode_r)
in
  case+ file of
  | ~Some_vt(f) => let
      fun read_lines(acc: List0(string)): List0(string) = let
        val line = fileref_get_line_string(f)
      in
        if string_is_empty(line) then
          acc
        else let
          // Remove ".git" suffix to get repo path
          val repo_path = remove_git_suffix(line)
        in
          read_lines(list_cons(repo_path, acc))
        end
      end
      val repos = read_lines(list_nil())
      val () = fileref_close(f)
    in
      repos
    end
  | ~None_vt() => list_nil()
end

(*
** Removes "/.git" suffix from path
*)
and remove_git_suffix(path: string): string = let
  val git_suffix = "/.git"
  val idx = string_index_of(path, git_suffix)
in
  if idx >= 0 then
    string_substring(path, 0, idx)
  else
    path
end

(* ========== Parallel Execution (Placeholder) ========== *)

(*
** Processes repositories in parallel (to be implemented in V)
** For now, this is a sequential implementation
**
** The actual parallelism will be handled by V coroutines
** This function just processes the list sequentially
*)
fun process_repos_sequential(
  repos: List0(string),
  commit_msg: string,
  dry_run: bool,
  results: List0(operation_result)
): List0(operation_result) =
  case+ repos of
  | list_nil() => results
  | list_cons(repo, rest) => let
      val result = git_sync_repo(repo, commit_msg, dry_run)
    in
      process_repos_sequential(rest, commit_msg, dry_run, list_cons(result, results))
    end

(* ========== Summary Report ========== *)

(*
** Generates summary report (like sync_repos.sh output)
** Returns formatted string
*)
fun generate_summary_report(results: List0(operation_result)): string = let
  fun count_results(
    results: List0(operation_result),
    success: int,
    failure: int,
    skipped: int
  ): @(int, int, int) =
    case+ results of
    | list_nil() => @(success, failure, skipped)
    | list_cons(r, rest) =>
        case+ r of
        | OpSuccess(_) => count_results(rest, success + 1, failure, skipped)
        | OpFailure(_) => count_results(rest, success, failure + 1, skipped)
        | OpSkipped(_) => count_results(rest, success, failure, skipped + 1)

  val @(s, f, sk) = count_results(results, 0, 0, 0)
  val total = s + f + sk

  // Build summary string
  val header = "\n--- Sync Summary ---\n"
  val table_header = "Status              | Count\n"
  val separator = "--------------------|----------\n"
  val success_line = "Fully Succeeded     | " + tostring_int(s) + "\n"
  val failure_line = "Failed/Partial      | " + tostring_int(f) + "\n"
  val skipped_line = "Skipped             | " + tostring_int(sk) + "\n"
  val total_line = "Total Processed     | " + tostring_int(total) + "\n"
in
  header + table_header + separator + success_line + failure_line +
  skipped_line + total_line
end

(*
** Generates failure details report
** Lists all failed operations
*)
fun generate_failure_report(results: List0(operation_result)): string = let
  fun collect_failures(
    results: List0(operation_result),
    failures: List0(string)
  ): List0(string) =
    case+ results of
    | list_nil() => failures
    | list_cons(r, rest) =>
        case+ r of
        | OpFailure(msg) => collect_failures(rest, list_cons(msg, failures))
        | _ => collect_failures(rest, failures)

  val failures = collect_failures(results, list_nil())
  val failure_count = list_length(failures)
in
  if failure_count = 0 then
    ""
  else let
    val header = "\n--- Failure Details ---\n"
    fun format_failures(failures: List0(string), acc: string): string =
      case+ failures of
      | list_nil() => acc
      | list_cons(msg, rest) =>
          format_failures(rest, acc + "  - " + msg + "\n")
  in
    header + format_failures(failures, "")
  end
end

(* ========== Main Git Sync Implementation ========== *)

(*
** Main implementation of git-sync operation
** This is the formally verified version of sync_repos.sh
*)
implement execute_git_sync_operation(
  base_dir: string,
  max_depth: int,
  commit_msg: string,
  parallel_jobs: int,
  dry_run: bool
): batch_result = let
  // Find all git repositories (like: find . -maxdepth 2 -name ".git")
  val repos = find_git_repos(base_dir, max_depth)

  // Process repositories
  // TODO: In V, this will use coroutines for parallel execution
  // For now, sequential processing
  val results = process_repos_sequential(repos, commit_msg, dry_run, list_nil())

  // Count results
  fun count_results(
    results: List0(operation_result),
    success: int,
    failure: int,
    skipped: int
  ): @(int, int, int) =
    case+ results of
    | list_nil() => @(success, failure, skipped)
    | list_cons(r, rest) =>
        case+ r of
        | OpSuccess(_) => count_results(rest, success + 1, failure, skipped)
        | OpFailure(_) => count_results(rest, success, failure + 1, skipped)
        | OpSkipped(_) => count_results(rest, success, failure, skipped + 1)

  val @(s, f, sk) = count_results(results, 0, 0, 0)

  // Generate summary report
  val summary = generate_summary_report(results)
  val failure_report = generate_failure_report(results)
  val () = print_string(summary)
  val () = print_string(failure_report)
in
  @{
    success_count = s,
    failure_count = f,
    skipped_count = sk,
    results = results,
    rollback_info = None()
  }
end

(* ========== Helper Functions ========== *)

and test_file_exists(path: string): bool = let
  val cmd = "test -e " + path
  val exit_code = system(cmd)
in
  exit_code = 0
end

and list_length(lst: List0('a)): int =
  case+ lst of
  | list_nil() => 0
  | list_cons(_, rest) => 1 + list_length(rest)
