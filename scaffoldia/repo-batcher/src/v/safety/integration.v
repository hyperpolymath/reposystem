// SPDX-License-Identifier: PMPL-1.0-or-later
//
// Safety Integration
// Bridge between CLI operations and safety system

module safety

import os
import toml

// SafetyContext holds safety state for an operation
pub struct SafetyContext {
pub mut:
	config       SafetyConfig
	rate_limiter RateLimiter
	audit_log    AuditLog
	enabled      bool
}

// Load safety config from .safety.toml or use defaults
pub fn load_safety_config() !SafetyConfig {
	config_path := '.safety.toml'

	if !os.exists(config_path) {
		println('⚠️  No .safety.toml found, using default strict safety')
		return default_safety_config()
	}

	doc := toml.parse_file(config_path) or {
		println('⚠️  Failed to parse .safety.toml: ${err}')
		println('⚠️  Using default strict safety')
		return default_safety_config()
	}

	// Parse [safety] section
	safety_table := doc.value('safety')

	mut config := default_safety_config()

	// Parse safety level
	if level_str := safety_table.value('level').string() {
		config.level = match level_str {
			'paranoid' { SafetyLevel.paranoid }
			'strict' { SafetyLevel.strict }
			'relaxed' { SafetyLevel.relaxed }
			'disabled' { SafetyLevel.disabled }
			else { SafetyLevel.strict }
		}
	}

	// Parse other settings
	if require_dry_run := safety_table.value('require_dry_run').bool() {
		config.require_dry_run = require_dry_run
	}

	if max_repos := safety_table.value('max_repos').i64() {
		config.max_repos = int(max_repos)
	}

	if confirm_threshold := safety_table.value('confirm_threshold').i64() {
		config.confirm_threshold = int(confirm_threshold)
	}

	if rate_limit_ms := safety_table.value('rate_limit_ms').i64() {
		config.rate_limit_ms = int(rate_limit_ms)
	}

	if backup_before := safety_table.value('backup_before').bool() {
		config.backup_before = backup_before
	}

	if audit_log := safety_table.value('audit_log').bool() {
		config.audit_log = audit_log
	}

	// Parse exclusions
	if exclusions_table := doc.value('exclusions') {
		if patterns := exclusions_table.value('patterns').array() {
			config.exclusion_list = []
			for pattern in patterns {
				if pattern_str := pattern.string() {
					config.exclusion_list << pattern_str
				}
			}
		}

		if repositories := exclusions_table.value('repositories').array() {
			for repo in repositories {
				if repo_str := repo.string() {
					config.exclusion_list << repo_str
				}
			}
		}
	}

	return config
}

// Create safety context for an operation
pub fn new_safety_context() !SafetyContext {
	config := load_safety_config()!

	// Expand ~ in audit log path
	mut audit_log_file := config.audit_log ? os.expand_tilde_to_home('~/.local/share/repo-batcher/audit.log') : ''

	mut audit_log := if config.audit_log {
		new_audit_log(audit_log_file) or {
			println('⚠️  Failed to create audit log: ${err}')
			AuditLog{ log_file: '' }
		}
	} else {
		AuditLog{ log_file: '' }
	}

	rate_limiter := new_rate_limiter(config.rate_limit_ms)

	return SafetyContext{
		config: config
		rate_limiter: rate_limiter
		audit_log: audit_log
		enabled: config.level != .disabled
	}
}

// Check if operation is safe to proceed
pub fn (ctx &SafetyContext) check_operation(
	operation_type OperationType,
	target_repos []string,
	description string,
	dry_run bool,
	force bool
) !SafetyCheckResult {
	if !ctx.enabled {
		return SafetyCheckResult{
			approved: true
			warnings: []
			blockers: []
			requires_confirm: false
			message: 'Safety disabled'
		}
	}

	request := OperationRequest{
		operation_type: operation_type
		target_repos: target_repos
		description: description
		dry_run: dry_run
		force: force
	}

	return check_operation_safety(request, ctx.config)
}

// Run validation rules
pub fn (ctx &SafetyContext) validate(
	repo_paths []string,
	operation_type string,
	dry_run bool
) !ValidationResult {
	if !ctx.enabled {
		return ValidationResult{
			passed: true
			errors: []
			warnings: []
			info: []
		}
	}

	validation_ctx := ValidationContext{
		repo_paths: repo_paths
		operation_type: operation_type
		dry_run: dry_run
	}

	rules := get_common_validation_rules()
	return run_validation(validation_ctx, rules)
}

// Prompt user for confirmation
pub fn (ctx &SafetyContext) confirm_operation(
	operation_type OperationType,
	target_repos []string,
	description string,
	dry_run bool,
	warnings []string
) !bool {
	if !ctx.enabled {
		return true
	}

	request := OperationRequest{
		operation_type: operation_type
		target_repos: target_repos
		description: description
		dry_run: dry_run
		force: false
	}

	return prompt_confirmation(request, warnings)
}

// Wait with rate limiting
pub fn (mut ctx SafetyContext) rate_limit() {
	if ctx.enabled && ctx.config.rate_limit_ms > 0 {
		ctx.rate_limiter.wait()
	}
}

// Record operation in audit log
pub fn (mut ctx SafetyContext) audit(
	operation_type OperationType,
	target_repos []string,
	description string,
	result string
) {
	if ctx.enabled && ctx.config.audit_log {
		request := OperationRequest{
			operation_type: operation_type
			target_repos: target_repos
			description: description
			dry_run: false
			force: false
		}

		ctx.audit_log.record(request, result) or {
			println('⚠️  Failed to write audit log: ${err}')
		}
	}
}

// Print safety banner
pub fn (ctx &SafetyContext) print_banner() {
	if !ctx.enabled {
		println('⚠️  SAFETY DISABLED - NO PROTECTION!')
		println('')
		return
	}

	level_str := match ctx.config.level {
		.paranoid { '🛡️  PARANOID (maximum safety)' }
		.strict { '🔒 STRICT (recommended)' }
		.relaxed { '⚡ RELAXED (minimal checks)' }
		.disabled { '⚠️  DISABLED (no protection)' }
	}

	println('Safety Level: ${level_str}')
	println('  Max repos: ${ctx.config.max_repos}')
	println('  Confirm threshold: ${ctx.config.confirm_threshold}')
	println('  Rate limit: ${ctx.config.rate_limit_ms}ms')
	println('')
}

// Check if operation should be allowed
pub fn (ctx &SafetyContext) should_proceed(
	operation_type OperationType,
	target_repos []string,
	description string,
	dry_run bool,
	force bool
) !bool {
	if !ctx.enabled {
		return true
	}

	// Check safety
	check_result := ctx.check_operation(operation_type, target_repos, description, dry_run, force)!

	// Print blockers if any
	if check_result.blockers.len > 0 {
		println('')
		println('❌ OPERATION BLOCKED:')
		for blocker in check_result.blockers {
			println('  - ${blocker}')
		}
		println('')
		return false
	}

	// If confirmation required and not forced
	if check_result.requires_confirm && !force {
		return ctx.confirm_operation(operation_type, target_repos, description, dry_run, check_result.warnings)!
	}

	return check_result.approved
}
