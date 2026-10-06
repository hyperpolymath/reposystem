#!/bin/bash
# SPDX-License-Identifier: MPL-2.0
# Safe script to update mirror-reusable.yml SHA pins estate-wide
#
# This script only updates files that:
# 1. Contain mirror-reusable.yml with a 40-character hex SHA
# 2. Are not already using the new SHA
# 3. Are tracked by git (not new untracked files)
#
# It creates backups and allows for rollback.

set -uo pipefail

NEW_SHA="34176e2af29e8be384d3e3da8c00fba72fa27236"
BACKUP_DIR="/home/hyperpolymath/developer/backups/mirror-sha-update-$(date +%Y%m%d-%H%M%S)"
LOG_FILE="/home/hyperpolymath/developer/logs/mirror-sha-update-$(date +%Y%m%d-%H%M%S).log"

mkdir -p "$(dirname "$BACKUP_DIR")" "$(dirname "$LOG_FILE")"

echo "==========================================" | tee "$LOG_FILE"
echo "Safe Mirror SHA Update Script" | tee -a "$LOG_FILE"
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
UNCOMMITTED=0

# Find all mirror.yml files
 while IFS= read -r -d '' file; do
    TOTAL=$((TOTAL + 1))
    
    # Skip if not in a git repo
    repo_dir=$(git -C "$(dirname "$file")" rev-parse --show-toplevel 2>/dev/null) || continue
    
    # Check if file has uncommitted changes
    if git -C "$repo_dir" diff --quiet "$file" 2>/dev/null; then
        # No uncommitted changes - proceed
        :
    else
        UNCOMMITTED=$((UNCOMMITTED + 1))
        echo "[SKIP UNCOMMITTED] $file" | tee -a "$LOG_FILE"
        continue
    fi
    
    # Check if file contains mirror-reusable.yml with a 40-char SHA
    if ! grep -qE "mirror-reusable\.yml@[a-f0-9]{40}" "$file" 2>/dev/null; then
        SKIPPED=$((SKIPPED + 1))
        echo "[SKIP NO SHA] $file" | tee -a "$LOG_FILE"
        continue
    fi
    
    # Extract the old SHA
    OLD_SHA=$(grep -E "mirror-reusable\.yml@[a-f0-9]{40}" "$file" | head -1 | grep -oE "@[a-f0-9]{40}" | tr -d '@')
    
    if [[ "$OLD_SHA" == "$NEW_SHA" ]]; then
        SKIPPED=$((SKIPPED + 1))
        echo "[SKIP ALREADY NEW] $file" | tee -a "$LOG_FILE"
        continue
    fi
    
    # Create backup
    backup_file="$BACKUP_DIR/$(echo "$file" | sed 's|/|_|g')_$(date +%s)"
    mkdir -p "$(dirname "$backup_file")"
    cp "$file" "$backup_file"
    
    # Update the file
    echo "[$TOTAL] Updating: $file (old: $OLD_SHA)" | tee -a "$LOG_FILE"
    if sed -i.bak "s|mirror-reusable\.yml@[a-f0-9]{40}|mirror-reusable.yml@${NEW_SHA}|g" "$file" 2>/dev/null; then
        rm -f "${file}.bak"
        UPDATED=$((UPDATED + 1))
        echo "  [OK] Updated to $NEW_SHA" | tee -a "$LOG_FILE"
    else
        ERRORS=$((ERRORS + 1))
        echo "  [ERROR] Failed to update" | tee -a "$LOG_FILE"
        # Restore from backup
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
echo "Errors: $ERRORS" | tee -a "$LOG_FILE"
echo "Uncommitted files skipped: $UNCOMMITTED" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

if [[ $ERRORS -gt 0 ]]; then
    echo "[WARNING] There were $ERRORS errors. Check $LOG_FILE" | tee -a "$LOG_FILE"
    exit 1
fi

if [[ $UNCOMMITTED -gt 0 ]]; then
    echo "[WARNING] $UNCOMMITTED files had uncommitted changes and were not updated" | tee -a "$LOG_FILE"
    echo "To update these, commit or stash the changes first, then re-run this script" | tee -a "$LOG_FILE"
fi

echo "[SUCCESS] All clean files updated successfully" | tee -a "$LOG_FILE"
echo "Backups saved to: $BACKUP_DIR" | tee -a "$LOG_FILE"
exit 0
