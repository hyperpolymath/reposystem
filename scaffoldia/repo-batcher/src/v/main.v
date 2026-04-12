// SPDX-License-Identifier: PMPL-1.0-or-later
//
// repo-batcher main entry point
// Fast CLI for formally verified batch repository operations

module main

import os
import time
import cli
import ffi
import executor
import utils
import rollback
import watcher
import github
import parsers
import safety
import templates

const (
	version = '0.1.0'
	app_name = 'repo-batcher'
	default_repos_dir = os.join_path(os.home_dir(), 'Documents', 'hyperpolymath-repos')
)

fn main() {
	mut app := cli.Command{
		name: app_name
		description: 'Formally verified batch operations for mass repository management'
		version: version
		execute: show_help
		commands: [
			cli.Command{
				name: 'list-ops'
				description: 'List all available operations'
				execute: cmd_list_operations
			},
			cli.Command{
				name: 'license-update'
				description: 'Update license across repositories'
				execute: cmd_license_update
				flags: [
					cli.Flag{
						flag: .string
						name: 'old'
						abbrev: 'o'
						description: 'Old license SPDX identifier'
						required: true
					},
					cli.Flag{
						flag: .string
						name: 'new'
						abbrev: 'n'
						description: 'New license SPDX identifier'
						required: true
					},
					cli.Flag{
						flag: .string
						name: 'targets'
						abbrev: 't'
						description: 'Target repositories (comma-separated or @pattern)'
						required: true
					},
					cli.Flag{
						flag: .bool
						name: 'dry-run'
						abbrev: 'd'
						description: 'Preview changes without executing'
					},
					cli.Flag{
						flag: .bool
						name: 'backup'
						abbrev: 'b'
						description: 'Create backups before changes'
					},
					cli.Flag{
						flag: .bool
						name: 'force'
						abbrev: 'f'
						description: 'Skip safety confirmation prompts'
					},
				]
			},
			cli.Command{
				name: 'file-replace'
				description: 'Replace files across repositories'
				execute: cmd_file_replace
				flags: [
					cli.Flag{
						flag: .string
						name: 'pattern'
						abbrev: 'p'
						description: 'File pattern to match'
						required: true
					},
					cli.Flag{
						flag: .string
						name: 'replacement'
						abbrev: 'r'
						description: 'Replacement file path'
						required: true
					},
					cli.Flag{
						flag: .string
						name: 'targets'
						abbrev: 't'
						description: 'Target repositories'
						required: true
					},
					cli.Flag{
						flag: .bool
						name: 'dry-run'
						abbrev: 'd'
						description: 'Preview changes without executing'
					},
					cli.Flag{
						flag: .bool
						name: 'backup'
						abbrev: 'b'
						description: 'Create backups before changes'
					},
					cli.Flag{
						flag: .bool
						name: 'force'
						abbrev: 'f'
						description: 'Skip safety confirmation prompts'
					},
				]
			},
			cli.Command{
				name: 'git-sync'
				description: 'Batch git sync (add, commit, push) across repositories'
				execute: cmd_git_sync
				flags: [
					cli.Flag{
						flag: .int
						name: 'parallel'
						abbrev: 'p'
						description: 'Number of parallel jobs (default: 4)'
						default_value: ['4']
					},
					cli.Flag{
						flag: .int
						name: 'depth'
						abbrev: 'D'
						description: 'Max depth for repository search (default: 2)'
						default_value: ['2']
					},
					cli.Flag{
						flag: .string
						name: 'commit-message'
						abbrev: 'm'
						description: 'Commit message (default: "chore: batch update")'
						default_value: ['chore: batch update']
					},
					cli.Flag{
						flag: .bool
						name: 'dry-run'
						abbrev: 'd'
						description: 'Preview changes without executing'
					},
					cli.Flag{
						flag: .bool
						name: 'force'
						abbrev: 'f'
						description: 'Skip safety confirmation prompts'
					},
				]
			},
			cli.Command{
				name: 'watch'
				description: 'Start watch daemon for batch operations'
				execute: cmd_watch
				flags: [
					cli.Flag{
						flag: .string
						name: 'folder'
						abbrev: 'f'
						description: 'Watch folder path (default: ~/.config/repo-batcher/watch)'
					},
					cli.Flag{
						flag: .int
						name: 'interval'
						abbrev: 'i'
						description: 'Check interval in seconds (default: 30)'
						default_value: ['30']
					},
				]
			},
			cli.Command{
				name: 'github-settings'
				description: 'Bulk GitHub repository settings configuration'
				execute: cmd_github_settings
				flags: [
					cli.Flag{
						flag: .string
						name: 'config'
						abbrev: 'c'
						description: 'TOML config file path'
					},
					cli.Flag{
						flag: .string
						name: 'targets'
						abbrev: 't'
						description: 'Target repositories (comma-separated or @pattern)'
						required: true
					},
					cli.Flag{
						flag: .bool
						name: 'dry-run'
						abbrev: 'd'
						description: 'Preview changes without executing'
					},
					cli.Flag{
						flag: .bool
						name: 'has-issues'
						description: 'Enable/disable issues (use --no-has-issues to disable)'
					},
					cli.Flag{
						flag: .bool
						name: 'has-wiki'
						description: 'Enable/disable wiki'
					},
					cli.Flag{
						flag: .bool
						name: 'delete-branch-on-merge'
						description: 'Auto-delete branches after merge'
					},
					cli.Flag{
						flag: .bool
						name: 'force'
						abbrev: 'f'
						description: 'Skip safety confirmation prompts'
					},
				]
			},
			cli.Command{
				name: 'wiki-setup'
				description: 'Initialize wikis with first page (enables automation)'
				execute: cmd_wiki_setup
				flags: [
					cli.Flag{
						flag: .string
						name: 'targets'
						abbrev: 't'
						description: 'Target repositories (comma-separated or @pattern)'
						required: true
					},
					cli.Flag{
						flag: .string
						name: 'home-template'
						abbrev: 'h'
						description: 'Path to Home.md template file'
					},
					cli.Flag{
						flag: .bool
						name: 'dry-run'
						abbrev: 'd'
						description: 'Preview changes without executing'
					},
					cli.Flag{
						flag: .bool
						name: 'force'
						abbrev: 'f'
						description: 'Skip safety confirmation prompts'
					},
				]
			},
			cli.Command{
				name: 'community-setup'
				description: 'Deploy community health files (CODE_OF_CONDUCT, CONTRIBUTING, etc.)'
				execute: cmd_community_setup
				flags: [
					cli.Flag{
						flag: .string
						name: 'targets'
						abbrev: 't'
						description: 'Target repositories (comma-separated or @pattern)'
						required: true
					},
					cli.Flag{
						flag: .string
						name: 'template-dir'
						abbrev: 'T'
						description: 'Directory with custom template files'
					},
					cli.Flag{
						flag: .bool
						name: 'dry-run'
						abbrev: 'd'
						description: 'Preview changes without executing'
					},
					cli.Flag{
						flag: .bool
						name: 'force'
						abbrev: 'f'
						description: 'Skip safety confirmation prompts'
					},
				]
			},
			cli.Command{
				name: 'templates-setup'
				description: 'Deploy issue and PR templates'
				execute: cmd_templates_setup
				flags: [
					cli.Flag{
						flag: .string
						name: 'targets'
						abbrev: 't'
						description: 'Target repositories (comma-separated or @pattern)'
						required: true
					},
					cli.Flag{
						flag: .string
						name: 'template-dir'
						abbrev: 'T'
						description: 'Directory with custom template files'
					},
					cli.Flag{
						flag: .bool
						name: 'dry-run'
						abbrev: 'd'
						description: 'Preview changes without executing'
					},
					cli.Flag{
						flag: .bool
						name: 'force'
						abbrev: 'f'
						description: 'Skip safety confirmation prompts'
					},
				]
			},
			cli.Command{
				name: 'discussions-setup'
				description: 'Enable and configure GitHub Discussions'
				execute: cmd_discussions_setup
				flags: [
					cli.Flag{
						flag: .string
						name: 'targets'
						abbrev: 't'
						description: 'Target repositories (comma-separated or @pattern)'
						required: true
					},
					cli.Flag{
						flag: .bool
						name: 'dry-run'
						abbrev: 'd'
						description: 'Preview changes without executing'
					},
					cli.Flag{
						flag: .bool
						name: 'force'
						abbrev: 'f'
						description: 'Skip safety confirmation prompts'
					},
				]
			},
			cli.Command{
				name: 'pages-setup'
				description: 'Enable and configure GitHub Pages'
				execute: cmd_pages_setup
				flags: [
					cli.Flag{
						flag: .string
						name: 'targets'
						abbrev: 't'
						description: 'Target repositories (comma-separated or @pattern)'
						required: true
					},
					cli.Flag{
						flag: .string
						name: 'source'
						abbrev: 's'
						description: 'Pages source (root-main, docs-main, gh-pages) [default: docs-main]'
						default_value: ['docs-main']
					},
					cli.Flag{
						flag: .string
						name: 'cname'
						abbrev: 'c'
						description: 'Custom domain for Pages'
					},
					cli.Flag{
						flag: .bool
						name: 'dry-run'
						abbrev: 'd'
						description: 'Preview changes without executing'
					},
					cli.Flag{
						flag: .bool
						name: 'force'
						abbrev: 'f'
						description: 'Skip safety confirmation prompts'
					},
				]
			},
			cli.Command{
				name: 'template-merge'
				description: 'Convert existing repos to template form (preserves content)'
				execute: cmd_template_merge
				flags: [
					cli.Flag{
						flag: .string
						name: 'targets'
						abbrev: 't'
						description: 'Target repositories (comma-separated or @pattern)'
						required: true
					},
					cli.Flag{
						flag: .bool
						name: 'workflows'
						description: 'Add GitHub workflows (default: true)'
					},
					cli.Flag{
						flag: .bool
						name: 'scm-files'
						description: 'Add .machine_readable SCM files (default: true)'
					},
					cli.Flag{
						flag: .bool
						name: 'bot-directives'
						description: 'Add .bot_directives (default: true)'
					},
					cli.Flag{
						flag: .bool
						name: 'contractiles'
						description: 'Add contractiles directory (default: true)'
					},
					cli.Flag{
						flag: .bool
						name: 'preserve'
						description: 'Preserve existing files (default: true)'
					},
					cli.Flag{
						flag: .bool
						name: 'dry-run'
						abbrev: 'd'
						description: 'Preview changes without executing'
					},
					cli.Flag{
						flag: .bool
						name: 'force'
						abbrev: 'f'
						description: 'Skip safety confirmation prompts'
					},
				]
			},
			cli.Command{
				name: 'rollback'
				description: 'Rollback last operation or specific log'
				execute: cmd_rollback
				flags: [
					cli.Flag{
						flag: .bool
						name: 'last'
						abbrev: 'l'
						description: 'Rollback last operation'
					},
					cli.Flag{
						flag: .string
						name: 'log-id'
						abbrev: 'L'
						description: 'Rollback specific log ID'
					},
				]
			},
		]
	}

	app.setup()
	app.parse(os.args)
}

