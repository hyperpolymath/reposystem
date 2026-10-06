#!/bin/bash
# SPDX-License-Identifier: MPL-2.0
# Complete update script to update mirror-reusable.yml SHA pins estate-wide
#
# This script updates ALL mirror.yml files that reference mirror-reusable.yml,
# including untracked files. It handles both SHA pins and @main references.
#
# This is the most aggressive version - it will update any file that:
# 1. Is named mirror.yml
# 2. Contains a reference to mirror-reusable.yml
#
# Guardrails maintained:
# 1. Only updates files that contain mirror-reusable.yml references
# 2. Creates backups before any modification
# 3. Validates the update was successful
# 4. Provides detailed logging
#
# Unlike the safe and force versions, this script:
# - Updates files with uncommitted changes
# - Updates both SHA-pinned and @main references
# - Updates untracked files
# - Operates directly on working tree

set -uo pipefail

NEW_SHA="34176e2af29e8be384d3e3da8c00fba72fa27236"
BACKUP_DIR="/home/hyperpolymath/developer/backups/mirror-sha-complete-update-$(date +%Y%m%d-%H%M%S)"
LOG_FILE="/home/hyperpolymath/developer/logs/mirror-sha-complete-update-$(date +%Y%m%d-%H%M%S).log"

mkdir -p "$(dirname "$BACKUP_DIR")" "$(dirname "$LOG_FILE")"

echo "==========================================" | tee "$LOG_FILE"
echo "COMPLETE Mirror SHA Update Script" | tee -a "$LOG_FILE"
echo "==========================================" | tee -a "$LOG_FILE"
echo "New SHA: $NEW_SHA" | tee -a "$LOG_FILE"
echo "Backup dir: $BACKUP_DIR" | tee -a "$LOG_FILE"
echo "Log file: $LOG_FILE" | tee -a "$LOG_FILE"
echo "Date: $(date)" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Counters
TOTAL=0
UPDATED=0
SKIPPED=0
ERRORS=0
NO_REF=0
ALREADY_NEW=0

while IFS= read -r -d '' file; do
    TOTAL=$((TOTAL + 1))
    
    # Skip if file doesn't exist or isn't readable
    if [ ! -f "$file" ] || [ ! -r "$file" ]; then
        SKIPPED=$((SKIPPED + 1))
        echo "[SKIP NOT READABLE] $file" | tee -a "$LOG_FILE"
        continue
    fi
    
    # Check if file contains mirror-reusable.yml reference
    if ! grep -qE "mirror-reusable\.yml" "$file" 2>/dev/null; then
        NO_REF=$((NO_REF + 1))
        echo "[SKIP NO REF] $file" | tee -a "$LOG_FILE"
        continue
    fi
    
    # Check current state
    if grep -qE "mirror-reusable\.yml@${NEW_SHA}" "$file" 2>/dev/null; then
        ALREADY_NEW=$((ALREADY_NEW + 1))
        echo "[SKIP ALREADY NEW] $file" | tee -a "$LOG_FILE"
        continue
    fi
    
    # Extract old reference for logging
    OLD_REF=$(grep -E "mirror-reusable\.yml@[a-zA-Z0-9]+" "$file" | head -1 | grep -oE "mirror-reusable\.yml@[a-zA-Z0-9]+" | head -1)
    
    # Create backup
    backup_file="$BACKUP_DIR/$(echo "$file" | tr '/' '_')_$(date +%s)"
    mkdir -p "$(dirname "$backup_file")"
    cp "$file" "$backup_file"
    
    # Update the file - replace both SHA pins and @main
    echo "[$TOTAL] Updating: $file (from: $OLD_REF)" | tee -a "$LOG_FILE"
    
    # Use temp file to avoid sed -i limitations
    tmp_file="$file.tmp"
    cp "$file" "$tmp_file"
    
    # Replace SHA-pinned references
    sed -i "s|mirror-reusable\.yml@[a-f0-9]{40}|mirror-reusable.yml@${NEW_SHA}|g" "$tmp_file" 2>/dev/null
    
    # Replace @main references
    sed -i "s|mirror-reusable\.yml@main|mirror-reusable.yml@${NEW_SHA}|g" "$tmp_file" 2>/dev/null
    
    # Verify the update
    if grep -qE "mirror-reusable\.yml@${NEW_SHA}" "$tmp_file" 2>/dev/null; then
        mv "$tmp_file" "$file"
        rm -f "${file}.bak" 2>/dev/null
        UPDATED=$((UPDATED + 1))
        echo "  [OK] Updated to $NEW_SHA" | tee -a "$LOG_FILE"
    else
        ERRORS=$((ERRORS + 1))
        echo "  [ERROR] Failed to update - restored from backup" | tee -a "$LOG_FILE"
        rm -f "$tmp_file"
        cp "$backup_file" "$file"
    fi
    
    echo "" | tee -a "$LOG_FILE"
    
done < <(find /home/hyperpolymath/developer/hyper-repos /home/hyperpolymath/developer/meta-repos -name "mirror.yml" -type f -print0 2>/dev/null | sort -z)

echo "" | tee -a "$LOG_FILE"
echo "==========================================" | tee -a "$LOG_FILE"
echo "Final Summary" | tee -a "$LOG_FILE"
echo "==========================================" | tee -a "$LOG_FILE"
echo "Total files scanned: $TOTAL" | tee -a "$LOG_FILE"
echo "Files updated: $UPDATED" | tee -a "$LOG_FILE"
echo "Files skipped: $SKIPPED" | tee -a "$LOG_FILE"
echo "No ref: $NO_REF" | tee -a "$LOG_FILE"
echo "Already new: $ALREADY_NEW" | tee -a "$LOG_FILE"
echo "Errors: $ERRORS" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

if [ $ERRORS -eq 0 ]; then
    echo "[SUCCESS] All files updated successfully" | tee -a "$LOG_FILE"
else
    echo "[WARNING] $ERRORS files failed to update" | tee -a "$LOG_FILE"
fi

echo "Backups saved to: $BACKUP_DIR" | tee -a "$LOG_FILE"
exit $ERRORS
