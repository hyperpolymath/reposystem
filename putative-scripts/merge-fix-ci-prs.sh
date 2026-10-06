#!/bin/bash

# Script to merge all open fix(ci)/feat(ci) PRs authored by hyperpolymath
#
# This script will attempt to merge PRs that are ready (have required approvals).
# PRs that require additional approvals will be skipped.
#
# Usage: ./merge-fix-ci-prs.sh [--dry-run] [--force]
#
# Requirements:
# - gh CLI installed and authenticated
# - Write access to the repositories
# - Branch protection must allow the authenticated user to merge

DRY_RUN=false
FORCE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Get all open PRs authored by hyperpolymath with fix(ci) or feat(ci) in title
PR_LIST=$(gh search prs --author hyperpolymath --limit 100 --state open | grep -E "fix\(ci\)|feat\(ci\)" | awk '{print $1"#"$2}')

if [[ -z "$PR_LIST" ]]; then
    echo "No PRs found to merge"
    exit 0
fi

echo "Found $(echo "$PR_LIST" | wc -l) PRs to check"
echo ""

MERGED=0
SKIPPED=0
FAILED=0

while IFS= read -r repo_pr; do
    repo=${repo_pr%%#*}
    pr_num=${repo_pr#*#}
    
    echo "Checking $repo #$pr_num..."
    
    # Check if mergeable
    MERGEABLE=$(gh api repos/$repo/pulls/$pr_num --jq '.mergeable' 2>/dev/null)
    MERGE_STATE=$(gh api repos/$repo/pulls/$pr_num --jq '.merge_state_status // ""' 2>/dev/null)
    
    if [[ "$MERGEABLE" != "true" ]]; then
        echo "  ❌ Not mergeable (state: $MERGE_STATE)"
        ((SKIPPED++))
        continue
    fi
    
    # Check if already merged
    STATE=$(gh api repos/$repo/pulls/$pr_num --jq '.state' 2>/dev/null)
    if [[ "$STATE" != "OPEN" ]]; then
        echo "  ℹ️  Already merged or closed"
        ((SKIPPED++))
        continue
    fi
    
    # Check for required approvals
    APPROVALS_NEEDED=$(gh api repos/$repo/branches/main/protection --jq '.required_pull_request_reviews.required_approving_review_count // 0' 2>/dev/null || echo "1")
    APPROVALS_HAVE=$(gh api repos/$repo/pulls/$pr_num/reviews --jq '[.[] | select(.state == "APPROVED")] | length' 2>/dev/null || echo "0")
    
    if [[ "$APPROVALS_HAVE" -lt "$APPROVALS_NEEDED" ]]; then
        echo "  ⏳ Needs $((APPROVALS_NEEDED - APPROVALS_HAVE)) more approval(s)"
        ((SKIPPED++))
        continue
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "  ✅ Would merge"
        continue
    fi
    
    # Try to merge
    if gh pr merge $pr_num --repo $repo --squash 2>/dev/null; then
        echo "  ✅ Merged successfully"
        ((MERGED++))
    else
        echo "  ❌ Failed to merge"
        ((FAILED++))
    fi
    
done

echo ""
echo "Summary:"
echo "  Merged: $MERGED"
echo "  Skipped: $SKIPPED"
echo "  Failed: $FAILED"