fn show_help(cmd cli.Command) ! {
	println('repo-batcher v${version}')
	println('Formally verified batch operations for mass repository management')
	println('')
	println('Usage:')
	println('  repo-batcher <command> [options]')
	println('')
	println('Available commands:')
	println('  list-ops          List all available operations')
	println('  license-update    Update license across repositories')
	println('  file-replace      Replace files across repositories')
	println('  git-sync          Batch git sync (add, commit, push)')
	println('  github-settings   Bulk repository configuration (features, merge settings)')
	println('  wiki-setup        Initialize wikis with first page (enables automation)')
	println('  community-setup   Deploy community health files')
	println('  templates-setup   Deploy issue and PR templates')
	println('  discussions-setup Enable and configure GitHub Discussions')
	println('  pages-setup       Enable and configure GitHub Pages')
	println('  template-merge    Convert repos to template form (preserves content)')
	println('  watch             Start watch daemon')
	println('  rollback          Rollback operation')
	println('')
	println('Use "repo-batcher <command> --help" for more information about a command.')
}

fn cmd_list_operations(cmd cli.Command) ! {
	println('Available Operations:')
	println('')
	println('  license-update    Replace license headers and LICENSE files')
	println('                    Safety: Valid SPDX IDs, backup required')
	println('')
	println('  file-replace      Replace files matching pattern')
	println('                    Safety: Backup required, no circular replacements')
	println('')
	println('  git-sync          Batch commit and push across repos')
	println('                    Safety: Valid repos, no conflicts, remote reachable')
	println('')
	println('  workflow-update   Update GitHub Actions workflows')
	println('                    Safety: Valid YAML, SHA pinning validation')
	println('')
	println('  github-settings   Bulk repository configuration via GitHub API')
	println('                    Safety: Pre-flight validation, rollback support')
	println('')
	println('  wiki-setup        Initialize wikis with first page')
	println('                    Safety: Creates Home.md to enable automation')
	println('')
	println('  community-setup   Deploy community health files')
	println('                    Safety: CODE_OF_CONDUCT, CONTRIBUTING, SECURITY, etc.')
	println('')
	println('  templates-setup   Deploy issue and PR templates')
	println('                    Safety: Bug report, feature request, documentation templates')
	println('')
	println('  discussions-setup Enable and configure GitHub Discussions')
	println('                    Safety: Creates 5 default categories (read-only operation)')
	println('')
	println('  pages-setup       Enable and configure GitHub Pages')
	println('                    Safety: Configure source, branch, custom domains (remote)')
	println('')
	println('  template-merge    Convert repos to template form (preserves content)')
	println('                    Safety: Adds workflows, SCM, bot directives, contractiles')
	println('')
	println('  custom            Execute custom operation from template')
	println('                    Safety: Template validation, dry-run enforced')
}

