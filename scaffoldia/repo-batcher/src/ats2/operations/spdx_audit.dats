(*
** SPDX-License-Identifier: PMPL-1.0-or-later
**
** SPDX Audit Operation Implementation
** Audits SPDX license headers across all source files
** Ensures compliance with hyperpolymath licensing standards
*)

#include "share/atspre_define.hats"
#include "share/atspre_staload.hats"

staload "libats/libc/SATS/stdio.sats"
staload "libats/libc/SATS/dirent.sats"

staload "./types.dats"
staload "../validation/spdx.dats"
staload "../utils/string_utils.sats"

(* ========== File Extensions ========== *)

(*
** Source file extensions that should have SPDX headers
*)
val source_extensions: List0(string) = list0_make(
  ".rs",    (* Rust *)
  ".v",     (* V *)
  ".c",     (* C *)
  ".h",     (* C headers *)
  ".cpp",   (* C++ *)
  ".hpp",   (* C++ headers *)
  ".js",    (* JavaScript *)
  ".jsx",   (* React *)
  ".ts",    (* TypeScript *)
  ".tsx",   (* React TypeScript *)
  ".py",    (* Python *)
  ".rb",    (* Ruby *)
  ".go",    (* Go *)
  ".java",  (* Java *)
  ".kt",    (* Kotlin *)
  ".scala", (* Scala *)
  ".ml",    (* OCaml *)
  ".mli",   (* OCaml interface *)
  ".ex",    (* Elixir *)
  ".exs",   (* Elixir script *)
  ".gleam", (* Gleam *)
  ".dats",  (* ATS2 *)
  ".sats",  (* ATS2 *)
  ".idr",   (* Idris2 *)
  ".zig",   (* Zig *)
  ".sh",    (* Shell *)
  ".bash",  (* Bash *)
  ".yml",   (* YAML *)
  ".yaml",  (* YAML *)
  ".toml",  (* TOML *)
  ".scm",   (* Scheme *)
  ".rkt",   (* Racket *)
  ".el",    (* Emacs Lisp *)
  ".jl",    (* Julia *)
  ".ad",    (* Ada body *)
  ".ads"    (* Ada spec *)
)

fun has_source_extension(path: string): bool = let
  fun check_extension(exts: List0(string)): bool =
    case+ exts of
    | list0_nil() => false
    | list0_cons(ext, rest) =>
      if string_has_suffix(path, ext) then true
      else check_extension(rest)
in
  check_extension(source_extensions)
end

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

(* ========== SPDX Header Detection ========== *)

(*
** Check if content has valid SPDX header
** Looks for "SPDX-License-Identifier:" in first 20 lines
*)
fun has_spdx_header(content: string): bool = let
  val lines = string_split(content, "\n")

  fun check_lines(ls: List0(string), count: int): bool =
    if count >= 20 then false
    else
      case+ ls of
      | list0_nil() => false
      | list0_cons(line, rest) =>
        if string_contains(line, "SPDX-License-Identifier:") then true
        else check_lines(rest, count + 1)
in
  check_lines(lines, 0)
end

(*
** Extract SPDX identifier from content
** Returns the license identifier (e.g., "PMPL-1.0-or-later")
*)
fun extract_spdx_id(content: string): Option(string) = let
  val lines = string_split(content, "\n")

  fun find_in_lines(ls: List0(string)): Option(string) =
    case+ ls of
    | list0_nil() => None()
    | list0_cons(line, rest) =>
      if string_contains(line, "SPDX-License-Identifier:") then let
        val id_pos = string_index_of(line, "SPDX-License-Identifier:")
        val after_id = string_suffix(line, id_pos + 24)
        val trimmed = string_trim(after_id)
      in
        if string_length(trimmed) > 0 then Some(trimmed)
        else None()
      end
      else find_in_lines(rest)
in
  find_in_lines(lines)
end

(* ========== Audit Results ========== *)

typedef audit_stats = @{
  total_files = int,
  with_spdx = int,
  without_spdx = int,
  invalid_spdx = int,
  pmpl_license = int,
  other_licenses = int
}

typedef audit_result = @{
  repo_path = string,
  stats = audit_stats,
  missing_files = List0(string),
  invalid_files = List0(string)
}

(* ========== Directory Scanning ========== *)

