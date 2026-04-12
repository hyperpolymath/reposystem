#!/bin/bash
# SPDX-License-Identifier: PMPL-1.0-or-later
#
# Real Repository Test
# Tests repo-batcher on actual repositories (safe dry-run mode)

set -e

REPOS_DIR="$HOME/Documents/hyperpolymath-repos"
BATCHER_DIR="$REPOS_DIR/repo-batcher"

echo "repo-batcher Real Repository Test"
echo "=================================="
echo ""
echo "⚠️  This test runs in DRY-RUN mode only (no changes made)"
echo ""

# Check if repo-batcher is built
check_build() {
    if [ ! -f "$BATCHER_DIR/build/repo-batcher" ]; then
        echo "Building repo-batcher..."
        cd "$BATCHER_DIR"
        just build-dev
        echo ""
    fi
}

# Test 1: Repository Discovery
test_discovery() {
    echo "Test 1: Repository Discovery"
    echo "----------------------------"

    cd "$BATCHER_DIR"

    echo "Finding repositories with depth=2..."
    repo_count=$(./build/repo-batcher git-sync --parallel 1 --depth 2 --dry-run 2>&1 | grep "Found" | awk '{print $2}')

    if [ -n "$repo_count" ]; then
        echo "✓ Found $repo_count repositories"
    else
        echo "✗ Failed to discover repositories"
        return 1
    fi

    echo ""
}

# Test 2: SPDX Validation
test_spdx() {
    echo "Test 2: SPDX Validation"
    echo "-----------------------"

    cd "$BATCHER_DIR"

    # Test valid license
    if ./build/repo-batcher license-update \
        --old "MIT" \
        --new "PMPL-1.0-or-later" \
        --targets "$BATCHER_DIR" \
        --dry-run 2>&1 | grep -q "Invalid.*identifier"; then
        echo "✗ Valid SPDX ID rejected"
        return 1
    else
        echo "✓ Valid SPDX identifiers accepted"
    fi

    # Test invalid license
    if ./build/repo-batcher license-update \
        --old "NotARealLicense" \
        --new "PMPL-1.0-or-later" \
        --targets "$BATCHER_DIR" \
        --dry-run 2>&1 | grep -q "Invalid.*identifier"; then
        echo "✓ Invalid SPDX identifiers rejected"
    else
        echo "✗ Invalid SPDX ID accepted"
        return 1
    fi

    echo ""
}

# Test 3: Git Sync Dry-Run
test_git_sync() {
    echo "Test 3: Git Sync (Dry-Run)"
    echo "--------------------------"

    cd "$BATCHER_DIR"

    # Test on repo-batcher itself
    echo "Testing git-sync on repo-batcher..."

    output=$(./build/repo-batcher git-sync \
        --parallel 2 \
        --depth 0 \
        --commit-message "test" \
        --dry-run 2>&1)

    if echo "$output" | grep -q "DRY RUN"; then
        echo "✓ Dry-run mode confirmed"
    else
        echo "✗ Dry-run mode not detected"
        return 1
    fi

    if echo "$output" | grep -q "Success\|Skipped"; then
        echo "✓ Git-sync completed successfully"
    else
        echo "✗ Git-sync failed"
        return 1
    fi

    echo ""
}

# Test 4: Target Resolution
test_targets() {
    echo "Test 4: Target Resolution"
    echo "-------------------------"

    cd "$BATCHER_DIR"

    # Test single repo
    echo "Testing single repository target..."
    if ./build/repo-batcher git-sync \
        --parallel 1 \
        --depth 0 \
        --targets "$BATCHER_DIR" \
        --dry-run 2>&1 | grep -q "Found 1 repositories"; then
        echo "✓ Single repository target works"
    else
        echo "✗ Single repository target failed"
        return 1
    fi

    # Test @all-repos pattern
    echo "Testing @all-repos pattern..."
    repo_count=$(./build/repo-batcher git-sync \
        --parallel 1 \
        --depth 2 \
        --dry-run 2>&1 | grep "Found" | awk '{print $2}')

    if [ "$repo_count" -gt 1 ]; then
        echo "✓ @all-repos pattern works (found $repo_count repos)"
    else
        echo "✗ @all-repos pattern failed"
        return 1
    fi

    echo ""
}

# Test 5: Parallel Execution
test_parallel() {
    echo "Test 5: Parallel Execution"
    echo "--------------------------"

    cd "$BATCHER_DIR"

    # Test different worker counts
    for workers in 1 2 4; do
        echo "Testing with $workers worker(s)..."

        output=$(./build/repo-batcher git-sync \
            --parallel $workers \
            --depth 2 \
            --dry-run 2>&1)

        if echo "$output" | grep -q "workers on"; then
            echo "  ✓ $workers worker(s) executed"
        else
            echo "  ✗ $workers worker(s) failed"
            return 1
        fi
    done

    echo ""
}

# Test 6: License Update Dry-Run
test_license_update() {
    echo "Test 6: License Update (Dry-Run)"
    echo "--------------------------------"

    cd "$BATCHER_DIR"

    output=$(./build/repo-batcher license-update \
        --old "PMPL-1.0-or-later" \
        --new "PMPL-1.0-or-later" \
        --targets "$BATCHER_DIR" \
        --dry-run 2>&1)

    if echo "$output" | grep -q "DRY RUN"; then
        echo "✓ License update dry-run mode confirmed"
    else
        echo "✗ License update dry-run failed"
        return 1
    fi

    echo ""
}

# Test 7: File Replace Validation
test_file_replace() {
    echo "Test 7: File Replace Validation"
    echo "--------------------------------"

    cd "$BATCHER_DIR"

    # Create temporary replacement file
    temp_file="/tmp/test-replacement.txt"
    echo "test content" > "$temp_file"

    output=$(./build/repo-batcher file-replace \
        --pattern "nonexistent.txt" \
        --replacement "$temp_file" \
        --targets "$BATCHER_DIR" \
        --dry-run 2>&1)

    if echo "$output" | grep -q "DRY RUN"; then
        echo "✓ File replace dry-run mode confirmed"
    else
        echo "✗ File replace dry-run failed"
        rm -f "$temp_file"
        return 1
    fi

    rm -f "$temp_file"
    echo ""
}

# Run all tests
run_tests() {
    check_build

    local passed=0
    local failed=0

    test_discovery && ((passed++)) || ((failed++))
    test_spdx && ((passed++)) || ((failed++))
    test_git_sync && ((passed++)) || ((failed++))
    test_targets && ((passed++)) || ((failed++))
    test_parallel && ((passed++)) || ((failed++))
    test_license_update && ((passed++)) || ((failed++))
    test_file_replace && ((passed++)) || ((failed++))

    echo ""
    echo "Test Summary"
    echo "============"
    echo "Passed: $passed"
    echo "Failed: $failed"
    echo "Total:  $((passed + failed))"
    echo ""

    if [ $failed -gt 0 ]; then
        echo "❌ Some tests failed"
        exit 1
    else
        echo "✅ All tests passed!"
        echo ""
        echo "repo-batcher is ready for production use!"
    fi
}

# Main
run_tests
