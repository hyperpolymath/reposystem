#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# add-proof-needed-label.sh — Add 'proof needed' label to a repository's settings.yml
#
# Usage:
#   ./add-proof-needed-label.sh [REPO_DIR...]
#   ./add-proof-needed-label.sh --all
#
# This script adds a 'proof needed' label to GitHub repository settings.yml files
# that use the probot/settings app for label management.

set -euo pipefail

# Label configuration
LABEL_NAME="proof needed"
LABEL_COLOR="e99695"
LABEL_DESCRIPTION="Formal proof required or verification gap identified"

# The YAML snippet to insert
LABEL_SNIPPET="  - name: \"${LABEL_NAME}\"\n    color: \"${LABEL_COLOR}\"\n    description: \"${LABEL_DESCRIPTION}\""

#######################################
# Add label to a single settings.yml file
#######################################
add_label_to_file() {
    local file="$1"

    # Verify file exists
    if [[ ! -f "$file" ]]; then
        echo "ERROR: File not found: $file" >&2
        return 1
    fi

    # Check if label already exists
    if grep -q "name: \"${LABEL_NAME}\"" "$file"; then
        echo "SKIP: Label '${LABEL_NAME}' already exists in $file"
        return 0
    fi

    # Check if there's a labels section
    if ! grep -q '^labels:' "$file"; then
        echo "ERROR: No 'labels:' section found in $file" >&2
        return 1
    fi

    # Create a temporary file
    local tmp_file
    tmp_file=$(mktemp)

    # Use awk to find the end of the labels section and insert our label
    awk -v snippet="$LABEL_SNIPPET" '
    /^labels:/ { in_labels=1; print; next }
    in_labels && /^  - name:/ { last_label=NR; print; next }
    in_labels && NR == last_label + 1 {
        if ($0 ~ /^$/ || $0 ~ /^[^ ]/ || $0 ~ /^# ───/) {
            print snippet
            print ""
            in_labels=0
        }
        print
        next
    }
    in_labels && /^[^ ]/ && !/^#/ { in_labels=0 }
    { print }
    END {
        if (in_labels) {
            print ""
            print snippet
        }
    }
    ' "$file" > "$tmp_file"

    # Check if the label was successfully added
    if grep -q "name: \"${LABEL_NAME}\"" "$tmp_file"; then
        mv "$tmp_file" "$file"
        echo "ADDED: Label '${LABEL_NAME}' to $file"
        return 0
    else
        # Fallback: append to end of labels section
        echo "WARNING: Complex insertion failed, trying simple append..." >&2
        
        # Find the last line of the labels section
        local labels_end
        labels_end=$(awk '/^labels:/ {found=1; next} found {if (/^[^ ]/ && !/^#/) exit; print NR}' "$file" | tail -1)
        
        if [[ -z "$labels_end" ]]; then
            labels_end=$(wc -l < "$file")
        fi
        
        head -n "$labels_end" "$file" > "$tmp_file"
        printf '\n%s\n' "$LABEL_SNIPPET" >> "$tmp_file"
        tail -n +$((labels_end + 1)) "$file" >> "$tmp_file"
        mv "$tmp_file" "$file"
        echo "ADDED: Label '${LABEL_NAME}' to $file (fallback method)"
        return 0
    fi
}

#######################################
# Add label to a repository directory
#######################################
add_label_to_repo() {
    local repo_dir="$1"
    local settings_file="${repo_dir}/.github/settings.yml"

    if [[ -f "$settings_file" ]]; then
        add_label_to_file "$settings_file"
    else
        echo "WARNING: No .github/settings.yml found in $repo_dir" >&2
        return 1
    fi
}

#######################################
# Find all repositories
#######################################
find_all_repos() {
    local repos=()

    # Search meta-repos
    if [[ -d "/home/hyperpolymath/developer/meta-repos" ]]; then
        while IFS= read -r -d '' dir; do
            repos+=("$dir")
        done < <(find /home/hyperpolymath/developer/meta-repos -name "settings.yml" -path "*/.github/*" -print0 2>/dev/null)
    fi

    # Search hyper-repos (but not too deep)
    if [[ -d "/home/hyperpolymath/developer/hyper-repos" ]]; then
        while IFS= read -r -d '' dir; do
            repos+=("$dir")
        done < <(find /home/hyperpolymath/developer/hyper-repos -maxdepth 4 -name "settings.yml" -path "*/.github/*" -print0 2>/dev/null)
    fi

    # Extract unique repository root directories
    declare -A seen_dirs
    local result=()
    for path in "${repos[@]}"; do
        # Get the parent directory of .github/settings.yml
        local repo_root="$(dirname "$(dirname "$path")")"
        if [[ -z "${seen_dirs[$repo_root]:-}" ]]; then
            seen_dirs["$repo_root"]=1
            result+=("$repo_root")
        fi
    done

    printf '%s\n' "${result[@]}"
}

#######################################
# Usage
#######################################
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [REPO_DIR...]

Add 'proof needed' label to GitHub repository settings.yml files.

Options:
  -a, --all       Add to all repositories with settings.yml in meta-repos and hyper-repos
  -h, --help      Show this help message

Arguments:
  REPO_DIR        Directory containing a .github/settings.yml file
                  If not specified, uses current directory

Examples:
  # Add to current repository
  ./$(basename "$0")

  # Add to specific repository
  ./$(basename "$0") /home/hyperpolymath/developer/meta-repos/paint-type

  # Add to all repositories
  ./$(basename "$0") --all

Note: This script modifies .github/settings.yml files which are used by the
probot/settings GitHub App. Changes will be applied when pushed to the default
branch of the repository.
EOF
}

#######################################
# Main
#######################################

# Parse arguments
ALL_REPOS=false
REPO_DIRS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -a|--all)
            ALL_REPOS=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            echo "ERROR: Unknown option: $1" >&2
            usage
            exit 1
            ;;
        *)
            REPO_DIRS+=("$1")
            shift
            ;;
    esac
done

# Collect repositories to process
if $ALL_REPOS; then
    echo "Searching for all repositories with settings.yml..."
    mapfile -t REPO_DIRS < <(find_all_repos)
    
    if [[ ${#REPO_DIRS[@]} -eq 0 ]]; then
        echo "ERROR: No repositories with .github/settings.yml found" >&2
        exit 1
    fi
    
    echo "Found ${#REPO_DIRS[@]} repositories to update"
    printf "  %s\n" "${REPO_DIRS[@]}"
    echo ""
elif [[ ${#REPO_DIRS[@]} -eq 0 ]]; then
    # Default to current directory
    REPO_DIRS=(".")
fi

# Process each repository
echo "Processing repositories..."
for repo_dir in "${REPO_DIRS[@]}"; do
    add_label_to_repo "$repo_dir"
done

echo ""
echo "Done!"
