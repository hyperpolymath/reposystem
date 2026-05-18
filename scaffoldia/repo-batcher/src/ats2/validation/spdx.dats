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

#include "share/atspre_define.hats"
#include "share/atspre_staload.hats"

staload "operations/types.sats"
staload "utils/string_utils.sats"
staload "validation/spdx.sats"

(* Local: a 1-char {c,'\000'} buffer borrowed as string then owned-copied.
** Same documented-unsafe idiom as utils/string_utils.dats:char_to_str
** (re-declared locally because that one is a private fn, not exported). *)
fn char_to_str (c: char): Strptr1 = let
  val cs = $UNSAFE.cast{string}(@[char][2](c, '\000'))
in
  string0_copy(cs)
end

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
  (* ASCII 40 = open paren, 42 = star; built from codes so neither the
  ** char literal for '(' nor the open-comment digraph appears in source. *)
  val lp = char_to_str(int2char0(40))
  val sp = char_to_str(int2char0(42))
  val st = string_append($UNSAFE.strptr2string(lp),
                         $UNSAFE.strptr2string(sp))
  val () = strptr_free(lp)
  val () = strptr_free(sp)
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
  val p2 = string_append($UNSAFE.strptr2string(p1), license)
  val () = strptr_free(p1)
  val p3 = string_append($UNSAFE.strptr2string(p2), "\n")
  val () = strptr_free(p2)
in
  p3
end
