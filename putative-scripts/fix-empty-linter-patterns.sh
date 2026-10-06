#!/bin/bash
# fix-empty-linter-patterns.sh - Bulk fix the byte sequence bug in dogfood-gate.yml
# 
# The bug: PATTERNS use UTF-8 byte sequences (\xc2\xa0) but grep -P matches characters.
# Bytes c2 a0 are ONE character U+00A0; \xc2\xa0 asks for TWO characters (U+00C2 then U+00A0).
# 
# The fix: Use codepoint escapes (\x{a0}) instead of byte sequences (\xc2\xa0).
# Also add C0 control characters and grep -a flag.
#
# See: hyperpolymath/empty-linter#71

set -euo pipefail

# The old buggy pattern
OLD_PATTERN='\\xc2\\xa0|\\xe2\\x80\\x8b|\\xe2\\x80\\x8c|\\xe2\\x80\\x8d|\\xef\\xbb\\xbf|\\xc2\\xad|\\xe2\\x80\\x8e|\\xe2\\x80\\x8f|\\xe2\\x80\\xaa|\\xe2\\x80\\xab|\\xe2\\x80\\xac|\\xe2\\x80\\xad|\\xe2\\x80\\xae|\\x00'

# The new fixed pattern with codepoint escapes and C0 controls
NEW_PATTERN='\\x00|[\\x01-\\x08\\x0B\\x0C\\x0E-\\x1F]|\\x{a0}|\\x{ad}|\\x{200b}|\\x{200c}|\\x{200d}|\\x{200e}|\\x{200f}|\\x{202a}|\\x{202b}|\\x{202c}|\\x{202d}|\\x{202e}|\\x{2060}|\\x{feff}'

# Count of files fixed
FIXED_COUNT=0
SKIPPED_COUNT=0
ERROR_COUNT=0

# Find all dogfood-gate.yml files with the buggy pattern
while IFS= read -r -d '' workflow_file; do
    # Check if file contains the buggy pattern
    if grep -q "$OLD_PATTERN" "$workflow_file" 2>/dev/null; then
        # Check if already has the grep -a flag (part of the fix)
        if grep -q "grep -aPrl" "$workflow_file" 2>/dev/null; then
            echo "SKIP: $workflow_file (already partially fixed)"
            SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
            continue
        fi
        
        # Backup the original file
        cp "$workflow_file" "${workflow_file}.backup"
        
        # Fix the PATTERNS line
        sed -i "s|$OLD_PATTERN|$NEW_PATTERN|" "$workflow_file"
        
        # Fix grep to use -a flag (handle binary files)
        # Replace "grep -Prl" with "grep -aPrl" but only in the context of the empty-linter job
        sed -i 's/\-exec grep -Prl/\-exec grep -aPrl/g' "$workflow_file"
        
        # Verify the changes
        if grep -q "$NEW_PATTERN" "$workflow_file" && grep -q "grep -aPrl" "$workflow_file"; then
            echo "FIXED: $workflow_file"
            FIXED_COUNT=$((FIXED_COUNT + 1))
            # Clean up backup on success
            rm "${workflow_file}.backup"
        else
            echo "ERROR: $workflow_file (fix verification failed)"
            ERROR_COUNT=$((ERROR_COUNT + 1))
            # Restore from backup on error
            mv "${workflow_file}.backup" "$workflow_file"
        fi
    else
        echo "SKIP: $workflow_file (no buggy pattern found)"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    fi
done < <(find /home/hyperpolymath/developer/hyper-repos /home/hyperpolymath/developer/meta-repos -name "dogfood-gate.yml" -type f -print0 2>/dev/null)

echo ""
echo "=== Summary ==="
echo "Fixed:   $FIXED_COUNT files"
echo "Skipped: $SKIPPED_COUNT files"
echo "Errors:  $ERROR_COUNT files"

if [ $ERROR_COUNT -gt 0 ]; then
    echo "WARNING: Some files could not be fixed. Check the output above."
    exit 1
fi

exit 0
