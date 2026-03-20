#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0
# SPDX-FileCopyrightText: 2025 Hyperpolymath
#
# forge-mesh.sh - Resilient multi-forge mirroring with fallback mesh
#
# Architecture:
#   - GitHub is the single source of truth (primary hub)
#   - All spokes can serve as temporary fallbacks if GitHub unreachable
#   - State file tracks last successful sync per forge
#   - Degraded mode warnings when operating from fallback
#   - Auto-recovery when primary comes back online

set -euo pipefail

# Configuration
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/forge-mesh"
STATE_FILE="$STATE_DIR/sync-state.json"
LOCK_FILE="$STATE_DIR/mesh.lock"
LOG_FILE="$STATE_DIR/mesh.log"

# Forge definitions (priority order for fallback)
declare -A FORGES=(
    [github]="git@github.com:hyperpolymath"
    [gitlab]="git@gitlab.com:hyperpolymath"
    [sourcehut]="git@git.sr.ht:~hyperpolymath"
    [codeberg]="git@codeberg.org:hyperpolymath"
    [bitbucket]="git@bitbucket.org:hyperpolymath"
    [radicle]="rad://hyperpolymath"  # Special handling
)

# Fallback priority (excluding primary)
FALLBACK_ORDER=(gitlab sourcehut codeberg bitbucket)

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging
log() {
    local level="$1"
    shift
    local msg="$*"
    local timestamp
    timestamp=$(date -Iseconds)
    echo "[$timestamp] [$level] $msg" >> "$LOG_FILE"

    case "$level" in
        ERROR)   echo -e "${RED}ERROR:${NC} $msg" >&2 ;;
        WARN)    echo -e "${YELLOW}WARN:${NC} $msg" ;;
        INFO)    echo -e "${GREEN}INFO:${NC} $msg" ;;
        DEBUG)   [[ "${DEBUG:-}" == "1" ]] && echo -e "${CYAN}DEBUG:${NC} $msg" ;;
        DEGRADED) echo -e "${YELLOW}[DEGRADED MODE]${NC} $msg" ;;
    esac
}

# Initialize state directory
init_state() {
    mkdir -p "$STATE_DIR"
    if [[ ! -f "$STATE_FILE" ]]; then
        echo '{"forges":{}, "primary":"github", "mode":"normal"}' > "$STATE_FILE"
    fi
}

# Update sync state for a forge
update_sync_state() {
    local forge="$1"
    local status="$2"  # success, failed, unreachable
    local commit_hash="${3:-}"
    local timestamp
    timestamp=$(date -Iseconds)

    # Using jq if available, otherwise simple sed
    if command -v jq &>/dev/null; then
        local tmp
        tmp=$(mktemp)
        jq --arg forge "$forge" \
           --arg status "$status" \
           --arg ts "$timestamp" \
           --arg hash "$commit_hash" \
           '.forges[$forge] = {
               "last_sync": $ts,
               "status": $status,
               "commit": $hash
           }' "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
    else
        log DEBUG "jq not available, using simple state tracking"
        echo "{\"forge\":\"$forge\",\"status\":\"$status\",\"timestamp\":\"$timestamp\"}" >> "$STATE_DIR/sync-log.jsonl"
    fi
}

# Get last successful sync info for a forge
get_sync_state() {
    local forge="$1"
    if command -v jq &>/dev/null && [[ -f "$STATE_FILE" ]]; then
        jq -r ".forges[\"$forge\"] // empty" "$STATE_FILE"
    fi
}

# Check if a forge is reachable
check_forge_health() {
    local forge="$1"
    local url="${FORGES[$forge]}"

    case "$forge" in
        github)
            # Check GitHub API and SSH
            if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
                return 0
            elif curl -sf --max-time 5 "https://api.github.com/zen" &>/dev/null; then
                return 0
            fi
            return 1
            ;;
        gitlab)
            ssh -T git@gitlab.com 2>&1 | grep -q "Welcome" && return 0
            curl -sf --max-time 5 "https://gitlab.com/api/v4/version" &>/dev/null && return 0
            return 1
            ;;
        sourcehut)
            ssh -T git@git.sr.ht 2>&1 | grep -qi "authenticated" && return 0
            curl -sf --max-time 5 "https://meta.sr.ht/api/version" &>/dev/null && return 0
            return 1
            ;;
        codeberg)
            ssh -T git@codeberg.org 2>&1 | grep -q "successfully authenticated" && return 0
            curl -sf --max-time 5 "https://codeberg.org/api/v1/version" &>/dev/null && return 0
            return 1
            ;;
        bitbucket)
            ssh -T git@bitbucket.org 2>&1 | grep -q "logged in" && return 0
            curl -sf --max-time 5 "https://api.bitbucket.org/2.0/user" &>/dev/null && return 0
            return 1
            ;;
        radicle)
            command -v rad &>/dev/null && rad self 2>/dev/null && return 0
            return 1
            ;;
        *)
            return 1
            ;;
    esac
}

