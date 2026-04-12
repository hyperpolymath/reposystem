(*
** SPDX-License-Identifier: PMPL-1.0-or-later
**
** GitHub Settings Operation Implementation
** Bulk GitHub repository configuration management
** Week 1: Basic repository and merge settings
*)

#include "share/atspre_define.hats"
#include "share/atspre_staload.hats"

staload "libats/libc/SATS/stdio.sats"

staload "./types.dats"
staload "../utils/string_utils.sats"

(* ========== Settings Type Definitions ========== *)

(*
** Repository feature settings
*)
typedef repo_features = @{
  has_issues = Option(bool),
  has_wiki = Option(bool),
  has_projects = Option(bool),
  has_downloads = Option(bool)
}

(*
** Merge strategy settings
*)
typedef merge_settings = @{
  allow_squash_merge = Option(bool),
  allow_merge_commit = Option(bool),
  allow_rebase_merge = Option(bool),
  delete_branch_on_merge = Option(bool),
  allow_auto_merge = Option(bool)
}

(*
** Complete settings configuration
*)
typedef github_settings = @{
  repo_features = repo_features,
  merge_settings = merge_settings
}

(*
** Settings change result
*)
typedef settings_result = @{
  repo_path = string,
  success = bool,
  changes_applied = int,
  message = string
}

(* ========== Default Settings ========== *)

(*
** Create default repository features
** All options are None (no changes)
*)
fun default_repo_features(): repo_features =
  @{
    has_issues = None(),
    has_wiki = None(),
    has_projects = None(),
    has_downloads = None()
  }

(*
** Create default merge settings
** All options are None (no changes)
*)
fun default_merge_settings(): merge_settings =
  @{
    allow_squash_merge = None(),
    allow_merge_commit = None(),
    allow_rebase_merge = None(),
    delete_branch_on_merge = None(),
    allow_auto_merge = None()
  }

(*
** Create default settings configuration
*)
fun default_github_settings(): github_settings =
  @{
    repo_features = default_repo_features(),
    merge_settings = default_merge_settings()
  }

(* ========== Settings Validation ========== *)

(*
** Count number of settings changes
** Returns count of non-None settings
*)
fun count_changes_repo_features(features: repo_features): int = let
  fun count_option(opt: Option(bool), acc: int): int =
    case+ opt of
    | Some(_) => acc + 1
    | None() => acc
in
  count_option(features.has_issues, 0) +
  count_option(features.has_wiki, 0) +
  count_option(features.has_projects, 0) +
  count_option(features.has_downloads, 0)
end

fun count_changes_merge_settings(settings: merge_settings): int = let
  fun count_option(opt: Option(bool), acc: int): int =
    case+ opt of
    | Some(_) => acc + 1
    | None() => acc
in
  count_option(settings.allow_squash_merge, 0) +
  count_option(settings.allow_merge_commit, 0) +
  count_option(settings.allow_rebase_merge, 0) +
  count_option(settings.delete_branch_on_merge, 0) +
  count_option(settings.allow_auto_merge, 0)
end

fun count_total_changes(settings: github_settings): int =
  count_changes_repo_features(settings.repo_features) +
  count_changes_merge_settings(settings.merge_settings)

(*
** Validate settings before applying
** Returns true if settings are safe to apply
*)
fun validate_settings(settings: github_settings): bool = let
  val change_count = count_total_changes(settings)
in
  (* Must have at least one change *)
  if change_count = 0 then false
  (* Too many changes at once might be dangerous *)
  else if change_count > 20 then false
  else true
end

(* ========== Settings Application (Stub for V FFI) ========== *)

(*
** Apply repository feature settings
** This will be implemented in V with GitHub API calls
*)
extern
fun apply_repo_features(
  repo: string,
  features: repo_features,
  dry_run: bool
): @(bool, int) = "ext#"

(*
** Apply merge settings
** This will be implemented in V with GitHub API calls
*)
extern
fun apply_merge_settings(
  repo: string,
  settings: merge_settings,
  dry_run: bool
): @(bool, int) = "ext#"

(* ========== Main Operation ========== *)

(*
** Apply GitHub settings to a single repository
*)
fun apply_settings_to_repo(
  repo: string,
  settings: github_settings,
  dry_run: bool
): settings_result = let
  (* Validate settings first *)
  val valid = validate_settings(settings)
