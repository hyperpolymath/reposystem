#!/usr/bin/env bash
# deprecate-poly-mcps.sh — Add deprecation notices to poly-*-mcp repos
#
# For each poly-*-mcp repo:
#   1. Adds a deprecation banner to README
#   2. Adds .language-policy.toml with role = "deprecated"
#   3. Opens a PR (does NOT archive the repo)
#
# Usage:
#   ./deprecate-poly-mcps.sh hyperpolymath
#   ./deprecate-poly-mcps.sh hyperpolymath --dry-run
#
# Requirements: gh (authenticated), git

set -euo pipefail

ORG="${1:?Usage: $0 <github-org> [--dry-run]}"
DRY_RUN=false
[[ "${2:-}" == "--dry-run" ]] && DRY_RUN=true

BOJ_SERVER_URL="https://github.com/$ORG/boj-server"
BRANCH_NAME="chore/deprecation-notice"

# Find all poly-*-mcp repos
REPOS=$(gh repo list "$ORG" --limit 1000 --no-archived --source --json name -q '.[].name' | grep '^poly-.*-mcp$' || true)

if [[ -z "$REPOS" ]]; then
  echo "No poly-*-mcp repos found in $ORG"
  exit 0
fi

echo "Found poly-*-mcp repos to deprecate:"
echo "$REPOS" | sed 's/^/  - /'
echo ""

for repo_name in $REPOS; do
  echo "Processing: $ORG/$repo_name"

  if [[ "$DRY_RUN" == true ]]; then
    echo "  → Would add deprecation notice and policy file"
    continue
  fi

  tmpdir=$(mktemp -d)
  if ! gh repo clone "$ORG/$repo_name" "$tmpdir/$repo_name" -- --depth 1 --quiet 2>/dev/null; then
    echo "  ✗ Clone failed"
    rm -rf "$tmpdir"
    continue
  fi

  cd "$tmpdir/$repo_name"
  git checkout -b "$BRANCH_NAME" 2>/dev/null

  # ── Prepend deprecation banner to README ──

  DEPRECATION_BANNER="$(cat << 'BANNER'
> [!CAUTION]
> ## This repository has been superseded
>
> This MCP server's functionality has moved to the **[boj-server](BOJ_URL)** cartridge system.
>
> **What to do:**
> - For new projects, use [boj-server](BOJ_URL) with the appropriate cartridge
> - For existing integrations, see the [migration guide](BOJ_URL#migrating-from-poly-mcp)
> - This repo remains available for reference but receives no further updates
>
> The boj-server provides the same capabilities through formally verified cartridges
> with the Teranga menu system, distributed community hosting, and unified tooling.

---

BANNER
)"

  # Replace BOJ_URL placeholder
  DEPRECATION_BANNER="${DEPRECATION_BANNER//BOJ_URL/$BOJ_SERVER_URL}"

  # Find the README (various formats)
  README_FILE=""
  for f in README.md README.adoc README.rst README.txt README; do
    if [[ -f "$f" ]]; then
      README_FILE="$f"
      break
    fi
  done

  if [[ -n "$README_FILE" ]]; then
    # Prepend banner
    EXISTING=$(cat "$README_FILE")
    echo "$DEPRECATION_BANNER" > "$README_FILE"
    echo "$EXISTING" >> "$README_FILE"
  else
    # Create README with just the banner
    echo "$DEPRECATION_BANNER" > README.md
    README_FILE="README.md"
  fi

  # ── Add deprecated policy file ──

  cat > .language-policy.toml << 'POLICY'
# This repository is deprecated — moving to boj-server cartridge system.
# Language gate runs in advisory mode only.

[policy]
role = "deprecated"

[allowed_languages]
extra_allowed = []

[provers]
required = []

[runtime]
js = "bun"

[ffi]
method = "hexadeca"

[beam]
native = "snif"

[abi]
method = "idrisiser"
POLICY

  # ── Commit and PR ──

  git add "$README_FILE" .language-policy.toml
  git commit -m "chore: add deprecation notice — moved to boj-server

This MCP server's functionality is now provided by boj-server cartridges.
The repo stays visible (not archived) for reference and existing users.

See: $BOJ_SERVER_URL" --quiet

  git push origin "$BRANCH_NAME" --quiet 2>/dev/null

  gh pr create \
    --title "Deprecation notice: moved to boj-server" \
    --body "Adds a deprecation banner to the README and a \`.language-policy.toml\` with \`role = \"deprecated\"\`.

This repo is **not** being archived — it stays visible so existing users can find it and follow the migration path to boj-server cartridges.

See: $BOJ_SERVER_URL" \
    --head "$BRANCH_NAME" 2>/dev/null

  echo "  ✓ Deprecation PR created"
  cd /
  rm -rf "$tmpdir"
done

echo ""
echo "Done. Review and merge the PRs to activate deprecation notices."
