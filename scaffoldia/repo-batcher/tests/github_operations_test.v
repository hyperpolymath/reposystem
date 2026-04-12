// SPDX-License-Identifier: PMPL-1.0-or-later
//
// GitHub Operations Tests
// Tests wiki-setup and community-setup operations

module main

import os
import github

const (
	test_dir = '/tmp/repo-batcher-github-tests'
	test_repos = ['test-repo-1', 'test-repo-2', 'test-repo-3']
)

fn main() {
	println('repo-batcher GitHub Operations Tests')
	println('=====================================')
	println('')

	// Setup test environment
	setup_test_repos() or {
		eprintln('Failed to setup test repos: ${err}')
		exit(1)
	}

	// Run tests
	mut passed := 0
	mut failed := 0

	if test_default_home_content() {
		passed++
	} else {
		failed++
	}

	if test_default_community_files() {
		passed++
	} else {
		failed++
	}

	if test_community_setup_local() {
		passed++
	} else {
		failed++
	}

	if test_community_setup_idempotency() {
		passed++
	} else {
		failed++
	}

	if test_wiki_dry_run() {
		passed++
	} else {
		failed++
	}

	if test_community_dry_run() {
		passed++
	} else {
		failed++
	}

	// Cleanup
	cleanup_test_repos()

	// Summary
	println('')
	println('Test Summary')
	println('============')
	println('Passed: ${passed}')
	println('Failed: ${failed}')
	println('Total:  ${passed + failed}')

	if failed > 0 {
		exit(1)
	}
}

// Setup test repositories
fn setup_test_repos() ! {
	// Create test directory
	os.mkdir_all(test_dir) or {
		return error('Failed to create test dir: ${err}')
	}

	// Create test repos
	for repo in test_repos {
		repo_path := os.join_path(test_dir, repo)
		os.mkdir_all(repo_path) or {
			return error('Failed to create repo: ${err}')
		}

		// Initialize git repo
		os.execute('cd "${repo_path}" && git init')

		// Create test files
		readme := os.join_path(repo_path, 'README.md')
		os.write_file(readme, '# ${repo}\n\nTest repository.\n') or {}
	}

	println('✓ Test repositories created')
}

// Cleanup test repositories
fn cleanup_test_repos() {
	os.rmdir_all(test_dir) or {}
	println('✓ Cleaned up test repositories')
}

// Test 1: Default home content generation
fn test_default_home_content() bool {
	println('Test 1: Default home content generation')

	content := github.default_home_content('test-repo')

	// Check content has expected structure
	checks := [
		content.contains('# test-repo Wiki'),
		content.contains('Welcome to the test-repo wiki'),
		content.contains('## Getting Started'),
		content.contains('## Contents'),
		content.contains('## Contributing'),
		content.len > 100,
	]

	mut passed := true
	for check in checks {
		if !check {
			passed = false
			break
		}
	}

	if passed {
		println('  ✓ Default home content looks correct')
	} else {
		eprintln('  ✗ Default home content missing expected elements')
	}

	return passed
}

// Test 2: Default community files generation
fn test_default_community_files() bool {
	println('Test 2: Default community files generation')

	files := github.standard_community_files()

	// Should have 5 files
	if files.len != 5 {
		eprintln('  ✗ Expected 5 files, got ${files.len}')
		return false
	}

	// Check all expected files are present
	mut found := map[string]bool{}
	for file in files {
		if file.path.contains('CODE_OF_CONDUCT') {
			found['conduct'] = true
		}
		if file.path.contains('CONTRIBUTING') {
			found['contributing'] = true
		}
		if file.path.contains('SECURITY') {
			found['security'] = true
		}
		if file.path.contains('SUPPORT') {
			found['support'] = true
		}
		if file.path.contains('FUNDING') {
			found['funding'] = true
		}
	}

	if found.len != 5 {
		eprintln('  ✗ Not all expected files present')
		return false
	}

	// Check content is not empty
	for file in files {
		if file.content.len == 0 {
			eprintln('  ✗ File ${file.name} has empty content')
			return false
		}
	}

	println('  ✓ All 5 community files generated correctly')
	return true
}

