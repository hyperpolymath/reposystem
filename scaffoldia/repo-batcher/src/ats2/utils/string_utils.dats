(*
** SPDX-License-Identifier: PMPL-1.0-or-later
**
** String Utility Functions
** Core string manipulation helpers for batch operations
*)

#include "share/atspre_define.hats"
#include "share/atspre_staload.hats"

(* ========== String Search ========== *)

(*
** Finds index of needle in haystack
** Returns -1 if not found, position >= 0 if found
*)
implement string_index_of(haystack, needle) = let
  val haystack_len = string_length(haystack)
  val needle_len = string_length(needle)

  fun loop(i: int): int =
    if i + needle_len > haystack_len then
      ~1  // Not found
    else let
      val match = string_equal_at(haystack, i, needle)
    in
      if match then i
      else loop(i + 1)
    end
in
  if needle_len = 0 then 0  // Empty needle found at position 0
  else if needle_len > haystack_len then ~1  // Needle longer than haystack
  else loop(0)
end

(*
** Checks if haystack starts with needle at position i
*)
and string_equal_at(haystack: string, i: int, needle: string): bool = let
  val needle_len = string_length(needle)

  fun loop(j: int): bool =
    if j >= needle_len then true
    else if haystack[i + j] != needle[j] then false
    else loop(j + 1)
in
  loop(0)
end

(*
** Finds last index of character in string
** Returns -1 if not found
*)
implement string_rindex_of(haystack, needle) = let
  val len = string_length(haystack)

  fun loop(i: int): int =
    if i < 0 then ~1
    else if haystack[i] = needle then i
    else loop(i - 1)
in
  loop(len - 1)
end

(*
** Checks if haystack contains needle
*)
implement string_contains(haystack, needle) =
  string_index_of(haystack, needle) >= 0

(* ========== String Extraction ========== *)

(*
** Extracts substring starting at position with given length
** Returns empty string if out of bounds
*)
implement string_substring(s, start, len) = let
  val s_len = string_length(s)
in
  if start < 0 orelse start >= s_len then
    ""
  else if len <= 0 then
    ""
  else let
    val actual_len = min(len, s_len - start)
    val buf = string_make_substring(s, start, actual_len)
  in
    buf
  end
end

(*
** Gets suffix of string starting at position
*)
implement string_suffix(s, start) = let
  val len = string_length(s)
in
  if start < 0 orelse start >= len then ""
  else string_substring(s, start, len - start)
end

(*
** Gets prefix of string up to length
*)
fun string_prefix(s: string, len: int): string =
  string_substring(s, 0, len)

(* ========== String Trimming ========== *)

(*
** Checks if character is whitespace
*)
fun is_whitespace(c: char): bool =
  c = ' ' orelse c = '\t' orelse c = '\n' orelse c = '\r'

(*
** Trims whitespace from start of string
*)
fun string_ltrim(s: string): string = let
  val len = string_length(s)

  fun find_start(i: int): int =
    if i >= len then len
    else if is_whitespace(s[i]) then find_start(i + 1)
    else i

  val start = find_start(0)
in
  if start >= len then ""
  else string_suffix(s, start)
end

(*
** Trims whitespace from end of string
*)
fun string_rtrim(s: string): string = let
  val len = string_length(s)

  fun find_end(i: int): int =
    if i < 0 then 0
    else if is_whitespace(s[i]) then find_end(i - 1)
    else i + 1

  val end_pos = find_end(len - 1)
in
  if end_pos <= 0 then ""
  else string_prefix(s, end_pos)
end

(*
** Trims whitespace from both ends of string
*)
implement string_trim(s) =
  string_rtrim(string_ltrim(s))

(* ========== String Replacement ========== *)

(*
** Replaces first occurrence of old with new
*)
fun string_replace_first(str: string, old: string, new: string): string = let
  val idx = string_index_of(str, old)
in
  if idx < 0 then
    str  // Not found, return original
  else let
    val old_len = string_length(old)
    val before = string_prefix(str, idx)
    val after = string_suffix(str, idx + old_len)
  in
    before + new + after
  end
