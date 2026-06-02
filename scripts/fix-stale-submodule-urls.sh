#!/bin/sh
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
#
# fix-stale-submodule-urls.sh — classify and (optionally) remediate the
# submodule entries that sync-aggregator left as `warn ... (update failed)`.
#
# Empirically the warns fall into FOUR classes, not one:
#
#   RENAMED      GitHub repo renamed; .gitmodules URL stale. The API (which
#                follows rename redirects) returns a different canonical name.
#                Remediation: rewrite submodule.<sec>.url.  (--apply-renames)
#   NONEXISTENT  No such repo (API 404). The estate .gitmodules over-declares
#                repos that were never created. URL is already basename-correct
#                so a rewrite cannot help. Remediation: prune the declaration.
#                (--prune-nonexistent — destructive, separately gated)
#   WIKI         A `.wikis/<repo>.wiki` entry whose base repo lacks an enabled
#                wiki. Not a code repo; cannot be rewritten. Remediation:
#                prune.  (rolled into --prune-nonexistent, labelled WIKI)
#   TRANSIENT    Repo exists and the URL is already canonical — a fetch blip.
#                Remediation: just re-run sync-aggregator.  (no action here)
#
# DRY-RUN by default: prints the classified plan only. Nothing is committed or
# pushed (sync-aggregator owns that). Refuses to run while sync-aggregator is
# still active (git-lock contention on the aggregator).
#
# Usage:
#   fix-stale-submodule-urls.sh [--log FILE] [AGG_DIR]            # classify only
#   fix-stale-submodule-urls.sh --apply-renames [...]             # rewrite URLs
#   fix-stale-submodule-urls.sh --prune-nonexistent [...]         # remove decls
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
apply_renames=no; prune=no; LOG=/tmp/sync-aggregator.log; AGG=""; OWNER=hyperpolymath
while [ $# -gt 0 ]; do
  case "$1" in
    --apply-renames)     apply_renames=yes ;;
    --prune-nonexistent) prune=yes ;;
    --log)               LOG=$2; shift ;;
    --owner)             OWNER=$2; shift ;;
    --*)                 echo "unknown flag $1" >&2; exit 2 ;;
    *)                   AGG=$1 ;;
  esac
  shift
done
AGG=${AGG:-"$ROOT/../repos-monorepo"}
[ -d "$AGG/.git" ] || { echo "not a git repo: $AGG" >&2; exit 1; }
[ -f "$LOG" ]      || { echo "no sync log: $LOG" >&2; exit 1; }
if pgrep -f 'sync-aggregator\.sh' >/dev/null 2>&1; then
  echo "refusing: sync-aggregator.sh still running (git-lock contention)." >&2
  exit 3
fi

warned=$(grep -E '^[[:space:]]+warn ' "$LOG" | awk '{print $2}' | sort -u)
[ -n "$warned" ] || { echo "no warned submodules in $LOG — nothing to do."; exit 0; }

# path -> .gitmodules section name (handles slashes and leading-dot paths)
section_for() {
  git -C "$AGG" config -f .gitmodules --get-regexp '\.path$' \
    | awk -v P="$1" '$2==P{ sub(/\.path$/,"",$1); print $1 }'
}