// Test 3: Community setup on local repository
fn test_community_setup_local() bool {
	println('Test 3: Community setup on local repository')

	repo_path := os.join_path(test_dir, test_repos[0])
	files := github.standard_community_files()

	result := github.setup_community_files(github.CommunitySetupParams{
		repo_path: repo_path
		files: files
		create_pr: false
		dry_run: false
	}) or {
		eprintln('  ✗ Setup failed: ${err}')
		return false
	}

	if !result.success {
		eprintln('  ✗ Setup reported failure: ${result.message}')
		return false
	}

	if result.files_created != 5 {
		eprintln('  ✗ Expected 5 files created, got ${result.files_created}')
		return false
	}

	// Verify files actually exist
	github_dir := os.join_path(repo_path, '.github')
	if !os.exists(github_dir) {
		eprintln('  ✗ .github directory not created')
		return false
	}

	expected_files := [
		'CODE_OF_CONDUCT.md',
		'CONTRIBUTING.md',
		'SECURITY.md',
		'SUPPORT.md',
		'FUNDING.yml',
	]

	for file in expected_files {
		file_path := os.join_path(github_dir, file)
		if !os.exists(file_path) {
			eprintln('  ✗ File not created: ${file}')
			return false
		}
	}

	println('  ✓ Community files deployed successfully')
	return true
}

// Test 4: Community setup idempotency
fn test_community_setup_idempotency() bool {
	println('Test 4: Community setup idempotency (skip unchanged files)')

	repo_path := os.join_path(test_dir, test_repos[0])
	files := github.standard_community_files()

	// Run setup again on same repo
	result := github.setup_community_files(github.CommunitySetupParams{
		repo_path: repo_path
		files: files
		create_pr: false
		dry_run: false
	}) or {
		eprintln('  ✗ Second setup failed: ${err}')
		return false
	}

	if !result.success {
		eprintln('  ✗ Second setup reported failure')
		return false
	}

	// Should have skipped all files (they already exist with same content)
	if result.files_skipped != 5 {
		eprintln('  ✗ Expected 5 files skipped, got ${result.files_skipped}')
		return false
	}

	if result.files_created != 0 {
		eprintln('  ✗ Expected 0 files created, got ${result.files_created}')
		return false
	}

	println('  ✓ Idempotency working (skipped unchanged files)')
	return true
}

// Test 5: Wiki setup dry-run
fn test_wiki_dry_run() bool {
	println('Test 5: Wiki setup dry-run mode')

	result := github.setup_wiki(github.WikiSetupParams{
		repo_owner: 'test-owner'
		repo_name: 'test-repo'
		home_content: 'Test content'
		dry_run: true
	}) or {
		eprintln('  ✗ Dry-run failed: ${err}')
		return false
	}

	if !result.success {
		eprintln('  ✗ Dry-run reported failure')
		return false
	}

	if !result.message.contains('[DRY RUN]') {
		eprintln('  ✗ Message does not indicate dry-run')
		return false
	}

	println('  ✓ Dry-run mode working correctly')
	return true
}

// Test 6: Community setup dry-run
fn test_community_dry_run() bool {
	println('Test 6: Community setup dry-run mode')

	repo_path := os.join_path(test_dir, test_repos[1])
	files := github.standard_community_files()

	result := github.setup_community_files(github.CommunitySetupParams{
		repo_path: repo_path
		files: files
		create_pr: false
		dry_run: true
	}) or {
		eprintln('  ✗ Dry-run failed: ${err}')
		return false
	}

	if !result.success {
		eprintln('  ✗ Dry-run reported failure')
		return false
	}

	if !result.message.contains('[DRY RUN]') {
		eprintln('  ✗ Message does not indicate dry-run')
		return false
	}

	// Verify no files were actually created
	github_dir := os.join_path(repo_path, '.github')
	if os.exists(github_dir) {
		eprintln('  ✗ Dry-run created files (should not)')
		return false
	}

	println('  ✓ Dry-run mode prevents file creation')
	return true
}
