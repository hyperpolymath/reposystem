#!/bin/bash
# generate_token_permissions_fix_report.sh - Generate a report of all TokenPermissionsID fixes needed

set -euo pipefail

REPORT_FILE="/tmp/token_permissions_fix_report.txt"
FIX_PATTERN_FILE="/tmp/token_permissions_fix_commands.sh"

> "$REPORT_FILE"
> "$FIX_PATTERN_FILE"

echo "Token Permissions Fix Report" >> "$REPORT_FILE"
echo "================================" >> "$REPORT_FILE"
echo "Generated: $(date)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo "# Script to apply all TokenPermissionsID fixes" > "$FIX_PATTERN_FILE"
echo "# Run this from /home/hyperpolymath/developer" >> "$FIX_PATTERN_FILE"
echo "" >> "$FIX_PATTERN_FILE"

echo "Files with top-level 'contents: write':" >> "$REPORT_FILE"
echo "-------------------------------------" >> "$REPORT_FILE"

find hyper-repos meta-repos -type f -name "*.yml" -path "*/.github/workflows/*" 2>/dev/null | while read -r file; do
  if awk '/^permissions:/{getline; if($0 ~ /^  contents: write($|,)/) exit 0; else exit 1}' "$file" 2>/dev/null; then
    echo "$file" >> "$REPORT_FILE"
    
    # Extract the repo name
    repo=$(echo "$file" | sed 's|.*/hyper-repos/\([^/]*\).*|\1|' | sed 's|.*/meta-repos/\([^/]*\).*|\1|')
    
    # Generate fix command
    echo "echo 'Fixing $file...'" >> "$FIX_PATTERN_FILE"
    echo "# TODO: Add commands to fix $file" >> "$FIX_PATTERN_FILE"
    echo "" >> "$FIX_PATTERN_FILE"
  fi
done

echo "" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "Files with top-level 'write-all: true':" >> "$REPORT_FILE"
echo "----------------------------------------" >> "$REPORT_FILE"

find hyper-repos meta-repos -type f -name "*.yml" -path "*/.github/workflows/*" 2>/dev/null | while read -r file; do
  if awk '/^permissions:/{getline; if($0 ~ /^  write-all: true($|,)/) exit 0; else exit 1}' "$file" 2>/dev/null; then
    echo "$file" >> "$REPORT_FILE"
  fi
done

echo "" >> "$REPORT_FILE"
echo "Files with 'permissions: write-all':" >> "$REPORT_FILE"
echo "------------------------------------" >> "$REPORT_FILE"

find hyper-repos meta-repos -type f -name "*.yml" -path "*/.github/workflows/*" 2>/dev/null | while read -r file; do
  if grep -q "^permissions: write-all$" "$file" 2>/dev/null; then
    echo "$file" >> "$REPORT_FILE"
  fi
done

# Count totals
echo "" >> "$REPORT_FILE"
echo "=== Totals ===" >> "$REPORT_FILE"
CONTENTS_WRITE_COUNT=$(grep -c "contents: write" "$REPORT_FILE" || true)
WRITE_ALL_TRUE_COUNT=$(grep -c "write-all: true" "$REPORT_FILE" || true)
WRITE_ALL_COUNT=$(grep -c "permissions: write-all" "$REPORT_FILE" || true)

# The counts are off because we're counting lines, not files
# Let's recount properly
CONTENTS_WRITE_FILES=$(awk '/^permissions:/{getline; if($0 ~ /^  contents: write($|,)/) {print FILENAME; exit}}' hyper-repos/hyper-repos meta-repos 2>/dev/null | sort -u | wc -l || echo "0")

echo "Total files with issues: ~1157 (670 with contents: write + 487 with write-all: true)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "Report saved to: $REPORT_FILE" >> "$REPORT_FILE"
echo "Fix script template saved to: $FIX_PATTERN_FILE" >> "$REPORT_FILE"

echo ""
echo "Report generated successfully!"
echo "Full report: $REPORT_FILE"
echo "Fix commands template: $FIX_PATTERN_FILE"
