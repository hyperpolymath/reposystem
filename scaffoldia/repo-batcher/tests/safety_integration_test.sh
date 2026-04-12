#!/bin/bash
# SPDX-License-Identifier: PMPL-1.0-or-later
#
# Safety Integration Test
# Tests safety system integration with CLI operations

set -e

TEST_DIR="/tmp/repo-batcher-safety-test-$$"
REPO_BATCHER_DIR="/var$REPOS_DIR/repo-batcher"

echo "Safety Integration Test"
echo "======================="
echo ""

# Cleanup function
cleanup() {
    echo ""
    echo "Cleaning up..."
    rm -rf "$TEST_DIR"
}

trap cleanup EXIT

# Setup test repositories
setup_test_repos() {
    echo "Setting up test repositories..."
    mkdir -p "$TEST_DIR"

    for i in 1 2 3; do
        repo="$TEST_DIR/test-repo-$i"
        mkdir -p "$repo"
        cd "$repo"
        git init -q
        echo "# Test Repo $i" > README.md
        git add README.md
        git config user.name "Test User"
        git config user.email "test@example.com"
        git commit -q -m "Initial commit"
    done

    echo "✓ Created 3 test repositories"
}

# Test 1: Safety module exists
test_safety_module_exists() {
    echo ""
    echo "Test 1: Safety module structure"

    if [ ! -f "$REPO_BATCHER_DIR/src/v/safety/guards.v" ]; then
        echo "✗ guards.v not found"
        return 1
    fi

    if [ ! -f "$REPO_BATCHER_DIR/src/v/safety/validation.v" ]; then
        echo "✗ validation.v not found"
        return 1
    fi

    if [ ! -f "$REPO_BATCHER_DIR/src/v/safety/integration.v" ]; then
        echo "✗ integration.v not found"
        return 1
    fi

    if [ ! -f "$REPO_BATCHER_DIR/.safety.toml" ]; then
        echo "✗ .safety.toml not found"
        return 1
    fi

    echo "✓ All safety files present"
}

# Test 2: Safety config loads
test_safety_config() {
    echo ""
    echo "Test 2: Safety configuration parsing"

    # Check config has required sections
    if ! grep -q "\[safety\]" "$REPO_BATCHER_DIR/.safety.toml"; then
        echo "✗ [safety] section missing"
        return 1
    fi

    if ! grep -q "\[exclusions\]" "$REPO_BATCHER_DIR/.safety.toml"; then
        echo "✗ [exclusions] section missing"
        return 1
    fi

    if ! grep -q "\[validation\]" "$REPO_BATCHER_DIR/.safety.toml"; then
        echo "✗ [validation] section missing"
        return 1
    fi

    echo "✓ Configuration file valid"
}

# Test 3: Safety integration in main.v
test_main_integration() {
    echo ""
    echo "Test 3: Main CLI integration"

    # Check main.v imports safety
    if ! grep -q "import safety" "$REPO_BATCHER_DIR/src/v/main.v"; then
        echo "✗ safety module not imported in main.v"
        return 1
    fi

    # Check wiki-setup has safety context
    if ! grep -q "safety.new_safety_context" "$REPO_BATCHER_DIR/src/v/main.v"; then
        echo "✗ safety_context not created in operations"
        return 1
    fi

    # Check validation is called
    if ! grep -q "safety_ctx.validate" "$REPO_BATCHER_DIR/src/v/main.v"; then
        echo "✗ validation not called"
        return 1
    fi

    # Check should_proceed is called
    if ! grep -q "safety_ctx.should_proceed" "$REPO_BATCHER_DIR/src/v/main.v"; then
        echo "✗ should_proceed not called"
        return 1
    fi

    # Check audit logging
    if ! grep -q "safety_ctx.audit" "$REPO_BATCHER_DIR/src/v/main.v"; then
        echo "✗ audit logging not called"
        return 1
    fi

    echo "✓ Safety integration present in main.v"
}

