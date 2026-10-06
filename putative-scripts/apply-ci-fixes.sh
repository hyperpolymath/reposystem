#!/bin/bash
# SPDX-License-Identifier: MPL-2.0
# apply-ci-fixes.sh - Apply foundational CI/CD fixes estate-wide
#
# This script applies the following fixes to all repositories:
# 1. Updates CodeQL workflows to use SHA-pinned actions with persist-credentials: false
# 2. Updates reusable workflow pins to current standards main SHAs
# 3. Adds persist-credentials: false to all checkout actions
#
# Usage: ./apply-ci-fixes.sh [--dry-run] [--repo <repo-path>]
#
# If --repo is not specified, scans the entire estate.

set -euo pipefail

# Configuration
STANDARDS_REPO="/home/hyperpolymath/developer/hyper-repos/standards"
ESTATE_ROOT="/home/hyperpolymath/developer"
DRY_RUN=false
TARGET_REPO=""

# Current SHAs from standards main
CODEQL_REUSABLE_SHA="$(cd "$STANDARDS_REPO" && git rev-parse HEAD:.github/workflows/codeql-reusable.yml)"
HYPATIA_SCAN_REUSABLE_SHA="$(cd "$STANDARDS_REPO" && git rev-parse HEAD:.github/workflows/hypatia-scan-reusable.yml)"
SCORECARD_REUSABLE_SHA="$(cd "$STANDARDS_REPO" && git rev-parse HEAD:.github/workflows/scorecard-reusable.yml)"
GOVERNANCE_REUSABLE_SHA="$(cd "$STANDARDS_REPO" && git rev-parse HEAD:.github/workflows/governance-reusable.yml)"
SECRET_SCANNER_REUSABLE_SHA="$(cd "$STANDARDS_REPO" && git rev-parse HEAD:.github/workflows/secret-scanner-reusable.yml)"

# SHA-pinned action versions
ACTIONS_CHECKOUT_SHA="3d3c42e5aac5ba805825da76410c181273ba90b1"  # v7.0.1
CODEQL_INIT_SHA="cdf488f595d80d6e07e03d4674febd5ab45fa938"     # v3
CODEQL_ANALYZE_SHA="cdf488f595d80d6e07e03d4674febd5ab45fa938"  # v3

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --repo)
            TARGET_REPO="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Logging functions
log_info() {
    echo "[INFO] $1"
}

# Print a warning line to stdout.
log_warn() {
    echo "[WARN] $1"
}

# Print an error line.
log_error() {
    echo "[ERROR] $1" >&2
}

