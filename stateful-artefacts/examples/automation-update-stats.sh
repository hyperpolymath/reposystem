#!/bin/bash
# SPDX-License-Identifier: PMPL-1.0-or-later
# Example automation script: Update repository statistics daily
#
# Usage: Run via cron or GitHub Actions to keep docs current
# Example cron: 0 0 * * * /path/to/automation-update-stats.sh

set -euo pipefail

# Configuration
OWNER="hyperpolymath"
STATE_FILE=".machine_readable/STATE.scm"
BACKUP_FILE=".machine_readable/STATE.scm.bak"

# Backup current STATE.scm
cp "$STATE_FILE" "$BACKUP_FILE"

echo "Fetching repository statistics for $OWNER..."

# Count total repositories
REPO_COUNT=$(gh repo list "$OWNER" --limit 1000 --json name --jq '. | length')
echo "Total repositories: $REPO_COUNT"

# Count stars across all repos
STAR_COUNT=$(gh repo list "$OWNER" --limit 1000 --json stargazerCount \
  --jq 'map(.stargazerCount) | add // 0')
echo "Total stars: $STAR_COUNT"

# Count active (non-archived) repos
ACTIVE_COUNT=$(gh repo list "$OWNER" --limit 1000 --json isArchived \
  --jq 'map(select(.isArchived == false)) | length')
echo "Active repositories: $ACTIVE_COUNT"

# Count unique languages (requires fetching each repo - slow!)
# For production, cache this or compute less frequently
echo "Counting languages (this may take a while)..."
LANGUAGE_COUNT=$(gh repo list "$OWNER" --limit 1000 --json name --jq '.[].name' \
  | xargs -I {} gh repo view "$OWNER/{}" --json languages --jq '.languages[].node.name' \
  | sort -u | wc -l)
echo "Unique languages: $LANGUAGE_COUNT"

# Get current date/time
LAST_UPDATED=$(date -Iseconds)

# Update STATE.scm
# Note: This is a simple sed-based update. For production, use a proper S-expression editor.
sed -i "s/(repo-count . [0-9]*)/(repo-count . $REPO_COUNT)/" "$STATE_FILE"
sed -i "s/(star-count . [0-9]*)/(star-count . $STAR_COUNT)/" "$STATE_FILE"
sed -i "s/(active-count . [0-9]*)/(active-count . $ACTIVE_COUNT)/" "$STATE_FILE"
sed -i "s/(language-count . [0-9]*)/(language-count . $LANGUAGE_COUNT)/" "$STATE_FILE"
sed -i "s/(last-updated . \"[^\"]*\")/(last-updated . \"$LAST_UPDATED\")/" "$STATE_FILE"

echo "STATE.scm updated successfully"

# Re-render all templates
echo "Rendering templates..."
gnosis examples/README.template.md README.md
gnosis examples/PROFILE.template.md PROFILE.md

echo "Templates rendered"

# Show diff
echo "Changes made:"
diff "$BACKUP_FILE" "$STATE_FILE" || true

# Commit changes
if git diff --quiet "$STATE_FILE" README.md PROFILE.md; then
  echo "No changes to commit"
else
  git add "$STATE_FILE" README.md PROFILE.md
  git commit -m "docs: update stats (repos: $REPO_COUNT, stars: $STAR_COUNT, active: $ACTIVE_COUNT)"
  echo "Changes committed. Ready to push."

  # Uncomment to auto-push:
  # git push origin main
fi

echo "Done!"
