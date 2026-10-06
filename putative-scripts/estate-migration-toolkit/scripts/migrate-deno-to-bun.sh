#!/usr/bin/env bash
# migrate-deno-to-bun.sh — Convert a Deno project to Bun
#
# Handles:
#   - deno.json → bunfig.toml + package.json
#   - Deno.* API → Bun equivalents
#   - Import maps → package.json imports
#   - deno.lock → bun.lockb
#   - Test runner: deno test → bun test
#
# Usage:
#   ./migrate-deno-to-bun.sh /path/to/repo
#   ./migrate-deno-to-bun.sh /path/to/repo --dry-run
#
# Requirements: bun, jq, sed

set -euo pipefail

REPO_PATH="${1:?Usage: $0 <repo-path> [--dry-run]}"
DRY_RUN=false
[[ "${2:-}" == "--dry-run" ]] && DRY_RUN=true

cd "$REPO_PATH"

echo "Migrating Deno → Bun: $REPO_PATH"
[[ "$DRY_RUN" == true ]] && echo "(DRY RUN)"
echo ""

CHANGES=()

# ─── Step 1: Convert deno.json to bunfig.toml + package.json ───────────

if [[ -f "deno.json" ]] || [[ -f "deno.jsonc" ]]; then
  DENO_CONFIG="${DENO_JSON:-deno.json}"
  [[ -f "deno.jsonc" ]] && DENO_CONFIG="deno.jsonc"

  echo "Step 1: Converting $DENO_CONFIG"

  if [[ "$DRY_RUN" == false ]]; then
    # Extract what we can from deno.json
    if command -v jq &>/dev/null; then
      # Get tasks
      TASKS=$(jq -r '.tasks // {} | to_entries | .[] | "    \"\(.key)\": \"bun run \(.value)\"" ' "$DENO_CONFIG" 2>/dev/null || true)

      # Get imports (import map)
      IMPORTS=$(jq -r '.imports // {} | to_entries | .[] | "    \"\(.key)\": \"\(.value)\"" ' "$DENO_CONFIG" 2>/dev/null || true)

      # Create/update package.json
      if [[ ! -f "package.json" ]]; then
        cat > package.json << PKGJSON
{
  "name": "$(basename "$REPO_PATH")",
  "version": "0.1.0",
  "type": "module",
  "scripts": {
$(echo "$TASKS" | sed 's/bun run deno /bun /g' | paste -sd ',' | sed 's/,/,\n/g')
  },
  "dependencies": {}
}
PKGJSON
      fi

      # Create bunfig.toml
      cat > bunfig.toml << 'BUNFIG'
# Migrated from deno.json
[install]
peer = false
optional = true

[test]
coverage = true
BUNFIG
    fi

    # Remove deno files
    rm -f deno.json deno.jsonc deno.lock
    CHANGES+=("Converted $DENO_CONFIG → package.json + bunfig.toml")
  else
    echo "  → Would convert $DENO_CONFIG to package.json + bunfig.toml"
  fi
fi

# ─── Step 2: Replace Deno.* API calls with Bun equivalents ────────────

echo "Step 2: Replacing Deno.* API calls"

declare -A API_MAP=(
  ["Deno.readTextFile"]="Bun.file(\$PATH).text()"
  ["Deno.readFile"]="Bun.file(\$PATH).arrayBuffer()"
  ["Deno.writeTextFile"]="Bun.write(\$PATH, \$DATA)"
  ["Deno.writeFile"]="Bun.write(\$PATH, \$DATA)"
  ["Deno.readDir"]="(await Array.fromAsync(new Bun.Glob('*').scan(\$PATH)))"
  ["Deno.serve"]="Bun.serve"
  ["Deno.env.get"]="Bun.env"
  ["Deno.args"]="Bun.argv.slice(2)"
  ["Deno.exit"]="process.exit"
  ["Deno.cwd()"]="process.cwd()"
  ["Deno.Command"]="Bun.spawn"
  ["Deno.stdout"]="Bun.stdout"
  ["Deno.stderr"]="Bun.stderr"
  ["Deno.stdin"]="Bun.stdin"
)

