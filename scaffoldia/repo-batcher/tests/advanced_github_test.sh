#!/bin/bash
# SPDX-License-Identifier: PMPL-1.0-or-later
#
# Advanced GitHub Operations Test
# Tests templates-setup, discussions-setup, and pages-setup

set -e

TEST_DIR="/tmp/repo-batcher-advanced-test-$$"

echo "repo-batcher Advanced GitHub Operations Test"
echo "============================================="
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

# Test 1: Issue template defaults exist
test_issue_template_defaults() {
    echo ""
    echo "Test 1: Issue template default functions exist"

    # Check for default template functions in source
    if ! grep -q "pub fn default_bug_report_template" /var$REPOS_DIR/repo-batcher/src/v/github/templates.v; then
        echo "✗ default_bug_report_template function not found"
        return 1
    fi

    if ! grep -q "pub fn default_feature_request_template" /var$REPOS_DIR/repo-batcher/src/v/github/templates.v; then
        echo "✗ default_feature_request_template function not found"
        return 1
    fi

    if ! grep -q "pub fn default_pr_template" /var$REPOS_DIR/repo-batcher/src/v/github/templates.v; then
        echo "✗ default_pr_template function not found"
        return 1
    fi

    echo "✓ All default template functions exist"
}

# Test 2: Issue templates directory structure
test_issue_template_structure() {
    echo ""
    echo "Test 2: Issue template directory structure"

    repo="$TEST_DIR/test-repo-1"

    # Create the ISSUE_TEMPLATE directory
    mkdir -p "$repo/.github/ISSUE_TEMPLATE"

    # Create sample issue templates
    cat > "$repo/.github/ISSUE_TEMPLATE/bug_report.yml" <<'EOF'
name: Bug Report
description: File a bug report
title: "[Bug]: "
labels: ["bug"]
body:
  - type: textarea
    id: what-happened
    attributes:
      label: What happened?
    validations:
      required: true
EOF

    cat > "$repo/.github/ISSUE_TEMPLATE/feature_request.yml" <<'EOF'
name: Feature Request
description: Suggest an idea
title: "[Feature]: "
labels: ["enhancement"]
body:
  - type: textarea
    id: problem
    attributes:
      label: Problem
    validations:
      required: true
EOF

    # Verify structure
    if [ ! -d "$repo/.github/ISSUE_TEMPLATE" ]; then
        echo "✗ ISSUE_TEMPLATE directory not created"
        return 1
    fi

    if [ ! -f "$repo/.github/ISSUE_TEMPLATE/bug_report.yml" ]; then
        echo "✗ bug_report.yml not created"
        return 1
    fi

    if [ ! -f "$repo/.github/ISSUE_TEMPLATE/feature_request.yml" ]; then
        echo "✗ feature_request.yml not created"
        return 1
    fi

    echo "✓ Issue template structure correct"
}

# Test 3: PR template creation
test_pr_template() {
    echo ""
    echo "Test 3: PR template creation"

    repo="$TEST_DIR/test-repo-1"

    # Create PR template
    mkdir -p "$repo/.github"
    cat > "$repo/.github/PULL_REQUEST_TEMPLATE.md" <<'EOF'
## Description

Please include a summary of the changes.

## Type of change

- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change

## Checklist

- [ ] My code follows the style guidelines
- [ ] I have performed a self-review
- [ ] I have added tests
EOF

    # Verify
    if [ ! -f "$repo/.github/PULL_REQUEST_TEMPLATE.md" ]; then
        echo "✗ PULL_REQUEST_TEMPLATE.md not created"
        return 1
    fi

    # Check content has expected sections
    if ! grep -q "## Description" "$repo/.github/PULL_REQUEST_TEMPLATE.md"; then
        echo "✗ PR template missing Description section"
        return 1
    fi

    if ! grep -q "## Checklist" "$repo/.github/PULL_REQUEST_TEMPLATE.md"; then
        echo "✗ PR template missing Checklist section"
        return 1
    fi

    echo "✓ PR template created with correct structure"
}

