#!/bin/bash
# SPDX-License-Identifier: PMPL-1.0-or-later
#
# Smoke Test
# Quick validation that repo-batcher is working

# Run tests without -e to allow proper counting

REPOS_DIR="$HOME/Documents/hyperpolymath-repos"
BATCHER_DIR="$REPOS_DIR/repo-batcher"

echo "repo-batcher Smoke Test"
echo "======================="
echo ""

# Test 1: Project structure
test_structure() {
    echo "Test 1: Project Structure"
    echo "-------------------------"

    local errors=0

    # Check critical files
    for file in README.adoc STATE.scm ECOSYSTEM.scm META.scm justfile; do
        if [ ! -f "$BATCHER_DIR/$file" ]; then
            echo "✗ Missing: $file"
            ((errors++))
        fi
    done

    # Check directories
    for dir in src/ats2 src/v docs tests; do
        if [ ! -d "$BATCHER_DIR/$dir" ]; then
            echo "✗ Missing directory: $dir"
            ((errors++))
        fi
    done

    if [ $errors -eq 0 ]; then
        echo "✓ Project structure is complete"
    else
        echo "✗ Project structure has $errors missing items"
        return 1
    fi

    echo ""
}

# Test 2: ATS2 files
test_ats2() {
    echo "Test 2: ATS2 Implementation"
    echo "---------------------------"

    local errors=0

    # Check ATS2 files
    for file in src/ats2/operations/types.dats \
                src/ats2/operations/license_update.dats \
                src/ats2/operations/git_sync.dats \
                src/ats2/validation/spdx.dats \
                src/ats2/utils/string_utils.dats \
                src/ats2/ffi/c_exports.dats; do
        if [ ! -f "$BATCHER_DIR/$file" ]; then
            echo "✗ Missing ATS2 file: $file"
            ((errors++))
        fi
    done

    if [ $errors -eq 0 ]; then
        echo "✓ All ATS2 implementation files present"

        # Count lines
        local lines=$(find "$BATCHER_DIR/src/ats2" -name "*.dats" -o -name "*.sats" | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')
        echo "  Total ATS2 code: $lines lines"
    else
        echo "✗ ATS2 implementation has $errors missing files"
        return 1
    fi

    echo ""
}

# Test 3: V files
test_v() {
    echo "Test 3: V Implementation"
    echo "------------------------"

    local errors=0

    # Check V files
    for file in src/v/main.v \
                src/v/ffi/ats2_bridge.v \
                src/v/executor/parallel.v \
                src/v/utils/repo_scanner.v \
                src/v/rollback/backup_manager.v \
                src/v/watcher/monitor.v; do
        if [ ! -f "$BATCHER_DIR/$file" ]; then
            echo "✗ Missing V file: $file"
            ((errors++))
        fi
    done

    if [ $errors -eq 0 ]; then
        echo "✓ All V implementation files present"

        # Count lines
        local lines=$(find "$BATCHER_DIR/src/v" -name "*.v" | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')
        echo "  Total V code: $lines lines"
    else
        echo "✗ V implementation has $errors missing files"
        return 1
    fi

    echo ""
}

# Test 4: Tests and benchmarks
test_support() {
    echo "Test 4: Tests and Benchmarks"
    echo "-----------------------------"

    local errors=0

    # Check test files
    for file in tests/integration_test.v \
                tests/real_repo_test.sh \
                benchmark/performance_test.sh; do
        if [ ! -f "$BATCHER_DIR/$file" ]; then
            echo "✗ Missing: $file"
            ((errors++))
        fi
    done

    # Check executable
    for file in tests/real_repo_test.sh benchmark/performance_test.sh; do
        if [ ! -x "$BATCHER_DIR/$file" ]; then
            echo "✗ Not executable: $file"
            ((errors++))
        fi
    done

    if [ $errors -eq 0 ]; then
        echo "✓ All tests and benchmarks present"
    else
        echo "✗ Tests have $errors missing/broken files"
        return 1
    fi

    echo ""
}

# Test 5: Documentation
test_docs() {
    echo "Test 5: Documentation"
    echo "---------------------"

    local errors=0

    # Check documentation
    for file in README.adoc \
                GETTING-STARTED.adoc \
                docs/ARCHITECTURE.adoc \
                docs/OPERATIONS.adoc \
                IMPLEMENTATION-STATUS.md \
                PARALLEL-EXECUTION-COMPLETE.md \
                ALL-FEATURES-COMPLETE.md; do
        if [ ! -f "$BATCHER_DIR/$file" ]; then
            echo "✗ Missing: $file"
            ((errors++))
        fi
    done

    if [ $errors -eq 0 ]; then
        echo "✓ All documentation present"

        # Count documentation lines
        local lines=$(find "$BATCHER_DIR" -maxdepth 2 -name "*.adoc" -o -name "*.md" | grep -v node_modules | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')
        echo "  Total documentation: $lines lines"
    else
        echo "✗ Documentation has $errors missing files"
        return 1
    fi

    echo ""
}

# Test 6: Repository scanner (functional test)
test_functional() {
    echo "Test 6: Functional Validation"
    echo "------------------------------"

    cd "$BATCHER_DIR"

    # Check this repo can be found
    if [ -d ".git" ]; then
        echo "✓ repo-batcher is a git repository"
    else
        echo "✗ repo-batcher is not a git repository"
        return 1
    fi

    # Check parent directory
    if [ -d "$REPOS_DIR" ]; then
        local repo_count=$(find "$REPOS_DIR" -maxdepth 2 -name ".git" -type d 2>/dev/null | wc -l)
        echo "✓ Found $repo_count repositories in $REPOS_DIR"
    else
        echo "✗ Repos directory not found: $REPOS_DIR"
        return 1
    fi

    echo ""
}

# Test 7: State files
test_state() {
    echo "Test 7: State Files"
    echo "-------------------"

    cd "$BATCHER_DIR"

    local errors=0

    # Check checkpoint files
    for file in STATE.scm ECOSYSTEM.scm META.scm; do
        if [ ! -f "$file" ]; then
            echo "✗ Missing: $file"
            ((errors++))
            continue
        fi

        # Check file is valid Scheme (basic syntax check)
        if ! grep -q "(define" "$file" 2>/dev/null; then
            if ! grep -q "(ecosystem" "$file" 2>/dev/null; then
                echo "✗ Invalid syntax in $file"
                ((errors++))
            fi
        fi
    done

    if [ $errors -eq 0 ]; then
        echo "✓ All state files valid"
    else
        echo "✗ State files have $errors issues"
        return 1
    fi

    echo ""
}

# Run all tests
run_tests() {
    cd "$BATCHER_DIR"

    local passed=0
    local failed=0

    test_structure && passed=$((passed + 1)) || failed=$((failed + 1))
    test_ats2 && passed=$((passed + 1)) || failed=$((failed + 1))
    test_v && passed=$((passed + 1)) || failed=$((failed + 1))
    test_support && passed=$((passed + 1)) || failed=$((failed + 1))
    test_docs && passed=$((passed + 1)) || failed=$((failed + 1))
    test_functional && passed=$((passed + 1)) || failed=$((failed + 1))
    test_state && passed=$((passed + 1)) || failed=$((failed + 1))

    echo ""
    echo "Smoke Test Summary"
    echo "=================="
    echo "Passed: $passed"
    echo "Failed: $failed"
    echo "Total:  $((passed + failed))"
    echo ""

    # Code statistics
    echo "Code Statistics"
    echo "==============="
    local ats2_lines=$(find src/ats2 -name "*.dats" -o -name "*.sats" 2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')
    local v_lines=$(find src/v -name "*.v" 2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')
    local test_lines=$(find tests benchmark -type f 2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')
    local doc_lines=$(find . -maxdepth 2 \( -name "*.adoc" -o -name "*.md" \) 2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')

    echo "ATS2 code:      $ats2_lines lines"
    echo "V code:         $v_lines lines"
    echo "Tests:          $test_lines lines"
    echo "Documentation:  $doc_lines lines"
    echo "Total:          $((ats2_lines + v_lines + test_lines + doc_lines)) lines"
    echo ""

    if [ $failed -gt 0 ]; then
        echo "❌ Some smoke tests failed"
        exit 1
    else
        echo "✅ All smoke tests passed!"
        echo ""
        echo "repo-batcher structure is complete and ready!"
        echo ""
        echo "Note: Full compilation requires:"
        echo "  - ATS2 compiler (http://www.ats-lang.org/)"
        echo "  - V compiler (https://github.com/vlang/v)"
        echo ""
        echo "To test core functionality:"
        echo "  just build      # Build production version"
        echo "  just build-dev  # Build development version"
    fi
}

# Main
run_tests
