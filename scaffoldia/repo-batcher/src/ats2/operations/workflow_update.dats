(*
** SPDX-License-Identifier: PMPL-1.0-or-later
**
** Workflow Update Operation Implementation
** Updates GitHub Actions workflows with SHA pinning
** Ensures all actions use commit SHAs instead of tags for security
*)

#include "share/atspre_define.hats"
#include "share/atspre_staload.hats"

staload "libats/libc/SATS/stdio.sats"
staload "libats/libc/SATS/dirent.sats"

staload "./types.dats"
staload "../utils/string_utils.sats"

(* ========== SHA Pinning Database ========== *)

(*
** Standard GitHub Actions with their SHA pins (2026-02-04)
** Format: (action_ref, version_tag, commit_sha)
*)
typedef action_pin = @{
  action = string,    (* e.g., "actions/checkout" *)
  version = string,   (* e.g., "v4" *)
  sha = string        (* Full commit SHA *)
}

val sha_pins: List0(action_pin) = list0_make(
  @{action = "actions/checkout", version = "v4", sha = "34e114876b0b11c390a56381ad16ebd13914f8d5"},
  @{action = "actions/checkout", version = "v5", sha = "93cb6efe18208431cddfb8368fd83d5badbf9bfd"},
  @{action = "github/codeql-action/init", version = "v3", sha = "6624720a57d4c312633c7b953db2f2da5bcb4c3a"},
  @{action = "github/codeql-action/autobuild", version = "v3", sha = "6624720a57d4c312633c7b953db2f2da5bcb4c3a"},
  @{action = "github/codeql-action/analyze", version = "v3", sha = "6624720a57d4c312633c7b953db2f2da5bcb4c3a"},
  @{action = "ossf/scorecard-action", version = "v2.4.0", sha = "62b2cac7ed8198b15735ed49ab1e5cf35480ba46"},
  @{action = "trufflesecurity/trufflehog", version = "main", sha = "7ee2e0fdffec27d19ccbb8fb3dcf8a83b9d7f9e8"},
  @{action = "dtolnay/rust-toolchain", version = "stable", sha = "4be9e76fd7c4901c61fb841f559994984270fce7"},
  @{action = "Swatinem/rust-cache", version = "v2", sha = "779680da715d629ac1d338a641029a2f4372abb5"},
  @{action = "codecov/codecov-action", version = "v5", sha = "671740ac38dd9b0130fbe1cec585b89eea48d3de"},
  @{action = "editorconfig-checker/action-editorconfig-checker", version = "main", sha = "4054fa83a075fdf090bd098bdb1c09aaf64a4169"},
  @{action = "slsa-framework/slsa-github-generator", version = "v2.1.0", sha = "f7dd8c54c2067bafc12ca7a55595d5ee9b75204a"},
  @{action = "webfactory/ssh-agent", version = "v0.9.0", sha = "dc588b651fe13675774614f8e6a936a468676387"},
  @{action = "ocaml/setup-ocaml", version = "v3", sha = "dec6499fef64fc5d7ed43d43a87251b7b1c306f5"},
  @{action = "softprops/action-gh-release", version = "v2", sha = "a06a81a03ee405af7f2048a818ed3f03bbf83c7b"},
  @{action = "actions/configure-pages", version = "v5", sha = "983d7736d9b0ae728b81ab479565c72886d7745b"},
  @{action = "actions/jekyll-build-pages", version = "v1", sha = "44a6e6beabd48582f863aeeb6cb2151cc1716697"},
  @{action = "actions/upload-pages-artifact", version = "v3", sha = "56afc609e74202658d3ffba0e8f6dda462b719fa"},
  @{action = "actions/deploy-pages", version = "v4", sha = "d6db90164ac5ed86f2b6aed7e0febac5b3c0c03e"},
  @{action = "ruby/setup-ruby", version = "v1", sha = "09a7688d3b55cf0e976497ff046b70949eeaccfd"}
)

(* ========== File Operations ========== *)

fun read_file_contents(path: string): Option(string) = let
  val file = fileref_open_opt(path, file_mode_r)
