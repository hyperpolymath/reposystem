#!/bin/sh
# SPDX-License-Identifier: PMPL-1.0-or-later
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
#
# thread.sh — fan a cross-repo "thread" over the flat clones.
#
# Source of truth = flat clones in $REPOS_DIR. A thread is one logical change
# across N repos; each repo still merges via its own normal per-repo PR. This
# runner only orchestrates the fan-out; it owns no history and pins nothing.
#
#   thread.sh resolve <selector>
#   thread.sh start   <thread> <selector>
#   thread.sh pr      <thread> [--refs "standards#130"]
#   thread.sh status  <thread> [<selector>]
#   thread.sh land    <thread> [<selector>] --yes
#
# <selector> is one of:  --group NAME | --kind KIND | --repos a,b,c
#
# Safety: `start` skips any repo with a dirty worktree. `pr` pushes and opens
# PRs (needs `gh`). `land` requires --yes and only merges PRs gh reports
# MERGEABLE. Nothing is force-pushed; nothing is deleted.
set -eu

REPOS_DIR=${REPOS_DIR:-"$HOME/dev/repos"}
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
MANIFEST="$ROOT/repos.toml"
GROUPS="$ROOT/repos.groups.toml"

die() { echo "thread: $*" >&2; exit 1; }
[ -f "$MANIFEST" ] || die "missing $MANIFEST (run: just repos-manifest)"

# --- selector resolution -> newline-separated repo names on stdout ----------
resolve() {
  sel=$1; val=${2:-}
  case "$sel" in
    --repos) echo "$val" | tr ',' '\n' | sed '/^$/d' ;;
    --kind)  awk -v k="$val" '
               /^\[\[repo\]\]/{n="";kd=""}
               /^name =/{gsub(/^name = "|"$/,"");n=$0}
               /^kind =/{gsub(/^kind = "|"$/,"");kd=$0; if(kd==k) print n}' "$MANIFEST" ;;
    --group)
      [ -f "$GROUPS" ] || die "no $GROUPS"
      line=$(grep -E "^[[:space:]]*$val[[:space:]]*=" "$GROUPS" || true)
      [ -n "$line" ] || die "group '$val' not in repos.groups.toml"
      echo "$line" | sed -e 's/^[^=]*=//' -e 's/[]["]//g' | tr ',' '\n' \
        | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d' ;;
    *) die "unknown selector '$sel' (use --group|--kind|--repos)" ;;
  esac
}

clone_dir() { echo "$REPOS_DIR/$1"; }

each() { # each <selector> <val> ; sets $name/$dir per iteration via callback $1fn
  fn=$1; shift
  resolve "$@" | while IFS= read -r name; do
    [ -n "$name" ] || continue
    dir=$(clone_dir "$name")
    if [ ! -d "$dir/.git" ]; then echo "  skip $name (no clone at $dir)"; continue; fi
    "$fn" "$name" "$dir"
  done
}

cmd=${1:-}; [ -n "$cmd" ] || die "usage: thread.sh <resolve|start|pr|status|land> ..."
shift || true

case "$cmd" in
  resolve)
    resolve "${1:-}" "${2:-}" ;;

  start)
    thread=${1:-}; [ -n "$thread" ] || die "start <thread> <selector>"; shift
    branch="thread/$thread"
    _start() {
      n=$1; d=$2
      if [ -n "$(git -C "$d" status --porcelain)" ]; then
        echo "  SKIP $n (dirty worktree — commit/stash first)"; return 0
      fi
      if git -C "$d" show-ref --verify --quiet "refs/heads/$branch"; then
        echo "  have $n ($branch exists)"
      else
        git -C "$d" checkout -q -b "$branch"
        echo "  made $n ($branch)"
      fi
    }
    echo "thread '$thread' -> branch $branch"
    each _start "$@" ;;

  pr)
    thread=${1:-}; [ -n "$thread" ] || die "pr <thread> [--refs ...] <selector>"; shift
    refs=""
    if [ "${1:-}" = "--refs" ]; then refs=${2:-}; shift 2; fi
    branch="thread/$thread"
    command -v gh >/dev/null 2>&1 || die "gh CLI required for 'pr'"
    body="Part of cross-repo thread \`$thread\`."
    [ -n "$refs" ] && body="$body Refs $refs."
    _pr() {
      n=$1; d=$2
      git -C "$d" rev-parse --verify --quiet "$branch" >/dev/null || { echo "  skip $n (no $branch)"; return 0; }
      git -C "$d" push -u origin "$branch" 2>/dev/null || echo "  warn $n: push failed (already pushed?)"
      url=$(gh --repo "hyperpolymath/$n" pr create --head "$branch" \
              --title "[$thread] $n" --body "$body" 2>/dev/null) \
        && echo "  PR  $n: $url" \
        || echo "  PR  $n: skipped (exists or no diff)"
    }
    each _pr "$@" ;;

  status)
    thread=${1:-}; [ -n "$thread" ] || die "status <thread> <selector>"; shift
    branch="thread/$thread"
    _st() {
      n=$1; d=$2
      git -C "$d" rev-parse --verify --quiet "$branch" >/dev/null || { echo "  --  $n (no $branch)"; return 0; }
      ahead=$(git -C "$d" rev-list --count "origin/HEAD..$branch" 2>/dev/null || echo '?')
      pr=$(gh --repo "hyperpolymath/$n" pr view "$branch" --json state,mergeable \
             -q '.state+" "+.mergeable' 2>/dev/null || echo 'no-PR')
      printf '  %-28s %s commits ahead | %s\n' "$n" "$ahead" "$pr"
    }
    each _st "$@" ;;

  land)
    thread=${1:-}; [ -n "$thread" ] || die "land <thread> <selector> --yes"; shift
    yes=no
    for a in "$@"; do [ "$a" = "--yes" ] && yes=yes; done
    [ "$yes" = yes ] || die "refusing to merge without --yes"
    branch="thread/$thread"
    command -v gh >/dev/null 2>&1 || die "gh CLI required for 'land'"
    _land() {
      n=$1
      m=$(gh --repo "hyperpolymath/$n" pr view "$branch" --json mergeable -q .mergeable 2>/dev/null || echo UNKNOWN)
      if [ "$m" = MERGEABLE ]; then
        gh --repo "hyperpolymath/$n" pr merge "$branch" --squash --delete-branch \
          && echo "  merged $n" || echo "  FAIL  $n (merge errored)"
      else
        echo "  hold  $n (mergeable=$m)"
      fi
    }
    each _land "$@" ;;

  *) die "unknown command '$cmd'" ;;
esac