# Find best available fallback source
find_fallback_source() {
    local repo="$1"
    local best_forge=""
    local best_time=""

    for forge in "${FALLBACK_ORDER[@]}"; do
        if check_forge_health "$forge"; then
            local state
            state=$(get_sync_state "$forge")
            if [[ -n "$state" ]]; then
                local sync_time
                sync_time=$(echo "$state" | jq -r '.last_sync // empty' 2>/dev/null)
                local status
                status=$(echo "$state" | jq -r '.status // empty' 2>/dev/null)

                if [[ "$status" == "success" && -n "$sync_time" ]]; then
                    # Compare timestamps (simple string comparison works for ISO format)
                    if [[ -z "$best_time" || "$sync_time" > "$best_time" ]]; then
                        best_forge="$forge"
                        best_time="$sync_time"
                    fi
                fi
            fi
        fi
    done

    if [[ -n "$best_forge" ]]; then
        echo "$best_forge"
        return 0
    fi
    return 1
}

# Sync from source to destination
sync_forge() {
    local repo="$1"
    local source="$2"
    local dest="$3"
    local source_url="${FORGES[$source]}/$repo.git"
    local dest_url="${FORGES[$dest]}/$repo.git"

    local work_dir
    work_dir=$(mktemp -d)
    trap "rm -rf $work_dir" EXIT

    log INFO "Syncing $repo: $source -> $dest"

    # Clone from source
    if ! git clone --mirror "$source_url" "$work_dir/repo.git" 2>/dev/null; then
        log ERROR "Failed to clone from $source"
        return 1
    fi

    cd "$work_dir/repo.git"
    local commit_hash
    commit_hash=$(git rev-parse HEAD 2>/dev/null || echo "unknown")

    # Push to destination
    if git push --mirror "$dest_url" 2>/dev/null; then
        log INFO "Successfully pushed to $dest (commit: ${commit_hash:0:8})"
        update_sync_state "$dest" "success" "$commit_hash"
        return 0
    else
        log ERROR "Failed to push to $dest"
        update_sync_state "$dest" "failed" "$commit_hash"
        return 1
    fi
}

# Main mirror operation with fallback
mirror_with_fallback() {
    local repo="$1"
    local primary="github"
    local mode="normal"
    local source_forge=""

    log INFO "Starting mirror operation for $repo"

    # Check primary (GitHub) health
    if check_forge_health "$primary"; then
        log INFO "Primary ($primary) is healthy"
        source_forge="$primary"
        mode="normal"
    else
        log WARN "Primary ($primary) is UNREACHABLE!"

        # Find best fallback
        source_forge=$(find_fallback_source "$repo") || {
            log ERROR "No healthy fallback sources available!"
            return 1
        }

        mode="degraded"
        log DEGRADED "Using $source_forge as temporary source (last synced: $(get_sync_state "$source_forge" | jq -r '.last_sync' 2>/dev/null))"

        echo ""
        echo -e "${YELLOW}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║  WARNING: OPERATING IN DEGRADED MODE                           ║${NC}"
        echo -e "${YELLOW}║                                                                ║${NC}"
        echo -e "${YELLOW}║  Primary source (GitHub) is unreachable.                       ║${NC}"
        echo -e "${YELLOW}║  Using fallback: $source_forge                                       ║${NC}"
        echo -e "${YELLOW}║                                                                ║${NC}"
        echo -e "${YELLOW}║  Data may be stale. Will auto-recover when GitHub is back.    ║${NC}"
        echo -e "${YELLOW}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
    fi

    # Update state file with current mode
    if command -v jq &>/dev/null; then
        local tmp
        tmp=$(mktemp)
        jq --arg mode "$mode" --arg source "$source_forge" \
           '.mode = $mode | .current_source = $source' "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
    fi

    # Sync to all healthy destinations
    local success_count=0
    local fail_count=0

    for dest in "${!FORGES[@]}"; do
        [[ "$dest" == "$source_forge" ]] && continue
        [[ "$dest" == "radicle" ]] && continue  # Radicle needs special handling

        if check_forge_health "$dest"; then
            if sync_forge "$repo" "$source_forge" "$dest"; then
                ((success_count++))
            else
                ((fail_count++))
            fi
        else
            log WARN "$dest is unreachable, skipping"
            update_sync_state "$dest" "unreachable" ""
        fi
    done

    # Summary
    echo ""
    log INFO "Mirror complete: $success_count succeeded, $fail_count failed"

    if [[ "$mode" == "degraded" ]]; then
        log WARN "Remember: Operating in degraded mode. Run again when GitHub is available."
    fi

    return 0
}

