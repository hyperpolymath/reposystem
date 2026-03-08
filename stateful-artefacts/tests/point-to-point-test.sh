#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
# Point-to-point tests: verify each component interface in isolation
# Tests boundaries between: CLI -> SCM loader -> DAX -> Renderer -> Output

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GNOSIS_DIR="$(cd "$SCRIPT_DIR/../gnosis" && pwd)"
TEST_DIR=$(mktemp -d)
PASS=0; FAIL=0; TOTAL=0

cleanup() { rm -rf "$TEST_DIR"; }
trap cleanup EXIT

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'

pass() { PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1)); printf "  ${GREEN}PASS${NC}  %s\n" "$1"; }
fail() { FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1)); printf "  ${RED}FAIL${NC}  %s\n    expected: %s\n    actual:   %s\n" "$1" "$2" "$3"; }

cd "$GNOSIS_DIR"
GNOSIS_BIN=$(cabal list-bin gnosis 2>/dev/null)

# ============================================================================
# P2P-1: CLI argument parsing
# ============================================================================

echo "--- P2P: CLI Argument Parsing ---"

# --version
V=$("$GNOSIS_BIN" --version 2>/dev/null)
echo "$V" | grep -q "Gnosis v" && pass "CLI: --version" || fail "CLI: --version" "Gnosis v..." "$V"

# --help
H=$("$GNOSIS_BIN" --help 2>/dev/null)
echo "$H" | grep -q "Usage:" && pass "CLI: --help shows usage" || fail "CLI: --help" "Usage:" "$H"
echo "$H" | grep -q "\-\-plain" && pass "CLI: --help lists --plain" || fail "CLI: --help --plain" "--plain" "$H"
echo "$H" | grep -q "\-\-badges" && pass "CLI: --help lists --badges" || fail "CLI: --help --badges" "--badges" "$H"
echo "$H" | grep -q "@index" && pass "CLI: --help lists @index" || fail "CLI: --help @index" "@index" "$H"
echo "$H" | grep -q "emojify" && pass "CLI: --help lists filters" || fail "CLI: --help filters" "emojify" "$H"

# No args -> help
NA=$("$GNOSIS_BIN" 2>/dev/null)
echo "$NA" | grep -q "Usage:" && pass "CLI: no args shows help" || fail "CLI: no args" "Usage:" "$NA"

echo ""

# ============================================================================
# P2P-2: SCM file loading interface
# ============================================================================

echo "--- P2P: SCM File Loading ---"

mkdir -p "$TEST_DIR/.machine_readable"

# Empty directory (no SCM files) -> should still work with 0 keys
echo "(:missing)" > "$TEST_DIR/p2p.template.md"
"$GNOSIS_BIN" --plain --scm-path "$TEST_DIR/.machine_readable" \
    "$TEST_DIR/p2p.template.md" "$TEST_DIR/p2p.md" 2>/dev/null
grep -q "MISSING" "$TEST_DIR/p2p.md" && pass "SCM: empty dir renders MISSING" || fail "SCM: empty dir" "MISSING" "$(cat "$TEST_DIR/p2p.md")"

# Single file loading
echo '(state (metadata (version "3.0")))' > "$TEST_DIR/.machine_readable/STATE.scm"
echo "V=(:version)" > "$TEST_DIR/p2p.template.md"
"$GNOSIS_BIN" --plain --scm-path "$TEST_DIR/.machine_readable" \
    "$TEST_DIR/p2p.template.md" "$TEST_DIR/p2p.md" 2>/dev/null
grep -q "V=3.0" "$TEST_DIR/p2p.md" && pass "SCM: STATE.scm loaded" || fail "SCM: STATE.scm" "V=3.0" "$(cat "$TEST_DIR/p2p.md")"

# Priority: later files override earlier
echo '(ecosystem (metadata (version "4.0")))' > "$TEST_DIR/.machine_readable/ECOSYSTEM.scm"
"$GNOSIS_BIN" --plain --scm-path "$TEST_DIR/.machine_readable" \
    "$TEST_DIR/p2p.template.md" "$TEST_DIR/p2p.md" 2>/dev/null
