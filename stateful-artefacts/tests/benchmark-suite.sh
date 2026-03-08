#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
# Gnosis comprehensive benchmark suite
#
# Covers: precompile, compile, build, execution, installation,
#         point-to-point, end-to-end, and evaluation benchmarks

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
GNOSIS_DIR="$PROJECT_DIR/gnosis"
TEST_DIR=$(mktemp -d)
RESULTS_FILE="$SCRIPT_DIR/benchmark-results.txt"

cleanup() { rm -rf "$TEST_DIR"; }
trap cleanup EXIT

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { printf "${CYAN}[BENCH]${NC} %s\n" "$1"; }
result() { printf "  %-45s %s\n" "$1" "$2"; echo "  $1  $2" >> "$RESULTS_FILE"; }

# Start fresh results
echo "Gnosis Benchmark Results — $(date -Iseconds)" > "$RESULTS_FILE"
echo "=============================================" >> "$RESULTS_FILE"

echo ""
echo "======================================================"
echo "  Gnosis Comprehensive Benchmark Suite"
echo "  $(date)"
echo "======================================================"
echo ""

# ============================================================================
# 1. PRECOMPILE BENCHMARKS
# ============================================================================

log "Phase 1: Precompile benchmarks"
echo "" >> "$RESULTS_FILE"
echo "--- Precompile ---" >> "$RESULTS_FILE"

cd "$GNOSIS_DIR"

# Clean build artefacts
cabal clean 2>/dev/null || true

# Measure dependency resolution time
START=$(date +%s%N)
cabal build --dry-run 2>/dev/null
END=$(date +%s%N)
DEP_MS=$(( (END - START) / 1000000 ))
result "dependency resolution" "${DEP_MS} ms"

# Measure cabal configure time
START=$(date +%s%N)
cabal configure 2>/dev/null
END=$(date +%s%N)
CONF_MS=$(( (END - START) / 1000000 ))
result "cabal configure" "${CONF_MS} ms"

echo ""

# ============================================================================
# 2. COMPILE BENCHMARKS
# ============================================================================

log "Phase 2: Compile benchmarks"
echo "" >> "$RESULTS_FILE"
echo "--- Compile ---" >> "$RESULTS_FILE"

# Clean build
cabal clean 2>/dev/null || true

# Full clean build (cold)
START=$(date +%s%N)
cabal build 2>&1 | tail -3
END=$(date +%s%N)
COLD_MS=$(( (END - START) / 1000000 ))
result "cold build (from clean)" "${COLD_MS} ms"

# Incremental build (no changes)
START=$(date +%s%N)
cabal build 2>/dev/null
END=$(date +%s%N)
NOOP_MS=$(( (END - START) / 1000000 ))
result "no-op build (no changes)" "${NOOP_MS} ms"

# Touch one file, rebuild (incremental)
touch src/DAX.hs
START=$(date +%s%N)
cabal build 2>/dev/null
END=$(date +%s%N)
INCR_MS=$(( (END - START) / 1000000 ))
result "incremental build (DAX.hs touched)" "${INCR_MS} ms"

# Test suite build
START=$(date +%s%N)
cabal build gnosis-tests 2>/dev/null
END=$(date +%s%N)
TEST_BUILD_MS=$(( (END - START) / 1000000 ))
result "test suite build" "${TEST_BUILD_MS} ms"

# Benchmark build
START=$(date +%s%N)
cabal build gnosis-bench 2>/dev/null
END=$(date +%s%N)
BENCH_BUILD_MS=$(( (END - START) / 1000000 ))
result "benchmark build (-O2)" "${BENCH_BUILD_MS} ms"

# Binary size
GNOSIS_BIN=$(cabal list-bin gnosis 2>/dev/null)
BIN_SIZE=$(stat --format=%s "$GNOSIS_BIN" 2>/dev/null || stat -f%z "$GNOSIS_BIN" 2>/dev/null)
BIN_SIZE_KB=$((BIN_SIZE / 1024))
result "binary size" "${BIN_SIZE_KB} KB"

# Source lines of code
SLOC=$(find src/ -name '*.hs' -exec cat {} + | wc -l)
result "source lines (src/*.hs)" "${SLOC} lines"

echo ""

# ============================================================================
# 3. BUILD EVALUATION
# ============================================================================

log "Phase 3: Build evaluation"
echo "" >> "$RESULTS_FILE"
echo "--- Build Evaluation ---" >> "$RESULTS_FILE"