# Spoke-to-spoke sync (when one spoke can't reach primary but another can)
spoke_sync() {
    local repo="$1"
    local target="$2"  # The spoke that needs updating

    log INFO "Attempting spoke-to-spoke sync for $target"

    # Can target reach GitHub directly?
    if check_forge_health github; then
        log INFO "GitHub reachable, using direct sync"
        sync_forge "$repo" "github" "$target"
        return $?
    fi

    # Find a spoke that was recently synced
    local source
    source=$(find_fallback_source "$repo") || {
        log ERROR "No valid source found for spoke-to-spoke sync"
        return 1
    }

    log DEGRADED "Syncing $target from $source (spoke-to-spoke)"
    sync_forge "$repo" "$source" "$target"
}

# Health check all forges
health_check() {
    echo -e "${BLUE}Forge Health Status${NC}"
    echo "==================="

    for forge in github "${FALLBACK_ORDER[@]}" radicle; do
        printf "%-12s: " "$forge"
        if check_forge_health "$forge"; then
            echo -e "${GREEN}HEALTHY${NC}"

            local state
            state=$(get_sync_state "$forge")
            if [[ -n "$state" ]]; then
                local last_sync status
                last_sync=$(echo "$state" | jq -r '.last_sync // "never"' 2>/dev/null)
                status=$(echo "$state" | jq -r '.status // "unknown"' 2>/dev/null)
                echo "             Last sync: $last_sync ($status)"
            fi
        else
            echo -e "${RED}UNREACHABLE${NC}"
        fi
    done

    echo ""

    # Show current mode
    if [[ -f "$STATE_FILE" ]] && command -v jq &>/dev/null; then
        local mode current_source
        mode=$(jq -r '.mode // "normal"' "$STATE_FILE")
        current_source=$(jq -r '.current_source // "github"' "$STATE_FILE")

        if [[ "$mode" == "degraded" ]]; then
            echo -e "${YELLOW}Mode: DEGRADED (using $current_source as source)${NC}"
        else
            echo -e "${GREEN}Mode: NORMAL (using GitHub as source)${NC}"
        fi
    fi
}

# Recovery: Re-sync everything from GitHub when it comes back
recover_from_degraded() {
    local repo="$1"

    log INFO "Checking if recovery from degraded mode is possible..."

    if ! check_forge_health github; then
        log WARN "GitHub still unreachable, cannot recover"
        return 1
    fi

    log INFO "GitHub is back! Initiating recovery sync..."

    # Update all spokes from GitHub
    for dest in "${FALLBACK_ORDER[@]}"; do
        if check_forge_health "$dest"; then
            sync_forge "$repo" "github" "$dest"
        fi
    done

    # Update mode to normal
    if command -v jq &>/dev/null; then
        local tmp
        tmp=$(mktemp)
        jq '.mode = "normal" | .current_source = "github"' "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
    fi

    log INFO "Recovery complete! All forges synced from GitHub."
}

# Show usage
usage() {
    cat << 'EOF'
Usage: forge-mesh.sh <command> [options]

Commands:
    mirror <repo>       Mirror repository to all forges (with fallback)
    health              Check health of all forges
    sync <repo> <dest>  Sync specific repo to specific destination
    recover <repo>      Re-sync all forges from GitHub after recovery
    status              Show current sync state

Options:
    --debug             Enable debug logging

Examples:
    forge-mesh.sh mirror bitfuckit
    forge-mesh.sh health
    forge-mesh.sh sync bitfuckit codeberg
    forge-mesh.sh recover bitfuckit

Architecture:
    GitHub is the single source of truth. If GitHub becomes unreachable,
    the most recently synced spoke becomes a temporary source. When GitHub
    comes back, run 'recover' to re-establish it as the source.

    Degraded mode warnings are shown when operating from a fallback source.
EOF
}

# Main
main() {
    init_state

    case "${1:-}" in
        mirror)
            [[ -z "${2:-}" ]] && { usage; exit 1; }
            mirror_with_fallback "$2"
            ;;
        health|status)
            health_check
            ;;
        sync)
            [[ -z "${2:-}" || -z "${3:-}" ]] && { usage; exit 1; }
            spoke_sync "$2" "$3"
            ;;
        recover)
            [[ -z "${2:-}" ]] && { usage; exit 1; }
            recover_from_degraded "$2"
            ;;
        --help|-h|help)
            usage
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

# Handle --debug flag
if [[ "${1:-}" == "--debug" ]]; then
    DEBUG=1
    shift
fi

main "$@"
