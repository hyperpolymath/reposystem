(*
** SPDX-License-Identifier: PMPL-1.0-or-later
**
** String Utility Functions - Implementation (real Postiats 0.4.2)
**
** Verified idioms (each probed against patsopt 0.4.2 before use here):
** - `g1ofg0(s)` lifts `string` to length-indexed `string(n)`; `g1ofg0(x)`
**   lifts `int` to `int(i)` so runtime comparison guards refine `i` in the
**   static context (the standard sound Postiats bound-discharge idiom).
** - `string_length : string(n) -> size_t(n)`.
** - `string_make_substring : {i+j<=n}(string(n),size_t(i),size_t(j)) -> strnptr`
**   bounds proven from refined ints; result freed with `strnptr_free`.
** - `string_append(a,b) : (string,string) -> Strptr1` ; freed via `strptr_free`.
** - `s[i]` is sound when `i:size_t(k)` and `k < n` is proven.
**
** Documented unsafe boundary (SINGLE, audited): every `$UNSAFE` cast in
** repo-batcher string code is confined to the labelled combinator block
** below (strptr_append_str / _append_strptr / _prepend_str / _rtrim_free
** / _trim_free / strnptr_dup_free / _parse_int_free / _is_empty_free /
** _peek_is_empty). Each borrows owned linear bytes as `string` for one
** synchronous use then frees the owner exactly once; no other module
** uses `$UNSAFE`. See string_utils.sats for the full audit contract.
**
** NOT proven: returned strings are not certified minimal/canonical; functions
** are total over finite input with patsopt-checked termination metrics.
*)

#include "share/atspre_define.hats"
#include "share/atspre_staload.hats"

(* Self-staload its interface so separate `patscc -c` compilation
** binds these implements (the `-tc -s` proof flag does not carry over
** to compilation). Canonical: resolved via -IATS . from src/ats2. *)
staload "utils/string_utils.sats"

(* ---- internal helpers ---- *)

fn is_ws (c: char): bool =
  c = ' ' orelse c = '\t' orelse c = '\n' orelse c = '\r'

fn lower (c: char): char =
  if c >= 'A' andalso c <= 'Z'
    then int2char0(char2int0(c) + 32)
    else c

(* digit (0..9) -> a freshly owned 1-char string.
**
** PROOF-DEBT / CODEGEN NOTE: the previous `@[char][2](c,'\000')`
** cast-to-string idiom TYPECHECKS but provokes a Postiats 0.4.2
** codegen INTERROR (pats_ccomp_dynexp: HDEarrinit) — it cannot be
** compiled by patscc. We therefore avoid stack-array char buffers
** entirely and map each decimal digit to a static string literal,
** which is fully codegen-safe. This is a sound, total replacement
** for the only use char_to_str had (decimal rendering). *)
fn digit_to_str (d: int): Strptr1 =
  if d = 0 then string0_copy("0")
  else if d = 1 then string0_copy("1")
  else if d = 2 then string0_copy("2")
  else if d = 3 then string0_copy("3")
  else if d = 4 then string0_copy("4")
  else if d = 5 then string0_copy("5")
  else if d = 6 then string0_copy("6")
  else if d = 7 then string0_copy("7")
  else if d = 8 then string0_copy("8")
  else if d = 9 then string0_copy("9")
  else string0_copy("?")

(* ===== PROOF-DEBT: SOLE $UNSAFE LINEARITY BOUNDARY (string layer) =====
** See string_utils.sats for the full audit contract. These nine bodies
** are the ONLY $UNSAFE in repo-batcher string code. Each: borrow owned
** linear bytes as `string` -> exactly one synchronous use -> free owner
** exactly once -> return. `string_append` copies before any free. *)

implement strptr_append_str (p, t) = let
  val r = string_append($UNSAFE.strptr2string(p), t)
  val () = strptr_free(p)
in r end

implement strptr_append_strptr (p, q) = let
  val r = string_append($UNSAFE.strptr2string(p), $UNSAFE.strptr2string(q))
  val () = strptr_free(p)
  val () = strptr_free(q)
in r end

