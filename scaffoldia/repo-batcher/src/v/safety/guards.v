// SPDX-License-Identifier: PMPL-1.0-or-later
//
// Safety Guards
// Comprehensive safety features for bulk repository operations

module safety

import os
import time

// SafetyLevel defines how strict safety checks are
pub enum SafetyLevel {
	paranoid  // Maximum safety, confirm everything
	strict    // Standard safety checks
	relaxed   // Minimal safety checks
	disabled  // No safety checks (dangerous!)
}

// OperationType categorizes risk level
pub enum OperationType {
	read_only       // No changes (audit, list)
	local_changes   // Local file changes only
	remote_changes  // Pushes to remote
	destructive     // Delete, force-push, etc.
}

// SafetyConfig holds safety configuration
pub struct SafetyConfig {
pub mut:
	level              SafetyLevel
	require_dry_run    bool    // Force dry-run first
	max_repos          int     // Maximum repos per operation
	confirm_threshold  int     // Require confirmation if > N repos
	rate_limit_ms      int     // Milliseconds between operations
	backup_before      bool    // Create backup before changes
	audit_log          bool    // Log all operations
	exclusion_list     []string // Never touch these repos
}

// OperationRequest represents a pending operation
pub struct OperationRequest {
pub:
	operation_type OperationType
	target_repos   []string
	description    string
	dry_run        bool
	force          bool
}

// SafetyCheck result
pub struct SafetyCheckResult {
pub:
	approved        bool
	warnings        []string
	blockers        []string
	requires_confirm bool
	message         string
}

// Default safety configuration
pub fn default_safety_config() SafetyConfig {
	return SafetyConfig{
		level: .strict
		require_dry_run: true
		max_repos: 100
		confirm_threshold: 10
		rate_limit_ms: 100
		backup_before: true
		audit_log: true
		exclusion_list: [
			'.git',
			'node_modules',
			'vendor',
			'.env',
			'.secrets',
		]
	}
}

// Paranoid safety configuration
pub fn paranoid_safety_config() SafetyConfig {
	return SafetyConfig{
		level: .paranoid
		require_dry_run: true
		max_repos: 50
		confirm_threshold: 5
		rate_limit_ms: 500
		backup_before: true
		audit_log: true
		exclusion_list: [
			'.git',
			'node_modules',
			'vendor',
			'.env',
			'.secrets',
			'*.pem',
			'*.key',
		]
	}
}

// Check if operation is safe to proceed
pub fn check_operation_safety(request OperationRequest, config SafetyConfig) !SafetyCheckResult {
	mut warnings := []string{}
	mut blockers := []string{}
	mut requires_confirm := false

	// Check 1: Dry-run requirement
	if config.require_dry_run && !request.dry_run {
		if request.operation_type == .destructive {
			blockers << 'Destructive operations require dry-run first'
		} else if request.operation_type == .remote_changes {
			warnings << 'Remote changes without dry-run - proceed with caution'
			requires_confirm = true
		}
	}

	// Check 2: Repository count limits
	repo_count := request.target_repos.len
	if repo_count > config.max_repos {
		blockers << 'Operation targets ${repo_count} repos (max: ${config.max_repos})'
	}

	if repo_count > config.confirm_threshold {
		warnings << 'Operation targets ${repo_count} repositories'
		requires_confirm = true
	}

	// Check 3: Destructive operation check
	if request.operation_type == .destructive && !request.force {
		blockers << 'Destructive operations require --force flag'
	}

	// Check 4: Exclusion list
	mut excluded_repos := []string{}
	for repo in request.target_repos {
		for exclusion in config.exclusion_list {
			if repo.contains(exclusion) {
				excluded_repos << repo
			}
		}
	}

	if excluded_repos.len > 0 {
		blockers << 'Some repos match exclusion list: ${excluded_repos}'
	}

	// Check 5: Safety level specific checks
	match config.level {
		.paranoid {
			if repo_count > 5 {
				requires_confirm = true
				warnings << 'Paranoid mode: Confirm batch operation'
			}
		}
		.strict {
			if request.operation_type != .read_only && !request.dry_run {
				requires_confirm = true
			}
		}
		.relaxed {
			// Minimal checks
		}
		.disabled {
			// No checks
		}
	}

	// Determine approval
	approved := blockers.len == 0 && (config.level == .disabled || !requires_confirm || request.force)

	// Generate message
	mut message := ''
	if blockers.len > 0 {
		message = 'Operation BLOCKED: ${blockers.join(', ')}'
	} else if warnings.len > 0 {
		message = 'Warnings: ${warnings.join(', ')}'
	} else {
		message = 'Operation safety checks passed'
	}

	return SafetyCheckResult{
		approved: approved
		warnings: warnings
		blockers: blockers
		requires_confirm: requires_confirm
		message: message
	}
}

