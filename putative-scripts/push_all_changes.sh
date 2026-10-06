#!/bin/bash
# push_all_changes.sh - Push all local changes to GitHub

set -euo pipefail

# Find all repos with local changes and push them
find /home/hyperpolymath/developer/hyper-repos /home/hyperpolymath/developer/meta-repos -type d -name ".git" -printf "%h\n" 2>/dev/null | while read -r repo; do
  if [ -d "$repo/.git" ]; then
    cd "$repo"
    
    # Check if there are any commits that haven't been pushed
    if ! git diff --quiet @{u} 2>/dev/null; then
      echo "Pushing: $(basename "$repo")"
      git push 2>&1 | tail -1
    fi
  fi
done

echo ""
echo "✓ All repos pushed!"