implement strptr_prepend_str (h, q) = let
  val r = string_append(h, $UNSAFE.strptr2string(q))
  val () = strptr_free(q)
in r end

implement strptr_rtrim_free (p) = let
  val r = string_rtrim($UNSAFE.strptr2string(p))
  val () = strptr_free(p)
in r end

implement strptr_trim_free (p) = let
  val r = string_trim($UNSAFE.strptr2string(p))
  val () = strptr_free(p)
in r end

implement strnptr_dup_free (p) = let
  val r = string0_copy($UNSAFE.strnptr2string(p))
  val () = strnptr_free(p)
in r end

implement strptr_parse_int_free (p) = let
  val r = g0string2int_int($UNSAFE.strptr2string(p))
  val () = strptr_free(p)
in r end

implement strptr_is_empty_free (p) = let
  val r = string_is_empty($UNSAFE.strptr2string(p))
  val () = strptr_free(p)
in r end

implement strptr_peek_is_empty (p) =
  string_is_empty($UNSAFE.strptr2string(p))

(* ===== end SOLE $UNSAFE LINEARITY BOUNDARY (string layer) ===== *)

(* substring with bounds proven from the {i+j<=n} constraint;
** the strnptr borrow is encapsulated in strnptr_dup_free above. *)
fn substr_raw {n,i,j:int | 0 <= i; 0 <= j; i + j <= n}
  (s: string(n), start: size_t(i), len: size_t(j)): Strptr1 = let
  val sub = string_make_substring(s, start, len)
in
  strnptr_dup_free(sub)
end

(* ========== String Search ========== *)

implement string_index_of(haystack0, needle0) = let
  val h = g1ofg0(haystack0)
  val nd = g1ofg0(needle0)
  val hn = string_length(h)
  val nn = string_length(nd)
  fun matchat
    {hl,nl:int | hl >= 0; nl >= 0} {p:nat | p <= hl}
    (h: string(hl), hl: size_t(hl), nd: string(nl), nl: size_t(nl),
     p: size_t(p)): bool = let
    fun go {j:nat | j <= nl} .<nl-j>. (j: size_t(j)): bool =
      if j >= nl then true
      else let
        val hi = p + j
      in
        if hi >= hl then false
        else if h[hi] <> nd[j] then false
        else go(succ(j))
      end
  in
    go(i2sz(0))
  end
  fun loop {hl,nl:int | hl >= 0; nl >= 0} {p:nat | p <= hl} .<hl-p>.
    (h: string(hl), hl: size_t(hl), nd: string(nl), nl: size_t(nl),
     p: size_t(p)): int =
    if p + nl > hl then ~1
    else if matchat(h, hl, nd, nl, p) then sz2i(p)
    else if p >= hl then ~1
    else loop(h, hl, nd, nl, succ(p))
in
  if sz2i(nn) = 0 then 0
  else if nn > hn then ~1
  else loop(h, hn, nd, nn, i2sz(0))
end

implement string_rindex_of(haystack0, c) = let
  val h = g1ofg0(haystack0)
  val n = string_length(h)
  fun loop {hl:int} {i:int | i >= ~1; i < hl} .<i+1>.
    (h: string(hl), i: int(i), hl: size_t(hl)): int =
    if i < 0 then ~1
    else if h[i2sz(i)] = c then i
    else loop(h, i - 1, hl)
in
  loop(h, sz2i(n) - 1, n)
end

implement string_contains(haystack, needle) =
  string_index_of(haystack, needle) >= 0

(* ========== String Extraction ========== *)

implement string_substring(s00, start00, len00) = let
  val s = g1ofg0(s00)
  val n = string_length(s)
  val start0 = g1ofg0(start00)
  val len0 = g1ofg0(len00)
in
  if start0 < 0 then string0_copy("")
  else let
    val st = i2sz(start0)
  in
    if st >= n then string0_copy("")
    else if len0 <= 0 then string0_copy("")
    else let
      val ln = i2sz(len0)
    in
      if st + ln <= n then substr_raw(s, st, ln)
      else substr_raw(s, st, n - st)
    end
  end
