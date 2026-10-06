#!/usr/bin/env bash
# find-nif-to-snif.sh — Find all NIF usage that should be SNIF
#
# Scans repos for Erlang/Elixir NIF patterns and reports locations
# that need migration to SNIF.
#
# Usage:
#   ./find-nif-to-snif.sh /path/to/repos-dir
#   ./find-nif-to-snif.sh --github hyperpolymath
#
# Requirements: grep, find. Optional: gh (for GitHub scanning)

set -euo pipefail

MODE=""
TARGET=""

case "${1:-}" in
  --github) MODE="github"; TARGET="${2:?Provide org name}" ;;
  --help|-h) echo "Usage: $0 <repos-dir> | --github <org>"; exit 0 ;;
  *) MODE="local"; TARGET="${1:?Provide repos directory or --github <org>}" ;;
esac

echo "Scanning for NIF usage that should be SNIF..."
echo ""

# NIF patterns to search for
NIF_PATTERNS=(
  'erl_nif\.h'                    # C NIF header
  '#\[rustler::nif\]'             # Rustler NIF macro
  'use Rustler'                   # Rustler in Elixir
  ':erlang\.nif_error'            # Erlang NIF error
  'enif_'                         # C NIF API functions
  '@on_load :init'                # Elixir NIF loading
  'erlang:load_nif'               # Erlang NIF loading
  'nif_helpers'                   # NIF helper modules
  ':nif_error'                    # NIF error in Elixir
  'ERL_NIF_INIT'                  # NIF init macro
)

# SNIF patterns (if found, the repo is already migrated)
SNIF_PATTERNS=(
  'snif'
  'SNIF'
  'safe_nif'
  'SafeNif'
  'safe_native'
)

# Report NIF usage in one repo and whether a SNIF (safe NIF) counterpart exists.
scan_repo() {
  local repo_path="$1"
  local repo_name="$2"
  local found_nif=false
  local found_snif=false
  local nif_locations=()

  # Check for NIF patterns
  for pattern in "${NIF_PATTERNS[@]}"; do
    matches=$(grep -rnl "$pattern" "$repo_path" \
      --include='*.rs' --include='*.erl' --include='*.ex' --include='*.exs' \
      --include='*.c' --include='*.h' --include='*.cpp' --include='*.hpp' \
      2>/dev/null | head -20)
    if [[ -n "$matches" ]]; then
      found_nif=true
      while IFS= read -r match; do
        nif_locations+=("$match")
      done <<< "$matches"
    fi
  done

  # Check for SNIF patterns (already migrated)
  for pattern in "${SNIF_PATTERNS[@]}"; do
    if grep -rql "$pattern" "$repo_path" 2>/dev/null; then
      found_snif=true
      break
    fi
  done

  # Report
  if [[ "$found_nif" == true ]]; then
    if [[ "$found_snif" == true ]]; then
      echo "⚠ $repo_name — has BOTH NIF and SNIF (partial migration?)"
    else
      echo "✗ $repo_name — uses NIF, needs SNIF migration"
    fi

    # Show specific locations
    local unique_files=($(printf '%s\n' "${nif_locations[@]}" | sort -u))
    for loc in "${unique_files[@]:0:10}"; do
      # Show the matching lines with context
      local rel_path="${loc#$repo_path/}"
      local line_info=$(grep -n -m3 -E "$(printf '%s|' "${NIF_PATTERNS[@]}" | sed 's/|$//')" "$loc" 2>/dev/null | head -3)
      echo "  → $rel_path"
      echo "$line_info" | sed 's/^/      /'
    done

    if [[ ${#unique_files[@]} -gt 10 ]]; then
      echo "  ... and $((${#unique_files[@]} - 10)) more files"
    fi
    echo ""
    return 1
  fi

  return 0
}

# ─── Main scan ─────────────────────────────────────────────────────────

TOTAL=0
NIF_REPOS=0

if [[ "$MODE" == "local" ]]; then
  for repo_path in "$TARGET"/*/; do
    [[ -d "$repo_path" ]] || continue
    TOTAL=$((TOTAL + 1))
    repo_name=$(basename "$repo_path")
    scan_repo "$repo_path" "$repo_name" || NIF_REPOS=$((NIF_REPOS + 1))
  done
elif [[ "$MODE" == "github" ]]; then
  REPOS=$(gh repo list "$TARGET" --limit 1000 --no-archived --source \
    --json name,primaryLanguage -q '.[] | select(.primaryLanguage.name == "Elixir" or .primaryLanguage.name == "Erlang" or .primaryLanguage.name == "Rust") | .name')

  for repo_name in $REPOS; do
    TOTAL=$((TOTAL + 1))
    tmpdir=$(mktemp -d)
    if gh repo clone "$TARGET/$repo_name" "$tmpdir/$repo_name" -- --depth 1 --quiet 2>/dev/null; then
      scan_repo "$tmpdir/$repo_name" "$repo_name" || NIF_REPOS=$((NIF_REPOS + 1))
    fi
    rm -rf "$tmpdir"
  done
fi

echo "════════════════════════════════════════════════════════════"
echo "  NIF → SNIF SCAN RESULTS"
echo "════════════════════════════════════════════════════════════"
echo "  Repos scanned:     $TOTAL"
echo "  Repos using NIF:   $NIF_REPOS"
echo "  Already on SNIF:   $((TOTAL - NIF_REPOS))"
echo "════════════════════════════════════════════════════════════"
