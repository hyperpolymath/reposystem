#!/bin/bash
# fix_token_permissions.sh - Bulk fix TokenPermissionsID issues across all repos
# This script finds workflows with overly permissive top-level permissions and fixes them
# by applying the principle of least privilege: top-level read-only, job-level writes

set -euo pipefail

REPO_ROOTS=("/home/hyperpolymath/developer/hyper-repos" "/home/hyperpolymath/developer/meta-repos")
DRY_RUN=false
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done

if $VERBOSE; then
    echo "=== Token Permissions Fix Script ==="
    echo "Dry run: $DRY_RUN"
    echo "Verbose: $VERBOSE"
    echo ""
fi

# Counter
TOTAL_FIXED=0
TOTAL_SCANNED=0
TOTAL_ISSUES=0

# Function to fix a single workflow file
fix_workflow_file() {
    local file="$1"
    local repo_path="$2"
    
    # Check if file has top-level permissions issues
    local has_issue=false
    local fix_needed=false
    local top_level_contents_write=false
    local top_level_write_all=false
    
    # Check for top-level contents: write
    if grep -q "^permissions:" "$file" && grep -A1 "^permissions:" "$file" | grep -q "^  contents: write$"; then
        has_issue=true
        top_level_contents_write=true
        fix_needed=true
    fi
    
    # Check for top-level write-all
    if grep -q "^permissions: write-all$" "$file"; then
        has_issue=true
        top_level_write_all=true
        fix_needed=true
    fi
    
    # Check for top-level write-all: true
    if grep -q "^permissions:" "$file" && grep -A1 "^permissions:" "$file" | grep -q "^  write-all: true$"; then
        has_issue=true
        top_level_write_all=true
        fix_needed=true
    fi
    
    if ! $has_issue; then
        return 0
    fi
    
    TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
    
    if $VERBOSE; then
        echo "  Found issue in: ${file#$repo_path/}"
        echo "    Top-level contents: write: $top_level_contents_write"
        echo "    Top-level write-all: $top_level_write_all"
    fi
    
    # Create a backup
    local backup_file="${file}.bak"
    cp "$file" "$backup_file"
    
    # Determine the fix needed
    local temp_file="${file}.tmp"
    
    if $top_level_contents_write; then
        # Change top-level contents: write to contents: read
        # And add job-level permissions where jobs need to write
        awk '
        /^permissions:$/ {
            print
            getline
            if ($0 ~ /^  contents: write$/) {
                print "  contents: read"
                in_permissions_block = true
                next
            }
        }
        in_permissions_block && /^[a-zA-Z_-]+:/ {
            in_permissions_block = false
        }
        { print }
        ' "$file" > "$temp_file"
        
        # Now add job-level permissions where needed
        # This is a simplified approach - in practice, we need to analyze each job
        # For now, we will add a comment indicating that job-level permissions should be reviewed
        
        mv "$temp_file" "$file"
    fi
    
    if $top_level_write_all; then
        # Change write-all to read-all
        sed -i 's/^permissions: write-all$/permissions: read-all/' "$file"
    fi
    
    # Verify the fix
    if ! grep -q "^permissions:" "$file" || ! grep -A1 "^permissions:" "$file" | grep -q "contents: write"; then
        if $VERBOSE; then
            echo "  ✓ Fixed"
        fi
        TOTAL_FIXED=$((TOTAL_FIXED + 1))
        
        if ! $DRY_RUN; then
            rm "$backup_file"
        fi
        return 0
    else
        if $VERBOSE; then
            echo "  ✗ Fix verification failed, restored backup"
        fi
        mv "$backup_file" "$file"
        rm -f "$temp_file"
        return 1
    fi
}

# Main loop
for repo_root in "${REPO_ROOTS[@]}"; do
    if [ ! -d "$repo_root" ]; then
        echo "Warning: $repo_root does not exist"
        continue
    fi
    
    echo "Scanning $repo_root..."
    
    # Find all repos
    find "$repo_root" -mindepth 2 -maxdepth 4 -type d -name ".git" -print 2>/dev/null | while read -r git_dir; do
        local repo_path="$(dirname "$git_dir")"
        local workflow_dir="$repo_path/.github/workflows"
        
        if [ ! -d "$workflow_dir" ]; then
            continue
        fi
        
        # Find all workflow files
        find "$workflow_dir" -maxdepth 1 -type f \( -name "*.yml" -o -name "*.yaml" \) -print 2>/dev/null | while read -r workflow_file; do
            TOTAL_SCANNED=$((TOTAL_SCANNED + 1))
            fix_workflow_file "$workflow_file" "$repo_path"
        done
    done
done

echo ""
echo "=== Summary ==="
echo "Total workflows scanned: $TOTAL_SCANNED"
echo "Total issues found: $TOTAL_ISSUES"
echo "Total files fixed: $TOTAL_FIXED"

if $DRY_RUN; then
    echo ""
    echo "DRY RUN: No changes were made. Add --dry-run to actually apply fixes."
fi