fn cmd_license_update(cmd cli.Command) ! {
	old := cmd.flags.get_string('old')!
	new := cmd.flags.get_string('new')!
	targets := cmd.flags.get_string('targets')!
	dry_run := cmd.flags.get_bool('dry-run') or { false }
	backup := cmd.flags.get_bool('backup') or { true }
	force := cmd.flags.get_bool('force') or { false }

	println('License Update Operation')
	println('  Old: ${old}')
	println('  New: ${new}')
	println('  Targets: ${targets}')
	println('  Dry Run: ${dry_run}')
	println('  Backup: ${backup}')
	println('')

	// Initialize safety system
	mut safety_ctx := safety.new_safety_context() or {
		println('⚠️  Failed to initialize safety system: ${err}')
		println('⚠️  Proceeding with default strict safety')
		safety.SafetyContext{
			config: safety.default_safety_config()
			rate_limiter: safety.new_rate_limiter(100)
			audit_log: safety.AuditLog{ log_file: '' }
			enabled: true
		}
	}
	safety_ctx.print_banner()

	// Validate SPDX identifiers first
	if !ffi.validate_spdx(old) {
		println('ERROR: Invalid old license SPDX identifier: ${old}')
		return error('Invalid SPDX identifier')
	}

	if !ffi.validate_spdx(new) {
		println('ERROR: Invalid new license SPDX identifier: ${new}')
		return error('Invalid SPDX identifier')
	}

	if dry_run {
		println('[DRY RUN] No changes will be made')
		println('')
	}

	// Resolve repositories from target specification
	println('Resolving target repositories...')
	repos := utils.resolve_targets(targets, default_repos_dir, 2)
	println('Found ${repos.len} repositories')
	println('')

	if repos.len == 0 {
		println('No repositories found matching: ${targets}')
		return
	}

	// Pre-flight validation
	validation_result := safety_ctx.validate(repos, 'license-update', dry_run) or {
		println('⚠️  Validation failed: ${err}')
		return error('Validation error')
	}

	safety.print_validation_result(validation_result)

	if !validation_result.passed {
		return error('Pre-flight validation failed')
	}

	// Safety check - should we proceed?
	if !safety_ctx.should_proceed(
		safety.OperationType.local_changes,
		repos,
		'Update license from ${old} to ${new}',
		dry_run,
		force
	)! {
		println('Operation cancelled by user or safety system')
		safety_ctx.audit(safety.OperationType.local_changes, repos, 'license-update', 'CANCELLED')
		return
	}

	// Determine parallel jobs (use 4 for license updates, less I/O intensive)
	parallel := if repos.len < 4 { repos.len } else { 4 }

	// Create parallel executor with V coroutines
	mut pool := executor.new_worker_pool(repos, parallel)

	// Execute license-update in parallel
	result := pool.execute_license_update(old, new, backup, dry_run)

	// Print results
	result.print()

	// Audit log
	status := if result.has_failures() { 'PARTIAL_FAILURE' } else { 'SUCCESS' }
	safety_ctx.audit(safety.OperationType.local_changes, repos, 'license-update', status)

	if result.has_failures() {
		return error('License update completed with failures')
	}
}

fn cmd_file_replace(cmd cli.Command) ! {
	pattern := cmd.flags.get_string('pattern')!
	replacement := cmd.flags.get_string('replacement')!
	targets := cmd.flags.get_string('targets')!
	dry_run := cmd.flags.get_bool('dry-run') or { false }
	backup := cmd.flags.get_bool('backup') or { true }
	force := cmd.flags.get_bool('force') or { false }

	println('File Replace Operation')
	println('  Pattern: ${pattern}')
	println('  Replacement: ${replacement}')
	println('  Targets: ${targets}')
	println('  Dry Run: ${dry_run}')
	println('  Backup: ${backup}')
	println('')

	// Initialize safety system
	mut safety_ctx := safety.new_safety_context() or {
		println('⚠️  Failed to initialize safety system: ${err}')
		println('⚠️  Proceeding with default strict safety')
		safety.SafetyContext{
			config: safety.default_safety_config()
			rate_limiter: safety.new_rate_limiter(100)
			audit_log: safety.AuditLog{ log_file: '' }
			enabled: true
		}
	}
	safety_ctx.print_banner()

	// Check replacement file exists
	if !os.exists(replacement) {
		println('ERROR: Replacement file does not exist: ${replacement}')
		return error('Replacement file not found')
	}

	if dry_run {
		println('[DRY RUN] No changes will be made')
		println('')
	}

	// Resolve repositories from target specification
	println('Resolving target repositories...')
	repos := utils.resolve_targets(targets, default_repos_dir, 2)
	println('Found ${repos.len} repositories')
	println('')

	if repos.len == 0 {
		println('No repositories found matching: ${targets}')
		return
	}

	// Pre-flight validation
	validation_result := safety_ctx.validate(repos, 'file-replace', dry_run) or {
		println('⚠️  Validation failed: ${err}')
		return error('Validation error')
	}

	safety.print_validation_result(validation_result)

	if !validation_result.passed {
		return error('Pre-flight validation failed')
	}

	// Safety check - should we proceed?
	if !safety_ctx.should_proceed(
		safety.OperationType.local_changes,
		repos,
		'Replace files matching ${pattern}',
		dry_run,
		force
	)! {
		println('Operation cancelled by user or safety system')
		safety_ctx.audit(safety.OperationType.local_changes, repos, 'file-replace', 'CANCELLED')
		return
	}

	// Determine parallel jobs
	parallel := if repos.len < 4 { repos.len } else { 4 }

	// Create parallel executor with V coroutines
	mut pool := executor.new_worker_pool(repos, parallel)

	// Execute file-replace in parallel
	result := pool.execute_file_replace(pattern, replacement, backup, dry_run)

	// Print results
	result.print()

	// Audit log
	status := if result.has_failures() { 'PARTIAL_FAILURE' } else { 'SUCCESS' }
	safety_ctx.audit(safety.OperationType.local_changes, repos, 'file-replace', status)

	if result.has_failures() {
		return error('File replace completed with failures')
	}
}

