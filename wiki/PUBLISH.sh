#!/usr/bin/env sh
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath)
#
# PUBLISH.sh — mirror the in-repo wiki sources (wiki/*.md) into the GitHub wiki
# repository (reposystem.wiki.git).
#
# WHY THIS EXISTS: GitHub wikis are a separate git repo (<repo>.wiki.git) that is
# NOT writable from every CI/sandbox environment (egress policy may 403 the wiki
# host even when the main repo is reachable). The canonical, reviewable source of
# truth for every page therefore lives here under wiki/; this script publishes it.
#
# Usage:
#   sh wiki/PUBLISH.sh                       # uses the default ssh wiki URL
#   WIKI_URL=https://github.com/hyperpolymath/reposystem.wiki.git sh wiki/PUBLISH.sh
#   sh wiki/PUBLISH.sh <wiki-remote-url>     # explicit URL argument
#
# Idempotent: re-running republishes the current wiki/ contents. Only *.md pages
# (and the _Sidebar/_Footer nav) are pushed; this script and README.adoc are not.

set -eu

WIKI_URL="${1:-${WIKI_URL:-git@github.com:hyperpolymath/reposystem.wiki.git}}"
SRC_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Redact any embedded credentials (e.g. https://x-access-token:TOKEN@github.com/...)
# before printing — keeps tokens out of CI logs / terminals.
WIKI_URL_SAFE="$(printf '%s' "$WIKI_URL" | sed -E 's#//[^/@]*@#//***@#')"
echo "==> wiki source : $SRC_DIR"
echo "==> wiki remote : $WIKI_URL_SAFE"

# Clone the existing wiki, or initialise a fresh one if it has no commits yet.
if git clone --depth 1 "$WIKI_URL" "$WORK/wiki" 2>/dev/null; then
  echo "==> cloned existing wiki"
else
  echo "==> wiki empty or unclonable; initialising a new repo"
  git init -q "$WORK/wiki"
  ( cd "$WORK/wiki" && git remote add origin "$WIKI_URL" )
fi

# Copy every published page (markdown only). Exclude this script + the in-repo README.
found=0
for f in "$SRC_DIR"/*.md; do
  [ -e "$f" ] || continue
  cp "$f" "$WORK/wiki/"
  found=$((found + 1))
done
if [ "$found" -eq 0 ]; then
  echo "!! no .md pages found in $SRC_DIR — nothing to publish" >&2
  exit 1
fi
echo "==> staged $found page(s)"

cd "$WORK/wiki"
git add -A
if git diff --cached --quiet; then
  echo "==> wiki already up to date; nothing to push"
  exit 0
fi
git -c user.name="reposystem-wiki-bot" \
    -c user.email="paraordinate@yahoo.co.uk" \
    commit -q -m "docs(wiki): sync from wiki/ in main repo"

# GitHub wiki default branch is 'master'; fall back to current branch name.
BR="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo master)"
git push origin "HEAD:${BR}" || git push origin "HEAD:master"
echo "==> published to $WIKI_URL ($BR)"
