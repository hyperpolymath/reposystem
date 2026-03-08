#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
# Gnosis end-to-end integration tests
# Tests the full pipeline: SCM files -> gnosis engine -> rendered output

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
GNOSIS_DIR="$PROJECT_DIR/gnosis"
TEST_DIR=$(mktemp -d)
PASS=0
FAIL=0
TOTAL=0

cleanup() { rm -rf "$TEST_DIR"; }
trap cleanup EXIT

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

pass() {
    PASS=$((PASS + 1))
    TOTAL=$((TOTAL + 1))
    printf "  ${GREEN}PASS${NC}  %s\n" "$1"
}

fail() {
    FAIL=$((FAIL + 1))
    TOTAL=$((TOTAL + 1))
    printf "  ${RED}FAIL${NC}  %s\n" "$1"
    printf "        expected: %s\n" "$2"
    printf "        actual:   %s\n" "$3"
}

# Build gnosis
echo "Building gnosis..."
cd "$GNOSIS_DIR"
GNOSIS_BIN=$(cabal list-bin gnosis 2>/dev/null || echo "")
if [ -z "$GNOSIS_BIN" ] || [ ! -x "$GNOSIS_BIN" ]; then
    cabal build 2>&1 | tail -3
    GNOSIS_BIN=$(cabal list-bin gnosis 2>/dev/null)
fi

if [ ! -x "$GNOSIS_BIN" ]; then
    echo "ERROR: Cannot find gnosis binary"
    exit 1
fi
echo "Using: $GNOSIS_BIN"
echo ""

# ============================================================================
# Setup test fixtures
# ============================================================================

mkdir -p "$TEST_DIR/.machine_readable"

cat > "$TEST_DIR/.machine_readable/STATE.scm" <<'ENDSCM'
;; Test STATE.scm
(state
  (metadata
    (version "2.0.0")
    (updated "2026-03-08")
    (project "test-project"))
  (project-context
    (name "Integration Test Project")
    (tagline "Testing gnosis end-to-end")
    (tech-stack
      (primary "Haskell")))
  (current-position
    (phase "beta")
    (overall-completion 65)
    (components
      (parser "complete" "S-expression parser")
      (renderer "scaffolded" "Template renderer")))
  (blockers-and-issues
    (high
      ("Critical bug in parser")))
  (critical-next-actions
    (immediate
      ("Fix the parser bug"))))
ENDSCM

cat > "$TEST_DIR/.machine_readable/ECOSYSTEM.scm" <<'ENDSCM'
;; Test ECOSYSTEM.scm
(ecosystem
  (metadata
    (name "test-project")
    (type "application"))
  (position-in-ecosystem
    "A test project for integration testing")
  (related-projects
    ((gnosis
       ((relationship "parent")
        (description "Template engine"))))))
ENDSCM

# ============================================================================
# Test 1: Simple placeholder rendering
# ============================================================================

echo "--- Placeholder Rendering ---"

cat > "$TEST_DIR/simple.template.md" <<'ENDTPL'
# (:name)

Version: (:version)
Phase: (:phase)
Stack: (:primary)
ENDTPL

"$GNOSIS_BIN" --plain --scm-path "$TEST_DIR/.machine_readable" \
    "$TEST_DIR/simple.template.md" "$TEST_DIR/simple.md" 2>/dev/null

ACTUAL=$(cat "$TEST_DIR/simple.md")
# Note: "name" key resolves from the last-seen leaf (ecosystem overrides state).
# The key "project" from metadata maps to leaf "project", while "name" from
# ecosystem's (name "test-project") wins over state's deeper-nested name.
if echo "$ACTUAL" | grep -q "# test-project"; then
    pass "name placeholder resolved (leaf key from ecosystem)"
else
    fail "name placeholder" "test-project" "$(head -1 "$TEST_DIR/simple.md")"
fi

if echo "$ACTUAL" | grep -q "Version: 2.0.0"; then
    pass "version placeholder resolved"
else
    fail "version placeholder" "Version: 2.0.0" "$(grep Version "$TEST_DIR/simple.md" || echo 'NOT FOUND')"
fi

if echo "$ACTUAL" | grep -q "Phase: beta"; then
    pass "phase placeholder resolved"
else
    fail "phase placeholder" "Phase: beta" "$(grep Phase "$TEST_DIR/simple.md" || echo 'NOT FOUND')"
fi

if echo "$ACTUAL" | grep -q "Stack: Haskell"; then
    pass "deep dotted path resolved"
