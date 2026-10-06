#!/bin/bash
# SPDX-License-Identifier: MPL-2.0
# Clean propagation of CI/CD fixes to actual git repos only

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ESTATE_ROOT="/home/hyperpolymath/developer"

# Counter
SUCCESS=0
FAILED=0
PROCESSED=0
NO_CHANGES=0

# Get all actual git repos (directories with .git subdirectory)
# that have codeql.yml with tag-based references
REPO_LIST_FILE="/tmp/clean-repo-list-$(date +%s).txt"

find "$ESTATE_ROOT/hyper-repos" "$ESTATE_ROOT/meta-repos" \
    -maxdepth 3 \
    -type d \
    -name ".git" | \
    while read git_dir; do
        repo_path="$(dirname "$git_dir")"
        codeql_file="$repo_path/.github/workflows/codeql.yml"
        if [[ -f "$codeql_file" ]]; then
            if grep -q "codeql-action.*@v\|actions/checkout@v" "$codeql_file" 2>/dev/null; then
                echo "$repo_path"
            fi
        fi
    done > "$REPO_LIST_FILE"

TOTAL=$(wc -l < "$REPO_LIST_FILE" | tr -d ' ')
echo "Total actual git repos to process: $TOTAL"
echo ""

# Process each repo
while IFS= read -r repo_path; do
    ((PROCESSED++))
    repo_name=$(basename "$repo_path")
    echo "[$PROCESSED/$TOTAL] Processing: $repo_name"
    
    # Run the fix script
    if "$SCRIPT_DIR/apply-fixes-with-pr.sh" "$repo_path" false 2>&1; then
        # Check if any changes were made
        if grep -q "Fixed" "$SCRIPT_DIR/../tmp/apply-fixes-$repo_name.log" 2>/dev/null; then
            echo "  SUCCESS"
            ((SUCCESS++))
        else
            echo "  NO CHANGES NEEDED"
            ((NO_CHANGES++))
        fi
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
echo "  Success (changes applied): $SUCCESS"
echo "  No changes needed: $NO_CHANGES"
echo "  Failed: $FAILED"
echo "=========================================="
