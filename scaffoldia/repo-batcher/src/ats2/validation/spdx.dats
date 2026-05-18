(*
** SPDX-License-Identifier: PMPL-1.0-or-later
**
** SPDX license-identifier validation - IMPLEMENTATION (real Postiats 0.4.2)
**
** CANONICAL BUILD: from src/ats2 with `-IATS .`.
** Reuses Layer-1 string idioms (length-indexed string(n), proven
** indexing) and Layer-2 is_valid_spdx. No `+` string operator (that is
** not valid ATS2; all concatenation is string_append -> Strptr1).
*)

#define ATS_DYNLOADFLAG 0 // L5 link-completeness: self-contained static-lib TU; sound here (no effectful top-level vals), no runtime dynload needed
#include "share/atspre_define.hats"
#include "share/atspre_staload.hats"

staload "operations/types.sats"
staload "utils/string_utils.sats"
staload "validation/spdx.sats"

(* CODEGEN NOTE: a stack `@[char][2]` cast-to-string typechecks but
** triggers a Postiats 0.4.2 codegen INTERROR (see the matching note in
** utils/string_utils.dats). The ATS open-comment digraph cannot appear
** as a single string literal either (comments nest — see spdx.sats).
** So we keep two SEPARATE single-char literals "(" and "*" (each safe
** in isolation) and append them at runtime. Sound, codegen-safe. *)

(* SPDX short-form id character class: A-Z a-z 0-9 . + - *)
fn is_spdx_char (c: char): bool =
  (c >= 'A' andalso c <= 'Z') orelse
  (c >= 'a' andalso c <= 'z') orelse
  (c >= '0' andalso c <= '9') orelse
  c = '.' orelse c = '+' orelse c = '-'

implement spdx_wellformed (s0) = let
  val s = g1ofg0(s0)
  val n = string_length(s)
  fun loop {sl:int} {i:nat | i <= sl} .<sl-i>.
    (s: string(sl), i: size_t(i), sl: size_t(sl)): bool =
    if i >= sl then true
    else if is_spdx_char(s[i]) then loop(s, succ(i), sl)
    else false
in
  if sz2i(n) = 0 then false else loop(s, i2sz(0), n)
end

implement spdx_acceptable (s) =
  if is_valid_spdx(s) then true else spdx_wellformed(s)

(* ATS2 has no string-literal patterns; dispatch by `=` on `string`.
** The ATS-family prefix is assembled char-wise (lp then star) so the
** source never contains the literal ATS open-comment digraph (see the
** spdx.sats note: Postiats 0.4.2 block comments nest, so that digraph
** even inside a string literal opens a comment). All arms yield a
** fresh Strptr1; string0_copy on the static arms keeps one uniform
** ownership story (caller frees exactly once). *)
implement comment_prefix_for_ext(ext) = let
  (* "(" then "*" as two separate literals (never the digraph). *)
  val st = string_append("(", "*")
in
  if ext = ".dats" then st
  else if ext = ".sats" then st
  else if ext = ".hats" then st
  else let
    val () = strptr_free(st)
  in
    if ext = ".rs" then string0_copy("//")
    else if ext = ".zig" then string0_copy("//")
    else if ext = ".idr" then string0_copy("--")
    else if ext = ".scm" then string0_copy(";;")
    else if ext = ".toml" then string0_copy("#")
    else if ext = ".yml" then string0_copy("#")
    else if ext = ".yaml" then string0_copy("#")
    else if ext = ".sh" then string0_copy("#")
    else if ext = ".just" then string0_copy("#")
    else if ext = ".md" then string0_copy("<!--")
    else if ext = ".adoc" then string0_copy("//")
    else string0_copy("#")
  end
end

(* Header line built by chained string_append; each intermediate
** Strptr1 is freed exactly once. NOTE: the binder is `cpfx`, never
** `prefix` — `prefix` is a reserved ATS2 keyword (fixity declarations)
** and using it as an identifier is a hard parse error in Postiats
** 0.4.2 (root-caused by minimal bisection). Same applies estate-wide
** to `infix`/`infixl`/`infixr`/`postfix`. *)
implement make_spdx_header(license, cpfx) = let
  val p1 = string_append(cpfx, " SPDX-License-Identifier: ")
  val p2 = strptr_append_str(p1, license)
  val p3 = strptr_append_str(p2, "\n")
in
  p3
end
