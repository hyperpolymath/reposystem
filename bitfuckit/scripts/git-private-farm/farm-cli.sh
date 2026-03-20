#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0
# farm-cli.sh - CLI for managing .git-private-farm
#
# Quick commands for instant multi-forge propagation

set -euo pipefail

FARM_REPO="hyperpolymath/.git-private-farm"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Propagate a single repo instantly
propagate() {
    local repo="${1:-}"
    local forges="${2:-}"

    if [[ -z "$repo" ]]; then
        # Get current repo name
        repo=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null) || {
            echo -e "${RED}Error: Not in a git repo and no repo specified${NC}"
            exit 1
        }
    fi

    echo -e "${BLUE}Triggering instant propagation for: ${GREEN}$repo${NC}"

    local payload="{\"repo\":\"$repo\",\"forges\":\"$forges\"}"

    gh workflow run propagate.yml \
        --repo "$FARM_REPO" \
        -f "repo=$repo" \
        -f "forges=$forges"

    echo -e "${GREEN}Propagation triggered!${NC}"
    echo -e "Monitor at: ${BLUE}https://github.com/$FARM_REPO/actions${NC}"
}

# Propagate with force push
force_propagate() {
    local repo="${1:-}"
    local forges="${2:-}"

    [[ -z "$repo" ]] && repo=$(basename "$(git rev-parse --show-toplevel)")

    echo -e "${YELLOW}WARNING: Force propagation will overwrite remote history${NC}"
    read -p "Continue? [y/N] " confirm
    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && exit 0

    gh workflow run propagate.yml \
        --repo "$FARM_REPO" \
        -f "repo=$repo" \
        -f "forges=$forges" \
        -f "force=true"

    echo -e "${GREEN}Force propagation triggered!${NC}"
}

# Batch propagate all repos
batch() {
    local forges="${1:-}"

    echo -e "${YELLOW}This will sync ALL repos to ${forges:-all forges}${NC}"
    read -p "Type CONFIRM to proceed: " confirm
    [[ "$confirm" != "CONFIRM" ]] && { echo "Aborted."; exit 0; }

    gh workflow run batch-propagate.yml \
        --repo "$FARM_REPO" \
        -f "forges=$forges" \
        -f "confirm=CONFIRM"

    echo -e "${GREEN}Batch propagation triggered!${NC}"
}

# Check propagation status
status() {
    echo -e "${BLUE}Recent propagation runs:${NC}"
    gh run list --repo "$FARM_REPO" --limit 10
}

# Watch a running propagation
watch_run() {
    local run_id="${1:-}"

    if [[ -z "$run_id" ]]; then
        # Get most recent run
        run_id=$(gh run list --repo "$FARM_REPO" --limit 1 --json databaseId -q '.[0].databaseId')
    fi

    gh run watch "$run_id" --repo "$FARM_REPO"
}

# Add dispatch trigger to current repo
setup_dispatch() {
    local workflow_dir=".github/workflows"
    local dispatch_file="$workflow_dir/instant-dispatch.yml"

    mkdir -p "$workflow_dir"

    if [[ -f "$dispatch_file" ]]; then
        echo -e "${YELLOW}Dispatch workflow already exists${NC}"
        return
    fi

    cat > "$dispatch_file" << 'EOF'
# SPDX-License-Identifier: PMPL-1.0
name: Instant Forge Sync

on:
  push:
    branches: [main, master]
  release:
    types: [published]

permissions:
  contents: read

jobs:
  dispatch:
    runs-on: ubuntu-latest
    steps:
      - name: Trigger Propagation
        uses: peter-evans/repository-dispatch@ff45666b9427631e3450c54a1bcbee4d9ff4d7c0
        with:
          token: ${{ secrets.FARM_DISPATCH_TOKEN }}
          repository: hyperpolymath/.git-private-farm
          event-type: propagate
          client-payload: |
            {
              "repo": "${{ github.event.repository.name }}",
              "ref": "${{ github.ref }}",
              "sha": "${{ github.sha }}",
              "forges": ""
            }
EOF

    echo -e "${GREEN}Created $dispatch_file${NC}"
    echo -e "${YELLOW}Remember to add FARM_DISPATCH_TOKEN secret to this repo!${NC}"
}

# Show available forges
forges() {
    echo -e "${BLUE}Available Forges:${NC}"
    echo "  gitlab     - GitLab.com"
    echo "  sourcehut  - SourceHut (sr.ht)"
    echo "  codeberg   - Codeberg.org"
    echo "  bitbucket  - Bitbucket.org"
    echo ""
    echo "Usage: farm propagate <repo> <forge1,forge2,...>"
}

# Help
usage() {
    cat << 'EOF'
farm-cli.sh - Instant multi-forge propagation

Usage:
    farm propagate [repo] [forges]     Propagate repo to forges (default: all)
    farm force [repo] [forges]         Force propagate (overwrites history)
    farm batch [forges]                Sync ALL repos to forges
    farm status                        Show recent propagation runs
    farm watch [run_id]                Watch a propagation run
    farm setup                         Add dispatch trigger to current repo
    farm forges                        List available forges

Examples:
    farm propagate                     # Current repo to all forges
    farm propagate bitfuckit           # Specific repo to all forges
    farm propagate bitfuckit gitlab    # Specific repo to GitLab only
    farm propagate . gitlab,codeberg   # Current repo to GitLab and Codeberg
    farm batch                         # Sync everything everywhere
    farm setup                         # Add instant sync to current repo

Speed:
    Propagation typically completes in 5-15 seconds for all forges.
    All forges are synced in parallel.
EOF
}

# Main
case "${1:-}" in
    propagate|push|p)
        shift
        propagate "$@"
        ;;
    force)
        shift
        force_propagate "$@"
        ;;
    batch|all)
        shift
        batch "$@"
        ;;
    status|s)
        status
        ;;
    watch|w)
        shift
        watch_run "$@"
        ;;
    setup|init)
        setup_dispatch
        ;;
    forges|list)
        forges
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        usage
        exit 1
        ;;
esac
