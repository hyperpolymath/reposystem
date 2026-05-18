(*
** SPDX-License-Identifier: PMPL-1.0-or-later
**
** SPDX-audit operation - IMPLEMENTATION (real Postiats 0.4.2)
**
** CANONICAL BUILD: from src/ats2 with `-IATS .`.
** Shell strings via string_append (freed once); effects via the
** verified effects layer. No `+`, no `prefix` identifier.
*)

#include "share/atspre_define.hats"
#include "share/atspre_staload.hats"

staload "operations/types.sats"
staload "operations/effects.sats"
staload "utils/string_utils.sats"
staload "operations/spdx_audit.sats"   (* self: bind implements for patscc *)

(* No `$UNSAFE` in this module: ownership goes through the single
** audited boundaries (string_utils combinators, sys_run_owned). *)

fn istr (n: int): Strptr1 = tostring_int(n)

implement count_missing_spdx (base_dir, max_depth) = let
  val c0 = string_append("find ", base_dir)
  val c1 = strptr_append_str(c0, " -maxdepth ")
  val c2 = strptr_append_strptr(c1, istr(max_depth))
  val c3 = strptr_append_str(c2, " -type f \\( -name '*.dats' -o -name '*.sats' -o -name '*.rs' -o -name '*.zig' -o -name '*.idr' \\) 2>/dev/null | xargs -r grep -L 'SPDX-License-Identifier:' 2>/dev/null | wc -l > /tmp/.rb56_spdx_audit")
  val rc = sys_run_owned(c3)
in
  if ~wexit_ok(rc) then ~1
  else let
    val f = fileref_open_opt("/tmp/.rb56_spdx_audit", file_mode_r)
  in
    case+ f of
    | ~Some_vt(fr) => let
        val line = fileref_get_line_string(fr)
        val () = fileref_close(fr)
        val n = strptr_parse_int_free(strptr_trim_free(line))
      in
        if n < 0 then 0 else n
      end
    | ~None_vt() => 0
  end
end

implement execute_spdx_audit (base_dir, max_depth) = let
  val miss = count_missing_spdx(base_dir, max_depth)
in
  if miss < 0 then @{
    success_count = 0, failure_count = 1, skipped_count = 0,
    message = "spdx-audit: scan failed" }
  else if miss = 0 then @{
    success_count = 1, failure_count = 0, skipped_count = 0,
    message = "spdx-audit: all scanned files carry an SPDX header" }
  else @{
    success_count = 0, failure_count = miss, skipped_count = 0,
    message = "spdx-audit: files missing SPDX header (see /tmp/.rb56_spdx_audit)" }
end
