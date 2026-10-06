#!/usr/bin/env bash
# estate-board.sh — HONEST main-branch CI health board for the stapeln ecosystem.
#
# For each repo it counts only workflows the repo still lists as ACTIVE, keyed by
# workflowDatabaseId (stable across renames) so a renamed/deleted workflow's orphaned
# last run cannot masquerade as a live red — the estate's "name==path is stale
# registration" trap. Per active workflow it takes the LATEST completed run on main:
#   GREEN  = success
#   RED    = failure / startup_failure(!) / timed_out / cancelled
#   PEND   = active but no completed run on main yet (or main-untriggered) — NOT red
# DISABLED workflows are counted separately (not silently dropped) so "green" can't
# hide a switched-off gate.
#
# Appends a dated snapshot under ../.estate-board/ so week-over-week is a number.
# Read-only: `gh run list` + the workflows API. No merges, no writes to any repo.
#
# Usage:  scripts/estate-board.sh
set -uo pipefail

REPOS=(
  metadatastician/stapeln
  metadatastician/cerro-torre
  metadatastician/svalinn
  metadatastician/selur
  metadatastician/vordr
  metadatastician/rokur
)

STAMP="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
LOGDIR="$(cd "$(dirname "$0")/.." && pwd)/.estate-board"
mkdir -p "$LOGDIR"
LOG="$LOGDIR/board-$STAMP.txt"

JQ='
  ( [ $runs[] | select(.status=="completed") ]
    | group_by(.workflowDatabaseId)
    | map( max_by(.createdAt) )
    | map( { (.workflowDatabaseId|tostring): .conclusion } )
    | add // {} ) as $latest
  | [ $wfs[] | . + { conclusion: ($latest[(.id|tostring)] // "no-run") } ] as $rows
  | ( [ $rows[] | select(.conclusion=="success") ] | length ) as $g
  | ( [ $rows[] | select(.conclusion=="failure" or .conclusion=="startup_failure"
                     or .conclusion=="timed_out" or .conclusion=="cancelled") ] ) as $rf
  | ( [ $rows[] | select(.conclusion=="no-run") ] | length ) as $p
  | "\($g)\t\($rf|length)\t\($p)\t" +
    ( $rf | map(.name + (if .conclusion=="startup_failure" then "!" else "" end)) | join(";") )
'

tot_green=0; tot_red=0; tot_pend=0; tot_dis=0
{
  echo "# Estate CI board — $STAMP"
  echo "# active workflows only, keyed by workflow id (rename-proof); latest completed run per workflow on main"
  echo
  printf '%-14s  %5s  %4s  %5s  %4s   %s\n' REPO GREEN RED PEND DISA "RED WORKFLOWS  (! = startup_failure)"
  printf '%-14s  %5s  %4s  %5s  %4s   %s\n' "-----" "-----" "----" "-----" "----" "-------------------------------------"
  for repo in "${REPOS[@]}"; do
    wfs="$(gh api "repos/$repo/actions/workflows?per_page=100" \
            --jq '[.workflows[] | select(.state=="active") | {id, name}]' 2>/dev/null)"
    dis="$(gh api "repos/$repo/actions/workflows?per_page=100" \
            --jq '[.workflows[] | select(.state|startswith("disabled"))] | length' 2>/dev/null)"
    runs="$(gh run list -R "$repo" --branch main -L 250 \
            --json workflowDatabaseId,conclusion,status,createdAt 2>/dev/null)"
    if [ -z "$wfs" ] || [ -z "$runs" ]; then
      printf '%-14s  %5s  %4s  %5s  %4s   %s\n' "${repo##*/}" "?" "?" "?" "?" "(query failed)"
      continue
    fi
    line="$(jq -rn --argjson wfs "$wfs" --argjson runs "$runs" "$JQ")"
    IFS=$'\t' read -r g r p reds <<<"$line"
    printf '%-14s  %5s  %4s  %5s  %4s   %s\n' "${repo##*/}" "$g" "$r" "$p" "${dis:-0}" "$reds"
    tot_green=$((tot_green + g)); tot_red=$((tot_red + r)); tot_pend=$((tot_pend + p)); tot_dis=$((tot_dis + ${dis:-0}))
  done
  echo
  echo "TOTAL   green=$tot_green   red=$tot_red   pending=$tot_pend   disabled=$tot_dis"
} | tee "$LOG"
echo
echo "snapshot: $LOG"