# Canonical "owner/name" for a repo, following rename redirects. Empty if the
# repo does not exist. NOTE: `gh api` writes the error JSON body to STDOUT on
# 4xx, so a bare capture would yield `{"message":"Not Found"...}` and be
# mistaken for a value. We therefore STRICTLY validate the result shape.
canon_name() {
  _c=$(gh api "repos/$OWNER/$1" --jq '.full_name' 2>/dev/null || true)
  case "$_c" in
    */*) printf '%s' "$_c" | grep -Eq '^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$' \
           && printf '%s' "$_c" || printf '' ;;
    *)   printf '' ;;
  esac
}

n_ren=0; n_non=0; n_wiki=0; n_tr=0
plan=$(mktemp); trap 'rm -f "$plan"' EXIT

echo "warned: $(echo "$warned" | wc -l | tr -d ' ') entries   mode: renames=$apply_renames prune=$prune"
echo

for path in $warned; do
  sec=$(section_for "$path")
  [ -n "$sec" ] || { echo "  ??? $path — no .gitmodules section (skipped)"; continue; }
  cururl=$(git -C "$AGG" config -f .gitmodules --get "$sec.url" 2>/dev/null || echo "")

  case "$path" in
    *.wiki)
      base=$(basename "$path" .wiki)
      if [ -z "$(canon_name "$base")" ]; then
        echo "  WIKI(no-repo)  $path — base repo $OWNER/$base gone; PRUNE"
      else
        echo "  WIKI           $path — base repo exists, wiki clone failed; PRUNE (wikis aren't tracked content)"
      fi
      n_wiki=$((n_wiki+1)); echo "PRUNE $sec $path" >> "$plan"; continue ;;
  esac

  repo=$(basename "$path")
  canon=$(canon_name "$repo")
  if [ -z "$canon" ]; then
    echo "  NONEXISTENT    $path — $OWNER/$repo: API 404 (over-declared); PRUNE"
    n_non=$((n_non+1)); echo "PRUNE $sec $path" >> "$plan"; continue
  fi
  newurl="git@github.com:$canon.git"
  if [ "$cururl" = "$newurl" ]; then
    echo "  TRANSIENT      $path — exists, URL canonical; re-run sync-aggregator"
    n_tr=$((n_tr+1)); continue
  fi
  echo "  RENAMED        $path: $cururl -> $newurl"
  n_ren=$((n_ren+1)); echo "RENAME $sec $newurl" >> "$plan"
done

echo
echo "summary: RENAMED=$n_ren  NONEXISTENT=$n_non  WIKI=$n_wiki  TRANSIENT=$n_tr"
echo

did=no
if [ "$apply_renames" = yes ] && [ "$n_ren" -gt 0 ]; then
  echo "-- applying RENAME rewrites --"
  while read -r op sec val; do
    [ "$op" = RENAME ] || continue
    git -C "$AGG" config -f .gitmodules "$sec.url" "$val"
    git -C "$AGG" submodule sync -- "$(echo "$sec" | sed 's/^submodule\.//')" >/dev/null 2>&1 || true
    echo "  rewrote $sec.url -> $val"
  done < "$plan"
  did=yes
fi
if [ "$prune" = yes ] && [ $((n_non+n_wiki)) -gt 0 ]; then
  echo "-- pruning NONEXISTENT/WIKI declarations (.gitmodules + tree + config) --"
  while read -r op sec ppath; do
    [ "$op" = PRUNE ] || continue
    git -C "$AGG" config -f .gitmodules --remove-section "$sec" >/dev/null 2>&1 || true
    # Untrack the orphan gitlink so tree and .gitmodules agree, drop any
    # stale .git/config entry, and remove the (typically empty) placeholder.
    git -C "$AGG" rm --cached --quiet -- "$ppath" >/dev/null 2>&1 || true
    git -C "$AGG" config --remove-section "$sec" >/dev/null 2>&1 || true
    [ -e "$AGG/$ppath" ] && rm -rf "$AGG/${ppath:?}" 2>/dev/null || true
    echo "  pruned $ppath ($sec)"
  done < "$plan"
  did=yes
fi

echo
if [ "$did" = yes ]; then
  echo "Done. .gitmodules edited (NOT committed). Next:"
  echo "  just sync-aggregator --push   # pick up fixes, regenerate artifact"
  echo "  just repos-manifest           # propagate to repos.toml"
else
  echo "Dry-run only. Re-run with --apply-renames and/or --prune-nonexistent."
  echo "(--prune-nonexistent is destructive: it removes .gitmodules sections.)"
fi
