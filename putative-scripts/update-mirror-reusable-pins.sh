#!/bin/bash
# SPDX-License-Identifier: MPL-2.0
# update-mirror-reusable-pins.sh - Estate-wide update of mirror-reusable.yml SHA pins
#
# Updates all downstream mirror.yml workflows to use the new fixed SHA of
# hyperpolymath/standards/.github/workflows/mirror-reusable.yml
#
# This addresses the SSH host key verification security fix (standards#762)
#
# Usage: ./update-mirror-reusable-pins.sh [--dry-run] [--limit N] [--verbose]

set -uo pipefail

# Configuration
NEW_SHA="34176e2af29e8be384d3e3da8c00fba72fa27236"
DRY_RUN=false
VERBOSE=false
LIMIT=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; echo "[INFO] Dry run mode enabled";;
        --limit) LIMIT="$2"; shift; echo "[INFO] Limit set to $LIMIT";;
        --verbose) VERBOSE=true; echo "[INFO] Verbose mode enabled";;
        *) echo "Unknown option: $1"; exit 1;;
    esac
    shift
done

# Counters
TOTAL=0
UPDATED=0
SKIPPED=0
ERRORS=0

# Temporary directory
TMP_DIR=$(mktemp -d)
UPDATED_LIST="$TMP_DIR/updated.txt"
ERROR_LIST="$TMP_DIR/errors.txt"
FILE_LIST="$TMP_DIR/files.txt"

# Remove the temporary working directory.
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

echo "=========================================="
echo "Mirror Reusable SHA Update Script"
echo "=========================================="
echo "New SHA: $NEW_SHA"
echo "Dry run: $DRY_RUN"
echo "Limit: ${LIMIT:-all}"
echo ""

# Find all mirror.yml files
 echo "[SCAN] Finding all mirror.yml files..."
find /home/hyperpolymath/developer/hyper-repos /home/hyperpolymath/developer/meta-repos \
    -name "mirror.yml" \
    -type f \
    -print0 2>/dev/null | while IFS= read -r -d '' file; do
        echo "$file" >> "$FILE_LIST"
    done

TOTAL=$(wc -l < "$FILE_LIST" 2>/dev/null || echo 0)
echo "[SCAN] Found $TOTAL mirror.yml files"
echo ""

# Process each file
COUNT=0
while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    
    COUNT=$((COUNT + 1))
    
    # Check limit
    if [[ -n "$LIMIT" && $COUNT -gt $LIMIT ]]; then
        echo "[LIMIT] Stopping after $LIMIT repos"
        break
    fi
    
    # Check if file contains mirror-reusable.yml reference
    if ! grep -q "mirror-reusable.yml@" "$file" 2>/dev/null; then
        SKIPPED=$((SKIPPED + 1))
        if [[ "$VERBOSE" == true ]]; then
            echo "[SKIP] $file (no mirror-reusable.yml reference)"
        fi
        continue
    fi
    
    # Extract old SHA
    OLD_SHA=$(grep "mirror-reusable.yml@" "$file" | head -1 | grep -oE "@[a-f0-9]{30,50}" | tr -d '@')
    
    # Check if already using new SHA
    if [[ "$OLD_SHA" == "$NEW_SHA" ]]; then
        SKIPPED=$((SKIPPED + 1))
        if [[ "$VERBOSE" == true ]]; then
            echo "[SKIP] $file (already using $NEW_SHA)"
        fi
        continue
    fi
    
    echo "[$COUNT/$TOTAL] Updating: $file"
    if [[ "$VERBOSE" == true ]]; then
        echo "  Old SHA: $OLD_SHA"
        echo "  New SHA: $NEW_SHA"
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        UPDATED=$((UPDATED + 1))
        echo "  [DRY RUN] Would update"
        echo "$file" >> "$UPDATED_LIST"
    else
        # Replace SHA in file - use more specific pattern
        if sed -i.bak "s|mirror-reusable\.yml@[a-f0-9]\{30,50\}|mirror-reusable.yml@${NEW_SHA}|g" "$file" 2>/dev/null; then
            rm -f "${file}.bak"
            UPDATED=$((UPDATED + 1))
            echo "  [OK] Updated successfully"
            echo "$file" >> "$UPDATED_LIST"
        else
            ERRORS=$((ERRORS + 1))
            echo "  [ERROR] Failed to update"
            echo "$file" >> "$ERROR_LIST"
        fi
    fi
done < "$FILE_LIST"

echo ""
echo "=========================================="
echo "Update Summary"
echo "=========================================="
echo "Total files scanned: $TOTAL"
echo "Files updated: $UPDATED"
echo "Files skipped: $SKIPPED"
echo "Errors: $ERRORS"
echo ""

if [[ -f "$UPDATED_LIST" && -s "$UPDATED_LIST" ]]; then
    echo "Updated files:"
    cat "$UPDATED_LIST"
    echo ""
fi

if [[ -f "$ERROR_LIST" && -s "$ERROR_LIST" ]]; then
    echo "Error files:"
    cat "$ERROR_LIST"
    echo ""
fi

if [[ $ERRORS -gt 0 ]]; then
    echo "[WARNING] There were $ERRORS errors"
    exit 1
fi

echo "[SUCCESS] All updates completed"
exit 0