# GHC warnings count
WARNINGS=$(cabal build 2>&1 | grep -c "warning:" || echo "0")
result "GHC warnings" "$WARNINGS"

# Test suite run
START=$(date +%s%N)
cabal test 2>/dev/null
END=$(date +%s%N)
TEST_MS=$(( (END - START) / 1000000 ))
result "unit test suite (94 tests)" "${TEST_MS} ms"

# Integration test run
START=$(date +%s%N)
bash "$SCRIPT_DIR/integration-test.sh" >/dev/null 2>&1
END=$(date +%s%N)
INT_MS=$(( (END - START) / 1000000 ))
result "integration tests (23 tests)" "${INT_MS} ms"

echo ""

# ============================================================================
# 4. EXECUTION BENCHMARKS (point-to-point)
# ============================================================================

log "Phase 4: Execution benchmarks (point-to-point)"
echo "" >> "$RESULTS_FILE"
echo "--- Execution (Point-to-Point) ---" >> "$RESULTS_FILE"

# Setup test fixtures
mkdir -p "$TEST_DIR/.machine_readable"
cat > "$TEST_DIR/.machine_readable/STATE.scm" <<'ENDSCM'
(state
  (metadata (version "2.0.0") (updated "2026-03-08") (project "bench-project"))
  (project-context (name "Benchmark Project") (tagline "Performance testing"))
  (current-position (phase "beta") (overall-completion 75)))
ENDSCM

# Minimal template (startup overhead)
echo "(:name)" > "$TEST_DIR/minimal.template.md"

# Time CLI startup + minimal render
START=$(date +%s%N)
for i in $(seq 1 20); do
    "$GNOSIS_BIN" --plain --scm-path "$TEST_DIR/.machine_readable" \
        "$TEST_DIR/minimal.template.md" "$TEST_DIR/out.md" 2>/dev/null
done
END=$(date +%s%N)
STARTUP_US=$(( (END - START) / 20000 ))
result "CLI startup + minimal render (avg)" "${STARTUP_US} us"

# --version (absolute minimum startup)
START=$(date +%s%N)
for i in $(seq 1 50); do
    "$GNOSIS_BIN" --version >/dev/null 2>&1
done
END=$(date +%s%N)
VER_US=$(( (END - START) / 50000 ))
result "CLI --version (avg)" "${VER_US} us"

# --dump-context
START=$(date +%s%N)
for i in $(seq 1 20); do
    "$GNOSIS_BIN" --dump-context --scm-path "$TEST_DIR/.machine_readable" >/dev/null 2>&1
done
END=$(date +%s%N)
DUMP_US=$(( (END - START) / 20000 ))
result "CLI --dump-context (avg)" "${DUMP_US} us"

# Small template (10 placeholders)
python3 -c "
for i in range(10):
    print(f'Key{i}: (:key{i})')
" > "$TEST_DIR/small.template.md" 2>/dev/null || {
    for i in $(seq 0 9); do echo "Key$i: (:key$i)"; done > "$TEST_DIR/small.template.md"
}

START=$(date +%s%N)
for i in $(seq 1 20); do
    "$GNOSIS_BIN" --plain --scm-path "$TEST_DIR/.machine_readable" \
        "$TEST_DIR/small.template.md" "$TEST_DIR/out.md" 2>/dev/null
done
END=$(date +%s%N)
SMALL_US=$(( (END - START) / 20000 ))
result "render: 10 placeholders (avg)" "${SMALL_US} us"

# Medium template (100 lines mixed)
{
    echo "# (:name)"
    echo ""
    for i in $(seq 1 30); do echo "Line $i: (:phase)"; done
    echo ""
    echo "{{#if phase == beta}}Beta mode{{#else}}Other{{/if}}"
    echo ""
    for i in $(seq 1 5); do echo "{{#if overall-completion >= 50}}Over 50{{/if}}"; done
} > "$TEST_DIR/medium.template.md"

START=$(date +%s%N)
for i in $(seq 1 20); do
    "$GNOSIS_BIN" --plain --scm-path "$TEST_DIR/.machine_readable" \
        "$TEST_DIR/medium.template.md" "$TEST_DIR/out.md" 2>/dev/null
done
END=$(date +%s%N)
MED_US=$(( (END - START) / 20000 ))
result "render: medium template (avg)" "${MED_US} us"