fn cmd_git_sync(cmd cli.Command) ! {
	parallel := cmd.flags.get_int('parallel') or { 4 }
	depth := cmd.flags.get_int('depth') or { 2 }
	message := cmd.flags.get_string('commit-message') or { 'chore: batch update' }
	dry_run := cmd.flags.get_bool('dry-run') or { false }
	force := cmd.flags.get_bool('force') or { false }

	println('Git Batch Sync Operation (ported from sync_repos.sh)')
	println('  Parallel Jobs: ${parallel}')
	println('  Max Depth: ${depth}')
	println('  Commit Message: ${message}')
	println('  Dry Run: ${dry_run}')
	println('')

	// Initialize safety system
	mut safety_ctx := safety.new_safety_context() or {
		println('⚠️  Failed to initialize safety system: ${err}')
		println('⚠️  Proceeding with default strict safety')
		safety.SafetyContext{
			config: safety.default_safety_config()
			rate_limiter: safety.new_rate_limiter(100)
			audit_log: safety.AuditLog{ log_file: '' }
			enabled: true
		}
	}
	safety_ctx.print_banner()

	if dry_run {
		println('[DRY RUN] No changes will be made')
		println('')
	}

	// Find all repositories
	println('Scanning for repositories (find . -maxdepth ${depth} -name ".git")...')
	repos := utils.find_git_repos(default_repos_dir, depth)
	println('Found ${repos.len} repositories')
	println('')

	if repos.len == 0 {
		println('No repositories found in ${default_repos_dir}')
		return
	}

	// Pre-flight validation
	validation_result := safety_ctx.validate(repos, 'git-sync', dry_run) or {
		println('⚠️  Validation failed: ${err}')
		return error('Validation error')
	}

	safety.print_validation_result(validation_result)

	if !validation_result.passed {
		return error('Pre-flight validation failed')
	}

	// Safety check - should we proceed?
	if !safety_ctx.should_proceed(
		safety.OperationType.remote_changes,
		repos,
		'Batch commit and push: ${message}',
		dry_run,
		force
	)! {
		println('Operation cancelled by user or safety system')
		safety_ctx.audit(safety.OperationType.remote_changes, repos, 'git-sync', 'CANCELLED')
		return
	}

	// Create parallel executor with V coroutines
	mut pool := executor.new_worker_pool(repos, parallel)

	// Execute git-sync in parallel
	result := pool.execute_git_sync(message, dry_run)

	// Print results
	result.print()

	// Audit log
	status := if result.has_failures() { 'PARTIAL_FAILURE' } else { 'SUCCESS' }
	safety_ctx.audit(safety.OperationType.remote_changes, repos, 'git-sync', status)

	if result.has_failures() {
		println('NOTE: Some repositories failed. Check logs for details.')
		return error('Git sync completed with failures')
	}
}

fn cmd_watch(cmd cli.Command) ! {
	folder := cmd.flags.get_string('folder') or {
		os.join_path(os.home_dir(), '.config', 'repo-batcher', 'watch')
	}
	interval := cmd.flags.get_int('interval') or { 30 }

	println('Starting Watch Daemon')
	println('  Watch Folder: ${folder}')
	println('  Check Interval: ${interval}s')
	println('')

	// Create and start monitor
	mut monitor := watcher.new_watch_monitor(folder, interval, true)
	monitor.start()
}

fn cmd_rollback(cmd cli.Command) ! {
	last := cmd.flags.get_bool('last') or { false }
	log_id := cmd.flags.get_string('log-id') or { '' }

	mut mgr := rollback.new_backup_manager()

	if last {
		println('Rolling back last operation...')
		println('')
		mgr.restore_last() or {
			println('')
			println('ERROR: ${err}')
			return error('Rollback failed')
		}
		println('')
		println('✓ Rollback completed successfully')
	} else if log_id != '' {
		println('Rolling back operation: ${log_id}')
		println('')
		mgr.restore_operation(log_id) or {
			println('')
			println('ERROR: ${err}')
			return error('Rollback failed')
		}
		println('')
		println('✓ Rollback completed successfully')
	} else {
		// List recent operations
		println('Recent operations:')
		println('')
		operations := mgr.list_operations(10)
		if operations.len == 0 {
			println('No operations to rollback')
		} else {
			for op in operations {
				timestamp := time.unix(op.timestamp).format()
				println('  ${op.operation_id}')
				println('    Type: ${op.operation_type}')
				println('    Time: ${timestamp}')
				println('    Repos: ${op.repos.len}')
				println('    Files: ${op.entries.len}')
				println('')
			}
			println('Use --last to rollback most recent, or --log-id <id> for specific operation')
		}
	}
}

fn cmd_github_settings(cmd cli.Command) ! {
	config_file := cmd.flags.get_string('config') or { '' }
	targets := cmd.flags.get_string('targets')!
	dry_run := cmd.flags.get_bool('dry-run') or { false }
	force := cmd.flags.get_bool('force') or { false }

	// Individual flag overrides
	has_issues := cmd.flags.get_bool('has-issues') or { none }
	has_wiki := cmd.flags.get_bool('has-wiki') or { none }
	delete_branch := cmd.flags.get_bool('delete-branch-on-merge') or { none }

	println('GitHub Settings Operation')
	println('  Config: ${if config_file != '' { config_file } else { '(command-line flags)' }}')
	println('  Targets: ${targets}')
	println('  Dry Run: ${dry_run}')
	println('')

	// Initialize safety system
	mut safety_ctx := safety.new_safety_context() or {
		println('⚠️  Failed to initialize safety system: ${err}')
		println('⚠️  Proceeding with default strict safety')
		safety.SafetyContext{
			config: safety.default_safety_config()
			rate_limiter: safety.new_rate_limiter(100)
			audit_log: safety.AuditLog{ log_file: '' }
			enabled: true
		}
	}
	safety_ctx.print_banner()

	// Check gh CLI authentication
	if !github.check_gh_cli_installed()! {
		println('ERROR: GitHub CLI (gh) is not installed')
		println('Please install it: https://cli.github.com/')
		return error('gh CLI not available')
	}

	if !github.check_gh_auth()! {
		println('ERROR: Not authenticated with GitHub CLI')
		println('Please run: gh auth login')
		return error('gh auth required')
	}

	// Load settings from config file or flags
	mut settings := github.GitHubSettings{
		repo_features: github.RepoFeatures{
			has_issues: has_issues
			has_wiki: has_wiki
		}
		merge_settings: github.MergeSettings{
			delete_branch_on_merge: delete_branch
		}
	}

	// If config file provided, parse it and merge with flags
	if config_file != '' {
		println('Loading settings from ${config_file}...')
		settings = parsers.parse_settings_toml(config_file) or {
			println('ERROR: Failed to parse config file: ${err}')
			return error('Config parse failed')
		}

		// Command-line flags override config file
		if has_issues != none {
			settings.repo_features.has_issues = has_issues
		}
		if has_wiki != none {
			settings.repo_features.has_wiki = has_wiki
		}
		if delete_branch != none {
			settings.merge_settings.delete_branch_on_merge = delete_branch
		}
	}

	// Validate settings
	parsers.validate_settings(settings) or {
		println('ERROR: Invalid settings: ${err}')
		return error('Validation failed')
	}

	if dry_run {
		println('[DRY RUN] No changes will be made')
		println('')
	}

	// Resolve repositories from target specification
	println('Resolving target repositories...')
	repos := utils.resolve_targets(targets, default_repos_dir, 2)
	println('Found ${repos.len} repositories')
	println('')

	if repos.len == 0 {
		println('No repositories found matching: ${targets}')
		return
	}

	// Pre-flight validation
	validation_result := safety_ctx.validate(repos, 'github-settings', dry_run) or {
		println('⚠️  Validation failed: ${err}')
		return error('Validation error')
	}

	safety.print_validation_result(validation_result)

	if !validation_result.passed {
		return error('Pre-flight validation failed')
	}

	// Convert repo paths to owner/repo format (assumes repos in ~/Documents/hyperpolymath-repos/)
	mut repo_names := []string{}
	for repo_path in repos {
		// Extract repo name from path
		parts := repo_path.split(os.path_separator)
		if parts.len > 0 {
			repo_name := parts[parts.len - 1]
			// Assume hyperpolymath organization
			repo_names << 'hyperpolymath/${repo_name}'
		}
	}

	// Safety check - should we proceed?
	if !safety_ctx.should_proceed(
		safety.OperationType.remote_changes,
		repo_names,
		'Apply GitHub repository settings',
		dry_run,
		force
	)! {
		println('Operation cancelled by user or safety system')
		safety_ctx.audit(safety.OperationType.remote_changes, repo_names, 'github-settings', 'CANCELLED')
		return
	}

	println('Applying settings to ${repo_names.len} repositories...')
	println('')

	// Execute settings update with rate limiting
	start_time := time.now()
	mut results := []github.SettingsResult{}

	for i, repo_name in repo_names {
		if i > 0 {
			safety_ctx.rate_limit()
		}

		result := github.apply_settings(repo_name, settings, dry_run) or {
			results << github.SettingsResult{
				repo_path: repo_name
				success: false
				message: 'Error: ${err}'
			}
			continue
		}

		results << result

		if i % 10 == 0 && i > 0 {
			println('  Progress: ${i}/${repo_names.len}')
		}
	}

	duration := time.since(start_time)

	// Print results
	println('')
	mut success := 0
	mut failed := 0
	for result in results {
		if result.success {
			success++
			println('✓ ${result.repo_path}: ${result.message}')
		} else {
			failed++
			println('✗ ${result.repo_path}: ${result.message}')
		}
	}

	println('')
	summary := github.compute_summary(results)
	github.print_summary(summary)

	println('Completed in ${duration.seconds():.2f}s')

	// Audit log
	status := if failed > 0 { 'PARTIAL_FAILURE' } else { 'SUCCESS' }
	safety_ctx.audit(safety.OperationType.remote_changes, repo_names, 'github-settings', status)

	if failed > 0 {
		return error('GitHub settings update completed with failures')
	}
}

