#!/bin/bash
ORG=$1
DEST_DIR=$2

if [ -z "$ORG" ] || [ -z "$DEST_DIR" ]; then
    echo "Usage: $0 <org_name> <destination_directory>"
    exit 1
fi

# Guard: a flat org clone at developer/ or developer/repos recreates the rogue
# duplicate tree that caused the 2026-07-28 supersede incident. Estate layout
# only supports hyper-repos/ and meta-repos/ as clone destinations — an ALLOWLIST,
# because the old denylist (developer/, developer/repos) let every other stray through.
DEST_ABS=$(readlink -f "$DEST_DIR" 2>/dev/null || realpath -m "$DEST_DIR")
DEV_ROOT="$HOME/developer"
case $DEST_ABS in "$DEV_ROOT"/hyper-repos|"$DEV_ROOT"/hyper-repos/*|"$DEV_ROOT"/meta-repos|"$DEV_ROOT"/meta-repos/*) ;; *)
    echo "REFUSED: '$DEST_ABS' is not a supported destination."
    echo "Clone into $DEV_ROOT/hyper-repos or $DEV_ROOT/meta-repos instead."
    exit 1
;; esac

echo "Synchronizing organization: $ORG into $DEST_DIR"
mkdir -p "$DEST_DIR"
cd "$DEST_DIR" || exit 1

echo "Scanning local directory $DEST_DIR for existing repositories..."
declare -A LOCAL_REPOS
while IFS= read -r git_dir; do
    repo_dir=$(dirname "$git_dir")
    repo_name=$(basename "$repo_dir")
    # Store the relative path
    LOCAL_REPOS["$repo_name"]="$repo_dir"
done < <(find . -type d -name ".git" 2>/dev/null)

echo "Found ${#LOCAL_REPOS[@]} local repositories."

echo "Fetching repository list for $ORG from GitHub..."
REPOS=$(gh repo list "$ORG" --limit 1000 --json name --jq '.[].name')
TOTAL_REPOS=$(echo "$REPOS" | wc -w)
echo "Found $TOTAL_REPOS remote repositories."

COUNT=0
for REPO in $REPOS; do
    COUNT=$((COUNT+1))
    echo "[$COUNT/$TOTAL_REPOS] Processing $REPO..."

    # Repos whose one checkout lives outside hyper-repos/meta-repos (AGENTS.md §1):
    # cloning them here would create a second copy.
    case "$ORG/$REPO" in hyperpolymath/tools|hyperpolymath/estate-scripts)
        echo "  Skipping $REPO: its one checkout lives directly under $DEV_ROOT."
        continue
    ;; esac

    if [ -n "${LOCAL_REPOS[$REPO]+isset}" ]; then
        EXISTING_PATH="${LOCAL_REPOS[$REPO]}"
        echo "  Repository $REPO exists locally at $EXISTING_PATH. Syncing..."
        (
            cd "$EXISTING_PATH" || exit
            if [ -n "$(git status --porcelain)" ]; then
                echo "  WARNING: Uncommitted changes in $REPO. Stashing..."
                git stash
            fi
            
            git fetch --all --prune --quiet
            DEFAULT_BRANCH=$(git remote show origin 2>/dev/null | grep 'HEAD branch' | awk '{print $NF}')
            if [ -z "$DEFAULT_BRANCH" ]; then
                DEFAULT_BRANCH="main" 
            fi
            git checkout "$DEFAULT_BRANCH" --quiet 2>/dev/null || git checkout master --quiet 2>/dev/null
            git pull origin "$DEFAULT_BRANCH" --rebase --quiet 2>/dev/null || git pull origin master --rebase --quiet 2>/dev/null
        )
    else
        echo "  Repository $REPO does not exist locally anywhere. Cloning into top level..."
        gh repo clone "$ORG/$REPO" -- -q
    fi
done

echo "Synchronization of $ORG complete."
