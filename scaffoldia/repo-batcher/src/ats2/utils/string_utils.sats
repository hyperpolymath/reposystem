(*
** SPDX-License-Identifier: PMPL-1.0-or-later
**
** String Utility Functions - Interface
**
** Real Postiats 0.4.2. Strings are immutable shared `string`; results that
** allocate are returned as `Strptr1` (a non-null linear string pointer the
** caller must free) so ownership is explicit and no GC is assumed.
*)

(* ========== String Search ========== *)

(* Index of first occurrence of `needle` in `haystack`, or ~1 if absent.
** Empty needle is found at position 0. *)
fun string_index_of(haystack: string, needle: string): int

(* Index of last occurrence of character `c`, or ~1 if absent. *)
fun string_rindex_of(haystack: string, c: char): int

(* True iff `needle` occurs in `haystack`. *)
fun string_contains(haystack: string, needle: string): bool

(* ========== String Extraction ========== *)

(* Substring [start, start+len) clamped to bounds; out-of-range -> "". *)
fun string_substring(s: string, start: int, len: int): Strptr1

(* Suffix from `start` to end; out-of-range -> "". *)
fun string_suffix(s: string, start: int): Strptr1

(* Prefix of length `len` (clamped). *)
fun string_prefix(s: string, len: int): Strptr1

(* ========== String Trimming ========== *)

fun string_ltrim(s: string): Strptr1
fun string_rtrim(s: string): Strptr1
fun string_trim(s: string): Strptr1

(* ========== Integer Conversion ========== *)

fun tostring_int(n: int): Strptr1

(* ========== String Validation ========== *)

fun string_is_empty(s: string): bool
fun string_is_nonempty(s: string): bool
fun string_is_whitespace(s: string): bool

(* ========== String Comparison ========== *)

fun string_equal_ci(s1: string, s2: string): bool