end

implement string_suffix(s00, start00) = let
  val s = g1ofg0(s00)
  val n = string_length(s)
  val start0 = g1ofg0(start00)
in
  if start0 < 0 then string0_copy("")
  else let
    val st = i2sz(start0)
  in
    if st >= n then string0_copy("")
    else substr_raw(s, st, n - st)
  end
end

implement string_prefix(s00, len00) = let
  val s = g1ofg0(s00)
  val n = string_length(s)
  val len0 = g1ofg0(len00)
in
  if len0 <= 0 then string0_copy("")
  else let
    val ln = i2sz(len0)
  in
    if ln <= n then substr_raw(s, i2sz(0), ln)
    else substr_raw(s, i2sz(0), n)
  end
end

(* ========== String Trimming ========== *)

implement string_ltrim(s00) = let
  val s = g1ofg0(s00)
  val n = string_length(s)
  fun find {sl:int} {i:nat | i <= sl} .<sl-i>.
    (s: string(sl), i: size_t(i), sl: size_t(sl)): int =
    if i >= sl then sz2i(sl)
    else if is_ws(s[i]) then find(s, succ(i), sl)
    else sz2i(i)
  val st = find(s, i2sz(0), n)
in
  if st >= sz2i(n) then string0_copy("")
  else string_suffix(s00, st)
end

implement string_rtrim(s00) = let
  val s = g1ofg0(s00)
  val n = string_length(s)
  fun find {sl:int} {i:int | i >= ~1; i < sl} .<i+1>.
    (s: string(sl), i: int(i), sl: size_t(sl)): int =
    if i < 0 then 0
    else if is_ws(s[i2sz(i)]) then find(s, i - 1, sl)
    else i + 1
  val ep = find(s, sz2i(n) - 1, n)
in
  if ep <= 0 then string0_copy("")
  else string_prefix(s00, ep)
end

implement string_trim(s00) = let
  val l = string_ltrim(s00)
in
  strptr_rtrim_free(l)
end

(* ========== Integer Conversion ========== *)

implement tostring_int(n0) = let
  val n = g1ofg0(n0)
  fun digits {x:nat} .<x>. (x: int(x), acc: Strptr1): Strptr1 =
    if x = 0 then acc
    else let
      val d = x mod 10
      val cstr = digit_to_str(d)
      val r = strptr_append_strptr(cstr, acc)
    in
      digits(x / 10, r)
    end
in
  if n = 0 then string0_copy("0")
  else if n < 0 then let
    val pos = digits(~n, string0_copy(""))
  in
    strptr_prepend_str("-", pos)
  end
  else digits(n, string0_copy(""))
end

(* ========== String Validation ========== *)

implement string_is_empty(s) =
  sz2i(string_length(g1ofg0(s))) = 0

implement string_is_nonempty(s) =
  sz2i(string_length(g1ofg0(s))) > 0

implement string_is_whitespace(s00) = let
  val s = g1ofg0(s00)
  val n = string_length(s)
  fun loop {sl:int} {i:nat | i <= sl} .<sl-i>.
    (s: string(sl), i: size_t(i), sl: size_t(sl)): bool =
    if i >= sl then true
    else if is_ws(s[i]) then loop(s, succ(i), sl)
    else false
in
  loop(s, i2sz(0), n)
end

(* ========== String Comparison ========== *)

implement string_equal_ci(s10, s20) = let
  val s1 = g1ofg0(s10)
  val s2 = g1ofg0(s20)
  val n1 = string_length(s1)
  val n2 = string_length(s2)
in
  if sz2i(n1) <> sz2i(n2) then false
  else let
    fun loop {la,lb:int} {i:nat | i <= la; i <= lb} .<la-i>.
      (a: string(la), b: string(lb),
       i: size_t(i), la: size_t(la), lb: size_t(lb)): bool =
      if i >= la then true
      else if i >= lb then true
      else if lower(a[i]) <> lower(b[i]) then false
      else loop(a, b, succ(i), la, lb)
  in
    loop(s1, s2, i2sz(0), n1, n2)
  end
end
