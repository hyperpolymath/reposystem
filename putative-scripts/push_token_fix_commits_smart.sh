#!/bin/bash
# push_token_fix_commits_smart.sh - Smart push script for TokenPermissionsID fixes
# Handles branch protection by creating new branches when needed

set -euo pipefail

# Git config
git config --global user.name "Mistral Vibe"
git config --global user.email "vibe@mistral.ai"

PUSHED=0
FAILED=0
SKIPPED=0
BRANCH_CREATED=0
TOTAL=0
FIX_BRANCH="fix/token-permissions-id-20260911"

echo "=========================================================================="
echo "SMART PUSH: TokenPermissionsID Fix Commits"
echo "=========================================================================="
echo ""

# Get list of repos with TokenPermissionsID fix commits
mapfile -t REPOS_WITH_FIXES < <(python3 -c "
import subprocess, os, sys
from pathlib import Path

repos = []
for root in ['hyper-repos', 'meta-repos']:
    repos_dir = Path(f'/home/hyperpolymath/developer/{root}')
    for git_dir in repos_dir.rglob('.git'):
        if git_dir.is_dir():
            repo_path = str(git_dir.parent)
            os.chdir(repo_path)
            try:
                result = subprocess.run(
                    ['git', 'log', '--oneline', '-10', '--grep=TokenPermissionsID'],
                    capture_output=True, text=True, timeout=10
                )
                if result.stdout and 'TokenPermissionsID' in result.stdout:
                    print(repo_path)
            except:
                pass
            finally:
                os.chdir('/home/hyperpolymath/developer')
sys.exit(0)
" 2>/dev/null)

if [ ${#REPOS_WITH_FIXES[@]} -eq 0 ]; then
    echo "No repos with TokenPermissionsID fix commits found. Exiting."
    exit 0
fi

echo "Found ${#REPOS_WITH_FIXES[@]} repos with TokenPermissionsID fixes to push"
echo ""

for repo_path in "${REPOS_WITH_FIXES[@]}"; do
    TOTAL=$((TOTAL + 1))
    
    if [ ! -d "$repo_path/.git" ]; then
        continue
    fi
    
    cd "$repo_path"
    
    repo_name=$(basename "$repo_path")
    current_branch=$(git branch --show-current 2>/dev/null || echo "")
    
    if [ -z "$current_branch" ]; then
        echo "[$TOTAL/$TOTAL] Skipping $repo_name (no branch)"
        SKIPPED=$((SKIPPED + 1))
        cd /home/hyperpolymath/developer
        continue
    fi
    
    echo "[$TOTAL/${#REPOS_WITH_FIXES[@]}] Processing $repo_name ($current_branch)..."
    
    # Try to push to current branch first
    if git push origin "$current_branch" 2>&1 | grep -q "successfully published\|up-to-date\|Already up to date"; then
        echo "  ✓ Pushed to $current_branch"
        PUSHED=$((PUSHED + 1))
        cd /home/hyperpolymath/developer
        continue
    fi
    
    # If push failed, try creating a new fix branch
    echo "  → Push to $current_branch failed, trying fix branch..."
    
    # Check if fix branch already exists locally
    if git rev-parse --verify "$FIX_BRANCH" 2>/dev/null; then
        # Branch exists, just push it
        if git push origin "$FIX_BRANCH" 2>&1 | grep -q "successfully published\|up-to-date\|Already up to date"; then
            echo "  ✓ Pushed to $FIX_BRANCH"
            PUSHED=$((PUSHED + 1))
            cd /home/hyperpolymath/developer
            continue
        fi
    else
        # Create new fix branch from current branch
        if git checkout -b "$FIX_BRANCH" "$current_branch" 2>&1; then
            if git push origin "$FIX_BRANCH" 2>&1 | grep -q "successfully published\|up-to-date"; then
                echo "  ✓ Created and pushed $FIX_BRANCH"
                BRANCH_CREATED=$((BRANCH_CREATED + 1))
                PUSHED=$((PUSHED + 1))
                cd /home/hyperpolymath/developer
                continue
            fi
        fi
    fi
    
    # If we get here, all push attempts failed
    echo "  ✗ Failed to push $repo_name"
    FAILED=$((FAILED + 1))
    cd /home/hyperpolymath/developer
done

echo ""
echo "=========================================================================="
echo "Push Summary"
echo "=========================================================================="
echo "Total repos with fixes: ${#REPOS_WITH_FIXES[@]}"
echo "Successfully pushed: $PUSHED"
echo "Branches created: $BRANCH_CREATED"
echo "Failed: $FAILED"
echo "Skipped: $SKIPPED"
echo ""
echo "Note: For repos with new branches, you may need to create PRs manually or"
echo "configure gitbot-fleet to auto-create PRs from $FIX_BRANCH branches."
