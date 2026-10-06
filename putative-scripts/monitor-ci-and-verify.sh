#!/bin/bash
# SPDX-License-Identifier: MPL-2.0
# Monitor CI status and verify fixes

set -euo pipefail

# List of repos with fix branches
REPOS=(
    "/home/hyperpolymath/developer/hyper-repos/jtv-halting-islands-ct"
    "/home/hyperpolymath/developer/hyper-repos/metadatastician/idaptik-ums"
    "/home/hyperpolymath/developer/hyper-repos/_EXTENSIONS _SET/oikosbot"
    "/home/hyperpolymath/developer/hyper-repos/_OPM (other peoples repos) _SET/awesome-idris2"
    "/home/hyperpolymath/developer/hyper-repos/_RSR _SET/rsr-julia-library-template-repo"
    "/home/hyperpolymath/developer/hyper-repos/_RSR _SET/rsr-template-repo"
    "/home/hyperpolymath/developer/hyper-repos/_JULIA_LIBRARIES _SET/Cliometrics.jl"
    "/home/hyperpolymath/developer/hyper-repos/_JULIA_LIBRARIES _SET/Cliodynamics.jl"
    "/home/hyperpolymath/developer/hyper-repos/_JULIA_LIBRARIES _SET/JuliaForChildren.jl"
    "/home/hyperpolymath/developer/hyper-repos/_WORK _SET/academic-workflow-suite"
    "/home/hyperpolymath/developer/hyper-repos/proven-tests-and-benches"
    "/home/hyperpolymath/developer/hyper-repos/_HARDWARE _SET/neurophone"
    "/home/hyperpolymath/developer/hyper-repos/_DATABASE _SET/hermeneia"
    "/home/hyperpolymath/developer/hyper-repos/_NETWORK _SET/ipv6-tools"
    "/home/hyperpolymath/developer/hyper-repos/_NETWORK _SET/ipfs-overlay"
    "/home/hyperpolymath/developer/hyper-repos/casket-ssg"
    "/home/hyperpolymath/developer/meta-repos/universal-modding-studio"
)

echo "=========================================="
echo "CI/CD Status Monitor"
echo "=========================================="
echo ""

for repo_path in "${REPOS[@]}"; do
    repo_name=$(basename "$repo_path")
    
    if [[ "$repo_path" == *"hyper-repos/"* ]]; then
        org="hyperpolymath"
    elif [[ "$repo_path" == *"meta-repos/"* ]]; then
        org="metadatastician"
    else
        continue
    fi
    
    echo "Checking: $org/$repo_name"
    cd "$repo_path"
    
    # Check if fix branch exists
    if git rev-parse "origin/chore/apply-foundation-ci-fixes-20260911" >/dev/null 2>&1; then
        # Check if PR exists
        PR_NUM=$(gh pr list --head chore/apply-foundation-ci-fixes-20260911 --json number --jq '.[] | .number' 2>/dev/null || true)
        
        if [[ -n "$PR_NUM" ]]; then
            STATE=$(gh pr view "$PR_NUM" --json state,mergeable,mergeStateStatus --jq '.state + "/" + .mergeable + "/" + .mergeStateStatus' 2>/dev/null || echo "UNKNOWN")
            echo "  PR #$PR_NUM - State: $STATE"
            
            # Get checks status
            echo "  CI Checks:"
            gh pr checks "$PR_NUM" 2>&1 | head -10 | sed 's/^/    /'
            
            # Get workflow runs for the branch
            echo "  Recent Workflow Runs:"
            gh run list --head "$chore/apply-foundation-ci-fixes-20260911" --limit 5 --json name,status,conclusion --jq '.[] | "    " + .name + " - " + (.status + "/" + .conclusion)' 2>/dev/null || echo "    (unable to query)"
        else
            echo "  Branch exists but no PR found"
            echo "  Workflow Runs:"
            gh run list --head "chore/apply-foundation-ci-fixes-20260911" --limit 5 --json name,status,conclusion --jq '.[] | "    " + .name + " - " + (.status + "/" + .conclusion)' 2>/dev/null || echo "    (unable to query)"
        fi
    else
        echo "  No fix branch found"
    fi
    echo ""
done

echo "=========================================="
echo "Monitoring complete"
echo "=========================================="