in
  if ~valid then
    @{
      repo_path = repo,
      success = false,
      changes_applied = 0,
      message = "Invalid settings configuration"
    }
  else let
    (* Apply repository features *)
    val (features_ok, features_count) = apply_repo_features(repo, settings.repo_features, dry_run)

    (* Apply merge settings *)
    val (merge_ok, merge_count) = apply_merge_settings(repo, settings.merge_settings, dry_run)

    (* Compute overall success *)
    val success = features_ok && merge_ok
    val total_changes = features_count + merge_count

    (* Generate message *)
    val message =
      if dry_run then
        "[DRY RUN] Would apply " + tostring_int(total_changes) + " changes"
      else if success then
        "Applied " + tostring_int(total_changes) + " changes successfully"
      else
        "Failed to apply settings"
  in
    @{
      repo_path = repo,
      success = success,
      changes_applied = total_changes,
      message = message
    }
  end
end

(*
** Execute GitHub settings operation across multiple repositories
*)
extern
fun execute_github_settings_operation(
  repos: List0(string),
  settings: github_settings,
  dry_run: bool
): List0(settings_result) = "ext#"

implement
execute_github_settings_operation(repos, settings, dry_run) = let
  fun process_repos(
    rs: List0(string),
    results: List0(settings_result)
  ): List0(settings_result) =
    case+ rs of
    | list0_nil() => results
    | list0_cons(repo, rest) => let
        val result = apply_settings_to_repo(repo, settings, dry_run)
      in
        process_repos(rest, list0_cons(result, results))
      end
in
  process_repos(repos, list0_nil())
end

(* ========== Settings Parsing (from TOML) ========== *)

(*
** Parse boolean setting from string
*)
fun parse_bool_setting(value: string): Option(bool) =
  if string_equal(value, "true") then Some(true)
  else if string_equal(value, "false") then Some(false)
  else None()

(*
** Set repository feature from key-value pair
*)
fun set_repo_feature(
  features: repo_features,
  key: string,
  value: string
): repo_features = let
  val bool_val = parse_bool_setting(value)
in
  if string_equal(key, "has_issues") then
    @{
      has_issues = bool_val,
      has_wiki = features.has_wiki,
      has_projects = features.has_projects,
      has_downloads = features.has_downloads
    }
  else if string_equal(key, "has_wiki") then
    @{
      has_issues = features.has_issues,
      has_wiki = bool_val,
      has_projects = features.has_projects,
      has_downloads = features.has_downloads
    }
  else if string_equal(key, "has_projects") then
    @{
      has_issues = features.has_issues,
      has_wiki = features.has_wiki,
      has_projects = bool_val,
      has_downloads = features.has_downloads
    }
  else if string_equal(key, "has_downloads") then
    @{
      has_issues = features.has_issues,
      has_wiki = features.has_wiki,
      has_projects = features.has_projects,
      has_downloads = bool_val
    }
  else features
end

(*
** Set merge setting from key-value pair
*)
fun set_merge_setting(
  settings: merge_settings,
  key: string,
  value: string
): merge_settings = let
  val bool_val = parse_bool_setting(value)
in
  if string_equal(key, "allow_squash_merge") then
    @{
      allow_squash_merge = bool_val,
      allow_merge_commit = settings.allow_merge_commit,
      allow_rebase_merge = settings.allow_rebase_merge,
      delete_branch_on_merge = settings.delete_branch_on_merge,
      allow_auto_merge = settings.allow_auto_merge
    }
  else if string_equal(key, "allow_merge_commit") then
    @{
      allow_squash_merge = settings.allow_squash_merge,
      allow_merge_commit = bool_val,
      allow_rebase_merge = settings.allow_rebase_merge,
      delete_branch_on_merge = settings.delete_branch_on_merge,
      allow_auto_merge = settings.allow_auto_merge
    }
  else if string_equal(key, "allow_rebase_merge") then
    @{
      allow_squash_merge = settings.allow_squash_merge,
      allow_merge_commit = settings.allow_merge_commit,
      allow_rebase_merge = bool_val,
      delete_branch_on_merge = settings.delete_branch_on_merge,
      allow_auto_merge = settings.allow_auto_merge
    }
  else if string_equal(key, "delete_branch_on_merge") then
    @{
      allow_squash_merge = settings.allow_squash_merge,
      allow_merge_commit = settings.allow_merge_commit,
      allow_rebase_merge = settings.allow_rebase_merge,
      delete_branch_on_merge = bool_val,
      allow_auto_merge = settings.allow_auto_merge
    }
  else if string_equal(key, "allow_auto_merge") then
    @{
      allow_squash_merge = settings.allow_squash_merge,
      allow_merge_commit = settings.allow_merge_commit,
      allow_rebase_merge = settings.allow_rebase_merge,
      delete_branch_on_merge = settings.delete_branch_on_merge,
      allow_auto_merge = bool_val
    }
  else settings