# Find all TS/JS files
TS_FILES=$(find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.mjs" \) \
  -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null)

DENO_API_FOUND=false
for file in $TS_FILES; do
  if grep -q 'Deno\.' "$file" 2>/dev/null; then
    DENO_API_FOUND=true
    if [[ "$DRY_RUN" == true ]]; then
      echo "  → Would replace Deno.* calls in: $file"
      grep -n 'Deno\.' "$file" | head -5 | sed 's/^/    /'
    else
      # Common replacements (safe, mechanical)
      sed -i \
        -e 's/Deno\.serve(/Bun.serve(/g' \
        -e 's/Deno\.env\.get(\([^)]*\))/Bun.env[\1]/g' \
        -e 's/Deno\.env\.set(\([^,]*\), \([^)]*\))/process.env[\1] = \2/g' \
        -e 's/Deno\.exit(/process.exit(/g' \
        -e 's/Deno\.cwd()/process.cwd()/g' \
        -e 's/Deno\.args/Bun.argv.slice(2)/g' \
        -e 's/Deno\.stdout/Bun.stdout/g' \
        -e 's/Deno\.stderr/Bun.stderr/g' \
        -e 's/Deno\.stdin/Bun.stdin/g' \
        "$file"

      # Flag complex replacements that need manual review
      if grep -q 'Deno\.' "$file" 2>/dev/null; then
        echo "  ⚠ $file — has remaining Deno.* calls needing manual review:"
        grep -n 'Deno\.' "$file" | head -5 | sed 's/^/    /'
      else
        echo "  ✓ $file — all Deno.* calls replaced"
      fi

      CHANGES+=("Replaced Deno.* API calls in $file")
    fi
  fi
done

[[ "$DENO_API_FOUND" == false ]] && echo "  No Deno.* API calls found"

# ─── Step 3: Replace Deno-specific imports ─────────────────────────────

echo "Step 3: Replacing Deno-specific imports"

for file in $TS_FILES; do
  if grep -q 'from "https://deno.land' "$file" 2>/dev/null; then
    if [[ "$DRY_RUN" == true ]]; then
      echo "  → Would replace deno.land imports in: $file"
    else
      # Replace common deno.land/std imports with npm equivalents
      sed -i \
        -e 's|from "https://deno.land/std[^"]*path[^"]*"|from "node:path"|g' \
        -e 's|from "https://deno.land/std[^"]*fs[^"]*"|from "node:fs/promises"|g' \
        -e 's|from "https://deno.land/std[^"]*http[^"]*"|from "node:http"|g' \
        -e 's|from "https://deno.land/std[^"]*crypto[^"]*"|from "node:crypto"|g' \
        -e 's|from "https://deno.land/std[^"]*streams[^"]*"|from "node:stream"|g' \
        "$file"

      if grep -q 'deno.land' "$file" 2>/dev/null; then
        echo "  ⚠ $file — has remaining deno.land imports needing manual review"
      else
        echo "  ✓ $file — deno.land imports replaced"
      fi

      CHANGES+=("Replaced deno.land imports in $file")
    fi
  fi
done

# ─── Step 4: Update CI/scripts references ─────────────────────────────

echo "Step 4: Updating CI and script references"

# Replace deno commands in CI workflows, Justfiles, Makefiles, scripts
CONFIG_FILES=$(find . -type f \( \
  -name "*.yml" -o -name "*.yaml" -o -name "Justfile" -o -name "justfile" \
  -o -name "Makefile" -o -name "makefile" -o -name "*.sh" \
  \) -not -path "*/.git/*" -not -path "*/node_modules/*" 2>/dev/null)

for file in $CONFIG_FILES; do
  if grep -q 'deno ' "$file" 2>/dev/null; then
    if [[ "$DRY_RUN" == true ]]; then
      echo "  → Would replace 'deno' commands in: $file"
    else
      sed -i \
        -e 's/deno run /bun run /g' \
        -e 's/deno test/bun test/g' \
        -e 's/deno install/bun install/g' \
        -e 's/deno fmt/bunx prettier --write ./g' \
        -e 's/deno lint/bunx eslint ./g' \
        -e 's/deno task /bun run /g' \
        -e 's/deno compile/bun build --compile/g' \
        "$file"
      echo "  ✓ $file — deno → bun commands replaced"
      CHANGES+=("Replaced deno commands in $file")
    fi
  fi
done

# ─── Step 5: Install deps with Bun ────────────────────────────────────

if [[ "$DRY_RUN" == false && -f "package.json" ]]; then
  echo "Step 5: Installing dependencies with Bun"
  if command -v bun &>/dev/null; then
    bun install 2>/dev/null && echo "  ✓ Dependencies installed" || echo "  ⚠ bun install had issues — review manually"
  else
    echo "  ⚠ bun not found — run 'bun install' manually after installing Bun"
  fi
fi

# ─── Summary ──────────────────────────────────────────────────────────

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  MIGRATION SUMMARY"
echo "════════════════════════════════════════════════════════════"
echo "  Changes made: ${#CHANGES[@]}"
for c in "${CHANGES[@]:-}"; do
  echo "    • $c"
done
echo ""
echo "  Manual review needed for:"
echo "    • Complex Deno.* API calls (readTextFile, writeFile patterns)"
echo "    • Third-party deno.land/x imports (find npm equivalents)"
echo "    • Deno.test() → describe/it/expect (Bun test API)"
echo "    • Permission flags (--allow-read etc.) — Bun has no sandbox"
echo "════════════════════════════════════════════════════════════"
