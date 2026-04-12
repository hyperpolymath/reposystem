(*
** SPDX-License-Identifier: PMPL-1.0-or-later
**
** File Replace Operation Implementation
** Replaces files matching patterns across repositories
** Ensures no circular replacements and validates file integrity
*)

#include "share/atspre_define.hats"
#include "share/atspre_staload.hats"

staload "libats/libc/SATS/stdio.sats"
staload "libats/libc/SATS/dirent.sats"
staload "libats/libc/SATS/sys/stat.sats"

staload "./types.dats"
staload "../utils/string_utils.sats"

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

fun file_exists(path: string): bool = let
  val file = fileref_open_opt(path, file_mode_r)
in
  case+ file of
  | ~Some_vt(f) => let val () = fileref_close(f) in true end
  | ~None_vt() => false
end

fun copy_file(source: string, dest: string): bool = let
  val content_opt = read_file_contents(source)
in
  case+ content_opt of
  | Some(content) => write_file_contents(dest, content)
  | None() => false
end

(* ========== Pattern Matching ========== *)

(*
** Check if file path matches pattern
** Supports:
**   - Exact match: "LICENSE"
**   - Wildcard: "*.md"
**   - Path pattern: ".github/workflows/*.yml"
*)
fun path_matches_pattern(path: string, pattern: string): bool = let
  (* Extract filename from path *)
  val last_slash = string_last_index_of(path, "/")
  val filename = if last_slash < 0 then path
                 else string_suffix(path, last_slash + 1)

  (* Check for wildcard *)
  val star_pos = string_index_of(pattern, "*")
in
  if star_pos < 0 then
    (* Exact match *)
    string_equal(filename, pattern) || string_equal(path, pattern)
  else let
    (* Wildcard match *)
    val prefix = string_prefix(pattern, star_pos)
    val suffix = string_suffix(pattern, star_pos + 1)
  in
    string_has_prefix(filename, prefix) && string_has_suffix(filename, suffix)
  end
end

(* ========== Directory Traversal ========== *)

(*
** Find all files matching pattern in directory tree
** Returns list of relative paths
*)
fun find_matching_files(
  base_dir: string,
  pattern: string,
  max_depth: int
): List0(string) = let
  fun scan_directory(
    dir_path: string,
    depth: int,
    acc: List0(string)
  ): List0(string) =
    if depth > max_depth then acc
    else let
      val dir_opt = dirptr_open_opt(dir_path)
    in
      case+ dir_opt of
      | ~Some_vt(dir) => let
          fun read_entries(acc: List0(string)): List0(string) = let
            val entry = dirptr_read_opt(dir)
          in
            case+ entry of
            | ~Some_vt(ent) => let
                val name = dirent_get_name(ent)
              in
                if string_equal(name, ".") || string_equal(name, "..") then
                  read_entries(acc)
                else let
                  val full_path = dir_path + "/" + name
                  (* Check if directory *)
                  val is_dir = dirent_is_dir(ent)
                in
                  if is_dir then
                    (* Skip .git and other hidden dirs *)
                    if string_has_prefix(name, ".") then read_entries(acc)
                    else read_entries(scan_directory(full_path, depth + 1, acc))
                  else
                    (* Check if matches pattern *)
                    if path_matches_pattern(full_path, pattern)
                    then read_entries(list0_cons(full_path, acc))
                    else read_entries(acc)
                end
              end
            | ~None_vt() => acc
          end

          val files = read_entries(acc)
          val () = dirptr_close(dir)
        in
          files
        end
      | ~None_vt() => acc
    end
in
  scan_directory(base_dir, 0, list0_nil())
end

(* ========== Circular Replacement Check ========== *)

(*
** Compute FNV-1a hash of file content
** Used to detect circular replacements
*)
fun compute_file_hash(content: string): uint64 = let
  val FNV_PRIME: uint64 = 0x100000001b3UL
  val FNV_OFFSET: uint64 = 0xcbf29ce484222325UL

  fun hash_bytes(s: string, i: int, len: int, hash: uint64): uint64 =
    if i >= len then hash
    else let
      val byte = string_get_at(s, i)
      val new_hash = (hash XOR g0int2uint(g1ofg0(g0int2int(byte)))) * FNV_PRIME
    in
      hash_bytes(s, i + 1, len, new_hash)
    end
