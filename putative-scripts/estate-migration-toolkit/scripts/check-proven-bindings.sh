#!/usr/bin/env bash
# check-proven-bindings.sh — Verify proven repo's language bindings are intact
#
# Checks that each binding directory actually contains code in the
# language it claims to bind, not all converted to the same language.
#
# Usage:
#   ./check-proven-bindings.sh [path-to-proven-repo]
#   ./check-proven-bindings.sh  # clones from GitHub
#
# Requirements: gh (if cloning), file, wc

set -euo pipefail

REPO_PATH="${1:-}"
CLEANUP=false

if [[ -z "$REPO_PATH" ]]; then
  REPO_PATH=$(mktemp -d)/proven
  echo "Cloning hyperpolymath/proven..."
  gh repo clone hyperpolymath/proven "$REPO_PATH" -- --depth 1 --quiet
  CLEANUP=true
fi

if [[ ! -d "$REPO_PATH" ]]; then
  echo "Error: $REPO_PATH does not exist" >&2
  exit 1
fi

echo "Checking proven repo bindings at: $REPO_PATH"
echo ""

# ─── Expected file extensions per binding language ──────────────────────

declare -A LANG_EXTENSIONS=(
  [ada]=".adb .ads"
  [c]=".c .h"
  [cpp]=".cpp .hpp .cc .cxx"
  [crystal]=".cr"
  [csharp]=".cs"
  [d]=".d"
  [dart]=".dart"
  [deno]=".ts"
  [elixir]=".ex .exs"
  [elm]=".elm"
  [erlang]=".erl .hrl"
  [fsharp]=".fs .fsi"
  [gleam]=".gleam"
  [go]=".go"
  [groovy]=".groovy"
  [haskell]=".hs"
  [java]=".java"
  [javascript]=".js .mjs"
  [julia]=".jl"
  [kotlin]=".kt .kts"
  [lua]=".lua"
  [nim]=".nim"
  [ocaml]=".ml .mli"
  [odin]=".odin"
  [perl]=".pl .pm"
  [php]=".php"
  [prolog]=".pl .pro"
  [purescript]=".purs"
  [python]=".py"
  [r]=".r .R"
  [racket]=".rkt"
  [rescript]=".res .resi"
  [ruby]=".rb"
  [rust]=".rs"
  [scala]=".scala"
  [swift]=".swift"
  [tcl]=".tcl"
  [typescript]=".ts .tsx"
  [v]=".v"
  [zig]=".zig"
)

BINDINGS_DIR="$REPO_PATH/bindings"

if [[ ! -d "$BINDINGS_DIR" ]]; then
  echo "ERROR: No bindings/ directory found at $BINDINGS_DIR"
  echo "The bindings may have been moved or deleted entirely."
  [[ "$CLEANUP" == true ]] && rm -rf "$(dirname "$REPO_PATH")"
  exit 1
fi

TOTAL=0
CORRECT=0
WRONG=0
EMPTY=0
SUSPICIOUS=()

echo "════════════════════════════════════════════════════════════"
echo "  BINDING INTEGRITY CHECK"
echo "════════════════════════════════════════════════════════════"
echo ""

for binding_dir in "$BINDINGS_DIR"/*/; do
  [[ -d "$binding_dir" ]] || continue

  lang_name=$(basename "$binding_dir")
  TOTAL=$((TOTAL + 1))

  # Get expected extensions for this language
  expected_exts="${LANG_EXTENSIONS[$lang_name]:-}"

  # Count total source files (excluding config/docs)
  total_files=$(find "$binding_dir" -type f \
    -not -name "*.md" -not -name "*.txt" -not -name "*.toml" \
    -not -name "*.yaml" -not -name "*.yml" -not -name "*.json" \
    -not -name "*.lock" -not -name "*.lockb" \
    -not -name "LICENSE*" -not -name "CHANGELOG*" \
    -not -name ".gitignore" -not -name ".gitattributes" \
    2>/dev/null | wc -l)

  if [[ "$total_files" -eq 0 ]]; then
    echo "  ⚠ $lang_name — EMPTY (no source files)"
    EMPTY=$((EMPTY + 1))
    continue
  fi

  if [[ -z "$expected_exts" ]]; then
    echo "  ? $lang_name — unknown language, skipping extension check ($total_files files)"
    continue
  fi

  # Count files matching expected extensions
  matching_files=0
  for ext in $expected_exts; do
    count=$(find "$binding_dir" -name "*$ext" -type f 2>/dev/null | wc -l)
    matching_files=$((matching_files + count))
  done

  # Calculate ratio
  if [[ "$total_files" -gt 0 ]]; then
    ratio=$((matching_files * 100 / total_files))
  else
    ratio=0
  fi

  if [[ "$matching_files" -eq 0 ]]; then
    # No files of the expected type — something is very wrong
    # Check what's actually in there
    actual_types=$(find "$binding_dir" -type f -name "*.*" \
      -not -name "*.md" -not -name "*.txt" -not -name "*.toml" \
      -not -name "*.yaml" -not -name "*.yml" -not -name "*.json" \
      2>/dev/null | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -3 | awk '{print $2"("$1")"}' | tr '\n' ' ')
    echo "  ✗ $lang_name — WRONG LANGUAGE: expected $expected_exts, found: $actual_types"
    WRONG=$((WRONG + 1))
    SUSPICIOUS+=("$lang_name: expected=$expected_exts actual=$actual_types")
  elif [[ "$ratio" -lt 30 ]]; then
    actual_types=$(find "$binding_dir" -type f -name "*.*" \
      -not -name "*.md" -not -name "*.toml" -not -name "*.yaml" -not -name "*.json" \
      2>/dev/null | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -3 | awk '{print $2"("$1")"}' | tr '\n' ' ')
    echo "  ⚠ $lang_name — SUSPICIOUS: only ${ratio}% match expected extensions. Found: $actual_types"
    WRONG=$((WRONG + 1))
    SUSPICIOUS+=("$lang_name: ${ratio}% match, actual=$actual_types")
  else
    echo "  ✓ $lang_name — OK (${matching_files}/${total_files} files match, ${ratio}%)"
    CORRECT=$((CORRECT + 1))
  fi
done

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  RESULTS"
echo "════════════════════════════════════════════════════════════"
echo "  Total bindings:  $TOTAL"
echo "  Correct:         $CORRECT"
echo "  Wrong/suspect:   $WRONG"
echo "  Empty:           $EMPTY"
echo ""

if [[ ${#SUSPICIOUS[@]} -gt 0 ]]; then
  echo "  SUSPICIOUS BINDINGS (may have been incorrectly converted):"
  for s in "${SUSPICIOUS[@]}"; do
    echo "    → $s"
  done
  echo ""
  echo "  ACTION: Manually inspect these bindings. A bot may have"
  echo "  converted them to the wrong language."
fi

echo "════════════════════════════════════════════════════════════"

[[ "$CLEANUP" == true ]] && rm -rf "$(dirname "$REPO_PATH")"
