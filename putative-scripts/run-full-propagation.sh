#!/bin/bash
# SPDX-License-Identifier: MPL-2.0
# Run full estate-wide CI/CD fixes propagation
# Creates branches and PRs for all repos that need fixing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ESTATE_ROOT="/home/hyperpolymath/developer"

# Counter
SUCCESS=0
FAILED=0
PROCESSED=0

# Get all repos that need fixing
# These are repos with codeql.yml that has tag-based action references
REPO_LIST_FILE="/tmp/repo-list-$(date +%s).txt"

# Find all repos
find "$ESTATE_ROOT/hyper-repos" "$ESTATE_ROOT/meta-repos" \
    -name "codeql.yml" \
    -path "*/.github/workflows/*" \
    ! -path "*stubs*" \
    ! -path "*_SET*" \
    ! -path "*/.git*" \
    ! -path "*/.claude*" \
    ! -path "*/worktrees/*" \
    -exec grep -l "codeql-action.*@v\|actions/checkout@v" {} \; 2>/dev/null | \
    while read file; do
        # Get repo path (grandparent of .github/workflows/codeql.yml)
        repo_path="$(dirname "$(dirname "$(dirname "$file")")")"
        # Validate it's a real repo with .git directory
        if [[ -d "$repo_path/.git" ]]; then
            echo "$repo_path"
        fi
    done > "$REPO_LIST_FILE"

TOTAL=$(wc -l < "$REPO_LIST_FILE" | tr -d ' ')
echo "Total repos to process: $TOTAL"
echo ""

# Process each repo
while IFS= read -r repo_path; do
    ((PROCESSED++))
    echo "=========================================="
    echo "[$PROCESSED/$TOTAL] Processing: $(basename "$repo_path")"
    echo "=========================================="
    
    if "$SCRIPT_DIR/apply-fixes-with-pr.sh" "$repo_path" false 2>&1; then
        echo "  SUCCESS"
        ((SUCCESS++))
    else
        echo "  FAILED"
        ((FAILED++))
    fi
    
    echo ""
done < "$REPO_LIST_FILE"

# Cleanup
rm -f "$REPO_LIST_FILE"

echo "=========================================="
echo "Final Summary:"
echo "  Total: $TOTAL"
echo "  Processed: $PROCESSED"
echo "  Success: $SUCCESS"
echo "  Failed: $FAILED"
echo "=========================================="