# ECOSYSTEM has higher priority than STATE for the "version" leaf key
grep -q "V=4.0" "$TEST_DIR/p2p.md" && pass "SCM: ECOSYSTEM overrides STATE" || fail "SCM: priority" "V=4.0" "$(cat "$TEST_DIR/p2p.md")"

# Dotted path access
echo '(state (project-context (tech-stack (primary "Rust"))))' > "$TEST_DIR/.machine_readable/STATE.scm"
echo "(:primary)" > "$TEST_DIR/p2p.template.md"
"$GNOSIS_BIN" --plain --scm-path "$TEST_DIR/.machine_readable" \
    "$TEST_DIR/p2p.template.md" "$TEST_DIR/p2p.md" 2>/dev/null
grep -q "Rust" "$TEST_DIR/p2p.md" && pass "SCM: deep dotted path" || fail "SCM: dotted path" "Rust" "$(cat "$TEST_DIR/p2p.md")"

# Comments stripped
rm -f "$TEST_DIR/.machine_readable/ECOSYSTEM.scm"
cat > "$TEST_DIR/.machine_readable/STATE.scm" <<'EOF'
;; This is a comment
;; Another comment
(state (metadata (version "5.0")))
EOF
echo "(:version)" > "$TEST_DIR/p2p.template.md"
"$GNOSIS_BIN" --plain --scm-path "$TEST_DIR/.machine_readable" \
    "$TEST_DIR/p2p.template.md" "$TEST_DIR/p2p.md" 2>/dev/null
grep -q "5.0" "$TEST_DIR/p2p.md" && pass "SCM: comments stripped" || fail "SCM: comments" "5.0" "$(cat "$TEST_DIR/p2p.md")"

# Malformed SCM (should not crash)
echo "(((broken" > "$TEST_DIR/.machine_readable/STATE.scm"
echo "test" > "$TEST_DIR/p2p.template.md"
"$GNOSIS_BIN" --plain --scm-path "$TEST_DIR/.machine_readable" \
    "$TEST_DIR/p2p.template.md" "$TEST_DIR/p2p.md" 2>/dev/null && pass "SCM: malformed doesn't crash" || fail "SCM: malformed" "no crash" "crash"

# --scm-path with absolute path
echo '(state (metadata (version "6.0")))' > "$TEST_DIR/.machine_readable/STATE.scm"
echo "(:version)" > "$TEST_DIR/p2p.template.md"
"$GNOSIS_BIN" --plain --scm-path "$TEST_DIR/.machine_readable" \
    "$TEST_DIR/p2p.template.md" "$TEST_DIR/p2p.md" 2>/dev/null
grep -q "6.0" "$TEST_DIR/p2p.md" && pass "SCM: absolute --scm-path" || fail "SCM: absolute path" "6.0" "$(cat "$TEST_DIR/p2p.md")"

echo ""

# ============================================================================
# P2P-3: DAX -> Renderer interface
# ============================================================================

echo "--- P2P: DAX -> Renderer Interface ---"

echo '(state (metadata (version "1.0") (phase "alpha") (count "42")))' > "$TEST_DIR/.machine_readable/STATE.scm"
rm -f "$TEST_DIR/.machine_readable/ECOSYSTEM.scm"

# DAX processes BEFORE renderer
echo '{{#if phase == alpha}}(:version){{/if}}' > "$TEST_DIR/p2p.template.md"
"$GNOSIS_BIN" --plain --scm-path "$TEST_DIR/.machine_readable" \
    "$TEST_DIR/p2p.template.md" "$TEST_DIR/p2p.md" 2>/dev/null
grep -q "1.0" "$TEST_DIR/p2p.md" && pass "DAX->Render: conditionals before placeholders" || fail "DAX->Render" "1.0" "$(cat "$TEST_DIR/p2p.md")"

