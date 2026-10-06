#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# audit-workspace-shape.sh — daily report on local workspace drift.
#
# WHY: the 2026-09-30 cleanup found 1304 git dirs for 545 remotes, 389 dead
# worktree registrations, 19 orphan checkouts (~24 GB) and clones in $HOME and
# on C:. AGENTS.md §1/§1a already forbade all of it; nothing ever looked. The
# PreToolUse hook workspace-shape-guard.sh stops Claude creating new drift;
# this catches everything else (Gemini, Codex, scripts, humans) after the fact.
#
# WHAT it checks (report-only, except the one safe auto-fix):
#   root      entries at the developer root not on the §1a allowlist
#   home      non-dot entries in $HOME other than developer/
#   prunable  worktree registrations whose directory is gone — AUTO-PRUNED
#             (`git worktree prune` only drops registrations for missing paths)
#   orphan    checkouts whose .git file points at a gitdir that no longer exists
#   misplaced worktrees registered outside developer/worktrees/
#   dupes     one remote cloned more than once among live clones
#   staging   *-delete-staging dirs in archive/ still waiting for an owner rm
#   disk      free space on / and on C:
#
# Exit 0 clean, 1 findings (so the unit shows in `systemctl --user --failed`).
# Report: dev-notes/inbox/workspace-audit-<date>.md
#
# Roots are overridable for the test (scripts/test/audit-workspace-shape.test.sh):
#   AUDIT_DEV AUDIT_HOME AUDIT_WIN AUDIT_OUT AUDIT_DISKS AUDIT_NO_PRUNE=1
set -uo pipefail

DEV=${AUDIT_DEV:-/home/hyperpolymath/developer}
HOMEDIR=${AUDIT_HOME:-/home/hyperpolymath}
WIN=${AUDIT_WIN:-/mnt/c/Users/USER}
OUT=${AUDIT_OUT:-$DEV/dev-notes/inbox/workspace-audit-$(date -u +%F).md}
# Keep in step with ROOT_OK in ~/.claude/hooks/workspace-shape-guard.sh.
ROOT_OK=' hyper-repos meta-repos worktrees dev-notes tools scripts logs gists archive llm-coding-configs .claude .migration-tmp repos AGENTS.md CLAUDE.md GEMINI.md .git .github .gstack '
HOME_OK=" developer snap AGENTS.md CLAUDE.md GEMINI.md "

findings=0
body=$(mktemp)
trap 'rm -f "$body"' EXIT
# Append a level-2 section heading to the report body.
section() { printf '\n## %s\n\n' "$1" >>"$body"; }
# Append a finding bullet to the report body and count it.
hit() { printf -- '- %s\n' "$1" >>"$body"; findings=$((findings+1)); }
# Append an informational bullet to the report body (not counted as a finding).
note() { printf -- '- %s\n' "$1" >>"$body"; }

# Every git checkout we care about: clones (.git dir) and worktrees (.git file).
# Build caches and archive/ are skipped (archive holds rescued copies by design;
# pending delete-staging is reported in its own section).
mapfile -t GITS < <(find "$DEV" \( -name node_modules -o -name target -o -name _build -o -name .lake -o -name zig-cache -o -name .migration-tmp -o -path "$DEV/archive" \) -prune \
  -o -name .git -print 2>/dev/null | sed 's|/\.git$||' | sort)

section "Developer root (closed: AGENTS.md §1a)"
for e in "$DEV"/* "$DEV"/.[!.]*; do
  [ -e "$e" ] || continue; n=${e##*/}
  [[ $ROOT_OK == *" $n "* ]] || hit "\`$n\` at the developer root is not on the allowlist"
done

section "\$HOME (toolchains and dotfiles only)"
for e in "$HOMEDIR"/*; do
  [ -e "$e" ] || continue; n=${e##*/}
  [[ $HOME_OK == *" $n "* ]] || hit "\`~/$n\` — \$HOME holds only toolchains and dotfiles"
done

section "Windows home"
if [ -d "$WIN" ]; then
  while IFS= read -r g; do hit "git checkout on C: \`${g%/.git}\`"; done \
    < <(find "$WIN" -maxdepth 4 \( -name AppData -o -name node_modules -o -name scoop -o \( -name ".*" ! -name .git \) \) -prune -o -name .git -print 2>/dev/null)