in
  hash_bytes(content, 0, string_length(content), FNV_OFFSET)
end

(*
** Check if replacement would be circular
** Returns true if source and dest have same content hash
*)
fun is_circular_replacement(source: string, dest: string): bool = let
  val source_content = read_file_contents(source)
  val dest_content = read_file_contents(dest)
in
  case+ (source_content, dest_content) of
  | (Some(s), Some(d)) =>
    compute_file_hash(s) = compute_file_hash(d)
  | (_, _) => false
end

(* ========== Repository Operations ========== *)

(*
** Replace files in repository
** Returns (successful_replacements, failed_replacements)
*)
fun replace_files_in_repo(
  repo_path: string,
  pattern: string,
  replacement_file: string,
  backup: bool,
  dry_run: bool
): @(int, int) = let
  (* Find all matching files *)
  val matching_files = find_matching_files(repo_path, pattern, 5)

  (* Read replacement content once *)
  val replacement_content = read_file_contents(replacement_file)
in
  case+ replacement_content of
  | None() => @(0, list0_length(matching_files))
  | Some(content) => let
      fun process_files(
        files: List0(string),
        success: int,
        failed: int
      ): @(int, int) =
        case+ files of
        | list0_nil() => @(success, failed)
        | list0_cons(file, rest) =>
          (* Check for circular replacement *)
          if is_circular_replacement(replacement_file, file) then
            process_files(rest, success, failed + 1)
          else
            if dry_run then
              process_files(rest, success + 1, failed)
            else let
              (* Create backup if requested *)
              val backup_result =
                if backup then
                  copy_file(file, file + ".backup")
                else true

              (* Write replacement *)
              val write_result =
                if backup_result then write_file_contents(file, content)
                else false
            in
              if write_result
              then process_files(rest, success + 1, failed)
              else process_files(rest, success, failed + 1)
            end
    in
      process_files(matching_files, 0, 0)
    end
end

(* ========== Main Operation ========== *)

(*
** Execute file replace operation
** Replaces files matching pattern with replacement file
*)
extern
fun execute_file_replace_operation(
  repos: List0(string),
  pattern: string,
  replacement_file: string,
  backup: bool,
  dry_run: bool
): batch_result = "ext#"

implement
execute_file_replace_operation(repos, pattern, replacement_file, backup, dry_run) = let
  (* Validate replacement file exists *)
  val replacement_exists = file_exists(replacement_file)
in
  if ~replacement_exists then
    @{
      total = 0,
      successful = 0,
      failed = 0,
      results = list0_nil()
    }
  else let
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
          val (replaced, errors) = replace_files_in_repo(repo, pattern, replacement_file, backup, dry_run)
          val result =
            if replaced > 0 || errors > 0 then
              @{
                repo_path = repo,
                success = errors = 0,
                message = "Replaced " + tostring_int(replaced) + " files, " + tostring_int(errors) + " errors",
                files_affected = replaced
              }
            else
              @{
                repo_path = repo,
                success = true,
                message = "No matching files found",
                files_affected = 0
              }
        in
          if errors = 0
          then process_repos(rest, success + 1, failed, list0_cons(result, results))
          else process_repos(rest, success, failed + 1, list0_cons(result, results))
        end
  in
    process_repos(repos, 0, 0, list0_nil())
  end
end

(* ========== C Exports ========== *)

extern
fun c_file_replace(
  base_dir: string,
  max_depth: int,
  pattern: string,
  replacement_file: string,
  backup: int,
  dry_run: int
): c_batch_result = "ext#"

implement
c_file_replace(base_dir, max_depth, pattern, replacement_file, backup, dry_run) = let
  (* Scan for repositories *)
  val repos = find_git_repos(base_dir, max_depth)

  (* Execute file replace *)
  val result = execute_file_replace_operation(
    repos,
    pattern,
    replacement_file,
    backup != 0,
    dry_run != 0
  )
in
  batch_result_to_c(result)
end
