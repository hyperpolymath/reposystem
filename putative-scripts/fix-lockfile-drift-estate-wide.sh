#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Estate-wide lockfile drift fix script
# This script fixes the root cause of CI/CD flow blocking: lockfile drift
# between workflows and actions.lock after Dependabot bumps action versions.
#
# Usage: ./fix-lockfile-drift-estate-wide.sh [--dry-run] [--repo <repo-path>]
#
# The --dry-run flag will show what would be done without making changes
# The --repo flag will process only a specific repository
# Without flags, processes all repos in the estate with Dependabot action bumps

set -uo pipefail

DRY_RUN=false
SPECIFIC_REPO=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --repo)
      SPECIFIC_REPO="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print an error line.
log_error() {
  echo -e "${RED}❌ $1${NC}"
}

# Print a success line.
log_success() {
  echo -e "${GREEN}✅ $1${NC}"
}

# Print a warning line.
log_warning() {
  echo -e "${YELLOW}⚠️  $1${NC}"
}

# Print an indented informational line.
log_info() {
  echo -e "   $1"
}

# Standards repo path (for scripts)
STANDARDS_REPO="/home/hyperpolymath/developer/hyper-repos/standards"

# Check if standards repo exists and has the required scripts
if [ ! -d "$STANDARDS_REPO/scripts" ]; then
  log_error "Standards repo not found at $STANDARDS_REPO"
  exit 1
fi

if [ ! -f "$STANDARDS_REPO/scripts/update-actions-lock.sh" ]; then
  log_error "update-actions-lock.sh not found in standards repo"
  exit 1
fi

# Function to regenerate lockfile for a repo
regenerate_lockfile() {
  repo_path="$1"
  repo_name="$2"
  
  log_info "Processing $repo_name..."
  
  # Check if repo has actions.lock
  lockfile="$repo_path/.github/workflows/actions.lock"
  if [ ! -f "$lockfile" ]; then
    log_warning "$repo_name: No actions.lock file found, skipping"
    return 0
  fi
  
  # Check if repo has workflow files
  if [ ! -d "$repo_path/.github/workflows" ]; then
    log_warning "$repo_name: No workflows directory found, skipping"
    return 0
  fi
  
  # Check if there are any workflow files
  workflow_count=$(find "$repo_path/.github/workflows" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) | wc -l)
  if [ "$workflow_count" -eq 0 ]; then
    log_warning "$repo_name: No workflow files found, skipping"
    return 0
  fi
  
  # Check if there are Dependabot branches for github_actions
  has_dependabot_actions=false
  if [ -d "$repo_path/.git" ]; then
    dependabot_branches=$(git -C "$repo_path" branch -a 2>/dev/null | grep -E "dependabot/github_actions" || true)
    if [ -n "$dependabot_branches" ]; then
      has_dependabot_actions=true
      if [ "$DRY_RUN" = true ]; then
        echo "$dependabot_branches" | while read -r branch; do
          log_info "  Dependabot branch: $branch"
        done
      fi
    fi
  fi
  
  # Check if there are local Dependabot branches (unmerged)
  local_dependabot_branches=""
  if [ -d "$repo_path/.git" ]; then
    local_dependabot_branches=$(git -C "$repo_path" branch --list "dependabot/github_actions/*" 2>/dev/null | sed 's/^[ *]*//' || true)
  fi
  
  # Check if main/workflow files have been modified but lockfile not updated
  # We can do this by running the update script in verify mode
  log_info "  Checking for lockfile drift..."
  
  drift_detected=false
  if bash "$STANDARDS_REPO/scripts/update-actions-lock.sh" --verify-local "$repo_path/.github/workflows" 2>&1 | grep -q "FAILED\|drift\|invalid"; then
    drift_detected=true
  fi
  
  # Also check if the lockfile verifies successfully
  verify_output=$(bash "$STANDARDS_REPO/scripts/update-actions-lock.sh" --verify-local "$repo_path/.github/workflows" 2>&1) || true
  verify_rc=$?
  
  if [ "$verify_rc" -ne 0 ] || echo "$verify_output" | grep -q "FAILED\|not in sync"; then
    drift_detected=true
  fi
  
  if [ "$drift_detected" = true ]; then
    log_warning "$repo_name: Lockfile drift DETECTED"
    
    if [ "$DRY_RUN" = true ]; then
      log_info "  Would regenerate actions.lock"
      return 0
    fi
    
    # Regenerate the lockfile
    log_info "  Regenerating actions.lock..."
    if bash "$STANDARDS_REPO/scripts/update-actions-lock.sh" "$repo_path/.github/workflows" 2>&1; then
      log_success "$repo_name: Lockfile regenerated successfully"
      return 0
    else
      log_error "$repo_name: Failed to regenerate lockfile"
      return 1
    fi
  else
    log_success "$repo_name: No lockfile drift detected"
    
    # Check if there are unmerged Dependabot branches
    if [ -n "$local_dependabot_branches" ]; then
      log_warning "$repo_name: Has unmerged Dependabot branches but no drift on main"
      log_info "  This means the Dependabot changes haven't been merged to main yet"
      if [ "$DRY_RUN" = true ]; then
        echo "$local_dependabot_branches" | while read -r branch; do
          log_info "    Branch: $branch"
        done
      fi
    fi
    
    return 0
  fi
}

