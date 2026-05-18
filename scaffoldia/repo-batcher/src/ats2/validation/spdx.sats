(*
** SPDX-License-Identifier: PMPL-1.0-or-later
**
** SPDX license-identifier validation - INTERFACE (real Postiats 0.4.2)
**
** This module provides SYNTACTIC SPDX-id validation and SPDX header
** construction. It is layered on top of the known-list membership test
** `is_valid_spdx` exported by operations/types.sats; this module adds:
**   - structural validation (non-empty, allowed character class) so that
**     ids outside the bundled list can still be recognised as
**     well-formed SPDX expressions,
**   - comment-style selection per file extension,
**   - SPDX header line construction.
**
** HONESTY NOTE: structural validity is a syntactic check, NOT a claim
** that the identifier names a real SPDX license. Authoritative
** membership remains `is_valid_spdx`. Returned header strings are
** caller-owned Strptr1 (free once via strptr_free).
*)

staload "operations/types.sats"

(* True iff every char of `s` is in [A-Za-z0-9.+-] and s is non-empty:
** the SPDX short-form identifier character class. *)
fun spdx_wellformed (s: string): bool

(* Authoritative-or-structural: known list OR well-formed shape.
** Used by tooling that must accept new-but-syntactically-valid ids. *)
fun spdx_acceptable (s: string): bool

(* Comment prefix for a file extension (".rs" -> slashslash, ".sh" ->
** hash, ".dats" -> the ATS open-comment digraph, ...). Returns a
** freshly allocated Strptr1 (free via strptr_free). It is a Strptr1
** rather than a shared static `string` specifically so the ATS-family
** prefix can be assembled from single-character literals at runtime.
** RATIONALE: Postiats 0.4.2 has a lexer defect whereby the ATS
** open-comment digraph, when it appears inside a double-quoted string
** literal, is still scanned as a real block-comment opener and
** swallows source until a close-comment digraph (reproduced
** minimally). We therefore never write that digraph literally
** anywhere in this codebase (including prose comments); it is built
** char-by-char. Sound workaround, identical runtime value. *)
fun comment_prefix_for_ext (ext: string): Strptr1

(* Builds: "<prefix> SPDX-License-Identifier: <license>\n".
** Result is a freshly allocated Strptr1 (free via strptr_free). *)
fun make_spdx_header (license: string, comment_prefix: string): Strptr1
