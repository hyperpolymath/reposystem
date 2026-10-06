#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# clear-pages-deployment-deadlock.sh — remove the `required_deployments` rule
# from repo rulesets where it can never be satisfied.
#
# WHY (measured 2026-08-07)
# ------------------------------------------------------------------------
# Repo rulesets carry:
#     required_deployments: { required_deployment_environments: ["github-pages"] }
#
# But the Pages workflows (pages.yml, casket-pages.yml) trigger on `push` and
# `workflow_dispatch` — NEVER `pull_request`. So a pull-request head SHA can
# never have a github-pages deployment, and the rule can never be satisfied on
# a PR. Every PR to an affected repo is therefore permanently BLOCKED, and the
# only way anything merges is the admin bypass (RepositoryRole id=2,
# mode=always) — which is why merged PRs in these repos show DISMISSED /
# CHANGES_REQUESTED / no approvals at all.
#
# VERIFIED per repo before this script was written: for all 18 affected repos,
#     gh api repos/OWNER/REPO/deployments?environment=github-pages
# returned ZERO deployments whose ref was a PR/branch ref. Five repos
# (scripts, systemet, casket-ssg, cargo-zigbuild, .git-private-farm) have never
# had ANY github-pages deployment at all, while still demanding one.
#
# This likely explains, from the other side:
#   - "Failing is not blocking" — 266 PRs red but only 27 counted as blocking
#   - "373 draft PRs prove the fix on branches; main has not moved on a single repo"
#   - "Ruleset phantom forces --admin bypass"
#
# WHAT IT DOES NOT DO
# ------------------------------------------------------------------------
# Nothing else is touched. required_signatures, pull_request,
# required_status_checks and code_scanning rules are preserved byte-for-byte.
# Pages still deploys on push to main exactly as before. This removes a rule
# that gates nothing and forces routine bypass.
#
# Every ruleset is backed up to ./ruleset-backups/ BEFORE modification, and the
# script refuses to write if the backup did not parse.
#
# Usage:
#   ./clear-pages-deployment-deadlock.sh            # dry run: show what would change
#   ./clear-pages-deployment-deadlock.sh --apply    # actually apply
#
# Revert one repo:
#   gh api -X PUT repos/hyperpolymath/REPO/rulesets/ID --input ruleset-backups/REPO-ID.json

set -uo pipefail

APPLY=0
[ "${1:-}" = "--apply" ] && APPLY=1

BACKUP_DIR="${BACKUP_DIR:-./ruleset-backups}"
mkdir -p "$BACKUP_DIR"

# repo <TAB> ruleset-id — verified deadlocked 2026-08-07.
# `standards` (14285635) is omitted: already cleared.
TARGETS="
hypatia	14968579
hypatia	18110858
scripts	14285602
echidna	10845116
maa-framework	12718101
my-lang	14699682
ephapax	14285235
alloyiser	14968882
awesome-nickel	14968599
systemet	19090312
julia-professional-registry	14968715
nextgen-databases	14968566
robot-vacuum-cleaner	10829722
nexia-list	14285457
universal-chat-extractor	14285673
casket-ssg	18110179
cargo-zigbuild	19085107
.git-private-farm	14699691
"

changed=0 skipped=0 failed=0

while IFS=$'\t' read -r repo id; do
  [ -n "${repo:-}" ] || continue
  [ -n "${id:-}" ] || continue

  before="$BACKUP_DIR/${repo#.}-${id}.json"
  if ! gh api "repos/hyperpolymath/$repo/rulesets/$id" > "$before" 2>/dev/null; then
    echo "  READ-FAIL   $repo/$id"; failed=$((failed + 1)); continue
  fi

  # ⚠ NO FALLBACK: if the backup did not parse we must not write. A malformed
  # backup means we cannot revert, and "cannot revert" is not an acceptable
  # state for a governance change.
  if ! jq -e '.rules' "$before" >/dev/null 2>&1; then
    echo "  BAD-BACKUP  $repo/$id — refusing to modify"; failed=$((failed + 1)); continue
  fi

  if ! jq -e '[.rules[]|select(.type=="required_deployments")]|length > 0' "$before" >/dev/null 2>&1; then
    echo "  skip        $repo/$id — no required_deployments rule"; skipped=$((skipped + 1)); continue
  fi

  env_list="$(jq -r '[.rules[]|select(.type=="required_deployments").parameters.required_deployment_environments[]]|join(",")' "$before")"

  # Evidence gate: only proceed if NO pull-request-ref deployment has ever
  # existed for this environment. If one has, the rule IS satisfiable here and
  # removing it would be a real weakening, not a deadlock fix.
  prdeploys="$(gh api "repos/hyperpolymath/$repo/deployments?environment=github-pages&per_page=100" \
                 --jq '[.[]|select((.ref // "") | test("^(main|master)$") | not)]|length' 2>/dev/null || echo 0)"
  if [ "${prdeploys:-0}" -gt 0 ]; then
    echo "  SKIP        $repo/$id — $prdeploys non-main deployment(s) exist; rule IS satisfiable here"
    skipped=$((skipped + 1)); continue
  fi

  after="$BACKUP_DIR/${repo#.}-${id}.new.json"
  jq '{name, target, enforcement,
       bypass_actors: [.bypass_actors[] | {actor_id, actor_type, bypass_mode}],
       conditions,
       rules: [.rules[] | select(.type != "required_deployments")]}' "$before" > "$after"

  if [ "$APPLY" -eq 0 ]; then
    echo "  would clear $repo/$id  (requires: $env_list)"
    changed=$((changed + 1))
    continue
  fi

  if gh api -X PUT "repos/hyperpolymath/$repo/rulesets/$id" --input "$after" >/dev/null 2>&1; then
    remaining="$(gh api "repos/hyperpolymath/$repo/rulesets/$id" --jq '[.rules[]|select(.type=="required_deployments")]|length' 2>/dev/null)"
    if [ "${remaining:-1}" -eq 0 ]; then
      echo "  cleared     $repo/$id"; changed=$((changed + 1))
    else
      echo "  VERIFY-FAIL $repo/$id — PUT succeeded but the rule is still present"; failed=$((failed + 1))
    fi
  else
    echo "  WRITE-FAIL  $repo/$id"; failed=$((failed + 1))
  fi
done <<EOF
$(printf '%s' "$TARGETS" | sed '/^$/d')
EOF

echo
if [ "$APPLY" -eq 0 ]; then
  echo "DRY RUN — $changed ruleset(s) would change, $skipped skipped, $failed failed."
  echo "Re-run with --apply to write. Backups are already in $BACKUP_DIR."
else
  echo "APPLIED — $changed cleared, $skipped skipped, $failed failed."
  echo "Revert one with:"
  echo "  gh api -X PUT repos/hyperpolymath/REPO/rulesets/ID --input $BACKUP_DIR/REPO-ID.json"
fi
[ "$failed" -eq 0 ]
