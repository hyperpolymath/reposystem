// SPDX-License-Identifier: PMPL-1.0-or-later
//
// Safety Validation
// Pre-flight validation for operations

module safety

import os

// ValidationRule represents a safety validation rule
pub struct ValidationRule {
pub:
	name        string
	description string
	check_fn    fn (ValidationContext) !bool
	severity    RuleSeverity
}

pub enum RuleSeverity {
	info     // Informational only
	warning  // Warning but can proceed
	error    // Blocks operation
	critical // Critical blocker
}

// ValidationContext provides context for validation
pub struct ValidationContext {
pub:
	repo_paths     []string
	operation_type string
	dry_run        bool
}

// ValidationResult contains validation outcome
pub struct ValidationResult {
pub:
	passed   bool
	errors   []string
	warnings []string
	info     []string
}

// Common validation rules
pub fn get_common_validation_rules() []ValidationRule {
	return [
		ValidationRule{
			name: 'git_repository_check'
			description: 'Verify all paths are git repositories'
			check_fn: validate_git_repositories
			severity: .error
		},
		ValidationRule{
			name: 'write_permission_check'
			description: 'Verify write permissions'
			check_fn: validate_write_permissions
			severity: .error
		},
		ValidationRule{
			name: 'uncommitted_changes_check'
			description: 'Check for uncommitted changes'
			check_fn: validate_no_uncommitted_changes
			severity: .warning
		},
		ValidationRule{
			name: 'remote_exists_check'
			description: 'Verify remote exists for push operations'
			check_fn: validate_remote_exists
			severity: .warning
		},
		ValidationRule{
			name: 'disk_space_check'
			description: 'Verify sufficient disk space'
			check_fn: validate_disk_space
			severity: .warning
		},
	]
}

// Validate that all paths are git repositories
fn validate_git_repositories(ctx ValidationContext) !bool {
	for repo_path in ctx.repo_paths {
		git_dir := os.join_path(repo_path, '.git')
		if !os.exists(git_dir) {
			return error('Not a git repository: ${repo_path}')
		}
	}
	return true
}

// Validate write permissions
fn validate_write_permissions(ctx ValidationContext) !bool {
	if ctx.dry_run {
		return true // Skip for dry-run
	}

	for repo_path in ctx.repo_paths {
		// Try to create a temp file to test write permission
		test_file := os.join_path(repo_path, '.repo-batcher-test')

		os.write_file(test_file, 'test') or {
			return error('No write permission: ${repo_path}')
		}

		os.rm(test_file) or {}
	}

	return true
}

// Check for uncommitted changes
fn validate_no_uncommitted_changes(ctx ValidationContext) !bool {
	if ctx.dry_run {
		return true
	}

	mut repos_with_changes := []string{}

	for repo_path in ctx.repo_paths {
		result := os.execute('cd "${repo_path}" && git status --porcelain')
		if result.exit_code == 0 && result.output.trim() != '' {
			repos_with_changes << repo_path
		}
	}

	if repos_with_changes.len > 0 {
		return error('Uncommitted changes in ${repos_with_changes.len} repositories')
	}

	return true
}

// Validate remote exists for push operations
fn validate_remote_exists(ctx ValidationContext) !bool {
	if !ctx.operation_type.contains('sync') && !ctx.operation_type.contains('push') {
		return true // Only relevant for push operations
	}

	mut repos_without_remote := []string{}

	for repo_path in ctx.repo_paths {
		result := os.execute('cd "${repo_path}" && git remote -v')
		if result.exit_code != 0 || result.output.trim() == '' {
			repos_without_remote << repo_path
		}
	}

	if repos_without_remote.len > 0 {
		return error('No remote configured in ${repos_without_remote.len} repositories')
	}

	return true
}

// Validate sufficient disk space
fn validate_disk_space(ctx ValidationContext) !bool {
	if ctx.dry_run {
		return true
	}

	// Get disk usage for home directory
	result := os.execute('df -h ~ | tail -1 | awk \'{print $5}\' | sed \'s/%//\'')

	if result.exit_code == 0 {
		usage := result.output.trim().int()
		if usage > 90 {
			return error('Disk usage at ${usage}% (>90%)')
		}
	}

	return true
}

// Run all validation rules
pub fn run_validation(ctx ValidationContext, rules []ValidationRule) ValidationResult {
	mut errors := []string{}
	mut warnings := []string{}
	mut info := []string{}

	for rule in rules {
		rule.check_fn(ctx) or {
			match rule.severity {
				.critical, .error {
					errors << '[${rule.name}] ${err}'
				}
				.warning {
					warnings << '[${rule.name}] ${err}'
				}
				.info {
					info << '[${rule.name}] ${err}'
				}
			}
			continue
		}
	}

	return ValidationResult{
		passed: errors.len == 0
		errors: errors
		warnings: warnings
		info: info
	}
}

// Print validation result
pub fn print_validation_result(result ValidationResult) {
	if result.errors.len > 0 {
		println('')
		println('❌ VALIDATION ERRORS (operation blocked):')
		for err in result.errors {
			println('  ${err}')
		}
	}

	if result.warnings.len > 0 {
		println('')
		println('⚠️  VALIDATION WARNINGS:')
		for warning in result.warnings {
			println('  ${warning}')
		}
	}

	if result.info.len > 0 {
		println('')
		println('ℹ️  VALIDATION INFO:')
		for info_msg in result.info {
			println('  ${info_msg}')
		}
	}

	if result.passed {
		println('')
		println('✓ Pre-flight validation passed')
	}
}
