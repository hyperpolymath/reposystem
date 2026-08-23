#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# On-Creation Regularise Hook (WS7)

set -euo pipefail

STATE_FILE="$HOME/.cache/hyperpolymath-estate-repos.txt"
OWNER="hyperpolymath"
REPOS_DIR="$HOME/developer/repos"

echo "=> Fetching live repo list from GitHub for $OWNER..."
# fail-closed: abort if we can't fetch
LIVE_REPOS=$(gh repo list "$OWNER" --limit 1000 --json name -q '.[].name' | sort)

if [[ -z "$LIVE_REPOS" ]]; then
    echo "ERROR: Could not fetch repos or zero repos found. Aborting." >&2
    exit 1
fi

mkdir -p "$(dirname "$STATE_FILE")"
touch "$STATE_FILE"

NEW_REPOS=$(comm -13 "$STATE_FILE" <(echo "$LIVE_REPOS") | sed '/^\s*$/d' || true)

if [[ -z "$NEW_REPOS" ]]; then
    echo "=> No new repos detected. State matches live (count: $(echo "$LIVE_REPOS" | wc -w))."
    exit 0
fi

echo "=> Found new repos to regularise:"
echo "$NEW_REPOS"

# Change directory to megasweep folder
cd "$REPOS_DIR/reposystem/repo-scripts/megasweep"

for repo in $NEW_REPOS; do
    echo "========================================"
    echo "=> Regularising $repo..."
    REPO_PATH="$REPOS_DIR/$repo"
    
    if [[ ! -d "$REPO_PATH" ]]; then
        echo "   Cloning $repo..."
        gh repo clone "$OWNER/$repo" "$REPO_PATH"
    fi
    
    echo "   Applying templates..."
    elixir megasweep.exs --detector templates --mode apply --root "$REPO_PATH"
    
    echo "   Applying settings..."
    elixir megasweep.exs --detector settings --mode apply --root "$REPO_PATH"
done

# Save state
echo "$LIVE_REPOS" > "$STATE_FILE"
echo "=> State updated. Hook run complete."