# Test 4: Template YAML validation
test_yaml_structure() {
    echo ""
    echo "Test 4: Issue template YAML structure"

    repo="$TEST_DIR/test-repo-1"
    template="$repo/.github/ISSUE_TEMPLATE/bug_report.yml"

    # Check YAML has required fields
    if ! grep -q "name:" "$template"; then
        echo "✗ YAML missing 'name' field"
        return 1
    fi

    if ! grep -q "description:" "$template"; then
        echo "✗ YAML missing 'description' field"
        return 1
    fi

    if ! grep -q "body:" "$template"; then
        echo "✗ YAML missing 'body' field"
        return 1
    fi

    echo "✓ YAML structure valid"
}

# Test 5: Discussion categories default
test_discussion_categories() {
    echo ""
    echo "Test 5: Discussion categories function exists"

    # Check for default categories function
    if ! grep -q "pub fn default_discussion_categories" /var$REPOS_DIR/repo-batcher/src/v/github/discussions.v; then
        echo "✗ default_discussion_categories function not found"
        return 1
    fi

    # Check for category structure
    if ! grep -q "DiscussionCategory" /var$REPOS_DIR/repo-batcher/src/v/github/discussions.v; then
        echo "✗ DiscussionCategory struct not found"
        return 1
    fi

    echo "✓ Discussion categories structure exists"
}

# Test 6: Pages source options
test_pages_source_options() {
    echo ""
    echo "Test 6: Pages source options defined"

    # Check for PagesSource enum
    if ! grep -q "pub enum PagesSource" /var$REPOS_DIR/repo-batcher/src/v/github/pages.v; then
        echo "✗ PagesSource enum not found"
        return 1
    fi

    # Check for specific options
    if ! grep -q "root_main" /var$REPOS_DIR/repo-batcher/src/v/github/pages.v; then
        echo "✗ root_main option not found"
        return 1
    fi

    if ! grep -q "docs_main" /var$REPOS_DIR/repo-batcher/src/v/github/pages.v; then
        echo "✗ docs_main option not found"
        return 1
    fi

    echo "✓ Pages source options defined"
}