# Apply fixes to a single repository
apply_fixes_to_repo() {
    local repo_path="$1"
    local repo_name
    repo_name=$(basename "$repo_path")
    
    log_info "Processing: $repo_name"
    
    local files_changed=0
    
    # 1. Fix codeql.yml if it exists
    local codeql_file="$repo_path/.github/workflows/codeql.yml"
    if [[ -f "$codeql_file" ]]; then
        # Check if it uses tag-based refs
        if grep -q "codeql-action.*@v" "$codeql_file" || grep -q "actions/checkout@v" "$codeql_file"; then
            log_info "  Fixing codeql.yml..."
            
            # Backup
            cp "$codeql_file" "$codeql_file.bak"
            
            # Update checkout to SHA-pinned with persist-credentials: false
            sed -i \
                -e "s|actions/checkout@v[0-9].*\+|actions/checkout@$ACTIONS_CHECKOUT_SHA # v7.0.1\n        with:\n          persist-credentials: false|g" \
                -e "s|github/codeql-action/init@v[0-9].*\+|github/codeql-action/init@$CODEQL_INIT_SHA # v3|g" \
                -e "s|github/codeql-action/analyze@v[0-9].*\+|github/codeql-action/analyze@$CODEQL_ANALYZE_SHA # v3|g" \
                "$codeql_file"
            
            # Clean up backup if dry run
            if $DRY_RUN; then
                mv "$codeql_file.bak" "$codeql_file"
            else
                rm "$codeql_file.bak"
                ((files_changed++))
            fi
            
            log_info "  Fixed codeql.yml"
        fi
    fi
    
    # 2. Fix governance.yml if it exists and uses old SHA
    local governance_file="$repo_path/.github/workflows/governance.yml"
    if [[ -f "$governance_file" ]]; then
        if grep -q "governance-reusable.yml@[a-f0-9]\{40\}" "$governance_file"; then
            local current_sha
            current_sha=$(grep "governance-reusable.yml@" "$governance_file" | grep -oE '[a-f0-9]{40}' | head -1)
            if [[ "$current_sha" != "$GOVERNANCE_REUSABLE_SHA" ]]; then
                log_info "  Fixing governance.yml..."
                sed -i "s|governance-reusable.yml@[a-f0-9]\{40\}|governance-reusable.yml@$GOVERNANCE_REUSABLE_SHA|g" "$governance_file"
                ((files_changed++))
                log_info "  Fixed governance.yml"
            fi
        fi
    fi
    
    # 3. Fix scorecard.yml if it exists and uses old SHA
    local scorecard_file="$repo_path/.github/workflows/scorecard.yml"
    if [[ -f "$scorecard_file" ]]; then
        if grep -q "scorecard-reusable.yml@[a-f0-9]\{40\}" "$scorecard_file"; then
            local current_sha
            current_sha=$(grep "scorecard-reusable.yml@" "$scorecard_file" | grep -oE '[a-f0-9]{40}' | head -1)
            if [[ "$current_sha" != "$SCORECARD_REUSABLE_SHA" ]]; then
                log_info "  Fixing scorecard.yml..."
                sed -i "s|scorecard-reusable.yml@[a-f0-9]\{40\}|scorecard-reusable.yml@$SCORECARD_REUSABLE_SHA|g" "$scorecard_file"
                ((files_changed++))
                log_info "  Fixed scorecard.yml"
            fi
        fi
    fi
    
    # 4. Fix hypatia-scan.yml if it exists and uses old SHA
    local hypatia_file="$repo_path/.github/workflows/hypatia-scan.yml"
    if [[ -f "$hypatia_file" ]]; then
        if grep -q "hypatia-scan-reusable.yml@[a-f0-9]\{40\}" "$hypatia_file"; then
            local current_sha
            current_sha=$(grep "hypatia-scan-reusable.yml@" "$hypatia_file" | grep -oE '[a-f0-9]{40}' | head -1)
            if [[ "$current_sha" != "$HYPATIA_SCAN_REUSABLE_SHA" ]]; then
                log_info "  Fixing hypatia-scan.yml..."
                sed -i "s|hypatia-scan-reusable.yml@[a-f0-9]\{40\}|hypatia-scan-reusable.yml@$HYPATIA_SCAN_REUSABLE_SHA|g" "$hypatia_file"
                ((files_changed++))
                log_info "  Fixed hypatia-scan.yml"
            fi
        fi
    fi
    
    # 5. Fix secret-scanner.yml if it exists and uses old SHA
    local scanner_file="$repo_path/.github/workflows/secret-scanner.yml"
    if [[ -f "$scanner_file" ]]; then
        if grep -q "secret-scanner-reusable.yml@[a-f0-9]\{40\}" "$scanner_file"; then
            local current_sha
            current_sha=$(grep "secret-scanner-reusable.yml@" "$scanner_file" | grep -oE '[a-f0-9]{40}' | head -1)
            if [[ "$current_sha" != "$SECRET_SCANNER_REUSABLE_SHA" ]]; then
                log_info "  Fixing secret-scanner.yml..."
                sed -i "s|secret-scanner-reusable.yml@[a-f0-9]\{40\}|secret-scanner-reusable.yml@$SECRET_SCANNER_REUSABLE_SHA|g" "$scanner_file"
                ((files_changed++))
                log_info "  Fixed secret-scanner.yml"
            fi
        fi
    fi
    
    if [[ $files_changed -gt 0 ]]; then
        log_info "  Total files changed in $repo_name: $files_changed"
        
        if ! $DRY_RUN; then
            # Commit changes
            cd "$repo_path"
            git add -A
            git commit -m "fix(ci): apply foundation CI/CD security fixes

- Update CodeQL workflow to SHA-pinned actions with persist-credentials: false
- Update reusable workflow pins to current standards main SHAs

Generated by Mistral Vibe.
Co-Authored-By: Mistral Vibe <vibe@mistral.ai>"
            
            # Push changes
            git push origin HEAD
            
            log_info "  Committed and pushed changes for $repo_name"
        fi
    else
        log_info "  No changes needed for $repo_name"
    fi
}

# Main execution
log_info "Starting CI/CD fixes application"
log_info "Standards SHAs:"
log_info "  CODEQL_REUSABLE_SHA: $CODEQL_REUSABLE_SHA"
log_info "  HYPATIA_SCAN_REUSABLE_SHA: $HYPATIA_SCAN_REUSABLE_SHA"
log_info "  SCORECARD_REUSABLE_SHA: $SCORECARD_REUSABLE_SHA"
log_info "  GOVERNANCE_REUSABLE_SHA: $GOVERNANCE_REUSABLE_SHA"

if [[ -n "$TARGET_REPO" ]]; then
    # Apply to specific repo
    if [[ -d "$TARGET_REPO" ]]; then
        apply_fixes_to_repo "$TARGET_REPO"
    else
        log_error "Repository not found: $TARGET_REPO"
        exit 1
    fi
else
    # Scan entire estate
    log_info "Scanning entire estate..."
    
    # Find all repos in hyper-repos and meta-repos
    find "$ESTATE_ROOT/hyper-repos" "$ESTATE_ROOT/meta-repos" -maxdepth 2 -name ".git" -type d | while read git_dir; do
        repo_path=$(dirname "$git_dir")
        apply_fixes_to_repo "$repo_path"
    done
fi

log_info "CI/CD fixes application complete"