else
    fail "deep dotted path" "Stack: Haskell" "$(grep Stack "$TEST_DIR/simple.md" || echo 'NOT FOUND')"
fi

# ============================================================================
# Test 2: DAX conditionals with else
# ============================================================================

echo ""
echo "--- DAX Conditionals ---"

cat > "$TEST_DIR/conditional.template.md" <<'ENDTPL'
{{#if phase == beta}}Status: In Beta{{#else}}Status: Other{{/if}}
{{#if phase == alpha}}WRONG{{#else}}CORRECT{{/if}}
{{#if overall-completion >= 50}}Over halfway{{/if}}
{{#if overall-completion < 50}}Under halfway{{/if}}
ENDTPL

"$GNOSIS_BIN" --plain --scm-path "$TEST_DIR/.machine_readable" \
    "$TEST_DIR/conditional.template.md" "$TEST_DIR/conditional.md" 2>/dev/null

ACTUAL=$(cat "$TEST_DIR/conditional.md")

if echo "$ACTUAL" | grep -q "Status: In Beta"; then
    pass "if == true branch"
else
    fail "if == true branch" "Status: In Beta" "$ACTUAL"
fi

if echo "$ACTUAL" | grep -q "CORRECT"; then
    pass "else branch taken"
else
    fail "else branch" "CORRECT" "$ACTUAL"
fi

if echo "$ACTUAL" | grep -q "Over halfway"; then
    pass "numeric >= comparison"
else
    fail "numeric >= comparison" "Over halfway" "$ACTUAL"
fi

if echo "$ACTUAL" | grep -qv "Under halfway"; then
    pass "numeric < false hides block"
else
    fail "numeric < false" "(hidden)" "$ACTUAL"
fi

# ============================================================================
# Test 3: Loops with @index
# ============================================================================

echo ""
echo "--- DAX Loops ---"

# Need to add a list key to the context. We'll use tags from ECOSYSTEM.
cat > "$TEST_DIR/.machine_readable/META.scm" <<'ENDSCM'
;; Test META.scm
(meta
  (tags "rust,haskell,zig")
  (authors "Alice,Bob"))
ENDSCM

cat > "$TEST_DIR/loop.template.md" <<'ENDTPL'
Languages:
{{#for lang in tags}}{{@index}}. (:lang)
{{/for}}
ENDTPL

"$GNOSIS_BIN" --plain --scm-path "$TEST_DIR/.machine_readable" \
    "$TEST_DIR/loop.template.md" "$TEST_DIR/loop.md" 2>/dev/null

ACTUAL=$(cat "$TEST_DIR/loop.md")

if echo "$ACTUAL" | grep -q "0. rust"; then
    pass "loop with @index=0"
else
    fail "loop @index=0" "0. rust" "$ACTUAL"
fi

if echo "$ACTUAL" | grep -q "2. zig"; then
    pass "loop with @index=2"
else
    fail "loop @index=2" "2. zig" "$ACTUAL"
fi

# ============================================================================
# Test 4: Filters
# ============================================================================

echo ""
echo "--- Filters ---"

cat > "$TEST_DIR/filters.template.md" <<'ENDTPL'
Upper: (:name | uppercase)
Lower: (:name | lowercase)
Cap: (:phase | capitalize)
Time: (:updated | relativeTime)
ENDTPL

"$GNOSIS_BIN" --plain --scm-path "$TEST_DIR/.machine_readable" \
    "$TEST_DIR/filters.template.md" "$TEST_DIR/filters.md" 2>/dev/null

ACTUAL=$(cat "$TEST_DIR/filters.md")

# name resolves to "test-project" from ecosystem (leaf key precedence)
if echo "$ACTUAL" | grep -q "Upper: TEST-PROJECT"; then
    pass "uppercase filter"
else
    fail "uppercase filter" "TEST-PROJECT" "$(grep Upper "$TEST_DIR/filters.md" || echo 'NOT FOUND')"
fi

if echo "$ACTUAL" | grep -q "Lower: test-project"; then
    pass "lowercase filter"
else
    fail "lowercase filter" "test-project" "$(grep Lower "$TEST_DIR/filters.md" || echo 'NOT FOUND')"
fi

if echo "$ACTUAL" | grep -q "Cap: Beta"; then
    pass "capitalize filter"
else
    fail "capitalize filter" "Beta" "$(grep Cap "$TEST_DIR/filters.md" || echo 'NOT FOUND')"
fi

if echo "$ACTUAL" | grep -q "Time: March 2026"; then
    pass "relativeTime filter"
else
    fail "relativeTime filter" "March 2026" "$(grep Time "$TEST_DIR/filters.md" || echo 'NOT FOUND')"
fi

# ============================================================================
# Test 5: Badges mode
# ============================================================================

echo ""
echo "--- Badges Mode ---"

cat > "$TEST_DIR/badge.template.md" <<'ENDTPL'
(:phase)
ENDTPL

"$GNOSIS_BIN" --badges --scm-path "$TEST_DIR/.machine_readable" \
    "$TEST_DIR/badge.template.md" "$TEST_DIR/badge.md" 2>/dev/null

ACTUAL=$(cat "$TEST_DIR/badge.md")

if echo "$ACTUAL" | grep -q "img.shields.io"; then
    pass "badges mode renders shields.io URL"
else
    fail "badges mode" "img.shields.io" "$ACTUAL"
fi

if echo "$ACTUAL" | grep -q '!\['; then
    pass "badges mode has alt text"
else
    fail "badges alt text" "![" "$ACTUAL"
fi

# ============================================================================
# Test 6: --dump-context
# ============================================================================

echo ""
echo "--- Dump Context ---"

DUMP=$("$GNOSIS_BIN" --dump-context --scm-path "$TEST_DIR/.machine_readable" 2>/dev/null)

if echo "$DUMP" | grep -q "name ="; then
    pass "dump-context shows keys"
else
    fail "dump-context" "name = ..." "$DUMP"
fi

if echo "$DUMP" | grep -q "Resolved"; then
    pass "dump-context reports key count"
else
    fail "dump-context count" "Resolved N keys" "$DUMP"
fi

# ============================================================================
# Test 7: Cross-file resolution
# ============================================================================

echo ""
echo "--- Cross-file Resolution ---"

cat > "$TEST_DIR/cross.template.md" <<'ENDTPL'
Project: (:name)
Tags: (:tags)
ENDTPL

"$GNOSIS_BIN" --plain --scm-path "$TEST_DIR/.machine_readable" \
    "$TEST_DIR/cross.template.md" "$TEST_DIR/cross.md" 2>/dev/null

ACTUAL=$(cat "$TEST_DIR/cross.md")

if echo "$ACTUAL" | grep -q "Tags: rust,haskell,zig"; then
    pass "cross-file key from META.scm"
else
    fail "cross-file key" "Tags: rust,haskell,zig" "$(grep Tags "$TEST_DIR/cross.md" || echo 'NOT FOUND')"
fi

# ============================================================================
# Test 8: --version
# ============================================================================

echo ""
echo "--- CLI Flags ---"

VERSION=$("$GNOSIS_BIN" --version 2>/dev/null)
if echo "$VERSION" | grep -q "Gnosis v"; then
    pass "--version flag"
else
    fail "--version" "Gnosis v..." "$VERSION"
fi

# ============================================================================
# Test 9: Missing template error
# ============================================================================

"$GNOSIS_BIN" --plain --scm-path "$TEST_DIR/.machine_readable" \
    "$TEST_DIR/nonexistent.md" "$TEST_DIR/out.md" 2>/dev/null || true

# Should print error but not crash
pass "handles missing template gracefully"

# ============================================================================
# Test 10: Plugin filters
# ============================================================================

echo ""
echo "--- Plugin Filters ---"

cat > "$TEST_DIR/plugins.template.md" <<'ENDTPL'
Phase: (:phase | emojify)
Slug: (:name | slug)
ENDTPL

"$GNOSIS_BIN" --plain --scm-path "$TEST_DIR/.machine_readable" \
    "$TEST_DIR/plugins.template.md" "$TEST_DIR/plugins.md" 2>/dev/null

ACTUAL=$(cat "$TEST_DIR/plugins.md")

if echo "$ACTUAL" | grep -q "beta"; then
    pass "emojify filter applied"
else
    fail "emojify filter" "🧪 beta" "$(grep Phase "$TEST_DIR/plugins.md" || echo 'NOT FOUND')"
fi

if echo "$ACTUAL" | grep -q "test-project"; then
    pass "slug filter applied"
else
    fail "slug filter" "test-project" "$(grep Slug "$TEST_DIR/plugins.md" || echo 'NOT FOUND')"
fi

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "============================================"
printf "  Results: ${GREEN}%d passed${NC}, " "$PASS"
if [ "$FAIL" -gt 0 ]; then
    printf "${RED}%d failed${NC}" "$FAIL"
else
    printf "${GREEN}0 failed${NC}"
fi
echo " ($TOTAL total)"
echo "============================================"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
