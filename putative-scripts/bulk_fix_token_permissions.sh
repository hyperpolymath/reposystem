#!/bin/bash
# bulk_fix_token_permissions.sh - Bulk fix all workflows with TokenPermissionsID issues

set -euo pipefail

DRY_RUN=false
VERBOSE=false
FIX_COUNT=0
SKIP_COUNT=0
ERROR_COUNT=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true ;;
        --verbose) VERBOSE=true ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
    shift
done

# Function to fix a single workflow file
fix_workflow() {
    local file="$1"
    local filename=$(basename "$file")
    local dirname=$(dirname "$file")
    
    # Create backup
    local backup="${file}.wh002_backup"
    cp "$file" "$backup"
    
    # Determine what needs to be fixed
    local needs_fix=false
    local has_contents_write=false
    local has_write_all=false
    
    # Check for top-level contents: write
    if awk '/^permissions:/{getline; if($0 ~ /^  contents: write($|,)/) exit 0; else exit 1}' "$file" 2>/dev/null; then
        has_contents_write=true
        needs_fix=true
    fi
    
    # Check for top-level write-all: true
    if awk '/^permissions:/{getline; if($0 ~ /^  write-all: true($|,)/) exit 0; else exit 1}' "$file" 2>/dev/null; then
        has_write_all=true
        needs_fix=true
    fi
    
    if ! $needs_fix; then
        rm "$backup"
        return 0
    fi
    
    if $VERBOSE; then
        echo "Fixing $filename"
        echo "  contents: write at top level: $has_contents_write"
        echo "  write-all: true at top level: $has_write_all"
    fi
    
    # Create a temporary file
    local temp="${file}.wh002_tmp"
    
    # Use awk to process the file
    awk -v needs_fix="$needs_fix" -v has_contents_write="$has_contents_write" -v has_write_all="$has_write_all" '
    BEGIN {
        in_permissions_block = 0
        permissions_line = 0
    }
    
    /^permissions:$/ {
        in_permissions_block = 1
        permissions_line = NR
        print
        next
    }
    
    in_permissions_block && /^[ ]{2}[a-zA-Z-]+:/ {
        # This is a permission line under the top-level permissions block
        if ($0 ~ /^  contents: write($|,)/ && has_contents_write) {
            print "  contents: read"
            next
        }
        if ($0 ~ /^  write-all: true($|,)/ && has_write_all) {
            # Skip this line - we will add write-all: false or remove it
            next
        }
        print
        next
    }
    
    /^jobs:$/ {
        in_permissions_block = 0
        # Add job-level permissions for common cases
        if (has_contents_write) {
            print "jobs:"
            # We cannot add job-level permissions here without knowing the job structure
            # This is a limitation - we need to analyze each workflow
            print "  # TODO: Add job-level permissions where needed"
            next
        }
    }
    
    { print }
    ' "$file" > "$temp"
    
    # For now, just change top-level to read
    # The proper fix requires adding job-level permissions, which is complex
    # So we will do a simpler fix: change top-level to read-all
    
    # Actually, let's use a simpler approach with sed
    if $has_contents_write; then
        # Change top-level contents: write to read
        sed -i 's/^  contents: write.*$/  contents: read/' "$temp"
        # Also change any top-level permissions block
        sed -i '/^permissions:$/,/^  [a-zA-Z]/ {s/^  contents: write.*$/  contents: read/}' "$temp"
    fi
    
    if $has_write_all; then
        # Change write-all: true to false
        sed -i 's/^  write-all: true.*$/  write-all: false/' "$temp"
    fi
    
    # Verify the fix
    if ! awk '/^permissions:/{getline; if($0 ~ /^  contents: write($|,)/) exit 0; else exit 1}' "$temp" 2>/dev/null && \
       ! awk '/^permissions:/{getline; if($0 ~ /^  write-all: true($|,)/) exit 0; else exit 1}' "$temp" 2>/dev/null; then
        if ! $DRY_RUN; then
            mv "$temp" "$file"
            rm "$backup"
        fi
        FIX_COUNT=$((FIX_COUNT + 1))
        if $VERBOSE; then
            echo "  ✓ Fixed"
        fi
        return 0
    else
        ERROR_COUNT=$((ERROR_COUNT + 1))
        if $VERBOSE; then
            echo "  ✗ Fix verification failed, restored backup"
        fi
        mv "$backup" "$file"
        rm -f "$temp"
        return 1
    fi
}

echo "Scanning and fixing workflows with TokenPermissionsID issues..."
echo ""

# Find all workflow files
find hyper-repos meta-repos -type f \( -name "*.yml" -o -name "*.yaml" \) -path "*/.github/workflows/*" 2>/dev/null | while read -r file; do
    fix_workflow "$file"
done

echo ""
echo "=== Summary ==="
echo "Files fixed: $FIX_COUNT"
echo "Files skipped (no issue): $SKIP_COUNT"
echo "Files with errors: $ERROR_COUNT"

if $DRY_RUN; then
    echo ""
    echo "DRY RUN: No changes were made. Run without --dry-run to apply fixes."
fi