# Badges mode
START=$(date +%s%N)
for i in $(seq 1 20); do
    "$GNOSIS_BIN" --badges --scm-path "$TEST_DIR/.machine_readable" \
        "$TEST_DIR/small.template.md" "$TEST_DIR/out.md" 2>/dev/null
done
END=$(date +%s%N)
BADGE_US=$(( (END - START) / 20000 ))
result "render: badges mode (avg)" "${BADGE_US} us"

echo ""

# ============================================================================
# 5. LARGE FILE BENCHMARKS
# ============================================================================

log "Phase 5: Large file benchmarks"
echo "" >> "$RESULTS_FILE"
echo "--- Large File Performance ---" >> "$RESULTS_FILE"

# Generate large SCM file (500 keys)
{
    echo "(state"
    for s in $(seq 1 10); do
        echo "  (section$s"
        for k in $(seq 1 50); do
            echo "    (key-$s-$k \"value-$s-$k\")"
        done
        echo "  )"
    done
    echo ")"
} > "$TEST_DIR/.machine_readable/STATE.scm"

START=$(date +%s%N)
for i in $(seq 1 10); do
    "$GNOSIS_BIN" --dump-context --scm-path "$TEST_DIR/.machine_readable" >/dev/null 2>&1
done
END=$(date +%s%N)
LARGE_SCM_US=$(( (END - START) / 10000 ))
result "load 500-key SCM file (avg)" "${LARGE_SCM_US} us"

# Generate large template (500 placeholders)
for i in $(seq 1 500); do echo "(:key-$((((i-1)/50)+1))-$(((i-1)%50+1)))"; done > "$TEST_DIR/large.template.md"

START=$(date +%s%N)
for i in $(seq 1 5); do
    "$GNOSIS_BIN" --plain --scm-path "$TEST_DIR/.machine_readable" \
        "$TEST_DIR/large.template.md" "$TEST_DIR/out.md" 2>/dev/null
done
END=$(date +%s%N)
LARGE_TPL_US=$(( (END - START) / 5000 ))
result "render: 500 placeholders (avg)" "${LARGE_TPL_US} us"

# Output file size
OUT_SIZE=$(wc -c < "$TEST_DIR/out.md")
result "output size (500 placeholders)" "${OUT_SIZE} bytes"

echo ""

# ============================================================================
# 6. INSTALLATION BENCHMARK
# ============================================================================

log "Phase 6: Installation benchmark"
echo "" >> "$RESULTS_FILE"
echo "--- Installation ---" >> "$RESULTS_FILE"

INSTALL_DIR=$(mktemp -d)

START=$(date +%s%N)
cp "$GNOSIS_BIN" "$INSTALL_DIR/gnosis"
chmod +x "$INSTALL_DIR/gnosis"
END=$(date +%s%N)
INSTALL_US=$(( (END - START) / 1000 ))
result "binary install (copy + chmod)" "${INSTALL_US} us"

# Verify installed binary works
INSTALLED_VER=$("$INSTALL_DIR/gnosis" --version 2>/dev/null || echo "FAILED")
if echo "$INSTALLED_VER" | grep -q "Gnosis"; then
    result "installed binary verification" "PASS"
else
    result "installed binary verification" "FAIL"
fi

rm -rf "$INSTALL_DIR"

echo ""

# ============================================================================
# 7. END-TO-END BENCHMARK
# ============================================================================

log "Phase 7: End-to-end benchmark"
echo "" >> "$RESULTS_FILE"
echo "--- End-to-End ---" >> "$RESULTS_FILE"

# Realistic workflow: load SCM -> process template with all features -> write output
# Restore a realistic SCM file
cat > "$TEST_DIR/.machine_readable/STATE.scm" <<'ENDSCM'
(state
  (metadata (version "2.0.0") (updated "2026-03-08") (project "real-project"))
  (project-context
    (name "Real Project")
    (tagline "A realistic benchmark scenario")
    (tech-stack (primary "Haskell")))
  (current-position
    (phase "beta")
    (overall-completion 75)
    (components
      (parser "complete" "S-expression parser")
      (renderer "complete" "Template renderer")
      (dax "complete" "Conditional engine")))
  (tags "rust,haskell,zig,gleam,elixir"))
ENDSCM

cat > "$TEST_DIR/e2e.template.md" <<'ENDTPL'
# (:name)

> (:tagline)

