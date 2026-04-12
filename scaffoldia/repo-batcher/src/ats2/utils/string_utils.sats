(*
** SPDX-License-Identifier: PMPL-1.0-or-later
**
** String Utility Functions - Interface
*)

(* ========== String Search ========== *)

fun string_index_of(haystack: string, needle: string): int
fun string_rindex_of(haystack: string, needle: char): int
fun string_contains(haystack: string, needle: string): bool

(* ========== String Extraction ========== *)

fun string_substring(s: string, start: int, len: int): string
fun string_suffix(s: string, start: int): string
fun string_prefix(s: string, len: int): string

(* ========== String Trimming ========== *)

fun string_trim(s: string): string
fun string_ltrim(s: string): string
fun string_rtrim(s: string): string

(* ========== String Replacement ========== *)

fun string_replace(str: string, old: string, new: string): string
fun string_replace_first(str: string, old: string, new: string): string

(* ========== String Building ========== *)

fun string_join(strings: List0(string), sep: string): string
fun string_split(s: string, sep: string): List0(string)

(* ========== Integer Conversion ========== *)

fun tostring_int(n: int): string

(* ========== String Validation ========== *)

fun string_is_empty(s: string): bool
fun string_is_nonempty(s: string): bool
fun string_is_whitespace(s: string): bool

(* ========== String Comparison ========== *)

fun string_equal_ci(s1: string, s2: string): bool
