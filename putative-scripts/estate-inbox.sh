#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# estate-inbox.sh — keep the GitHub inbox and the "needs me" board current.
#
# Runs, in order:
#   1. `squabble inbox-sweep --apply` — unsubscribe + mark done every notification
#      thread whose PR/issue is already merged or closed. Nothing else is touched.
#   2. `squabble board --publish <issue>` — rewrite the body of the pinned
#      "Estate: needs me" issue. It edits the body only and never comments.
#
# Driven by the systemd user timer estate-inbox.timer (hourly). Needs the owner's
# gh token with the `notifications` scope — an App token cannot read notifications.
#
# The binary is a separately installed copy (SQUABBLE_BIN), NOT ~/.local/bin/squabble,
# which carries `verify-satisfied` from another branch that the Claude hooks use.
#
# Exit: 0 both steps complete; 6 a step finished but left a stated gap (unreadable
# repo, due thread not cleared); 2 a step failed. Non-zero leaves the unit in
# `systemctl --user --failed`, so a gap is visible as state rather than buried in
# a log. Log: developer/logs/estate-inbox/<UTC date>.log
set -uo pipefail

ROOT=/home/hyperpolymath/developer
SQUABBLE_BIN="${SQUABBLE_BIN:-$ROOT/tools/opt/estate-inbox/bin/squabble}"
BOARD_ISSUE="${ESTATE_BOARD_ISSUE:-}"
# Threads already cleared (id → updated_at); keeps hourly runs from re-clearing them.
STATE="${ESTATE_INBOX_STATE:-$ROOT/tools/opt/estate-inbox/state.json}"
LOGDIR="$ROOT/logs/estate-inbox"
LOG="$LOGDIR/$(date -u +%F).log"

# Print a UTC-timestamped line to stderr and append it to the day's log.
say() {
  printf '%s %s\n' "$(date -u +%FT%TZ)" "$*" | tee -a "$LOG" >&2
}

# Run one squabble step, logging its output; prints the step's exit code.
step() {
  local name="$1"; shift
  say "== $name: $SQUABBLE_BIN $*"
  "$SQUABBLE_BIN" "$@" >>"$LOG" 2>&1
  local rc=$?
  say "== $name: exit $rc"
  echo "$rc"
}

mkdir -p "$LOGDIR"
if [[ ! -x "$SQUABBLE_BIN" ]]; then
  say "FATAL: $SQUABBLE_BIN is not an executable"
  exit 2
fi
if [[ ! "$BOARD_ISSUE" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+#[0-9]+$ ]]; then
  say "FATAL: ESTATE_BOARD_ISSUE must be owner/repo#N, got '${BOARD_ISSUE}'"
  exit 2
fi

sweep_rc=$(step inbox-sweep inbox-sweep --apply --state "$STATE")
board_rc=$(step board board --publish "$BOARD_ISSUE")

worst=0
for rc in "$sweep_rc" "$board_rc"; do
  if [[ "$rc" == 2 || ( "$rc" != 0 && "$rc" != 6 ) ]]; then worst=2
  elif [[ "$rc" == 6 && "$worst" == 0 ]]; then worst=6
  fi
done
say "done: sweep=$sweep_rc board=$board_rc → exit $worst"
exit "$worst"
