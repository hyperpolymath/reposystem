#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Positive + negative controls for scripts/audit-workspace-shape.sh.
# Also: IMPOSTOR (copied .git file) must be flagged without flagging the real owner.
set -uo pipefail
A=$(cd "$(dirname "$0")/.." && pwd)/audit-workspace-shape.sh
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
# Create a git repo at the given path with one empty commit.
g() { git -c init.defaultBranch=main init -q "$1" && git -C "$1" -c user.name=t -c user.email=t@t commit -q --allow-empty -m i; }
# Run the audit script against the fixture tree and print its exit code.
run() { AUDIT_DISKS=/nonexistent AUDIT_DEV=$T/dev AUDIT_HOME=$T/home AUDIT_WIN=$T/win AUDIT_OUT=$T/out.md "$@" bash "$A" >/dev/null; echo $?; }
pass=0; fail=0
# Evaluate an assertion; count it as a pass or print FAIL with its label.
ok() { if eval "$2"; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: $1"; fi; }

# Clean layout: one clone, one worktree in the right place.
mkdir -p $T/dev/hyper-repos $T/dev/worktrees $T/home/developer $T/win
g $T/dev/hyper-repos/a; git -C $T/dev/hyper-repos/a remote add origin git@github.com:o/a.git
git -C $T/dev/hyper-repos/a worktree add -q $T/dev/worktrees/a-x -b x
ok "clean layout exits 0" '[ "$(run)" = 0 ]'

# Planted positives, one at a time.
mkdir $T/dev/repos-stray;                     ok "root stray flagged"    '[ "$(run)" = 1 ] && grep -q repos-stray $T/out.md'; rmdir $T/dev/repos-stray
mkdir $T/home/projects;                       ok "home stray flagged"    '[ "$(run)" = 1 ] && grep -q "~/projects" $T/out.md'; rmdir $T/home/projects
g $T/win/clone;                               ok "C: clone flagged"      '[ "$(run)" = 1 ] && grep -q "on C:" $T/out.md'; rm -rf $T/win/clone
g $T/dev/hyper-repos/a2; git -C $T/dev/hyper-repos/a2 remote add origin https://github.com/O/a
                                              ok "dupe remote flagged"   '[ "$(run)" = 1 ] && grep -q "cloned 2 times" $T/out.md'; rm -rf $T/dev/hyper-repos/a2
git -C $T/dev/hyper-repos/a worktree add -q $T/dev/hyper-repos/a/.claude/worktrees/y -b y
                                              ok "misplaced wt flagged"  '[ "$(run)" = 1 ] && grep -q "outside developer/worktrees" $T/out.md'
git -C $T/dev/hyper-repos/a worktree remove $T/dev/hyper-repos/a/.claude/worktrees/y
mkdir -p $T/dev/hyper-repos/a/.claude/worktrees/orph && echo "gitdir: $T/nowhere/.git/worktrees/orph" > $T/dev/hyper-repos/a/.claude/worktrees/orph/.git
                                              ok "orphan flagged"        '[ "$(run)" = 1 ] && grep -q ORPHAN $T/out.md'; rm -rf $T/dev/hyper-repos/a/.claude
git -C $T/dev/hyper-repos/a worktree add -q $T/dev/worktrees/a-z -b z; rm -rf $T/dev/worktrees/a-z
                                              ok "prunable flagged (no-prune)" '[ "$(run env AUDIT_NO_PRUNE=1)" = 1 ] && grep -q prunable $T/out.md'
                                              ok "prunable auto-pruned"  '[ "$(run)" = 0 ] && ! git -C $T/dev/hyper-repos/a worktree list --porcelain | grep -q prunable'
mkdir -p $T/dev/archive/2026-01-01-delete-staging; ok "staging flagged"  '[ "$(run)" = 1 ] && grep -q delete-staging $T/out.md'; rmdir $T/dev/archive/2026-01-01-delete-staging
# A stray repo at the developer root must not make every clone look "nested".
g $T/dev/hyper-repos/a3; git -C $T/dev/hyper-repos/a3 remote add origin git@github.com:o/a.git; git init -q $T/dev
                                              ok "dupe still flagged under a root .git" '[ "$(run)" = 1 ] && grep -q "cloned 2 times" $T/out.md'; rm -rf $T/dev/.git $T/dev/hyper-repos/a3
# A vendored clone nested inside a clone is not a dupe.
g $T/dev/hyper-repos/a/vendor/a; git -C $T/dev/hyper-repos/a/vendor/a remote add origin git@github.com:o/a.git
                                              ok "nested vendor clone ignored" '[ "$(run)" = 0 ]'; rm -rf $T/dev/hyper-repos/a/vendor
# A copied .git file that borrows another worktree's admin dir.
mkdir -p $T/dev/worktrees/a-copy && cp $T/dev/worktrees/a-x/.git $T/dev/worktrees/a-copy/.git
                                              ok "impostor flagged" '[ "$(run)" = 1 ] && grep -q "IMPOSTOR .worktrees/a-copy" $T/out.md && ! grep -q "IMPOSTOR .worktrees/a-x" $T/out.md'; rm -rf $T/dev/worktrees/a-copy
# Negative: a DIRTY worktree in the right place (hypatia-issue-sweep pattern) is not a finding.
echo wip > $T/dev/worktrees/a-x/f;            ok "dirty worktree in place is clean" '[ "$(run)" = 0 ]'
echo "pass=$pass fail=$fail"; [ $fail = 0 ]