# DAX else feeds into renderer
echo '{{#if phase == beta}}BETA{{#else}}(:phase | uppercase){{/if}}' > "$TEST_DIR/p2p.template.md"
"$GNOSIS_BIN" --plain --scm-path "$TEST_DIR/.machine_readable" \
    "$TEST_DIR/p2p.template.md" "$TEST_DIR/p2p.md" 2>/dev/null
grep -q "ALPHA" "$TEST_DIR/p2p.md" && pass "DAX->Render: else block with filter" || fail "DAX->Render else" "ALPHA" "$(cat "$TEST_DIR/p2p.md")"

# Loop output feeds into renderer
echo '(state (metadata (tags "a,b,c")))' > "$TEST_DIR/.machine_readable/STATE.scm"
echo '{{#for x in tags}}[(:x)]{{/for}}' > "$TEST_DIR/p2p.template.md"
"$GNOSIS_BIN" --plain --scm-path "$TEST_DIR/.machine_readable" \
    "$TEST_DIR/p2p.template.md" "$TEST_DIR/p2p.md" 2>/dev/null
grep -q "\[a\]\[b\]\[c\]" "$TEST_DIR/p2p.md" && pass "DAX->Render: loop with placeholders" || fail "DAX->Render loop" "[a][b][c]" "$(cat "$TEST_DIR/p2p.md")"

echo ""

# ============================================================================
# P2P-4: Renderer -> Output interface
# ============================================================================

echo "--- P2P: Renderer -> Output ---"

echo '(state (metadata (name "Test")))' > "$TEST_DIR/.machine_readable/STATE.scm"

# Plain mode output
echo '(:name)' > "$TEST_DIR/p2p.template.md"
"$GNOSIS_BIN" --plain --scm-path "$TEST_DIR/.machine_readable" \
    "$TEST_DIR/p2p.template.md" "$TEST_DIR/p2p-plain.md" 2>/dev/null
PLAIN=$(cat "$TEST_DIR/p2p-plain.md")
echo "$PLAIN" | grep -qv "shields.io" && pass "Output: plain mode has no badges" || fail "Output: plain" "no badges" "$PLAIN"

# Badges mode output
"$GNOSIS_BIN" --badges --scm-path "$TEST_DIR/.machine_readable" \
    "$TEST_DIR/p2p.template.md" "$TEST_DIR/p2p-badges.md" 2>/dev/null
BADGES=$(cat "$TEST_DIR/p2p-badges.md")
echo "$BADGES" | grep -q "shields.io" && pass "Output: badges mode has shields.io" || fail "Output: badges" "shields.io" "$BADGES"
echo "$BADGES" | grep -q '!\[' && pass "Output: badges has alt text" || fail "Output: alt" "![" "$BADGES"

# Output overwrites existing file
echo "OLD CONTENT" > "$TEST_DIR/p2p-overwrite.md"
"$GNOSIS_BIN" --plain --scm-path "$TEST_DIR/.machine_readable" \
    "$TEST_DIR/p2p.template.md" "$TEST_DIR/p2p-overwrite.md" 2>/dev/null
grep -qv "OLD CONTENT" "$TEST_DIR/p2p-overwrite.md" && pass "Output: overwrites existing file" || fail "Output: overwrite" "new content" "$(cat "$TEST_DIR/p2p-overwrite.md")"

# Dump context output format
DUMP=$("$GNOSIS_BIN" --dump-context --scm-path "$TEST_DIR/.machine_readable" 2>/dev/null)
echo "$DUMP" | grep -q "Resolved" && pass "Output: dump-context format" || fail "Output: dump" "Resolved N keys" "$DUMP"
echo "$DUMP" | grep -q "engine = " && pass "Output: dump includes builtins" || fail "Output: builtins" "engine =" "$DUMP"

echo ""

# ============================================================================
# SUMMARY
# ============================================================================

echo "============================================"
printf "  Results: ${GREEN}%d passed${NC}" "$PASS"
if [ "$FAIL" -gt 0 ]; then
    printf ", ${RED}%d failed${NC}" "$FAIL"
else
    printf ", ${GREEN}0 failed${NC}"
fi
echo " ($TOTAL total)"
echo "============================================"

[ "$FAIL" -eq 0 ] || exit 1
