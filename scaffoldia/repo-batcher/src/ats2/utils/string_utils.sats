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

(* ========================================================================
** PROOF-DEBT: SOLE $UNSAFE LINEARITY BOUNDARY (string layer)
** ------------------------------------------------------------------------
** The IMPLEMENTATIONS of the functions below are the ONLY place
** `$UNSAFE.strptr2string` / `$UNSAFE.strnptr2string` appears in the
** repo-batcher string code. Each borrows an owned linear pointer's bytes
** as a shared `string` for exactly ONE synchronous call, then frees the
** owner exactly once; the borrowed view never escapes. Soundness is
** HAND-VERIFIED, NOT machine-proven (ATS2's linear checker is switched
** off inside an `$UNSAFE` cast):
**   - append/prepend: `string_append` copies BOTH arguments into a fresh
**     buffer before we `strptr_free` the owner — no use-after-free;
**   - rtrim/trim: the borrowed value is consumed synchronously by a
**     copying combinator before the owner is freed;
**   - parse/empty/dup: read-only borrow, owner freed immediately after;
**   - `strptr_peek_*` take `!Strptr1` (NON-consuming): pure read, no free,
**     caller retains ownership.
** Auditing repo-batcher string memory-safety == auditing ONLY this block.
** Every other module is $UNSAFE-free and IS machine-linearity-checked.
** ======================================================================== *)

(* p ++ t; consumes and frees p; result owned by caller. *)
fun strptr_append_str    (p: Strptr1, t: string): Strptr1
(* p ++ q; consumes and frees BOTH; result owned by caller. *)
fun strptr_append_strptr (p: Strptr1, q: Strptr1): Strptr1
(* h ++ q; consumes and frees q; result owned by caller. *)
fun strptr_prepend_str   (h: string, q: Strptr1): Strptr1
(* rtrim(p); consumes and frees p. *)
fun strptr_rtrim_free    (p: Strptr1): Strptr1
(* trim(p); consumes and frees p. *)
fun strptr_trim_free     (p: Strptr1): Strptr1
(* copy(p); consumes and frees the strnptr p. *)
fun strnptr_dup_free     (p: Strnptr1): Strptr1
(* parse decimal int from p; consumes and frees p. *)
fun strptr_parse_int_free (p: Strptr1): int
(* emptiness of p; consumes and frees p. *)
fun strptr_is_empty_free  (p: Strptr1): bool
(* emptiness of p WITHOUT consuming it (caller still owns/frees p). *)
fun strptr_peek_is_empty  (p: !Strptr1): bool
