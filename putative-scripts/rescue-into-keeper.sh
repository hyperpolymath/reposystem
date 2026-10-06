#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# rescue-into-keeper.sh <loser> <keeper> <tag>
#
# Make a spare copy of a repo deletable with zero loss, without pushing anywhere.
#  1. Uncommitted state in <loser> (tracked + untracked, respecting .gitignore) is
#     captured as a commit object via a throwaway index; <loser>'s worktree, index
#     and branches are not modified.
#  2. Every branch of <loser> (+ that WIP commit) is fetched into <keeper> under
#     refs/rescued/<tag>/...
#  3. Rescued refs whose tip is already reachable from <keeper>'s own refs are
#     deleted again, so only genuinely unique work remains under refs/rescued/.
#  4. Verifies every loser branch tip now exists as an object in <keeper>.
# Prints one TSV line: tag  loser  keeper  branches  unique_refs  wip  status
# Exit 0 only when the loser is provably safe to delete.
set -uo pipefail

loser=${1:?loser}; keeper=${2:?keeper}; tag=${3:?tag}
tag=${tag//[^A-Za-z0-9._-]/_}
# Print one tab-separated result row for this rescue.
out() { printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$tag" "$loser" "$keeper" "$1" "$2" "$3" "$4"; }

git -C "$loser" rev-parse --git-dir >/dev/null 2>&1 || { out - - - "FAIL:loser-not-a-repo"; exit 2; }
git -C "$keeper" rev-parse --git-dir >/dev/null 2>&1 || { out - - - "FAIL:keeper-not-a-repo"; exit 2; }
[ "$(cd "$loser" && pwd -P)" != "$(cd "$keeper" && pwd -P)" ] || { out - - - "FAIL:same-repo"; exit 2; }

# 1. WIP snapshot without touching the loser's index or worktree.
wip=none
if [ -n "$(git -C "$loser" status --porcelain --untracked-files=all 2>/dev/null | head -1)" ]; then
  tmpidx=$(mktemp); rm -f "$tmpidx"
  if git -C "$loser" rev-parse -q --verify HEAD >/dev/null; then
    GIT_INDEX_FILE=$tmpidx git -C "$loser" read-tree HEAD
    parent=(-p HEAD)
  else
    parent=()
  fi
  # Refuse to snapshot un-ignored build output (target/, node_modules/ ...) as WIP.
  nuntr=$(git -C "$loser" ls-files --others --exclude-standard 2>/dev/null | wc -l)
  if [ "$nuntr" -gt "${RESCUE_MAX_UNTRACKED:-20000}" ]; then
    rm -f "$tmpidx"; out - - - "FAIL:untracked=$nuntr"; exit 5
  fi
  GIT_INDEX_FILE=$tmpidx git -C "$loser" add -A . 2>/dev/null
  tree=$(GIT_INDEX_FILE=$tmpidx git -C "$loser" write-tree)
  rm -f "$tmpidx"
  wip=$(git -C "$loser" -c user.name=rescue -c user.email=rescue@localhost \
        commit-tree "$tree" "${parent[@]}" -m "rescue WIP snapshot of $loser ($tag)")
  git -C "$loser" update-ref refs/rescue-wip "$wip"
fi

# 2. Fetch everything into the keeper (local transport, no network).
specs=('+refs/heads/*:refs/rescued/'"$tag"'/heads/*')
[ "$wip" != none ] && specs+=('+refs/rescue-wip:refs/rescued/'"$tag"'/wip')
if ! git -C "$keeper" fetch --no-tags --quiet "$(cd "$loser" && pwd -P)" "${specs[@]}" 2>/dev/null; then
  # Detached-HEAD-only or shallow repos: fall back to HEAD.
  git -C "$keeper" fetch --no-tags --quiet "$(cd "$loser" && pwd -P)" "+HEAD:refs/rescued/$tag/HEAD" 2>/dev/null \
    || { out - - "$wip" "FAIL:fetch"; exit 3; }
fi
# Detached HEAD in the loser that is on no branch.
if ! git -C "$loser" symbolic-ref -q HEAD >/dev/null && git -C "$loser" rev-parse -q --verify HEAD >/dev/null; then
  git -C "$keeper" fetch --no-tags --quiet "$(cd "$loser" && pwd -P)" "+HEAD:refs/rescued/$tag/HEAD" 2>/dev/null
fi

# 3. Drop rescued refs already reachable from the keeper's own history.
unique=0
while read -r sha ref; do
  # refs/rescue-wip is our own scratch ref; a worktree loser shares it with the
  # keeper, so counting it would make every WIP snapshot look already reachable.
  r=$(git -C "$keeper" rev-list -n1 "$sha" --not --exclude='refs/rescued/*' --exclude='refs/rescue-wip' --all 2>/dev/null); rc=$?
  if [ "$rc" -eq 0 ] && [ -z "$r" ]; then
    git -C "$keeper" update-ref -d "$ref"
  else
    unique=$((unique+1))
  fi
done < <(git -C "$keeper" for-each-ref --format='%(objectname) %(refname)' "refs/rescued/$tag/")

# 4. Verify: every loser branch tip (and HEAD) is an object in the keeper.
branches=0; missing=0
while read -r sha; do
  branches=$((branches+1))
  git -C "$keeper" cat-file -e "$sha^{commit}" 2>/dev/null || missing=$((missing+1))
done < <( { git -C "$loser" for-each-ref --format='%(objectname)' refs/heads/; git -C "$loser" rev-parse -q --verify HEAD; [ "$wip" != none ] && echo "$wip"; } | sort -u)

if [ "$missing" -eq 0 ]; then out "$branches" "$unique" "$wip" OK; exit 0
else out "$branches" "$unique" "$wip" "FAIL:missing=$missing"; exit 4; fi
