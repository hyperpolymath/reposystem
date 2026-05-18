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

fn app (acc: Strptr1, tail: string): Strptr1 = let
  val r = string_append($UNSAFE.strptr2string(acc), tail)
  val () = strptr_free(acc)
in
  r
end

fn istr (n: int): Strptr1 = tostring_int(n)

implement count_missing_spdx (base_dir, max_depth) = let
  val ds = istr(max_depth)
  val c0 = string_append("find ", base_dir)
  val c1 = app(c0, " -maxdepth ")
  val c2 = app(c1, $UNSAFE.strptr2string(ds))
  val () = strptr_free(ds)
  val c3 = app(c2, " -type f \\( -name '*.dats' -o -name '*.sats' -o -name '*.rs' -o -name '*.zig' -o -name '*.idr' \\) 2>/dev/null | xargs -r grep -L 'SPDX-License-Identifier:' 2>/dev/null | wc -l > /tmp/.rb56_spdx_audit")
  val rc = sys_run($UNSAFE.strptr2string(c3))
  val () = strptr_free(c3)
in
  if ~wexit_ok(rc) then ~1
  else let
    val f = fileref_open_opt("/tmp/.rb56_spdx_audit", file_mode_r)
  in
    case+ f of
    | ~Some_vt(fr) => let
        val line = fileref_get_line_string(fr)
        val () = fileref_close(fr)
        val s = string_trim($UNSAFE.strptr2string(line))
        val () = strptr_free(line)
        val n = g0string2int_int($UNSAFE.strptr2string(s))
        val () = strptr_free(s)
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