end

(* ========== Summary Statistics ========== *)

(*
** Compute summary statistics from results
*)
fun compute_summary(results: List0(settings_result)): @(int, int, int) = let
  fun loop(rs: List0(settings_result), success: int, failed: int, changes: int): @(int, int, int) =
    case+ rs of
    | list0_nil() => @(success, failed, changes)
    | list0_cons(r, rest) =>
      if r.success then
        loop(rest, success + 1, failed, changes + r.changes_applied)
      else
        loop(rest, success, failed + 1, changes)
in
  loop(results, 0, 0, 0)
end

(*
** Print summary of settings operation
*)
fun print_summary(results: List0(settings_result)): void = let
  val (success, failed, changes) = compute_summary(results)
  val total = success + failed
in
  println("=== GitHub Settings Summary ===");
  println("Total repositories: " + tostring_int(total));
  println("Successful: " + tostring_int(success));
  println("Failed: " + tostring_int(failed));
  println("Total changes applied: " + tostring_int(changes));
  println("")
end

(* ========== C Exports for FFI ========== *)

(*
** C-compatible settings structure
*)
typedef c_github_settings = @{
  (* Repository features *)
  has_issues = int,  (* -1=none, 0=false, 1=true *)
  has_wiki = int,
  has_projects = int,
  has_downloads = int,
  (* Merge settings *)
  allow_squash_merge = int,
  allow_merge_commit = int,
  allow_rebase_merge = int,
  delete_branch_on_merge = int,
  allow_auto_merge = int
}

(*
** Convert Option(bool) to C int representation
*)
fun option_bool_to_int(opt: Option(bool)): int =
  case+ opt of
  | Some(true) => 1
  | Some(false) => 0
  | None() => ~1

(*
** Convert C int to Option(bool)
*)
fun int_to_option_bool(n: int): Option(bool) =
  if n = 1 then Some(true)
  else if n = 0 then Some(false)
  else None()

(*
** Convert github_settings to C-compatible structure
*)
fun settings_to_c(settings: github_settings): c_github_settings =
  @{
    has_issues = option_bool_to_int(settings.repo_features.has_issues),
    has_wiki = option_bool_to_int(settings.repo_features.has_wiki),
    has_projects = option_bool_to_int(settings.repo_features.has_projects),
    has_downloads = option_bool_to_int(settings.repo_features.has_downloads),
    allow_squash_merge = option_bool_to_int(settings.merge_settings.allow_squash_merge),
    allow_merge_commit = option_bool_to_int(settings.merge_settings.allow_merge_commit),
    allow_rebase_merge = option_bool_to_int(settings.merge_settings.allow_rebase_merge),
    delete_branch_on_merge = option_bool_to_int(settings.merge_settings.delete_branch_on_merge),
    allow_auto_merge = option_bool_to_int(settings.merge_settings.allow_auto_merge)
  }

(*
** Main C export for github-settings operation
*)
extern
fun c_github_settings(
  base_dir: string,
  max_depth: int,
  settings: c_github_settings,
  dry_run: int
): int = "ext#"

implement
c_github_settings(base_dir, max_depth, c_settings, dry_run) = let
  (* Convert C settings to ATS2 settings *)
  val settings = @{
    repo_features = @{
      has_issues = int_to_option_bool(c_settings.has_issues),
      has_wiki = int_to_option_bool(c_settings.has_wiki),
      has_projects = int_to_option_bool(c_settings.has_projects),
      has_downloads = int_to_option_bool(c_settings.has_downloads)
    },
    merge_settings = @{
      allow_squash_merge = int_to_option_bool(c_settings.allow_squash_merge),
      allow_merge_commit = int_to_option_bool(c_settings.allow_merge_commit),
      allow_rebase_merge = int_to_option_bool(c_settings.allow_rebase_merge),
      delete_branch_on_merge = int_to_option_bool(c_settings.delete_branch_on_merge),
      allow_auto_merge = int_to_option_bool(c_settings.allow_auto_merge)
    }
  }

  (* Scan for repositories *)
  val repos = find_git_repos(base_dir, max_depth)

  (* Execute operation *)
  val results = execute_github_settings_operation(repos, settings, dry_run != 0)

  (* Print summary *)
  val () = print_summary(results)

  (* Return success count *)
  val (success, failed, _) = compute_summary(results)
in
  success
end