// Prompt user for confirmation
pub fn prompt_confirmation(request OperationRequest, warnings []string) !bool {
	println('')
	println('=== OPERATION CONFIRMATION REQUIRED ===')
	println('Operation: ${request.description}')
	println('Type: ${request.operation_type}')
	println('Target repos: ${request.target_repos.len}')
	println('Dry run: ${request.dry_run}')
	println('')

	if warnings.len > 0 {
		println('⚠️  WARNINGS:')
		for warning in warnings {
			println('  - ${warning}')
		}
		println('')
	}

	if request.target_repos.len <= 10 {
		println('Repositories:')
		for repo in request.target_repos {
			println('  - ${repo}')
		}
	} else {
		println('First 5 repositories:')
		for i := 0; i < 5 && i < request.target_repos.len; i++ {
			println('  - ${request.target_repos[i]}')
		}
		println('  ... and ${request.target_repos.len - 5} more')
	}

	println('')
	print('Proceed with this operation? [y/N]: ')

	// Read user input
	input := os.input('').trim().to_lower()

	return input == 'y' || input == 'yes'
}

// Rate limiter to avoid hammering APIs
pub struct RateLimiter {
mut:
	last_operation_time i64
	delay_ms           int
}

pub fn new_rate_limiter(delay_ms int) RateLimiter {
	return RateLimiter{
		last_operation_time: 0
		delay_ms: delay_ms
	}
}

pub fn (mut limiter RateLimiter) wait() {
	if limiter.last_operation_time > 0 {
		now := time.now().unix_milli()
		elapsed := now - limiter.last_operation_time

		if elapsed < limiter.delay_ms {
			sleep_time := limiter.delay_ms - int(elapsed)
			time.sleep(sleep_time * time.millisecond)
		}
	}

	limiter.last_operation_time = time.now().unix_milli()
}

// Audit logger
pub struct AuditLog {
mut:
	log_file string
}

pub fn new_audit_log(log_file string) !AuditLog {
	// Ensure parent directory exists
	log_dir := os.dir(log_file)
	os.mkdir_all(log_dir) or {
		return error('Failed to create audit log directory: ${err}')
	}

	return AuditLog{
		log_file: log_file
	}
}

pub fn (mut log AuditLog) record(request OperationRequest, result string) ! {
	timestamp := time.now().format_ss()

	entry := '${timestamp} | ${request.operation_type} | ${request.target_repos.len} repos | ${request.description} | ${result}\n'

	mut f := os.open_append(log.log_file) or {
		return error('Failed to open audit log: ${err}')
	}
	defer { f.close() }

	f.write_string(entry) or {
		return error('Failed to write to audit log: ${err}')
	}
}

// Check if repo should be excluded
pub fn is_repo_excluded(repo_path string, exclusions []string) bool {
	for exclusion in exclusions {
		if repo_path.contains(exclusion) {
			return true
		}
	}
	return false
}

// Validate repository count
pub fn validate_repo_count(count int, max int) !bool {
	if count == 0 {
		return error('No repositories specified')
	}

	if count > max {
		return error('Repository count (${count}) exceeds maximum (${max})')
	}

	return true
}

// Generate operation summary for review
pub fn generate_operation_summary(request OperationRequest) string {
	mut summary := '=== Operation Summary ===\n'
	summary += 'Description: ${request.description}\n'
	summary += 'Type: ${request.operation_type}\n'
	summary += 'Repositories: ${request.target_repos.len}\n'
	summary += 'Dry run: ${request.dry_run}\n'

	if request.target_repos.len <= 20 {
		summary += '\nRepositories:\n'
		for repo in request.target_repos {
			summary += '  - ${repo}\n'
		}
	} else {
		summary += '\nFirst 10 repositories:\n'
		for i := 0; i < 10; i++ {
			summary += '  - ${request.target_repos[i]}\n'
		}
		summary += '  ... and ${request.target_repos.len - 10} more\n'
	}

	return summary
}
