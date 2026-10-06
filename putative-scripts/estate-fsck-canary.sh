#!/usr/bin/env bash
# estate-fsck-canary.sh — detect object-store and index corruption across the estate
# in DAYS, not three weeks.
#
# Why this exists: the 2026-08-16 pack damage went unnoticed until 2026-09-02
# because nothing ever looked. All 22 damaged repos were hit inside a 32-minute
# window; a daily snapshot would have caught it the next morning.
#
# It measures TWO different failures, because they have different causes and
# neither test sees the other (see memory: index-vs-pack-corruption):
#   * object store  — `git fsck --connectivity-only`   (pack/loose object damage)
#   * index         — `git --no-optional-locks status` (torn .git/index writes)
# 23 of 42 "corrupt" checkouts in 2026-09-02 had ONLY a bad .git/index.
# NOTE: a bad index ALSO trips fsck (fsck reads the index) — verified against a
# deliberately garbled fixture, which returned fsck rc=128. So the second column
# is not there for DETECTION; it is there for ATTRIBUTION: it names WHICH
# worktree is at fault (fsck is per object store, indexes are per worktree) and
# its error text separates index damage ("bad index", "unknown index entry
# format") from pack damage ("inflate:", "missing"). Do not drop it.
#
# READ-ONLY. It never commits, never pushes, never fetches, never touches a ref,
# and never refreshes an index (`--no-optional-locks`). Per the estate rule:
# scripts that sweep the estate never commit and never push.
#
# THE ALARM IS THE DELTA, not the absolute list. Some stores are expected to be
# unhappy (the quarantine is full of halted rebases). What matters is a store that
# was clean yesterday and is not clean today.
#
# Usage:
#   scripts/estate-fsck-canary.sh                     # daily run, the normal case
#   scripts/estate-fsck-canary.sh --full              # full fsck, not connectivity-only (slow; weekly at most)
#   scripts/estate-fsck-canary.sh --include-quarantine
#   scripts/estate-fsck-canary.sh --trees "hyper-repos meta-repos repos"
#   scripts/estate-fsck-canary.sh --timeout 300 --out /some/dir
#
# Expect ~10-25 minutes over ~570 stores. Run it in the background:
#   nohup scripts/estate-fsck-canary.sh > ~/fsck-canary.out 2>&1 &
#
set -uo pipefail

DEV="${DEV:-/home/hyperpolymath/developer}"
TREES=("hyper-repos" "meta-repos")
OUT="$DEV/logs/fsck-canary"
FSCK_ARGS=(--connectivity-only --no-dangling --no-progress)
TIMEOUT=180
INCLUDE_QUARANTINE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --full)               FSCK_ARGS=(--no-dangling --no-progress); shift ;;
    --include-quarantine) INCLUDE_QUARANTINE=1; shift ;;
    --trees)              read -r -a TREES <<< "$2"; shift 2 ;;
    --timeout)            TIMEOUT="$2"; shift 2 ;;
    --out)                OUT="$2"; shift 2 ;;
    -h|--help)            sed -n '2,32p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

[ "$INCLUDE_QUARANTINE" = 1 ] && TREES+=("_QUARANTINE-2026-09-03-halted-rebase")

mkdir -p "$OUT"
TODAY="$(date +%F)"
REPORT="$OUT/$TODAY.tsv"
PREV="$(find "$OUT" -maxdepth 1 -name '*.tsv' ! -name "$TODAY.tsv" 2>/dev/null | sort | tail -1)"

# --- enumerate ---------------------------------------------------------------
# `-name .git` WITHOUT `-type d`: a linked worktree's .git is a FILE, and
# `find -type d -name .git` misses it entirely.
#
# fsck runs ONCE PER OBJECT STORE (--git-common-dir), because worktrees share one
# store and fscking each separately is the same work N times over. But the INDEX
# probe runs for EVERY worktree, because each worktree has its own .git/index and
# a torn index in one is invisible from another. 44 of the estate's 611 .git
# entries are linked worktrees; deduping them away would have blinded this test.
PAIRS="$(mktemp)"; CANDS="$(mktemp)"
trap 'rm -f "$PAIRS" "$CANDS"' EXIT

for t in "${TREES[@]}"; do
  [ -e "$DEV/$t" ] || continue
  find "$DEV/$t" -name .git -print0 2>/dev/null >> "$CANDS"
done

while IFS= read -r -d '' g; do
  d="$(dirname "$g")"
  cd "$d" 2>/dev/null || continue
  cdir="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || continue
  [ -n "$cdir" ] && printf '%s\t%s\n' "$cdir" "$d"
done < "$CANDS" | sort -u > "$PAIRS"

TOTAL="$(wc -l < "$PAIRS")"
STORECOUNT="$(cut -f1 "$PAIRS" | sort -u | wc -l)"
echo "estate-fsck-canary  $TODAY"
echo "trees      : ${TREES[*]}"
echo "mode       : ${FSCK_ARGS[*]}"
echo "worktrees  : $TOTAL   object stores: $STORECOUNT"
echo "report     : $REPORT"
echo "compare to : ${PREV:-<none — this is the baseline run>}"
echo

