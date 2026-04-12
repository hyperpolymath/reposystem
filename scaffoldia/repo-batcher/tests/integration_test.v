// SPDX-License-Identifier: PMPL-1.0-or-later
//
// Integration Tests
// Tests repo-batcher operations on real test repositories

module main

import os
import ffi
import utils
import executor

const (
	test_dir = '/tmp/repo-batcher-tests'
	test_repos = ['test-repo-1', 'test-repo-2', 'test-repo-3']
)

fn main() {
	println('repo-batcher Integration Tests')
	println('================================')
	println('')

	// Setup test environment
	setup_test_repos() or {
		eprintln('Failed to setup test repos: ${err}')
		exit(1)
	}

	// Run tests
	mut passed := 0
	mut failed := 0

	if test_spdx_validation() {
		passed++
	} else {
		failed++
	}

	if test_repo_scanner() {
		passed++
	} else {
		failed++
	}

	if test_target_resolution() {
		passed++
	} else {
		failed++
	}

	if test_git_sync_dry_run() {
		passed++
	} else {
		failed++
	}

	if test_parallel_execution() {
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

// Sets up test repositories
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
		os.execute('cd ${repo_path} && git init')

		// Create test files
		test_file := os.join_path(repo_path, 'README.md')
		os.write_file(test_file, '# Test Repository\n\nThis is a test.\n') or {}

		// Create LICENSE file
		license_file := os.join_path(repo_path, 'LICENSE')
		os.write_file(license_file, 'MIT License\n\nCopyright (c) 2026\n') or {}

		// Initial commit
		os.execute('cd ${repo_path} && git add . && git commit -m "Initial commit"')
	}

	println('✓ Setup test repositories')
}

// Cleans up test repositories
fn cleanup_test_repos() {
	os.rmdir_all(test_dir) or {}
	println('✓ Cleaned up test repositories')
}

// Test SPDX validation
fn test_spdx_validation() bool {
	println('Testing SPDX validation...')

	// Valid identifiers
	valid := ['MIT', 'Apache-2.0', 'GPL-3.0-only', 'PMPL-1.0-or-later']
	for id in valid {
		if !ffi.validate_spdx(id) {
			println('  ✗ Failed: ${id} should be valid')
			return false
		}
	}

	// Invalid identifiers
	invalid := ['NotALicense', 'MIT-INVALID', '']
	for id in invalid {
		if ffi.validate_spdx(id) {
			println('  ✗ Failed: ${id} should be invalid')
			return false
		}
	}

	println('  ✓ SPDX validation works')
	return true
}

// Test repository scanner
fn test_repo_scanner() bool {
	println('Testing repository scanner...')

	repos := utils.find_git_repos(test_dir, 2)

	if repos.len != test_repos.len {
		println('  ✗ Failed: Expected ${test_repos.len} repos, found ${repos.len}')
		return false
	}

	for expected in test_repos {
		found := false
		for repo in repos {
			if repo.contains(expected) {
				found = true
				break
			}
		}
		if !found {
			println('  ✗ Failed: Missing repo ${expected}')
			return false
		}
	}

	println('  ✓ Repository scanner works')
	return true
}

// Test target resolution
fn test_target_resolution() bool {
	println('Testing target resolution...')

	// Test explicit list
	targets := '${os.join_path(test_dir, test_repos[0])},${os.join_path(test_dir, test_repos[1])}'
	repos := utils.resolve_targets(targets, test_dir, 2)

	if repos.len != 2 {
		println('  ✗ Failed: Expected 2 repos, got ${repos.len}')
		return false
	}

	// Test @all-repos pattern
	all_repos := utils.resolve_targets('@all-repos', test_dir, 2)
	if all_repos.len != test_repos.len {
		println('  ✗ Failed: @all-repos should find ${test_repos.len} repos, found ${all_repos.len}')
		return false
	}

	println('  ✓ Target resolution works')
	return true
}

// Test git-sync dry-run
fn test_git_sync_dry_run() bool {
	println('Testing git-sync (dry-run)...')

	repos := utils.find_git_repos(test_dir, 2)

	mut pool := executor.new_worker_pool(repos, 2)
	result := pool.execute_git_sync('test commit', true) // dry_run = true

	if result.failure_count > 0 {
		println('  ✗ Failed: Got ${result.failure_count} failures in dry-run')
		return false
	}

	println('  ✓ Git-sync dry-run works')
	return true
}

// Test parallel execution
fn test_parallel_execution() bool {
	println('Testing parallel execution...')

	repos := utils.find_git_repos(test_dir, 2)

	// Test with 2 workers
	mut pool := executor.new_worker_pool(repos, 2)
	result := pool.execute_git_sync('parallel test', true)

	// Should process all repos
	total := result.success_count + result.failure_count + result.skipped_count
	if total != repos.len {
		println('  ✗ Failed: Processed ${total} repos, expected ${repos.len}')
		return false
	}

	println('  ✓ Parallel execution works')
	return true
}