**Version**: (:version)
**Phase**: (:phase | capitalize)
**Completion**: (:overall-completion)%
**Stack**: (:primary | uppercase)
**Updated**: (:updated | relativeTime)

{{#if phase == beta}}
## Beta Notice
This project is in beta. Expect changes.
{{#else}}
## Stable
This project is stable.
{{/if}}

{{#if overall-completion >= 50}}
More than halfway done.
{{/if}}

## Languages

{{#for lang in tags}}{{@index}}. (:lang | capitalize)
{{/for}}

---
Generated by (:engine)
ENDTPL

# Warm up
"$GNOSIS_BIN" --plain --scm-path "$TEST_DIR/.machine_readable" \
    "$TEST_DIR/e2e.template.md" "$TEST_DIR/e2e.md" 2>/dev/null

# Timed runs
START=$(date +%s%N)
for i in $(seq 1 50); do
    "$GNOSIS_BIN" --plain --scm-path "$TEST_DIR/.machine_readable" \
        "$TEST_DIR/e2e.template.md" "$TEST_DIR/e2e.md" 2>/dev/null
done
END=$(date +%s%N)
E2E_US=$(( (END - START) / 50000 ))
result "end-to-end: realistic template (avg)" "${E2E_US} us"

# Verify output correctness
E2E_OUT=$(cat "$TEST_DIR/e2e.md")
E2E_CHECKS=0
E2E_PASS=0

check_e2e() {
    E2E_CHECKS=$((E2E_CHECKS + 1))
    if echo "$E2E_OUT" | grep -q "$1"; then
        E2E_PASS=$((E2E_PASS + 1))
    fi
}

check_e2e "Real Project"
check_e2e "Version.*2.0.0"
check_e2e "Beta"
check_e2e "More than halfway"
check_e2e "Capitalize"
check_e2e "March 2026"
check_e2e "0\. Rust"
check_e2e "4\. Elixir"

result "end-to-end correctness" "${E2E_PASS}/${E2E_CHECKS} checks passed"

echo ""

# ============================================================================
# 8. HASKELL BENCHMARKS (in-process)
# ============================================================================

log "Phase 8: Haskell in-process benchmarks"
echo "" >> "$RESULTS_FILE"
echo "--- Haskell In-Process ---" >> "$RESULTS_FILE"

BENCH_BIN=$(cabal list-bin gnosis-bench 2>/dev/null || echo "")
if [ -n "$BENCH_BIN" ] && [ -x "$BENCH_BIN" ]; then
    START=$(date +%s%N)
    "$BENCH_BIN" 2>&1 | tee "$TEST_DIR/bench-output.txt"
    END=$(date +%s%N)
    HASKELL_MS=$(( (END - START) / 1000000 ))
    result "haskell benchmark suite total" "${HASKELL_MS} ms"
    cat "$TEST_DIR/bench-output.txt" >> "$RESULTS_FILE"
else
    result "haskell benchmarks" "SKIPPED (binary not found)"
fi

echo ""

# ============================================================================
# SUMMARY
# ============================================================================

echo "======================================================"
echo "  Benchmark Summary"
echo "======================================================"
echo ""
printf "  ${GREEN}Precompile${NC}:    configure ${CONF_MS}ms, deps ${DEP_MS}ms\n"
printf "  ${GREEN}Compile${NC}:       cold ${COLD_MS}ms, incremental ${INCR_MS}ms, noop ${NOOP_MS}ms\n"
printf "  ${GREEN}Binary${NC}:        ${BIN_SIZE_KB}KB, ${SLOC} SLOC\n"
printf "  ${GREEN}Unit tests${NC}:    94 tests in ${TEST_MS}ms\n"
printf "  ${GREEN}Integration${NC}:   23 tests in ${INT_MS}ms\n"
printf "  ${GREEN}Startup${NC}:       ${VER_US}us (version), ${STARTUP_US}us (minimal render)\n"
printf "  ${GREEN}Rendering${NC}:     ${SMALL_US}us (10 ph), ${MED_US}us (medium), ${LARGE_TPL_US}us (500 ph)\n"
printf "  ${GREEN}End-to-end${NC}:    ${E2E_US}us (realistic template)\n"
printf "  ${GREEN}Correctness${NC}:   ${E2E_PASS}/${E2E_CHECKS} e2e checks\n"
echo ""
echo "Full results written to: $RESULTS_FILE"
echo "======================================================"