in
  case+ file of
  | ~Some_vt(f) => let
      val content = fileref_get_file_string(f)
      val () = fileref_close(f)
    in
      Some(content)
    end
  | ~None_vt() => None()
end

fun write_file_contents(path: string, content: string): bool = let
  val file = fileref_open_opt(path, file_mode_w)
in
  case+ file of
  | ~Some_vt(f) => let
      val () = fileref_put_string(f, content)
      val () = fileref_close(f)
    in
      true
    end
  | ~None_vt() => false
end

(* ========== Workflow Analysis ========== *)

(*
** Find SHA pin for action reference
** Looks up action@version and returns the commit SHA
*)
fun find_sha_pin(action_ref: string): Option(string) = let
  (* Parse action@version *)
  val at_pos = string_index_of(action_ref, "@")
in
  if at_pos < 0 then None()
  else let
    val action = string_prefix(action_ref, at_pos)
    val version = string_suffix(action_ref, at_pos + 1)

    fun loop(pins: List0(action_pin)): Option(string) =
      case+ pins of
      | list0_nil() => None()
      | list0_cons(pin, rest) =>
        if string_equal(pin.action, action) && string_equal(pin.version, version)
        then Some(pin.sha)
        else loop(rest)
  in
    loop(sha_pins)
  end
end

(*
** Check if action reference is already SHA-pinned
** Returns true if uses full commit SHA (40 hex chars)
*)
fun is_sha_pinned(action_ref: string): bool = let
  val at_pos = string_index_of(action_ref, "@")