(*
** Scan repository for source files and audit SPDX headers
*)
fun audit_repository(repo_path: string): audit_result = let
  fun scan_directory(
    dir_path: string,
    depth: int,
    stats: audit_stats,
    missing: List0(string),
    invalid: List0(string)
  ): @(audit_stats, List0(string), List0(string)) =
    if depth > 5 then @(stats, missing, invalid)
    else let
      val dir_opt = dirptr_open_opt(dir_path)
    in
      case+ dir_opt of
      | ~Some_vt(dir) => let
          fun read_entries(
            s: audit_stats,
            m: List0(string),
            i: List0(string)
          ): @(audit_stats, List0(string), List0(string)) = let
            val entry = dirptr_read_opt(dir)
          in
            case+ entry of
            | ~Some_vt(ent) => let
                val name = dirent_get_name(ent)
              in
                if string_equal(name, ".") || string_equal(name, "..") then
                  read_entries(s, m, i)
                else let
                  val full_path = dir_path + "/" + name
                  val is_dir = dirent_is_dir(ent)
                in
                  if is_dir then
                    (* Skip hidden directories *)
                    if string_has_prefix(name, ".") then read_entries(s, m, i)
                    else let
                      val (new_stats, new_missing, new_invalid) =
                        scan_directory(full_path, depth + 1, s, m, i)
                    in
                      read_entries(new_stats, new_missing, new_invalid)
                    end
                  else
                    (* Check if source file *)
                    if has_source_extension(full_path) then let
                      val content_opt = read_file_contents(full_path)
                    in
                      case+ content_opt of
                      | Some(content) =>
                        if has_spdx_header(content) then let
                          val spdx_id_opt = extract_spdx_id(content)
                        in
                          case+ spdx_id_opt of
                          | Some(spdx_id) =>
                            if is_valid_spdx(spdx_id) then let
                              val is_pmpl = string_has_prefix(spdx_id, "PMPL-1.0")
                              val new_stats = @{
                                total_files = s.total_files + 1,
                                with_spdx = s.with_spdx + 1,
                                without_spdx = s.without_spdx,
                                invalid_spdx = s.invalid_spdx,
                                pmpl_license = if is_pmpl then s.pmpl_license + 1 else s.pmpl_license,
                                other_licenses = if is_pmpl then s.other_licenses else s.other_licenses + 1
                              }
                            in
                              read_entries(new_stats, m, i)
                            end
                            else let
                              val new_stats = @{
                                total_files = s.total_files + 1,
                                with_spdx = s.with_spdx,
                                without_spdx = s.without_spdx,
                                invalid_spdx = s.invalid_spdx + 1,
                                pmpl_license = s.pmpl_license,
                                other_licenses = s.other_licenses
                              }
                            in
                              read_entries(new_stats, m, list0_cons(full_path, i))
                            end
                          | None() => let
                              val new_stats = @{
                                total_files = s.total_files + 1,
                                with_spdx = s.with_spdx,
                                without_spdx = s.without_spdx,
                                invalid_spdx = s.invalid_spdx + 1,
                                pmpl_license = s.pmpl_license,
                                other_licenses = s.other_licenses
                              }
                            in
                              read_entries(new_stats, m, list0_cons(full_path, i))
                            end
                        end
                        else let
                          val new_stats = @{
                            total_files = s.total_files + 1,
                            with_spdx = s.with_spdx,
                            without_spdx = s.without_spdx + 1,
                            invalid_spdx = s.invalid_spdx,
                            pmpl_license = s.pmpl_license,
                            other_licenses = s.other_licenses
                          }
                        in
                          read_entries(new_stats, list0_cons(full_path, m), i)
                        end
                      | None() => read_entries(s, m, i)
                    end
                    else read_entries(s, m, i)
                end
              end
            | ~None_vt() => @(s, m, i)
          end

          val (final_stats, final_missing, final_invalid) = read_entries(stats, missing, invalid)
          val () = dirptr_close(dir)
        in
          @(final_stats, final_missing, final_invalid)
        end
      | ~None_vt() => @(stats, missing, invalid)
    end

  val initial_stats = @{
    total_files = 0,
    with_spdx = 0,
    without_spdx = 0,
    invalid_spdx = 0,
    pmpl_license = 0,
    other_licenses = 0
  }

  val (stats, missing, invalid) = scan_directory(repo_path, 0, initial_stats, list0_nil(), list0_nil())
in
  @{
    repo_path = repo_path,
    stats = stats,
    missing_files = missing,
    invalid_files = invalid
  }
end

(* ========== Main Operation ========== *)

(*
** Execute SPDX audit operation
** Audits all source files for SPDX license headers
*)
extern
fun execute_spdx_audit_operation(
  repos: List0(string)
): List0(audit_result) = "ext#"

implement
execute_spdx_audit_operation(repos) = let
  fun process_repos(
    rs: List0(string),
    results: List0(audit_result)
  ): List0(audit_result) =
    case+ rs of
    | list0_nil() => results
    | list0_cons(repo, rest) => let
        val result = audit_repository(repo)
      in
        process_repos(rest, list0_cons(result, results))
      end
in
  process_repos(repos, list0_nil())
end

(* ========== C Exports ========== *)

(*
** C-compatible audit result for FFI
*)
typedef c_audit_stats = @{
  total_files = int,
  with_spdx = int,
  without_spdx = int,
  invalid_spdx = int,
  pmpl_license = int,
  other_licenses = int
}

typedef c_audit_result = @{
  repo_path = string,
  stats = c_audit_stats,
  compliance_percent = int
}

extern
fun c_spdx_audit(
  base_dir: string,
  max_depth: int
): @{
  total_repos = int,
  results = ptr
} = "ext#"

implement
c_spdx_audit(base_dir, max_depth) = let
  (* Scan for repositories *)
  val repos = find_git_repos(base_dir, max_depth)

  (* Execute audit *)
  val results = execute_spdx_audit_operation(repos)

  (* Calculate compliance percentages *)
  fun compute_compliance(stats: audit_stats): int =
    if stats.total_files = 0 then 100
    else (stats.with_spdx * 100) / stats.total_files

  (* Convert to C results *)
  fun to_c_results(
    rs: List0(audit_result),
    acc: List0(c_audit_result)
  ): List0(c_audit_result) =
    case+ rs of
    | list0_nil() => acc
    | list0_cons(r, rest) => let
        val c_result = @{
          repo_path = r.repo_path,
          stats = r.stats,
          compliance_percent = compute_compliance(r.stats)
        }
      in
        to_c_results(rest, list0_cons(c_result, acc))
      end

  val c_results = to_c_results(results, list0_nil())
in
  @{
    total_repos = list0_length(c_results),
    results = $UNSAFE.cast{ptr}(c_results)
  }
end
