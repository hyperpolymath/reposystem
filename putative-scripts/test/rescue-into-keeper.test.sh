#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Tests for scripts/rescue-into-keeper.sh. Run: scripts/test/rescue-into-keeper.test.sh
# Control 2 is the 2026-10-02 regression: a loser that is a WORKTREE of the keeper
# shares its refs, so the WIP snapshot looked "already reachable" and was dropped.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd -P)
script=${RESCUE_SCRIPT:-$here/../rescue-into-keeper.sh}
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

# check NAME CONDITION... — record a pass when the command succeeds, else a fail.
check() {
  local name=$1; shift
  if "$@"; then pass=$((pass+1)); echo "ok   $name"; else fail=$((fail+1)); echo "FAIL $name"; fi
}

# has_wip KEEPER TAG — true when the keeper holds a rescued WIP ref for TAG.
has_wip() { git -C "$1" rev-parse -q --verify "refs/rescued/$2/wip" >/dev/null; }

git init -q -b main "$tmp/keeper"
echo a > "$tmp/keeper/f"; git -C "$tmp/keeper" add f; git -C "$tmp/keeper" commit -qm init

# 1. Separate clone with a dirty file: WIP must be kept.
git clone -q "$tmp/keeper" "$tmp/clone"; echo dirty > "$tmp/clone/f"
"$script" "$tmp/clone" "$tmp/keeper" t-clone >/dev/null
check "clone loser keeps WIP" has_wip "$tmp/keeper" t-clone

# 2. Worktree of the keeper with a dirty file: WIP must be kept (the regression).
git -C "$tmp/keeper" worktree add -q "$tmp/wt" -b side; echo dirty > "$tmp/wt/f"
"$script" "$tmp/wt" "$tmp/keeper" t-wt >/dev/null
check "worktree loser keeps WIP" has_wip "$tmp/keeper" t-wt

# 3. Clean clone with nothing unique: nothing kept (the pruning still works).
git clone -q "$tmp/keeper" "$tmp/clean"
"$script" "$tmp/clean" "$tmp/keeper" t-clean >/dev/null
check "clean loser keeps nothing" test -z "$(git -C "$tmp/keeper" for-each-ref refs/rescued/t-clean/)"

echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