fn cmd_wiki_setup(cmd cli.Command) ! {
	targets := cmd.flags.get_string('targets')!
	home_template := cmd.flags.get_string('home-template') or { '' }
	dry_run := cmd.flags.get_bool('dry-run') or { false }
	force := cmd.flags.get_bool('force') or { false }

	println('Wiki Setup Operation')
	println('  Targets: ${targets}')
	println('  Home template: ${if home_template != '' { home_template } else { '(default)' }}')
	println('  Dry Run: ${dry_run}')
	println('')

	// Initialize safety system
	mut safety_ctx := safety.new_safety_context() or {
		println('⚠️  Failed to initialize safety system: ${err}')
		println('⚠️  Proceeding with default strict safety')
		safety.SafetyContext{
			config: safety.default_safety_config()
			rate_limiter: safety.new_rate_limiter(100)
			audit_log: safety.AuditLog{ log_file: '' }
			enabled: true
		}
	}
	safety_ctx.print_banner()

	// Check gh CLI authentication
	if !github.check_gh_cli_installed()! {
		println('ERROR: GitHub CLI (gh) is not installed')
		println('Please install it: https://cli.github.com/')
		return error('gh CLI not available')
	}

	if !github.check_gh_auth()! {
		println('ERROR: Not authenticated with GitHub CLI')
		println('Please run: gh auth login')
		return error('gh auth required')
	}

	// Load home content from template or use default
	mut home_content := ''
	if home_template != '' {
		home_content = os.read_file(home_template) or {
			println('ERROR: Failed to read home template: ${err}')
			return error('Template read failed')
		}
	}

	if dry_run {
		println('[DRY RUN] No changes will be made')
		println('')
	}

	// Resolve repositories
	println('Resolving target repositories...')
	repos := utils.resolve_targets(targets, default_repos_dir, 2)
	println('Found ${repos.len} repositories')
	println('')

	if repos.len == 0 {
		println('No repositories found matching: ${targets}')
		return
	}

	// Pre-flight validation
	validation_result := safety_ctx.validate(repos, 'wiki-setup', dry_run) or {
		println('⚠️  Validation failed: ${err}')
		return error('Validation error')
	}

	safety.print_validation_result(validation_result)

	if !validation_result.passed {
		return error('Pre-flight validation failed')
	}

	// Convert to owner/repo format
	mut repo_names := []string{}
	for repo_path in repos {
		parts := repo_path.split(os.path_separator)
		if parts.len > 0 {
			repo_name := parts[parts.len - 1]
			repo_names << 'hyperpolymath/${repo_name}'

			// Use default content if no template provided
			if home_content == '' {
				home_content = github.default_home_content(repo_name)
			}
		}
	}

	// Safety check - should we proceed?
	if !safety_ctx.should_proceed(
		safety.OperationType.remote_changes,
		repo_names,
		'Initialize wikis with first page',
		dry_run,
		force
	)! {
		println('Operation cancelled by user or safety system')
		safety_ctx.audit(safety.OperationType.remote_changes, repo_names, 'wiki-setup', 'CANCELLED')
		return
	}

	println('Initializing wikis for ${repo_names.len} repositories...')
	println('')

	// Execute wiki setup with rate limiting
	start_time := time.now()
	mut results := []github.WikiSetupResult{}

	for i, repo_name in repo_names {
		if i > 0 {
			safety_ctx.rate_limit()
		}

		result := github.setup_wiki(github.WikiSetupParams{
			repo: repo_name
			home_content: home_content
			dry_run: dry_run
		}) or {
			results << github.WikiSetupResult{
				repo: repo_name
				success: false
				message: 'Error: ${err}'
			}
			continue
		}

		results << result

		if i % 10 == 0 && i > 0 {
			println('  Progress: ${i}/${repo_names.len}')
		}
	}

	duration := time.since(start_time)

	// Print summary
	github.print_wiki_summary(results)
	println('Completed in ${duration.seconds():.2f}s')

	// Check for failures
	mut failed := 0
	for result in results {
		if !result.success {
			failed++
		}
	}

	// Audit log
	status := if failed > 0 { 'PARTIAL_FAILURE' } else { 'SUCCESS' }
	safety_ctx.audit(safety.OperationType.remote_changes, repo_names, 'wiki-setup', status)

	if failed > 0 {
		return error('Wiki setup completed with failures')
	}
}

