#!/bin/sh
# SPDX-License-Identifier: PMPL-1.0-or-later
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
#
# fix-stale-submodule-urls.sh — repair submodule entries that sync-aggregator
# left as `warn ... (update failed)`, where the cause is a renamed/deleted
# GitHub repo whose .gitmodules URL is now stale.
#
# For each warned submodule it asks the GitHub API for the canonical name
# (the API follows rename redirects). If the canonical owner/name differs from
# what .gitmodules records, it rewrites submodule.<name>.url to the canonical
# SSH URL and runs `git submodule sync`. Deleted repos (API 404) are reported,
# not touched.
#
# DRY-RUN by default. --apply writes .gitmodules + `git submodule sync`.
# Does NOT commit or push (sync-aggregator owns that). Run only AFTER
# sync-aggregator has finished (it must hold no git lock on the aggregator).
#
# Usage: fix-stale-submodule-urls.sh [--apply] [--log FILE] [AGG_DIR]
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
apply=no; LOG=/tmp/sync-aggregator.log; AGG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) apply=yes ;;
    --log)   LOG=$2; shift ;;
    --*)     echo "unknown flag $1" >&2; exit 2 ;;
    *)       AGG=$1 ;;
  esac
  shift
done
AGG=${AGG:-"$ROOT/../repos-monorepo"}
[ -d "$AGG/.git" ] || { echo "not a git repo: $AGG" >&2; exit 1; }
[ -f "$LOG" ] || { echo "no sync log: $LOG" >&2; exit 1; }

# Refuse to run while sync-aggregator still holds the aggregator.
if pgrep -f 'sync-aggregator.sh' >/dev/null 2>&1; then
  echo "refusing: sync-aggregator.sh still running (git lock contention)." >&2
  exit 3
fi

warned=$(grep -E '^[[:space:]]+warn ' "$LOG" | awk '{print $2}' | sort -u)
[ -n "$warned" ] || { echo "no warned submodules in $LOG — nothing to fix."; exit 0; }

echo "warned submodules: $(echo "$warned" | tr '\n' ' ')"
echo "mode: $([ $apply = yes ] && echo APPLY || echo dry-run)"
echo

owner=hyperpolymath
for name in $warned; do
  cur=$(git -C "$AGG" config -f .gitmodules --get "submodule.$name.url" 2>/dev/null || echo "")
  canon=$(gh api "repos/$owner/$name" -q .full_name 2>/dev/null || echo "")
  if [ -z "$canon" ]; then
    echo "  DELETED?  $name — GitHub API 404 (no canonical repo). Manual decision needed."
    continue
  fi
  newurl="git@github.com:$canon.git"
  if [ "$cur" = "$newurl" ]; then
    echo "  TRANSIENT $name — URL already canonical ($cur). Re-run sync-aggregator; likely a fetch blip."
    continue
  fi
  echo "  RENAMED   $name: $cur  ->  $newurl"
  if [ "$apply" = yes ]; then
    git -C "$AGG" config -f .gitmodules "submodule.$name.url" "$newurl"
    git -C "$AGG" submodule sync -- "$name" >/dev/null 2>&1 || true
    git -C "$AGG" submodule update --init --remote -- "$name" >/dev/null 2>&1 \
      && echo "            fixed + fetched" \
      || echo "            url rewritten but fetch still failed — inspect manually"
  fi
done

echo
if [ "$apply" = yes ]; then
  echo "Done. .gitmodules updated (NOT committed). Re-run: just sync-aggregator --push"
  echo "Then regenerate the manifest: just repos-manifest"
else
  echo "Dry-run only. Re-run with --apply to rewrite .gitmodules."
fi