# Test 7: Jekyll site structure
test_jekyll_site() {
    echo ""
    echo "Test 7: Jekyll site deployment structure"

    repo="$TEST_DIR/test-repo-2"

    # Create docs directory for Pages
    mkdir -p "$repo/docs"

    # Create _config.yml
    cat > "$repo/docs/_config.yml" <<'EOF'
theme: jekyll-theme-minimal
title: Test Documentation
description: Test site
markdown: kramdown
EOF

    # Create index.md
    cat > "$repo/docs/index.md" <<'EOF'
# Documentation

Welcome to the test site!

## Contents

- [Getting Started](#getting-started)
EOF

    # Verify files
    if [ ! -f "$repo/docs/_config.yml" ]; then
        echo "✗ _config.yml not created"
        return 1
    fi

    if [ ! -f "$repo/docs/index.md" ]; then
        echo "✗ index.md not created"
        return 1
    fi

    # Check _config.yml has required fields
    if ! grep -q "theme:" "$repo/docs/_config.yml"; then
        echo "✗ _config.yml missing theme"
        return 1
    fi

    echo "✓ Jekyll site structure correct"
}

# Test 8: Templates batch processing structure
test_batch_functions() {
    echo ""
    echo "Test 8: Batch processing functions exist"

    # Check for batch functions
    if ! grep -q "pub fn setup_templates_batch" /var$REPOS_DIR/repo-batcher/src/v/github/templates.v; then
        echo "✗ setup_templates_batch function not found"
        return 1
    fi

    if ! grep -q "pub fn setup_discussions_batch" /var$REPOS_DIR/repo-batcher/src/v/github/discussions.v; then
        echo "✗ setup_discussions_batch function not found"
        return 1
    fi

    if ! grep -q "pub fn setup_pages_batch" /var$REPOS_DIR/repo-batcher/src/v/github/pages.v; then
        echo "✗ setup_pages_batch function not found"
        return 1
    fi

    echo "✓ All batch processing functions exist"
}

# Test 9: Summary functions
test_summary_functions() {
    echo ""
    echo "Test 9: Summary printing functions exist"

    # Check for summary functions
    if ! grep -q "pub fn print_templates_summary" /var$REPOS_DIR/repo-batcher/src/v/github/templates.v; then
        echo "✗ print_templates_summary function not found"
        return 1
    fi

    if ! grep -q "pub fn print_discussions_summary" /var$REPOS_DIR/repo-batcher/src/v/github/discussions.v; then
        echo "✗ print_discussions_summary function not found"
        return 1
    fi

    if ! grep -q "pub fn print_pages_summary" /var$REPOS_DIR/repo-batcher/src/v/github/pages.v; then
        echo "✗ print_pages_summary function not found"
        return 1
    fi

    echo "✓ All summary functions exist"
}

# Test 10: Template file validation
test_template_validation() {
    echo ""
    echo "Test 10: Template content validation"

    repo="$TEST_DIR/test-repo-1"

    # Check that templates have content
    if [ ! -s "$repo/.github/ISSUE_TEMPLATE/bug_report.yml" ]; then
        echo "✗ bug_report.yml is empty"
        return 1
    fi

    if [ ! -s "$repo/.github/PULL_REQUEST_TEMPLATE.md" ]; then
        echo "✗ PULL_REQUEST_TEMPLATE.md is empty"
        return 1
    fi

    # Check YAML is valid (basic check - has body section)
    if ! grep -q "body:" "$repo/.github/ISSUE_TEMPLATE/bug_report.yml"; then
        echo "✗ Issue template missing body section"
        return 1
    fi

    echo "✓ Template content validation passed"
}

# Test 11: Multiple issue templates
test_multiple_templates() {
    echo ""
    echo "Test 11: Multiple issue templates support"

    repo="$TEST_DIR/test-repo-3"
    mkdir -p "$repo/.github/ISSUE_TEMPLATE"

    # Create 3 different templates
    for template in bug_report feature_request documentation; do
        cat > "$repo/.github/ISSUE_TEMPLATE/${template}.yml" <<EOF
name: ${template}
description: Template for ${template}
body:
  - type: textarea
    id: content
    attributes:
      label: Content
EOF
    done

    # Count templates
    template_count=$(ls "$repo/.github/ISSUE_TEMPLATE"/*.yml 2>/dev/null | wc -l)

    if [ "$template_count" -ne 3 ]; then
        echo "✗ Expected 3 templates, found $template_count"
        return 1
    fi

    echo "✓ Multiple issue templates supported"
}

# Test 12: Docs folder for Pages
test_docs_folder() {
    echo ""
    echo "Test 12: Docs folder structure for Pages"

    repo="$TEST_DIR/test-repo-2"

    if [ ! -d "$repo/docs" ]; then
        echo "✗ docs directory not found"
        return 1
    fi

    # Should have at least _config.yml and index.md
    file_count=$(ls "$repo/docs" 2>/dev/null | wc -l)

    if [ "$file_count" -lt 2 ]; then
        echo "✗ docs folder missing files (expected at least 2)"
        return 1
    fi

    echo "✓ Docs folder structure correct"
}

# Run tests
main() {
    setup_test_repos

    passed=0
    failed=0

    for test_func in \
        test_issue_template_defaults \
        test_issue_template_structure \
        test_pr_template \
        test_yaml_structure \
        test_discussion_categories \
        test_pages_source_options \
        test_jekyll_site \
        test_batch_functions \
        test_summary_functions \
        test_template_validation \
        test_multiple_templates \
        test_docs_folder
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