fn cmd_community_setup(cmd cli.Command) ! {
	targets := cmd.flags.get_string('targets')!
	template_dir := cmd.flags.get_string('template-dir') or { '' }
	dry_run := cmd.flags.get_bool('dry-run') or { false }
	force := cmd.flags.get_bool('force') or { false }

	println('Community Health Files Setup')
	println('  Targets: ${targets}')
	println('  Templates: ${if template_dir != '' { template_dir } else { '(default)' }}')
	println('  Dry Run: ${dry_run}')
	println('')

	// Initialize safety system
	mut safety_ctx := safety.new_safety_context() or {
		println('⚠️  Failed to initialize safety system: ${err}')
		println('⚠️  Proceeding with default strict safety')
		safety.SafetyContext{
			config: safety.default_safety_config()
			rate_limiter: safety.new_rate_limiter(100)
			audit_log: safety.AuditLog{ log_file: '' }
			enabled: true
		}
	}
	safety_ctx.print_banner()

	// Get community files (default or from template directory)
	mut files := []github.CommunityFile{}
	if template_dir != '' {
		// Load custom templates
		println('Loading custom templates from ${template_dir}...')

		// Define expected files
		template_files := [
			'CODE_OF_CONDUCT.md',
			'CONTRIBUTING.md',
			'SECURITY.md',
			'SUPPORT.md',
			'FUNDING.yml',
		]

		for template_file in template_files {
			file_path := os.join_path(template_dir, template_file)
			if os.exists(file_path) {
				content := os.read_file(file_path) or {
					println('WARNING: Failed to read ${template_file}: ${err}')
					continue
				}

				target_path := if template_file.ends_with('.yml') {
					'.github/${template_file}'
				} else {
					'.github/${template_file}'
				}

				files << github.CommunityFile{
					path: target_path
					content: content
					name: template_file
				}
			}
		}

		if files.len == 0 {
			println('ERROR: No template files found in ${template_dir}')
			return error('No templates found')
		}
		println('Loaded ${files.len} custom templates')
	} else {
		// Use default templates
		files = github.standard_community_files()
		println('Using default community file templates (${files.len} files)')
	}
	println('')

	if dry_run {
		println('[DRY RUN] No changes will be made')
		println('')
	}

	// Resolve repositories
	println('Resolving target repositories...')
	repos := utils.resolve_targets(targets, default_repos_dir, 2)
	println('Found ${repos.len} repositories')
	println('')

	if repos.len == 0 {
		println('No repositories found matching: ${targets}')
		return
	}

	// Pre-flight validation
	validation_result := safety_ctx.validate(repos, 'community-setup', dry_run) or {
		println('⚠️  Validation failed: ${err}')
		return error('Validation error')
	}

	safety.print_validation_result(validation_result)

	if !validation_result.passed {
		return error('Pre-flight validation failed')
	}

	// Safety check - should we proceed?
	if !safety_ctx.should_proceed(
		safety.OperationType.local_changes,
		repos,
		'Deploy community health files',
		dry_run,
		force
	)! {
		println('Operation cancelled by user or safety system')
		safety_ctx.audit(safety.OperationType.local_changes, repos, 'community-setup', 'CANCELLED')
		return
	}

	println('Deploying community files to ${repos.len} repositories...')
	println('')

	// Execute community setup with rate limiting
	start_time := time.now()
	mut results := []github.CommunitySetupResult{}

	for i, repo_path in repos {
		if i > 0 {
			safety_ctx.rate_limit()
		}

		result := github.setup_community_files(github.CommunitySetupParams{
			repo_path: repo_path
			files: files
			dry_run: dry_run
		}) or {
			results << github.CommunitySetupResult{
				repo_path: repo_path
				success: false
				files_created: 0
				message: 'Error: ${err}'
			}
			continue
		}

		results << result

		if i % 10 == 0 && i > 0 {
			println('  Progress: ${i}/${repos.len}')
		}
	}

	duration := time.since(start_time)

	// Print summary
	github.print_community_summary(results)
	println('Completed in ${duration.seconds():.2f}s')

	// Check for failures
	mut failed := 0
	for result in results {
		if !result.success {
			failed++
		}
	}

	// Audit log
	status := if failed > 0 { 'PARTIAL_FAILURE' } else { 'SUCCESS' }
	safety_ctx.audit(safety.OperationType.local_changes, repos, 'community-setup', status)

	if failed > 0 {
		return error('Community setup completed with failures')
	}
}

fn cmd_templates_setup(cmd cli.Command) ! {
	targets := cmd.flags.get_string('targets')!
	template_dir := cmd.flags.get_string('template-dir') or { '' }
	dry_run := cmd.flags.get_bool('dry-run') or { false }
	force := cmd.flags.get_bool('force') or { false }

	println('Issue & PR Templates Setup')
	println('  Targets: ${targets}')
	println('  Templates: ${if template_dir != '' { template_dir } else { '(default)' }}')
	println('  Dry Run: ${dry_run}')
	println('')

	// Initialize safety system
	mut safety_ctx := safety.new_safety_context() or {
		println('⚠️  Failed to initialize safety system: ${err}')
		println('⚠️  Proceeding with default strict safety')
		safety.SafetyContext{
			config: safety.default_safety_config()
			rate_limiter: safety.new_rate_limiter(100)
			audit_log: safety.AuditLog{ log_file: '' }
			enabled: true
		}
	}
	safety_ctx.print_banner()

	// Get templates (default or custom)
	mut issue_templates := []github.IssueTemplate{}
	mut pr_template := ''

	if template_dir != '' {
		// Load custom templates
		println('Loading custom templates from ${template_dir}...')

		// Try to load issue templates
		issue_template_dir := os.join_path(template_dir, 'ISSUE_TEMPLATE')
		if os.exists(issue_template_dir) {
			files := os.ls(issue_template_dir) or { []string{} }
			for file in files {
				if file.ends_with('.yml') || file.ends_with('.md') {
					file_path := os.join_path(issue_template_dir, file)
					content := os.read_file(file_path) or {
						println('WARNING: Failed to read ${file}')
						continue
					}

					issue_templates << github.IssueTemplate{
						name: file.replace('.yml', '').replace('.md', '')
						filename: file
						content: content
						description: file
					}
				}
			}
		}

		// Try to load PR template
		pr_template_path := os.join_path(template_dir, 'PULL_REQUEST_TEMPLATE.md')
		if os.exists(pr_template_path) {
			pr_template = os.read_file(pr_template_path) or { '' }
		}

		println('Loaded ${issue_templates.len} issue templates')
	} else {
		// Use default templates
		issue_templates = github.standard_issue_templates()
		pr_template = github.default_pr_template()
		println('Using default templates (${issue_templates.len} issue + 1 PR)')
	}
	println('')

	if dry_run {
		println('[DRY RUN] No changes will be made')
		println('')
	}

	// Resolve repositories
	println('Resolving target repositories...')
	repos := utils.resolve_targets(targets, default_repos_dir, 2)
	println('Found ${repos.len} repositories')
	println('')

	if repos.len == 0 {
		println('No repositories found matching: ${targets}')
		return
	}

	// Pre-flight validation
	validation_result := safety_ctx.validate(repos, 'templates-setup', dry_run) or {
		println('⚠️  Validation failed: ${err}')
		return error('Validation error')
	}

	safety.print_validation_result(validation_result)

	if !validation_result.passed {
		return error('Pre-flight validation failed')
	}

	// Safety check - should we proceed?
	if !safety_ctx.should_proceed(
		safety.OperationType.local_changes,
		repos,
		'Deploy issue and PR templates',
		dry_run,
		force
	)! {
		println('Operation cancelled by user or safety system')
		safety_ctx.audit(safety.OperationType.local_changes, repos, 'templates-setup', 'CANCELLED')
		return
	}

	println('Deploying templates to ${repos.len} repositories...')
	println('')

	// Execute templates setup with rate limiting
	start_time := time.now()
	mut results := []github.TemplatesSetupResult{}

	for i, repo_path in repos {
		if i > 0 {
			safety_ctx.rate_limit()
		}

		result := github.setup_templates(github.TemplatesSetupParams{
			repo_path: repo_path
			issue_templates: issue_templates
			pr_template: pr_template
			dry_run: dry_run
		}) or {
			results << github.TemplatesSetupResult{
				repo_path: repo_path
				success: false
				templates_created: 0
				message: 'Error: ${err}'
			}
			continue
		}

		results << result

		if i % 10 == 0 && i > 0 {
			println('  Progress: ${i}/${repos.len}')
		}
	}

	duration := time.since(start_time)

	// Print summary
	github.print_templates_summary(results)
	println('Completed in ${duration.seconds():.2f}s')

	// Check for failures
	mut failed := 0
	for result in results {
		if !result.success {
			failed++
		}
	}

	// Audit log
	status := if failed > 0 { 'PARTIAL_FAILURE' } else { 'SUCCESS' }
	safety_ctx.audit(safety.OperationType.local_changes, repos, 'templates-setup', status)

	if failed > 0 {
		return error('Templates setup completed with failures')
	}
}