# Function to find all repos in the estate
find_repos() {
  repo_list=""
  
  # Look in hyper-repos and meta-repos
  local search_paths=(
    "/home/hyperpolymath/developer/hyper-repos"
    "/home/hyperpolymath/developer/meta-repos"
  )
  
  for search_path in "${search_paths[@]}"; do
    if [ -d "$search_path" ]; then
      # Find all .git directories (these are repo roots)
      while IFS= read -r -d '' git_dir; do
        repo_path="$(dirname "$git_dir")"
        
        # Skip if this is a worktree (has .git file pointing to another repo)
        if [ -f "$repo_path/.git" ] && [ ! -d "$repo_path/.git" ]; then
          continue
        fi
        
        # Check if this repo has workflows
        if [ -d "$repo_path/.github/workflows" ]; then
          # Check if it has actions.lock
          if [ -f "$repo_path/.github/workflows/actions.lock" ]; then
            repo_list+="$repo_path "
          fi
        fi
      done < <(find "$search_path" -name ".git" -type d -print0 2>/dev/null)
    fi
  done
  
  echo "$repo_list"
}

# Main logic
log_info "Lockfile Drift Fix Script"
log_info "========================"
log_info ""

if [ "$DRY_RUN" = true ]; then
  log_warning "Running in DRY-RUN mode - no changes will be made"
fi
log_info ""

if [ -n "$SPECIFIC_REPO" ]; then
  # Process only the specific repo
  if [ -d "$SPECIFIC_REPO" ]; then
    repo_name=$(basename "$SPECIFIC_REPO")
    regenerate_lockfile "$SPECIFIC_REPO" "$repo_name"
  else
    log_error "Repository not found: $SPECIFIC_REPO"
    exit 1
  fi
else
  # Process all repos in the estate
  log_info "Scanning estate for repos with lockfiles..."
  repos=$(find_repos)
  
  if [ -z "$repos" ]; then
    log_error "No repos with lockfiles found in the estate"
    exit 1
  fi
  
  log_info "Found $(echo "$repos" | wc -w) repos with lockfiles"
  log_info ""
  
  local total=0
  local drift_found=0
  local fixed=0
  local errors=0
  
  total=0
  errors=0
  for repo_path in $repos; do
    total=$((total + 1))
    repo_name=$(basename "$repo_path")
    
    if regenerate_lockfile "$repo_path" "$repo_name"; then
      # Check if drift was detected
      # This is a bit hacky, but we can check the output
      : # placeholder
    else
      errors=$((errors + 1))
    fi
    
    log_info ""
  done
  
  log_info "Summary:"
  log_info "  Total repos checked: $total"
  log_info "  Errors: $errors"
  
  if [ "$DRY_RUN" = true ]; then
    log_warning "  (Dry run - no changes were actually made)"
  fi
fi

log_success "Done!"