printf 'store\twork\tvendored\tfsck_rc\tindex_rc\tloose\tsize_kb\tpacks\trefs\tfsck_first_error\tindex_error\n' > "$REPORT"

# A vendored checkout (Lake/npm/cargo deps) is re-downloadable, so its corruption
# is noise, not loss. Matched on path COMPONENTS — substring matching on path
# fragments false-positives on repo NAMES (`corpus` once matched `squisher-corpus`).
is_vendored() {
  case "/$1/" in
    */.lake/packages/*|*/node_modules/*|*/vendor/*|*/.cargo/*|*/target/*|*/_build/*) return 0 ;;
  esac
  return 1
}

i=0; last_cdir=""; fsck_rc=0; fsck_err=""; loose=""; size=""; packs=""; refs=""
while IFS=$'\t' read -r cdir work; do
  i=$((i+1))
  [ $((i % 50)) -eq 0 ] && echo "  ... $i / $TOTAL" >&2

  vend=no; is_vendored "$work" && vend=yes

  if [ "$cdir" != "$last_cdir" ]; then
    fsck_out="$(timeout "$TIMEOUT" git --git-dir="$cdir" fsck "${FSCK_ARGS[@]}" 2>&1)"; fsck_rc=$?
    fsck_err="$(printf '%s' "$fsck_out" | grep -m1 -E '^(error|fatal|missing|broken|dangling)' | cut -c1-160 | tr '\t\n' '  ')"
    co="$(git --git-dir="$cdir" count-objects -v 2>/dev/null)"
    loose="$(printf '%s\n' "$co" | awk '/^count:/{print $2}')"
    size="$(printf '%s\n' "$co" | awk '/^size-pack:/{print $2}')"
    packs="$(printf '%s\n' "$co" | awk '/^packs:/{print $2}')"
    refs="$(git --git-dir="$cdir" for-each-ref 2>/dev/null | wc -l)"
    last_cdir="$cdir"
  fi

  # Index probe, per worktree. --no-optional-locks so we never rewrite the index
  # we are testing — this script must not mutate a single repo.
  index_rc=0; index_err=""
  if [ -d "$work" ]; then
    idx_out="$(cd "$work" 2>/dev/null && timeout 60 git --no-optional-locks status --porcelain --untracked-files=no 2>&1 >/dev/null)"; index_rc=$?
    index_err="$(printf '%s' "$idx_out" | grep -m1 -E '^(error|fatal)' | cut -c1-160 | tr '\t\n' '  ')"
  fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "${cdir#$DEV/}" "${work#$DEV/}" "$vend" "$fsck_rc" "$index_rc" \
    "${loose:-?}" "${size:-?}" "${packs:-?}" "$refs" "$fsck_err" "$index_err" >> "$REPORT"
done < "$PAIRS"
# --- summary -----------------------------------------------------------------
# fsck failures are counted over DISTINCT OBJECT STORES; a store with 9 worktrees
# would otherwise be reported as 9 failures. Index failures are counted per
# worktree, because that is genuinely per-worktree.
echo
awk -F'\t' 'NR>1{
  rows++;
  if (!(($1) in seen)) { seen[$1]=1; stores++; if ($4!=0) { f++; if ($3=="no") fr++ } }
  if ($5!=0) { x++; if ($3=="no") xr++ }
} END{
  printf "worktree rows       : %d\n", rows;
  printf "object stores       : %d\n", stores;
  printf "fsck  failures      : %d stores  (%d real, %d vendored)\n", f, fr, f-fr;
  printf "index failures      : %d worktrees  (%d real, %d vendored)\n", x, xr, x-xr;
  if (fr+xr==0) print "\nNo corruption in non-vendored checkouts.";
}' "$REPORT"

# --- THE ALARM: what changed since the last run ------------------------------
if [ -n "${PREV:-}" ]; then
  echo
  echo "=== DELTA vs $(basename "$PREV" .tsv) ==="
  join -t $'\t' -j 1 \
    <(awk -F'\t' 'NR>1{print $2"\t"$4"\t"$5"\t"$9}' "$PREV"   | sort -k1,1) \
    <(awk -F'\t' 'NR>1{print $2"\t"$4"\t"$5"\t"$9}' "$REPORT" | sort -k1,1) \
  | awk -F'\t' '
      $2=="0" && $5!="0" { printf "NEW FSCK FAILURE   %s\n", $1; a++ }
      $3=="0" && $6!="0" { printf "NEW INDEX FAILURE  %s\n", $1; a++ }
      $4+0 > $7+0        { printf "REFS LOST %s -> %s   %s\n", $4, $7, $1; a++ }
      END { if (!a) print "no new failures, no refs lost." }'

  echo
  comm -13 <(awk -F'\t' 'NR>1{print $2}' "$PREV" | sort) \
           <(awk -F'\t' 'NR>1{print $2}' "$REPORT" | sort) | sed 's/^/APPEARED   /'
  comm -23 <(awk -F'\t' 'NR>1{print $2}' "$PREV" | sort) \
           <(awk -F'\t' 'NR>1{print $2}' "$REPORT" | sort) | sed 's/^/VANISHED   /'
else
  echo
  echo "Baseline written. Run again tomorrow; the delta is the alarm."
fi
