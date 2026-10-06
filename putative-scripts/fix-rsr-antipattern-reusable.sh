#!/bin/bash
# fix-rsr-antipattern-reusable.sh - Fix repos calling non-existent rsr-antipattern-reusable workflow
#
# The issue: Some repos call hyperpolymath/standards/.github/workflows/rsr-antipattern-reusable.yml
# but that workflow didn't exist until now. This caused those repos' checks to fail instantly.
#
# The fix: Update the call to use the correct SHA pin of the new reusable workflow.

set -euo pipefail

# The SHA of the new reusable workflow in standards
STANDARDS_SHA="8f31a5a4ba591d544b65f91f6d78b136e07756f0"  # main pin

# Repos that are calling the non-existent reusable workflow
REPOS_WITH_BROKEN_CALL=(
    "/home/hyperpolymath/developer/hyper-repos/_TROPES _SET/trope-particularity-workbench"
    "/home/hyperpolymath/developer/hyper-repos/_TROPES _SET/vocarium/.claude/worktrees/vocarium-fixes/.gate-tools/trope-checker"
    "/home/hyperpolymath/developer/hyper-repos/_TROPES _SET/vocarium/.gate-tools/trope-checker"
    "/home/hyperpolymath/developer/hyper-repos/_TROPES _SET/trope-checker"
    "/home/hyperpolymath/developer/hyper-repos/recon-silly-ation"
    "/home/hyperpolymath/developer/hyper-repos/_WORK _SET/zotero-tools/rescript-templater"
    "/home/hyperpolymath/developer/llm-coding-configs/codex/20260907-github-inbox-remediation/hyperpolymath__recon-silly-ation__scope"
)

FIXED_COUNT=0
ERROR_COUNT=0

for repo in "${REPOS_WITH_BROKEN_CALL[@]}"; do
    workflow_file="$repo/.github/workflows/rsr-antipattern.yml"
    
    if [ ! -f "$workflow_file" ]; then
        echo "SKIP: $workflow_file does not exist"
        continue
    fi
    
    # Check if it's calling the reusable workflow
    if grep -q "hyperpolymath/standards.*rsr-antipattern-reusable" "$workflow_file"; then
        # Backup
        cp "$workflow_file" "${workflow_file}.backup"
        
        # Update the SHA or add it if missing
        # The current calls might be using @main or an old SHA
        sed -i 's|@main$|@'"$STANDARDS_SHA"'|g' "$workflow_file"
        sed -i 's|@[a-f0-9]\{40\}|@'"$STANDARDS_SHA"'|g' "$workflow_file"
        
        # Verify it's calling the correct workflow
        if grep -q "hyperpolymath/standards/.github/workflows/rsr-antipattern-reusable.yml@$STANDARDS_SHA" "$workflow_file"; then
            echo "FIXED: $workflow_file"
            FIXED_COUNT=$((FIXED_COUNT + 1))
            rm "${workflow_file}.backup"
        else
            echo "ERROR: $workflow_file (could not update SHA)"
            ERROR_COUNT=$((ERROR_COUNT + 1))
            mv "${workflow_file}.backup" "$workflow_file"
        fi
    else
        echo "SKIP: $workflow_file is not calling the reusable workflow"
    fi
done

echo ""
echo "=== Summary ==="
echo "Fixed:   $FIXED_COUNT repos"
echo "Errors:  $ERROR_COUNT repos"

if [ $ERROR_COUNT -gt 0 ]; then
    exit 1
fi

exit 0