fn cmd_discussions_setup(cmd cli.Command) ! {
	targets := cmd.flags.get_string('targets')!
	dry_run := cmd.flags.get_bool('dry-run') or { false }
	force := cmd.flags.get_bool('force') or { false }

	println('GitHub Discussions Setup')
	println('  Targets: ${targets}')
	println('  Dry Run: ${dry_run}')
	println('')

	// Initialize safety system
	mut safety_ctx := safety.new_safety_context() or {
		println('⚠️  Failed to initialize safety system: ${err}')
		println('⚠️  Proceeding with default strict safety')
		safety.SafetyContext{
			config: safety.default_safety_config()
			rate_limiter: safety.new_rate_limiter(100)
			audit_log: safety.AuditLog{ log_file: '' }
			enabled: true
		}
	}
	safety_ctx.print_banner()

	// Check gh CLI authentication
	if !github.check_gh_cli_installed()! {
		println('ERROR: GitHub CLI (gh) is not installed')
		println('Please install it: https://cli.github.com/')
		return error('gh CLI not available')
	}

	if !github.check_gh_auth()! {
		println('ERROR: Not authenticated with GitHub CLI')
		println('Please run: gh auth login')
		return error('gh auth required')
	}

	if dry_run {
		println('[DRY RUN] No changes will be made')
		println('')
	}

	// Resolve repositories
	println('Resolving target repositories...')
	repos := utils.resolve_targets(targets, default_repos_dir, 2)
	println('Found ${repos.len} repositories')
	println('')

	if repos.len == 0 {
		println('No repositories found matching: ${targets}')
		return
	}

	// Pre-flight validation
	validation_result := safety_ctx.validate(repos, 'discussions-setup', dry_run) or {
		println('⚠️  Validation failed: ${err}')
		return error('Validation error')
	}

	safety.print_validation_result(validation_result)

	if !validation_result.passed {
		return error('Pre-flight validation failed')
	}

	// Convert to owner/repo format
	mut repo_names := []string{}
	for repo_path in repos {
		parts := repo_path.split(os.path_separator)
		if parts.len > 0 {
			repo_name := parts[parts.len - 1]
			repo_names << 'hyperpolymath/${repo_name}'
		}
	}

	// Safety check - should we proceed?
	if !safety_ctx.should_proceed(
		safety.OperationType.read_only,
		repo_names,
		'Check GitHub Discussions status',
		dry_run,
		force
	)! {
		println('Operation cancelled by user or safety system')
		safety_ctx.audit(safety.OperationType.read_only, repo_names, 'discussions-setup', 'CANCELLED')
		return
	}

	println('Setting up discussions for ${repo_names.len} repositories...')
	println('')

	// Execute discussions setup with rate limiting
	categories := github.default_discussion_categories()
	start_time := time.now()
	mut results := []github.DiscussionsSetupResult{}

	for i, repo_name in repo_names {
		if i > 0 {
			safety_ctx.rate_limit()
		}

		result := github.check_discussions_status(repo_name, categories, dry_run) or {
			results << github.DiscussionsSetupResult{
				repo: repo_name
				success: false
				enabled: false
				message: 'Error: ${err}'
			}
			continue
		}

		results << result

		if i % 10 == 0 && i > 0 {
			println('  Progress: ${i}/${repo_names.len}')
		}
	}

	duration := time.since(start_time)

	// Print summary
	github.print_discussions_summary(results)
	println('Completed in ${duration.seconds():.2f}s')

	println('')
	println('Note: Discussions must be manually enabled in GitHub repository settings')
	println('due to API limitations. This command verifies their status.')

	// Audit log
	safety_ctx.audit(safety.OperationType.read_only, repo_names, 'discussions-setup', 'SUCCESS')
}

