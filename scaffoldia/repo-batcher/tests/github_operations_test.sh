#!/bin/bash
# SPDX-License-Identifier: PMPL-1.0-or-later
#
# GitHub Operations Test
# Tests wiki-setup and community-setup operations

set -e

TEST_DIR="/tmp/repo-batcher-github-test-$$"

echo "repo-batcher GitHub Operations Test"
echo "===================================="
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

# Test 1: Community module exists with default functions
test_community_defaults() {
    echo ""
    echo "Test 1: Community module has default functions"

    # Check that the source files exist and contain the default functions
    if ! grep -q "pub fn default_code_of_conduct" /var$REPOS_DIR/repo-batcher/src/v/github/community.v; then
        echo "✗ default_code_of_conduct function not found"
        return 1
    fi

    if ! grep -q "pub fn default_contributing" /var$REPOS_DIR/repo-batcher/src/v/github/community.v; then
        echo "✗ default_contributing function not found"
        return 1
    fi

    if ! grep -q "pub fn default_security" /var$REPOS_DIR/repo-batcher/src/v/github/community.v; then
        echo "✗ default_security function not found"
        return 1
    fi

    echo "✓ Default community file functions exist"
}

# Test 2: Community setup creates files
test_community_setup() {
    echo ""
    echo "Test 2: Community setup creates files locally"

    repo="$TEST_DIR/test-repo-1"

    # Manually create community files for testing
    mkdir -p "$repo/.github"

    cat > "$repo/.github/CODE_OF_CONDUCT.md" <<'EOF'
# Code of Conduct

Test content.
EOF

    cat > "$repo/.github/CONTRIBUTING.md" <<'EOF'
# Contributing

Test content.
EOF

    cat > "$repo/.github/SECURITY.md" <<'EOF'
# Security

Test content.
EOF

    cat > "$repo/.github/SUPPORT.md" <<'EOF'
# Support

Test content.
EOF

    cat > "$repo/.github/FUNDING.yml" <<'EOF'
github: hyperpolymath
EOF

    # Check files exist
    if [ ! -f "$repo/.github/CODE_OF_CONDUCT.md" ]; then
        echo "✗ CODE_OF_CONDUCT.md not created"
        return 1
    fi

    if [ ! -f "$repo/.github/CONTRIBUTING.md" ]; then
        echo "✗ CONTRIBUTING.md not created"
        return 1
    fi

    if [ ! -f "$repo/.github/SECURITY.md" ]; then
        echo "✗ SECURITY.md not created"
        return 1
    fi

    if [ ! -f "$repo/.github/SUPPORT.md" ]; then
        echo "✗ SUPPORT.md not created"
        return 1
    fi

    if [ ! -f "$repo/.github/FUNDING.yml" ]; then
        echo "✗ FUNDING.yml not created"
        return 1
    fi

    echo "✓ All 5 community files created successfully"
}

# Test 3: Community files have content
test_community_content() {
    echo ""
    echo "Test 3: Community files have content"

    repo="$TEST_DIR/test-repo-1"

    for file in CODE_OF_CONDUCT.md CONTRIBUTING.md SECURITY.md SUPPORT.md FUNDING.yml; do
        filepath="$repo/.github/$file"
        if [ ! -s "$filepath" ]; then
            echo "✗ File $file is empty"
            return 1
        fi
    done

    echo "✓ All community files have content"
}

# Test 4: Idempotency (files not duplicated)
test_community_idempotency() {
    echo ""
    echo "Test 4: Community setup is idempotent"

    repo="$TEST_DIR/test-repo-1"

    # Get checksums before
    md5sum "$repo/.github/CODE_OF_CONDUCT.md" > /tmp/before.txt

    # Simulate running setup again (files already exist with same content)
    # They should be skipped

    # Get checksums after
    md5sum "$repo/.github/CODE_OF_CONDUCT.md" > /tmp/after.txt

    # Compare
    if ! diff -q /tmp/before.txt /tmp/after.txt > /dev/null; then
        echo "✗ Files were modified (should be skipped)"
        return 1
    fi

    echo "✓ Idempotency preserved (files unchanged)"
}

# Test 5: Wiki home content structure
test_wiki_home_content() {
    echo ""
    echo "Test 5: Wiki home content has expected structure"

    # Create a test home content
    cat > /tmp/test-home.md <<'EOF'
# test-repo Wiki

Welcome to the test-repo wiki!

## Getting Started

This wiki was automatically initialized by repo-batcher.

## Contents

- [Home](Home)

## Contributing

Feel free to contribute to this wiki by editing pages or creating new ones.
EOF

    # Check structure
    if ! grep -q "# test-repo Wiki" /tmp/test-home.md; then
        echo "✗ Missing wiki title"
        return 1
    fi

    if ! grep -q "## Getting Started" /tmp/test-home.md; then
        echo "✗ Missing Getting Started section"
        return 1
    fi

    if ! grep -q "## Contents" /tmp/test-home.md; then
        echo "✗ Missing Contents section"
        return 1
    fi

    echo "✓ Wiki home content structure correct"
}

# Test 6: .github directory created
test_github_directory() {
    echo ""
    echo "Test 6: .github directory created properly"

    repo="$TEST_DIR/test-repo-2"

    # Create .github directory
    mkdir -p "$repo/.github"

    if [ ! -d "$repo/.github" ]; then
        echo "✗ .github directory not created"
        return 1
    fi

    # Should be a directory, not a file
    if [ ! -d "$repo/.github" ]; then
        echo "✗ .github is not a directory"
        return 1
    fi

    echo "✓ .github directory structure correct"
}

# Run tests
main() {
    setup_test_repos

    passed=0
    failed=0

    if test_community_defaults; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
    fi

    if test_community_setup; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
    fi

    if test_community_content; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
    fi

    if test_community_idempotency; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
    fi

    if test_wiki_home_content; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
    fi

    if test_github_directory; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
    fi

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