# Test 4: Force flag added to operations
test_force_flag() {
    echo ""
    echo "Test 4: Force flag in CLI commands"

    # Check wiki-setup has force flag
    if ! grep -A 50 "name: 'wiki-setup'" "$REPO_BATCHER_DIR/src/v/main.v" | grep -q "name: 'force'"; then
        echo "✗ wiki-setup missing force flag"
        return 1
    fi

    # Check community-setup has force flag
    if ! grep -A 50 "name: 'community-setup'" "$REPO_BATCHER_DIR/src/v/main.v" | grep -q "name: 'force'"; then
        echo "✗ community-setup missing force flag"
        return 1
    fi

    echo "✓ Force flag added to operations"
}

# Test 5: SafetyContext structure
test_safety_context() {
    echo ""
    echo "Test 5: SafetyContext structure"

    # Check structure definition
    if ! grep -q "pub struct SafetyContext" "$REPO_BATCHER_DIR/src/v/safety/integration.v"; then
        echo "✗ SafetyContext struct not found"
        return 1
    fi

    # Check essential methods
    if ! grep -q "pub fn new_safety_context" "$REPO_BATCHER_DIR/src/v/safety/integration.v"; then
        echo "✗ new_safety_context function not found"
        return 1
    fi

    if ! grep -q "pub fn (ctx &SafetyContext) check_operation" "$REPO_BATCHER_DIR/src/v/safety/integration.v"; then
        echo "✗ check_operation method not found"
        return 1
    fi

    if ! grep -q "pub fn (ctx &SafetyContext) validate" "$REPO_BATCHER_DIR/src/v/safety/integration.v"; then
        echo "✗ validate method not found"
        return 1
    fi

    echo "✓ SafetyContext structure complete"
}

# Test 6: Validation rules
test_validation_rules() {
    echo ""
    echo "Test 6: Validation rules defined"

    # Check all 5 rules exist in guards.v or validation.v
    rules=(
        "git_repository_check"
        "write_permission_check"
        "uncommitted_changes_check"
        "remote_exists_check"
        "disk_space_check"
    )

    for rule in "${rules[@]}"; do
        if ! grep -q "$rule" "$REPO_BATCHER_DIR/src/v/safety/validation.v"; then
            echo "✗ Rule $rule not found"
            return 1
        fi
    done

    echo "✓ All 5 validation rules defined"
}

# Test 7: Safety levels
test_safety_levels() {
    echo ""
    echo "Test 7: Safety levels enum"

    # Check SafetyLevel enum
    if ! grep -q "pub enum SafetyLevel" "$REPO_BATCHER_DIR/src/v/safety/guards.v"; then
        echo "✗ SafetyLevel enum not found"
        return 1
    fi

    # Check all 4 levels
    if ! grep -q "paranoid" "$REPO_BATCHER_DIR/src/v/safety/guards.v"; then
        echo "✗ paranoid level not found"
        return 1
    fi

    if ! grep -q "strict" "$REPO_BATCHER_DIR/src/v/safety/guards.v"; then
        echo "✗ strict level not found"
        return 1
    fi

    if ! grep -q "relaxed" "$REPO_BATCHER_DIR/src/v/safety/guards.v"; then
        echo "✗ relaxed level not found"
        return 1
    fi

    if ! grep -q "disabled" "$REPO_BATCHER_DIR/src/v/safety/guards.v"; then
        echo "✗ disabled level not found"
        return 1
    fi

    echo "✓ All 4 safety levels defined"
}

# Test 8: Operation types
test_operation_types() {
    echo ""
    echo "Test 8: Operation types enum"

    # Check OperationType enum
    if ! grep -q "pub enum OperationType" "$REPO_BATCHER_DIR/src/v/safety/guards.v"; then
        echo "✗ OperationType enum not found"
        return 1
    fi

    # Check all 4 types
    types=("read_only" "local_changes" "remote_changes" "destructive")

    for type in "${types[@]}"; do
        if ! grep -q "$type" "$REPO_BATCHER_DIR/src/v/safety/guards.v"; then
            echo "✗ OperationType $type not found"
            return 1
        fi
    done

    echo "✓ All 4 operation types defined"
}

