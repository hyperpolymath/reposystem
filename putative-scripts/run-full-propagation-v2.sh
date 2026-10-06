#!/bin/bash
# SPDX-License-Identifier: MPL-2.0
# Run full estate-wide CI/CD fixes propagation - Version 2

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ESTATE_ROOT="/home/hyperpolymath/developer"

# Counter
SUCCESS=0
FAILED=0
PROCESSED=0

# Get all repos that need fixing
REPO_LIST_FILE="/tmp/repo-list-$(date +%s).txt"

# Step 1: Find all codeql.yml files with tag-based refs
find "$ESTATE_ROOT/hyper-repos" "$ESTATE_ROOT/meta-repos" \
    -name "codeql.yml" \
    -path "*/.github/workflows/*" \
    -exec grep -l "codeql-action.*@v\|actions/checkout@v" {} \; 2>/dev/null > /tmp/codeql-files.txt

# Step 2: Convert file paths to repo paths
while IFS= read -r file; do
    # Get the repo path (parent of .github/workflows)
    # file = /home/hyperpolymath/developer/hyper-repos/repo/.github/workflows/codeql.yml
    # We want: /home/hyperpolymath/developer/hyper-repos/repo
    repo_path="$(echo "$file" | sed 's|/.github/workflows/codeql.yml$||')"
    
    # Validate it's a real repo
    if [[ -d "$repo_path/.git" ]]; then
        echo "$repo_path"
    fi
done < /tmp/codeql-files.txt > "$REPO_LIST_FILE"

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
rm -f "$REPO_LIST_FILE" /tmp/codeql-files.txt

echo "=========================================="
echo "Final Summary:"
echo "  Total: $TOTAL"
echo "  Processed: $PROCESSED"
echo "  Success: $SUCCESS"
echo "  Failed: $FAILED"
echo "=========================================="
