(*
** SPDX-License-Identifier: PMPL-1.0-or-later
**
** SPDX license identifier validation
** Validates license identifiers against SPDX specification
*)

#include "share/atspre_define.hats"
#include "share/atspre_staload.hats"

staload "../operations/types.dats"

(* ========== SPDX License List ========== *)

(*
** Common SPDX license identifiers
** Full list: https://spdx.org/licenses/
*)
val common_spdx_licenses = @[
  "PMPL-1.0-or-later",
  "MIT",
  "Apache-2.0",
  "GPL-3.0-only",
  "GPL-3.0-or-later",
  "LGPL-3.0-only",
  "LGPL-3.0-or-later",
  "BSD-2-Clause",
  "BSD-3-Clause",
  "ISC",
  "MPL-2.0",
  "AGPL-3.0-only",
  "PMPL-1.0-or-later",
  "Unlicense",
  "0BSD"
] : List0(string)

(*
** Validates if a string is a valid SPDX identifier
** Returns true if valid, false otherwise
*)
fun is_valid_spdx(s: string): bool = let
  fun check_list(licenses: List0(string)): bool =
    case+ licenses of
    | list_nil() => false
    | list_cons(lic, rest) =>
        if s = lic then true
        else check_list(rest)
in
  if string_is_empty(s) then false
  else check_list(common_spdx_licenses)
end

(*
** Validates SPDX identifier and returns proof type
** Returns Some(spdx_id) if valid, None otherwise
*)
implement validate_spdx_id(s) =
  if is_valid_spdx(s) then Some(s)
  else None()

(*
** Extracts SPDX identifier from header line
** Format: "// SPDX-License-Identifier: MIT"
** Returns extracted license or empty string
*)
fun extract_spdx_from_header(line: string): string = let
  val prefix = "SPDX-License-Identifier:"
  val idx = string_index_of(line, prefix)
in
  if idx >= 0 then let
    val start = idx + string_length(prefix)
    val rest = string_suffix(line, start)
    val trimmed = string_trim(rest)
  in
    trimmed
  end
  else ""
end

(*
** Checks if a file contains SPDX header
** Returns Some(license) if found, None otherwise
*)
fun find_spdx_in_file(path: string): Option(string) = let
  val file = fileref_open_opt(path, file_mode_r)
in
  case+ file of
  | ~Some_vt(f) => let
      fun loop(): Option(string) = let
        val line = fileref_get_line_string(f)
      in
        if string_is_empty(line) then None()
        else let
          val spdx = extract_spdx_from_header(line)
        in
          if string_is_empty(spdx) then loop()
          else Some(spdx)
        end
      end
      val result = loop()
      val () = fileref_close(f)
    in
      result
    end
  | ~None_vt() => None()
end

(*
** Generates SPDX header for given license and comment style
** comment_style: "//", "#", "--", etc.
*)
fun generate_spdx_header(license: string, comment_style: string): string =
  comment_style + " SPDX-License-Identifier: " + license + "\n"

(*
** Determines comment style for file extension
** Returns comment prefix ("//", "#", "--", etc.)
*)
fun get_comment_style_for_ext(ext: string): string =
  case+ ext of
  | ".rs" => "//"
  | ".v" => "//"
  | ".dats" => "(*"
  | ".sats" => "(*"
  | ".idr" => "--"
  | ".zig" => "//"
  | ".scm" => ";;"
  | ".toml" => "#"
  | ".yml" => "#"
  | ".yaml" => "#"
  | ".md" => "<!--"
  | ".adoc" => "//"
  | _ => "//"  // Default to C-style