end

(*
** Replaces all occurrences of old with new
*)
implement string_replace(str, old, new) = let
  val old_len = string_length(old)

  fun loop(s: string, acc: string): string = let
    val idx = string_index_of(s, old)
  in
    if idx < 0 then
      acc + s  // No more occurrences
    else let
      val before = string_prefix(s, idx)
      val after = string_suffix(s, idx + old_len)
      val new_acc = acc + before + new
    in
      loop(after, new_acc)
    end
  end
in
  if old_len = 0 then str  // Don't replace empty string
  else loop(str, "")
end

(* ========== String Building ========== *)

(*
** Joins list of strings with separator
*)
fun string_join(strings: List0(string), sep: string): string = let
  fun loop(lst: List0(string), first: bool, acc: string): string =
    case+ lst of
    | list_nil() => acc
    | list_cons(s, rest) =>
        if first then
          loop(rest, false, s)
        else
          loop(rest, false, acc + sep + s)
in
  loop(strings, true, "")
end

(*
** Splits string by separator
*)
fun string_split(s: string, sep: string): List0(string) = let
  val sep_len = string_length(sep)

  fun loop(str: string, acc: List0(string)): List0(string) = let
    val idx = string_index_of(str, sep)
  in
    if idx < 0 then
      list_cons(str, acc)  // Last part
    else let
      val before = string_prefix(str, idx)
      val after = string_suffix(str, idx + sep_len)
    in
      loop(after, list_cons(before, acc))
    end
  end

  val parts = loop(s, list_nil())

  // Reverse to get correct order
  fun reverse(lst: List0(string), acc: List0(string)): List0(string) =
    case+ lst of
    | list_nil() => acc
    | list_cons(x, rest) => reverse(rest, list_cons(x, acc))
in
  reverse(parts, list_nil())
end

(* ========== Integer Conversion ========== *)

(*
** Converts integer to string
*)
implement tostring_int(n) = let
  fun int2string(i: int): string =
    if i = 0 then "0"
    else if i < 0 then "-" + int2string_pos(~i)
    else int2string_pos(i)

  and int2string_pos(i: int): string =
    if i = 0 then ""
    else int2string_pos(i / 10) + digit2char(i mod 10)

  and digit2char(d: int): string =
    case+ d of
    | 0 => "0" | 1 => "1" | 2 => "2" | 3 => "3" | 4 => "4"
    | 5 => "5" | 6 => "6" | 7 => "7" | 8 => "8" | 9 => "9"
    | _ => "?"
in
  int2string(n)
end

(* ========== Helper Functions ========== *)

fun min(a: int, b: int): int =
  if a < b then a else b

fun max(a: int, b: int): int =
  if a > b then a else b

(* ========== String Validation ========== *)

(*
** Checks if string is empty
*)
fun string_is_empty(s: string): bool =
  string_length(s) = 0

(*
** Checks if string is non-empty
*)
fun string_is_nonempty(s: string): bool =
  string_length(s) > 0

(*
** Checks if string contains only whitespace
*)
fun string_is_whitespace(s: string): bool = let
  val len = string_length(s)

  fun loop(i: int): bool =
    if i >= len then true
    else if is_whitespace(s[i]) then loop(i + 1)
    else false
in
  loop(0)
end

(* ========== String Comparison ========== *)

(*
** Case-insensitive string comparison
*)
fun string_equal_ci(s1: string, s2: string): bool = let
  val len1 = string_length(s1)
  val len2 = string_length(s2)
in
  if len1 != len2 then false
  else let
    fun loop(i: int): bool =
      if i >= len1 then true
      else if tolower(s1[i]) != tolower(s2[i]) then false
      else loop(i + 1)
  in
    loop(0)
  end
end

and tolower(c: char): char =
  if c >= 'A' && c <= 'Z' then
    char_of_int(int_of_char(c) + 32)
  else
    c
