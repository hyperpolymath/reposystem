#!/bin/bash
# push_all_token_fix_commits.sh - Push all TokenPermissionsID fix commits to GitHub

set -euo pipefail

# Git config
git config --global user.name "Mistral Vibe"
git config --global user.email "vibe@mistral.ai"

PUSHED=0
FAILED=0
SKIPPED=0
TOTAL=0

for repo_path in $(find /home/hyperpolymath/developer/hyper-repos /home/hyperpolymath/developer/meta-repos -type d -name ".git" -printf "%h\n" 2>/dev/null); do
    TOTAL=$((TOTAL + 1))
    
    if [ ! -d "$repo_path/.git" ]; then
        continue
    fi
    
    cd "$repo_path"
    
    # Get current branch
    current_branch=$(git branch --show-current 2>/dev/null || echo "")
    if [ -z "$current_branch" ]; then
        SKIPPED=$((SKIPPED + 1))
        cd /home/hyperpolymath/developer
        continue
    fi
    
    # Check if there are unpushed commits
    if ! git diff --quiet @{u} 2>/dev/null; then
        repo_name=$(basename "$repo_path")
        echo "[$TOTAL] Pushing $repo_name ($current_branch)..."
        
        if git push 2>&1 | grep -q "successfully published\|up-to-date\|Already up to date"; then
            echo "  ✓ Pushed"
            PUSHED=$((PUSHED + 1))
        else
            echo "  ✗ Failed"
            FAILED=$((FAILED + 1))
        fi
    else
        SKIPPED=$((SKIPPED + 1))
    fi
    
    cd /home/hyperpolymath/developer
done

echo ""
echo "=========================================="
echo "Push Summary"
echo "=========================================="
echo "Total repos checked: $TOTAL"
echo "Successfully pushed: $PUSHED"
echo "Failed: $FAILED"
echo "Skipped (no changes or up-to-date): $SKIPPED"