in
  if at_pos < 0 then false
  else let
    val ref_part = string_suffix(action_ref, at_pos + 1)
    val len = string_length(ref_part)
  in
    (* SHA must be 40 hex characters *)
    if len != 40 then false
    else let
      fun is_hex_char(c: char): bool =
        (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')

      fun check_all_hex(s: string, i: int): bool =
        if i >= len then true
        else if is_hex_char(string_get_at(s, i)) then check_all_hex(s, i + 1)
        else false
    in
      check_all_hex(ref_part, 0)
    end
  end
end

(*
** Replace action reference with SHA-pinned version
** e.g., "actions/checkout@v4" -> "actions/checkout@34e114876b0b..."
** Preserves comment showing original version
*)
fun pin_action_reference(line: string): string = let
  val uses_pos = string_index_of(line, "uses:")
in
  if uses_pos < 0 then line  (* Not a uses: line *)
  else let
    (* Extract the action reference *)
    val after_uses = string_suffix(line, uses_pos + 5)
    val trimmed = string_trim(after_uses)

    (* Check if already pinned *)
  in
    if is_sha_pinned(trimmed) then line
    else
      case+ find_sha_pin(trimmed) of
      | Some(sha) => let
          val at_pos = string_index_of(trimmed, "@")
          val action = string_prefix(trimmed, at_pos)
          val version = string_suffix(trimmed, at_pos + 1)
          val indentation = string_prefix(line, uses_pos)
          val pinned = action + "@" + sha
          val comment = " # " + version
        in
          indentation + "uses: " + pinned + comment
        end
      | None() => line  (* No pin found, leave unchanged *)
  end
end

(*
** Process entire workflow file
** Updates all action references with SHA pins
*)
fun update_workflow_file(content: string): string = let
  val lines = string_split(content, "\n")

  fun process_lines(ls: List0(string)): List0(string) =
    case+ ls of
    | list0_nil() => list0_nil()
    | list0_cons(line, rest) =>
      list0_cons(pin_action_reference(line), process_lines(rest))

  val updated_lines = process_lines(lines)
in
  string_join(updated_lines, "\n")
end

(* ========== Repository Operations ========== *)

(*
** Find all workflow files in .github/workflows/
** Returns list of relative paths
*)
fun find_workflow_files(repo_path: string): List0(string) = let
  val workflows_dir = repo_path + "/.github/workflows"

  (* Check if directory exists *)
  fun dir_exists(path: string): bool = let
    val dir = dirptr_open_opt(path)
  in
    case+ dir of
    | ~Some_vt(d) => let val () = dirptr_close(d) in true end
    | ~None_vt() => false
  end
in
  if ~dir_exists(workflows_dir) then list0_nil()
  else let
    (* List all .yml and .yaml files *)
    val dir = dirptr_open_exn(workflows_dir)

    fun read_entries(acc: List0(string)): List0(string) = let
      val entry = dirptr_read_opt(dir)
    in
      case+ entry of
      | ~Some_vt(ent) => let
          val name = dirent_get_name(ent)
          val is_yaml = string_has_suffix(name, ".yml") || string_has_suffix(name, ".yaml")
        in
          if is_yaml
          then read_entries(list0_cons(workflows_dir + "/" + name, acc))
          else read_entries(acc)
        end
      | ~None_vt() => acc
    end

    val files = read_entries(list0_nil())
    val () = dirptr_close(dir)
  in
    files
  end
end

(*
** Update all workflows in repository
** Returns number of files updated
*)
fun update_repository_workflows(
  repo_path: string,
  backup: bool,
  dry_run: bool
): @(int, int) = let  (* (updated_count, total_count) *)
  val workflow_files = find_workflow_files(repo_path)

  fun process_file(file_path: string): bool = let
    val content_opt = read_file_contents(file_path)
  in
    case+ content_opt of
    | Some(content) => let
        val updated = update_workflow_file(content)
        val has_changes = ~string_equal(content, updated)
      in
        if has_changes then
          if dry_run then true
          else let
            (* Create backup if requested *)
            val backup_result =
              if backup then let
                val backup_path = file_path + ".backup"
              in
                write_file_contents(backup_path, content)
              end
              else true

            (* Write updated content *)
            val write_result =
              if backup_result then write_file_contents(file_path, updated)
              else false
          in
            write_result
          end
        else false
      end
    | None() => false
  end

  fun count_updates(files: List0(string), updated: int, total: int): @(int, int) =
    case+ files of
    | list0_nil() => @(updated, total)
    | list0_cons(file, rest) =>
      if process_file(file)
      then count_updates(rest, updated + 1, total + 1)
      else count_updates(rest, updated, total + 1)
in
  count_updates(workflow_files, 0, 0)
end

(* ========== Main Operation ========== *)

(*
** Execute workflow update operation
** Updates GitHub Actions with SHA pinning across repositories
*)
extern
fun execute_workflow_update_operation(
  repos: List0(string),
  backup: bool,
  dry_run: bool
): batch_result = "ext#"

implement
execute_workflow_update_operation(repos, backup, dry_run) = let
  fun process_repos(
    rs: List0(string),
    success: int,
    failed: int,
    results: List0(operation_result)
  ): batch_result =
    case+ rs of
    | list0_nil() =>
      @{
        total = success + failed,
        successful = success,
        failed = failed,
        results = results
      }
    | list0_cons(repo, rest) => let
        val (updated, total) = update_repository_workflows(repo, backup, dry_run)
        val result =
          if updated > 0 || total > 0 then
            @{
              repo_path = repo,
              success = true,
              message = "Updated " + tostring_int(updated) + "/" + tostring_int(total) + " workflows",
              files_affected = updated
            }
          else
            @{
              repo_path = repo,
              success = true,
              message = "No workflows found",
              files_affected = 0
            }
      in
        process_repos(rest, success + 1, failed, list0_cons(result, results))
      end
in
  process_repos(repos, 0, 0, list0_nil())
end

(* ========== C Exports ========== *)

extern
fun c_workflow_update(
  base_dir: string,
  max_depth: int,
  backup: int,
  dry_run: int
): c_batch_result = "ext#"

implement
c_workflow_update(base_dir, max_depth, backup, dry_run) = let
  (* Scan for repositories *)
  val repos = find_git_repos(base_dir, max_depth)

  (* Execute workflow update *)
  val result = execute_workflow_update_operation(
    repos,
    backup != 0,
    dry_run != 0
  )
in
  batch_result_to_c(result)
end