fn cmd_pages_setup(cmd cli.Command) ! {
	targets := cmd.flags.get_string('targets')!
	source_str := cmd.flags.get_string('source') or { 'docs-main' }
	cname := cmd.flags.get_string('cname') or { '' }
	dry_run := cmd.flags.get_bool('dry-run') or { false }
	force := cmd.flags.get_bool('force') or { false }

	// Parse source parameter
	source := match source_str {
		'root-main' { github.PagesSource.root_main }
		'docs-main' { github.PagesSource.docs_main }
		'gh-pages' { github.PagesSource.root_gh_pages }
		else { github.PagesSource.docs_main }
	}

	println('GitHub Pages Setup')
	println('  Targets: ${targets}')
	println('  Source: ${source_str}')
	if cname != '' {
		println('  Custom domain: ${cname}')
	}
	println('  Dry Run: ${dry_run}')
	println('')

	// Initialize safety system
	mut safety_ctx := safety.new_safety_context() or {
		println('⚠️  Failed to initialize safety system: ${err}')
		println('⚠️  Proceeding with default strict safety')
		safety.SafetyContext{
			config: safety.default_safety_config()
			rate_limiter: safety.new_rate_limiter(100)
			audit_log: safety.AuditLog{ log_file: '' }
			enabled: true
		}
	}
	safety_ctx.print_banner()

	// Check gh CLI authentication
	if !github.check_gh_cli_installed()! {
		println('ERROR: GitHub CLI (gh) is not installed')
		println('Please install it: https://cli.github.com/')
		return error('gh CLI not available')
	}

	if !github.check_gh_auth()! {
		println('ERROR: Not authenticated with GitHub CLI')
		println('Please run: gh auth login')
		return error('gh auth required')
	}

	if dry_run {
		println('[DRY RUN] No changes will be made')
		println('')
	}

	// Resolve repositories
	println('Resolving target repositories...')
	repos := utils.resolve_targets(targets, default_repos_dir, 2)
	println('Found ${repos.len} repositories')
	println('')

	if repos.len == 0 {
		println('No repositories found matching: ${targets}')
		return
	}

	// Pre-flight validation
	validation_result := safety_ctx.validate(repos, 'pages-setup', dry_run) or {
		println('⚠️  Validation failed: ${err}')
		return error('Validation error')
	}

	safety.print_validation_result(validation_result)

	if !validation_result.passed {
		return error('Pre-flight validation failed')
	}

	// Convert to owner/repo format
	mut repo_names := []string{}
	for repo_path in repos {
		parts := repo_path.split(os.path_separator)
		if parts.len > 0 {
			repo_name := parts[parts.len - 1]
			repo_names << 'hyperpolymath/${repo_name}'
		}
	}

	// Safety check - should we proceed?
	if !safety_ctx.should_proceed(
		safety.OperationType.remote_changes,
		repo_names,
		'Enable GitHub Pages',
		dry_run,
		force
	)! {
		println('Operation cancelled by user or safety system')
		safety_ctx.audit(safety.OperationType.remote_changes, repo_names, 'pages-setup', 'CANCELLED')
		return
	}

	println('Setting up Pages for ${repo_names.len} repositories...')
	println('')

	// Execute Pages setup with rate limiting
	start_time := time.now()
	mut results := []github.PagesSetupResult{}

	for i, repo_name in repo_names {
		if i > 0 {
			safety_ctx.rate_limit()
		}

		result := github.setup_pages(github.PagesSetupParams{
			repo: repo_name
			source: source
			cname: cname
			dry_run: dry_run
		}) or {
			results << github.PagesSetupResult{
				repo: repo_name
				success: false
				url: ''
				message: 'Error: ${err}'
			}
			continue
		}

		results << result

		if i % 10 == 0 && i > 0 {
			println('  Progress: ${i}/${repo_names.len}')
		}
	}

	duration := time.since(start_time)

	// Print summary
	github.print_pages_summary(results)
	println('Completed in ${duration.seconds():.2f}s')

	// Check for failures
	mut failed := 0
	for result in results {
		if !result.success {
			failed++
		}
	}

	// Audit log
	status := if failed > 0 { 'PARTIAL_FAILURE' } else { 'SUCCESS' }
	safety_ctx.audit(safety.OperationType.remote_changes, repo_names, 'pages-setup', status)

	if failed > 0 {
		return error('Pages setup completed with failures')
	}
}

fn cmd_template_merge(cmd cli.Command) ! {
	targets := cmd.flags.get_string('targets')!
	workflows := cmd.flags.get_bool('workflows') or { true }
	scm_files := cmd.flags.get_bool('scm-files') or { true }
	bot_directives := cmd.flags.get_bool('bot-directives') or { true }
	contractiles := cmd.flags.get_bool('contractiles') or { true }
	preserve := cmd.flags.get_bool('preserve') or { true }
	dry_run := cmd.flags.get_bool('dry-run') or { false }
	force := cmd.flags.get_bool('force') or { false }

	println('Template Merge Operation')
	println('  Targets: ${targets}')
	println('  Add workflows: ${workflows}')
	println('  Add SCM files: ${scm_files}')
	println('  Add bot directives: ${bot_directives}')
	println('  Add contractiles: ${contractiles}')
	println('  Preserve existing: ${preserve}')
	println('  Dry Run: ${dry_run}')
	println('')

	// Initialize safety system
	mut safety_ctx := safety.new_safety_context() or {
		println('⚠️  Failed to initialize safety system: ${err}')
		println('⚠️  Proceeding with default strict safety')
		safety.SafetyContext{
			config: safety.default_safety_config()
			rate_limiter: safety.new_rate_limiter(100)
			audit_log: safety.AuditLog{ log_file: '' }
			enabled: true
		}
	}
	safety_ctx.print_banner()

	if dry_run {
		println('[DRY RUN] No changes will be made')
		println('')
	}

	// Resolve repositories
	println('Resolving target repositories...')
	repos := utils.resolve_targets(targets, default_repos_dir, 2)
	println('Found ${repos.len} repositories')
	println('')

	if repos.len == 0 {
		println('No repositories found matching: ${targets}')
		return
	}

	// Pre-flight validation
	validation_result := safety_ctx.validate(repos, 'template-merge', dry_run) or {
		println('⚠️  Validation failed: ${err}')
		return error('Validation error')
	}

	safety.print_validation_result(validation_result)

	if !validation_result.passed {
		return error('Pre-flight validation failed')
	}

	// Safety check - should we proceed?
	if !safety_ctx.should_proceed(
		safety.OperationType.local_changes,
		repos,
		'Convert to template form (preserve existing content)',
		dry_run,
		force
	)! {
		println('Operation cancelled by user or safety system')
		safety_ctx.audit(safety.OperationType.local_changes, repos, 'template-merge', 'CANCELLED')
		return
	}

	// Build template merge config
	config := templates.TemplateMergeConfig{
		add_github_workflows: workflows
		add_scm_files: scm_files
		add_bot_directives: bot_directives
		add_contractiles: contractiles
		add_justfile: true
		add_editorconfig: true
		preserve_existing: preserve
		template_source: 'rsr-template-repo'
	}

	println('Applying template merge to ${repos.len} repositories...')
	println('')

	// Execute template merge with rate limiting
	start_time := time.now()
	mut results := []templates.TemplateMergeResult{}

	for i, repo_path in repos {
		if i > 0 {
			safety_ctx.rate_limit()
		}

		result := templates.apply_template_merge(repo_path, config, dry_run) or {
			results << templates.TemplateMergeResult{
				repo_path: repo_path
				success: false
				files_added: 0
				files_preserved: 0
				files_updated: 0
				message: 'Error: ${err}'
			}
			continue
		}

		results << result

		// Progress indicator
		if i % 10 == 0 && i > 0 {
			println('  Progress: ${i}/${repos.len}')
		}
	}

	duration := time.since(start_time)

	// Print summary
	println('')
	println('Template Merge Summary')
	println('=====================')
	mut successful := 0
	mut failed := 0
	mut total_added := 0
	mut total_preserved := 0
	mut total_updated := 0

	for result in results {
		if result.success {
			successful++
			total_added += result.files_added
			total_preserved += result.files_preserved
			total_updated += result.files_updated
		} else {
			failed++
			println('  ✗ ${result.repo_path}: ${result.message}')
		}
	}

	println('')
	println('Results:')
	println('  Successful: ${successful}')
	println('  Failed: ${failed}')
	println('  Files added: ${total_added}')
	println('  Files preserved: ${total_preserved}')
	println('  Files updated: ${total_updated}')
	println('Completed in ${duration.seconds():.2f}s')

	// Audit log
	status := if failed > 0 { 'PARTIAL_FAILURE' } else { 'SUCCESS' }
	safety_ctx.audit(safety.OperationType.local_changes, repos, 'template-merge', status)

	if failed > 0 {
		return error('Template merge completed with failures')
	}
}