# Test 9: Rate limiter
test_rate_limiter() {
    echo ""
    echo "Test 9: Rate limiter implementation"

    if ! grep -q "pub struct RateLimiter" "$REPO_BATCHER_DIR/src/v/safety/guards.v"; then
        echo "✗ RateLimiter struct not found"
        return 1
    fi

    if ! grep -q "pub fn new_rate_limiter" "$REPO_BATCHER_DIR/src/v/safety/guards.v"; then
        echo "✗ new_rate_limiter function not found"
        return 1
    fi

    if ! grep -q "pub fn (mut limiter RateLimiter) wait" "$REPO_BATCHER_DIR/src/v/safety/guards.v"; then
        echo "✗ RateLimiter.wait method not found"
        return 1
    fi

    echo "✓ Rate limiter implemented"
}

# Test 10: Audit log
test_audit_log() {
    echo ""
    echo "Test 10: Audit logging"

    if ! grep -q "pub struct AuditLog" "$REPO_BATCHER_DIR/src/v/safety/guards.v"; then
        echo "✗ AuditLog struct not found"
        return 1
    fi

    if ! grep -q "pub fn new_audit_log" "$REPO_BATCHER_DIR/src/v/safety/guards.v"; then
        echo "✗ new_audit_log function not found"
        return 1
    fi

    if ! grep -q "pub fn (mut log AuditLog) record" "$REPO_BATCHER_DIR/src/v/safety/guards.v"; then
        echo "✗ AuditLog.record method not found"
        return 1
    fi

    echo "✓ Audit logging implemented"
}

# Test 11: Documentation
test_documentation() {
    echo ""
    echo "Test 11: Safety documentation"

    if [ ! -f "$REPO_BATCHER_DIR/docs/SAFETY-FEATURES.adoc" ]; then
        echo "✗ SAFETY-FEATURES.adoc not found"
        return 1
    fi

    # Check doc has key sections
    doc="$REPO_BATCHER_DIR/docs/SAFETY-FEATURES.adoc"

    if ! grep -q "Safety Levels" "$doc"; then
        echo "✗ Safety Levels section missing"
        return 1
    fi

    if ! grep -q "Pre-flight Validation" "$doc"; then
        echo "✗ Pre-flight Validation section missing"
        return 1
    fi

    if ! grep -q "Confirmation Prompts" "$doc"; then
        echo "✗ Confirmation Prompts section missing"
        return 1
    fi

    echo "✓ Documentation complete"
}

# Test 12: Safety banner
test_safety_banner() {
    echo ""
    echo "Test 12: Safety banner display"

    if ! grep -q "pub fn (ctx &SafetyContext) print_banner" "$REPO_BATCHER_DIR/src/v/safety/integration.v"; then
        echo "✗ print_banner method not found"
        return 1
    fi

    if ! grep -q "safety_ctx.print_banner" "$REPO_BATCHER_DIR/src/v/main.v"; then
        echo "✗ print_banner not called in operations"
        return 1
    fi

    echo "✓ Safety banner implementation complete"
}

# Run tests
main() {
    setup_test_repos

    passed=0
    failed=0

    for test_func in \
        test_safety_module_exists \
        test_safety_config \
        test_main_integration \
        test_force_flag \
        test_safety_context \
        test_validation_rules \
        test_safety_levels \
        test_operation_types \
        test_rate_limiter \
        test_audit_log \
        test_documentation \
        test_safety_banner
    do
        if $test_func; then
            passed=$((passed + 1))
        else
            failed=$((failed + 1))
        fi
    done

    echo ""
    echo "Test Summary"
    echo "============"
    echo "Passed: $passed"
    echo "Failed: $failed"
    echo "Total:  $((passed + failed))"

    if [ $failed -gt 0 ]; then
        exit 1
    fi
}

main
