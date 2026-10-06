#!/bin/bash
# SPDX-License-Identifier: MPL-2.0
# Run estate-wide CI/CD fixes
# Processes all repos that need fixing, creating PRs for each

set -euo pipefail

ESTATE_ROOT="/home/hyperpolymath/developer"
BATCH_SIZE=${1:-10}
DRY_RUN=${2:-false}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Get list of repos that need fixing
get_repos() {
    find "$ESTATE_ROOT/hyper-repos" "$ESTATE_ROOT/meta-repos" \
        -name "codeql.yml" \
        -path "*/.github/workflows/*" \
        ! -path "*stubs*" \
        ! -path "*_SET*" \
        -exec grep -l "codeql-action.*@v\|actions/checkout@v" {} \; 2>/dev/null | while read file; do
        # Get repo path (grandparent of .github/workflows/codeql.yml)
        # file = hyper-repos/reposystem/.github/workflows/codeql.yml
        # dirname = hyper-repos/reposystem/.github/workflows
        # dirname = hyper-repos/reposystem/.github
        # dirname = hyper-repos/reposystem
        dirname "$(dirname "$(dirname "$file")")"
    done | sort -u
}

# Get repo name from path
get_repo_name() {
    basename "$1"
}

# Get org from path
get_org() {
    local path="$1"
    if [[ "$path" == *"hyper-repos/"* ]]; then
        echo "hyperpolymath"
    elif [[ "$path" == *"meta-repos/"* ]]; then
        echo "metadatastician"
    else
        echo "unknown"
    fi
}

# Get GitHub URL for PR
get_pr_url() {
    local repo_path="$1"
    local org
    org=$(get_org "$repo_path")
    local repo
    repo=$(get_repo_name "$repo_path")
    local branch="chore/apply-foundation-ci-fixes-$(date +%Y%m%d)"
    echo "https://github.com/$org/$repo/compare/$branch?expand=1"
}

# Main
echo "Starting estate-wide CI/CD fixes"
echo "Batch size: $BATCH_SIZE"
echo "Dry run: $DRY_RUN"
echo ""

REPOS=$(get_repos)
TOTAL=$(echo "$REPOS" | wc -l)

echo "Total repos to process: $TOTAL"
echo ""

if $DRY_RUN; then
    echo "Running in DRY-RUN mode - no changes will be made"
    echo ""
fi

# Process each repo
SUCCESS=0
FAILED=0
SKIPPED=0

for repo_path in $REPOS; do
    echo "=========================================="
    echo "Processing: $(get_repo_name "$repo_path")"
    echo "=========================================="
    
    if $DRY_RUN; then
        # Just check what would be fixed
        CODEQL_FILE="$repo_path/.github/workflows/codeql.yml"
        if [[ -f "$CODEQL_FILE" ]]; then
            if grep -q "codeql-action.*@v\|actions/checkout@v" "$CODEQL_FILE" 2>/dev/null; then
                echo "  [DRY-RUN] Would fix codeql.yml"
            fi
        fi
        
        GOVERNANCE_FILE="$repo_path/.github/workflows/governance.yml"
        if [[ -f "$GOVERNANCE_FILE" ]]; then
            CURRENT_SHA=$(grep "governance-reusable.yml@" "$GOVERNANCE_FILE" 2>/dev/null | grep -oE '[a-f0-9]{40}' | head -1 || true)
            if [[ -n "$CURRENT_SHA" ]]; then
                GOVERNANCE_REUSABLE_SHA="8f31a5a4ba591d544b65f91f6d78b136e07756f0"
                if [[ "$CURRENT_SHA" != "$GOVERNANCE_REUSABLE_SHA" ]]; then
                    echo "  [DRY-RUN] Would fix governance.yml"
                fi
            fi
        fi
        
        echo "  [DRY-RUN] Skipped"
        ((SKIPPED++))
    else
        # Run the actual fix script
        if "$SCRIPT_DIR/apply-fixes-with-pr.sh" "$repo_path" false 2>&1; then
            echo "  SUCCESS"
            ((SUCCESS++))
        else
            echo "  FAILED"
            ((FAILED++))
        fi
    fi
    
    echo ""
done

echo "=========================================="
echo "Summary:"
echo "  Total: $TOTAL"
echo "  Success: $SUCCESS"
echo "  Failed: $FAILED"
echo "  Skipped (dry-run): $SKIPPED"
echo "=========================================="
