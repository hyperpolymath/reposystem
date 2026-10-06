#!/usr/bin/env bash
# memory-index-health.sh — REPORT-ONLY health check for the Claude memory index.
#
# Checks three things that fail SILENTLY and have each already cost real work:
#   1. SIZE      MEMORY.md past its ~24KB limit loads TRUNCATED; the tail is lost
#                with no warning. (Stated in MEMORY.md's own line 3.)
#   2. DEAD LINKS  An index line pointing at a file that no longer exists is
#                load-bearing FALSE information — a "resume here" pointer to a
#                deleted checkpoint sent a session looking for work that was done.
#   3. ORPHANS   Memory files on disk that nothing indexes. Informational: not a
#                defect (tier-2 files are deliberately unindexed), but the ratio
#                is the signal for when curation is overdue.
#
# THIS SCRIPT NEVER WRITES TO MEMORY.md. MEMORY.md has concurrent writers across
# live sessions: a read-modify-write silently drops a peer's line added mid-edit.
# Report only — a human or a higher tier decides what to change.
#
# Exit: 0 = healthy, 1 = problems found, 2 = could not run.

set -uo pipefail

MEM_DIR="${MEMORY_DIR:-$HOME/.claude/projects/-home-hyperpolymath-developer/memory}"
INDEX="$MEM_DIR/MEMORY.md"
LIMIT="${MEMORY_LIMIT_BYTES:-24576}"   # ~24KB hard truncation limit
WARN_AT=$(( LIMIT * 90 / 100 ))        # start warning at 90%

GREP=/usr/bin/grep
[ -x "$GREP" ] || GREP=grep

if [ ! -f "$INDEX" ]; then
  echo "FATAL: no index at $INDEX" >&2
  exit 2
fi

problems=0
echo "memory-index-health  as-of $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "index: $INDEX"
echo

# ---------------------------------------------------------------- 1. SIZE
size=$(stat -c %s "$INDEX")
pct=$(( size * 100 / LIMIT ))
printf '1. SIZE  %s bytes / %s limit (%s%%)\n' "$size" "$LIMIT" "$pct"
if [ "$size" -gt "$LIMIT" ]; then
  printf '   OVER LIMIT by %s bytes — THIS FILE IS LOADING TRUNCATED.\n' "$(( size - LIMIT ))"
  printf '   Everything past the cut is invisible to every new session.\n'
  problems=$(( problems + 1 ))
elif [ "$size" -gt "$WARN_AT" ]; then
  printf '   within %s bytes of the limit — curation due soon.\n' "$(( LIMIT - size ))"
else
  printf '   OK (%s bytes of headroom)\n' "$(( LIMIT - size ))"
fi
echo

# ------------------------------------------------- 2. DEAD LINKS + PATHS
# (a) markdown link targets: [text](target.md) — resolved against the memory dir.
dead_links=0
checked_links=0
while IFS= read -r target; do
  case "$target" in
    http://*|https://*|"") continue ;;
  esac
  target="${target%%#*}"                       # strip any #anchor
  [ -n "$target" ] || continue
  checked_links=$(( checked_links + 1 ))
  if [ ! -e "$MEM_DIR/$target" ]; then
    printf '   DEAD LINK  %s\n' "$target"
    dead_links=$(( dead_links + 1 ))
  fi
done < <("$GREP" -oE '\]\([^)]+\)' "$INDEX" | sed -e 's/^](//' -e 's/)$//' | sort -u)

# (b) backticked filesystem paths ending .md — the shape that went dead before.
#     Resolved against several plausible roots; found under ANY = alive.
dead_paths=0
checked_paths=0
while IFS= read -r p; do
  [ -n "$p" ] || continue
  case "$p" in */*) ;; *) continue ;; esac   # bare names aren't path claims
  # Skip code snippets: a glob or a shell variable is an illustration of a
  # command, not a claim that a file exists. (`$dir/*.md` in a trap writeup
  # is the bug being described, not a broken pointer.)
  case "$p" in *'*'*|*'?'*|*'$'*|*'['*) continue ;; esac
  checked_paths=$(( checked_paths + 1 ))
  found=0
  for root in "$MEM_DIR" "$HOME" "$HOME/developer" ""; do
    if [ -e "$root/$p" ] || { [ -z "$root" ] && [ -e "$p" ]; }; then found=1; break; fi
  done
  if [ "$found" -eq 0 ]; then
    printf '   DEAD PATH  %s\n' "$p"
    dead_paths=$(( dead_paths + 1 ))
  fi
done < <("$GREP" -oE '`[^`]+\.md`' "$INDEX" | tr -d '`' | sort -u)

printf '2. LINKS  %s markdown targets, %s backticked paths checked\n' \
       "$checked_links" "$checked_paths"
if [ "$(( dead_links + dead_paths ))" -eq 0 ]; then
  printf '   OK — every target resolves.\n'
else
  printf '   %s dead: %s link(s), %s path(s) above.\n' \
         "$(( dead_links + dead_paths ))" "$dead_links" "$dead_paths"
  printf '   A dead pointer in the index is FALSE information, not a missing file.\n'
  problems=$(( problems + 1 ))
fi
echo

# ------------------------------------------------------------- 3. ORPHANS
on_disk=$(ls -1 "$MEM_DIR"/*.md 2>/dev/null | wc -l)
indexed=$(printf '%s\n' "$checked_links")
printf '3. FILES  %s .md files on disk, %s indexed targets\n' "$on_disk" "$indexed"
printf '   %s unindexed (tier-2 and closed topics are deliberately unindexed —\n' \
       "$(( on_disk - indexed ))"
printf '   informational, recalled by description, not a defect).\n'
echo

# ----------------------------------------------------------------- VERDICT
if [ "$problems" -eq 0 ]; then
  echo "VERDICT: healthy."
  exit 0
fi
echo "VERDICT: $problems problem area(s) — report only, nothing was changed."
exit 1