else note "not mounted — skipped"; fi

section "Worktree registrations"
pruned=0; orphans=0; misplaced=0
for r in "${GITS[@]}"; do
  if [ -d "$r/.git" ]; then
    n=$(git -C "$r" worktree list --porcelain 2>/dev/null | grep -c '^prunable')
    if [ "$n" -gt 0 ]; then
      if [ "${AUDIT_NO_PRUNE:-0}" = 1 ]; then hit "\`${r#$DEV/}\`: $n prunable registration(s)"
      else git -C "$r" worktree prune 2>/dev/null && pruned=$((pruned+n)); fi
    fi
  elif [ -f "$r/.git" ]; then
    gd=$(sed -n 's/^gitdir: //p' "$r/.git")
    case $gd in /*) ;; *) gd=$r/$gd;; esac
    if [ ! -d "$gd" ]; then hit "ORPHAN \`${r#$DEV/}\` — its gitdir \`$gd\` is gone (rescue with scripts/rescue-into-keeper.sh, then delete)"; orphans=$((orphans+1))
    elif [ -f "$gd/gitdir" ] && [ "$(realpath -m "$(cat "$gd/gitdir")")" != "$(realpath -m "$r/.git")" ]; then
      # A copied .git file (scaffolding a repo by copying another): the admin dir
      # belongs to a DIFFERENT checkout, so git here reads and writes that one's index.
      hit "IMPOSTOR \`${r#$DEV/}\` — its .git file borrows the admin dir of \`$(dirname "$(cat "$gd/gitdir")")\` (rescue its files, then delete; never run git inside it)"
    else
      case $r in
        "$DEV"/worktrees/*) ;;
        *) hit "worktree outside developer/worktrees/: \`${r#$DEV/}\` (move with \`git worktree move\`, never mv)"; misplaced=$((misplaced+1));;
      esac
    fi
  fi
done
note "auto-pruned $pruned dead registration(s); $orphans orphan(s); $misplaced misplaced"

section "Duplicate clones of one remote (live trees only)"
declare -A seen=()
for r in "${GITS[@]}"; do
  [ -d "$r/.git" ] || continue
  # A clone nested inside another checkout is vendored (deps/, tools/vendor/), not a dupe.
  top=$(git -C "$(dirname "$r")" rev-parse --show-toplevel 2>/dev/null)
  case $top in "$DEV"/?*) continue;; esac  # (a stray repo AT $DEV must not hide every clone)
  case $r in "$DEV"/archive/*|"$DEV"/tools/*|"$DEV"/llm-coding-configs/*|*/.claude/jobs/*) continue;; esac
  u=$(git -C "$r" config --get remote.origin.url 2>/dev/null) || continue
  k=$(sed -E 's#^(git@|https?://)##; s#:#/#; s#\.git$##; s#/$##' <<<"$u" | tr 'A-Z' 'a-z')
  seen[$k]+="${r#$DEV/}"$'\n'
done
for k in "${!seen[@]}"; do
  c=$(printf '%s' "${seen[$k]}" | grep -c .)
  [ "$c" -gt 1 ] && hit "\`$k\` cloned $c times: $(printf '%s' "${seen[$k]}" | paste -sd";" | sed "s/;/; /g") — keep one, use worktrees for the rest"
done

section "Delete staging awaiting the owner"
for s in "$DEV"/archive/*-delete-staging; do
  [ -d "$s" ] && hit "\`${s#$DEV/}\` ($(du -sh "$s" 2>/dev/null | cut -f1)) — contents are rescued; owner deletes with \`rm -rf '$s'\`"
done

section "Disk"
for m in ${AUDIT_DISKS:-/ /mnt/c}; do
  [ -d "$m" ] || continue
  p=$(df --output=pcent "$m" 2>/dev/null | tail -1 | tr -dc 0-9)
  [ -n "$p" ] || continue
  if [ "$p" -ge 90 ]; then hit "\`$m\` is ${p}% full"; else note "\`$m\` ${p}% used"; fi
done

mkdir -p "$(dirname "$OUT")"
{ printf '# Workspace audit %s\n\nfindings: %d — generated by scripts/audit-workspace-shape.sh\n' "$(date -u +%FT%TZ)" "$findings"; cat "$body"; } >"$OUT"
echo "findings=$findings report=$OUT"
[ "$findings" -eq 0 ]
