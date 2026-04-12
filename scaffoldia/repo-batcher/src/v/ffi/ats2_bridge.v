// SPDX-License-Identifier: PMPL-1.0-or-later
//
// ATS2 FFI Bridge
// V bindings for ATS2 formally verified operations

module ffi

// C-compatible structures matching ATS2 exports
pub struct CBatchResult {
pub mut:
	success_count int
	failure_count int
	skipped_count int
	message       &char
}

pub struct CAuditStats {
pub mut:
	total_files    int
	with_spdx      int
	without_spdx   int
	invalid_spdx   int
	pmpl_license   int
	other_licenses int
}

pub struct CAuditResult {
pub mut:
	repo_path          &char
	stats              CAuditStats
	compliance_percent int
}

pub struct CAuditResults {
pub mut:
	total_repos int
	results     voidptr
}

pub struct CGitHubSettings {
pub mut:
	// Repository features (-1=none, 0=false, 1=true)
	has_issues    int
	has_wiki      int
	has_projects  int
	has_downloads int
	// Merge settings
	allow_squash_merge     int
	allow_merge_commit     int
	allow_rebase_merge     int
	delete_branch_on_merge int
	allow_auto_merge       int
}

// Convert C string to V string
fn c_string_to_v(s &char) string {
	if s == 0 {
		return ''
	}
	return unsafe { cstring_to_vstring(s) }
}

// ========== ATS2 C Function Declarations ==========

fn C.c_validate_spdx(&char) int

fn C.c_license_update(&char, &char, &char, int, int, int) CBatchResult

fn C.c_git_sync(&char, int, &char, int, int) CBatchResult

fn C.c_file_replace(&char, &char, &char, int, int, int) CBatchResult

fn C.c_workflow_update(&char, int, int, int) CBatchResult

fn C.c_spdx_audit(&char, int) CAuditResults

fn C.c_github_settings(&char, int, CGitHubSettings, int) int

fn C.c_get_version() &char

// ========== V-friendly wrappers ==========

// BatchResult is the V-friendly version of batch results
pub struct BatchResult {
pub mut:
	success_count int
	failure_count int
	skipped_count int
	message       string
}

// Validates SPDX identifier
// Returns true if valid, false otherwise
pub fn validate_spdx(license string) bool {
	result := C.c_validate_spdx(license.str)
	return result == 1
}

// LicenseUpdateParams contains parameters for license update
pub struct LicenseUpdateParams {
pub:
	old_license string
	new_license string
	base_dir    string
	max_depth   int
	dry_run     bool
	backup      bool
}

// Performs license update operation
// Calls formally verified ATS2 implementation
pub fn license_update(params LicenseUpdateParams) BatchResult {
	dry_run_flag := if params.dry_run { 1 } else { 0 }
	backup_flag := if params.backup { 1 } else { 0 }

	c_result := C.c_license_update(
		params.old_license.str,
		params.new_license.str,
		params.base_dir.str,
		params.max_depth,
		dry_run_flag,
		backup_flag
	)

	return BatchResult{
		success_count: c_result.success_count
		failure_count: c_result.failure_count
		skipped_count: c_result.skipped_count
		message: c_string_to_v(c_result.message)
	}
}

// GitSyncParams contains parameters for git sync
pub struct GitSyncParams {
pub:
	base_dir      string
	max_depth     int
	commit_msg    string
	parallel_jobs int
	dry_run       bool
}

// Performs git batch sync operation
// Calls formally verified ATS2 implementation
// This replaces sync_repos.sh with type-safe version
pub fn git_sync(params GitSyncParams) BatchResult {
	dry_run_flag := if params.dry_run { 1 } else { 0 }

	c_result := C.c_git_sync(
		params.base_dir.str,
		params.max_depth,
		params.commit_msg.str,
		params.parallel_jobs,
		dry_run_flag
	)

	return BatchResult{
		success_count: c_result.success_count
		failure_count: c_result.failure_count
		skipped_count: c_result.skipped_count
		message: c_string_to_v(c_result.message)
	}
}

// FileReplaceParams contains parameters for file replace
pub struct FileReplaceParams {
pub:
	pattern     string
	replacement string
	base_dir    string
	max_depth   int
	dry_run     bool
	backup      bool
}

// Performs file replace operation
// Calls formally verified ATS2 implementation
pub fn file_replace(params FileReplaceParams) BatchResult {
	dry_run_flag := if params.dry_run { 1 } else { 0 }
	backup_flag := if params.backup { 1 } else { 0 }

	c_result := C.c_file_replace(
		params.pattern.str,
		params.replacement.str,
		params.base_dir.str,
		params.max_depth,
		dry_run_flag,
		backup_flag
	)

	return BatchResult{
		success_count: c_result.success_count
		failure_count: c_result.failure_count
		skipped_count: c_result.skipped_count
		message: c_string_to_v(c_result.message)
	}
}

// Gets version from ATS2 core
pub fn get_version() string {
	c_version := C.c_get_version()
	return c_string_to_v(c_version)
}

// Prints batch result in human-readable format
pub fn (result BatchResult) print() {
	println('\n=== Batch Operation Results ===')
	println('Success: ${result.success_count}')
	println('Failure: ${result.failure_count}')
	println('Skipped: ${result.skipped_count}')
	println('Total:   ${result.success_count + result.failure_count + result.skipped_count}')
	if result.message != '' {
		println('\nMessage: ${result.message}')
	}
	println('')
}

// Checks if operation was successful
pub fn (result BatchResult) is_success() bool {
	return result.failure_count == 0
}

// Checks if any operations failed
pub fn (result BatchResult) has_failures() bool {
	return result.failure_count > 0
}

// WorkflowUpdateParams contains parameters for workflow update
pub struct WorkflowUpdateParams {
pub:
	base_dir  string
	max_depth int
	backup    bool
	dry_run   bool
}

// Performs workflow update with SHA pinning
// Updates GitHub Actions workflows across repositories
pub fn workflow_update(params WorkflowUpdateParams) BatchResult {
	dry_run_flag := if params.dry_run { 1 } else { 0 }
	backup_flag := if params.backup { 1 } else { 0 }

	c_result := C.c_workflow_update(
		params.base_dir.str,
		params.max_depth,
		backup_flag,
		dry_run_flag
	)

	return BatchResult{
		success_count: c_result.success_count
		failure_count: c_result.failure_count
		skipped_count: c_result.skipped_count
		message: c_string_to_v(c_result.message)
	}
}

// AuditStats contains SPDX audit statistics
pub struct AuditStats {
pub mut:
	total_files    int
	with_spdx      int
	without_spdx   int
	invalid_spdx   int
	pmpl_license   int
	other_licenses int
}

// AuditResult contains audit results for a single repository
pub struct AuditResult {
pub mut:
	repo_path          string
	stats              AuditStats
	compliance_percent int
}

// SPDXAuditParams contains parameters for SPDX audit
pub struct SPDXAuditParams {
pub:
	base_dir  string
	max_depth int
}

// Performs SPDX license header audit
// Scans all source files for SPDX identifiers
pub fn spdx_audit(params SPDXAuditParams) []AuditResult {
	c_results := C.c_spdx_audit(
		params.base_dir.str,
		params.max_depth
	)

	// Convert C results to V array
	mut results := []AuditResult{}

	// For now, return empty array since we need to implement proper C array conversion
	// Full implementation would iterate through c_results.results pointer
	return results
}

// Prints audit results in human-readable format
pub fn print_audit_results(results []AuditResult) {
	println('\n=== SPDX Audit Results ===')
	println('Total repositories scanned: ${results.len}')
	println('')

	mut total_files := 0
	mut total_with_spdx := 0
	mut total_without_spdx := 0
	mut total_pmpl := 0

	for result in results {
		total_files += result.stats.total_files
		total_with_spdx += result.stats.with_spdx
		total_without_spdx += result.stats.without_spdx
		total_pmpl += result.stats.pmpl_license

		if result.stats.without_spdx > 0 || result.stats.invalid_spdx > 0 {
			println('Repository: ${result.repo_path}')
			println('  Compliance: ${result.compliance_percent}%')
			println('  Total files: ${result.stats.total_files}')
			println('  With SPDX: ${result.stats.with_spdx}')
			println('  Without SPDX: ${result.stats.without_spdx}')
			println('  Invalid SPDX: ${result.stats.invalid_spdx}')
			println('  PMPL-licensed: ${result.stats.pmpl_license}')
			println('')
		}
	}

	println('=== Summary ===')
	println('Total files scanned: ${total_files}')
	println('With SPDX headers: ${total_with_spdx}')
	println('Without SPDX headers: ${total_without_spdx}')
	println('PMPL-1.0-or-later: ${total_pmpl}')

	if total_files > 0 {
		compliance := (total_with_spdx * 100) / total_files
		println('Overall compliance: ${compliance}%')
	}
	println('')
}

// GitHubSettingsParams contains parameters for GitHub settings operation
pub struct GitHubSettingsParams {
pub:
	base_dir  string
	max_depth int
	// Repository features (none = don't change)
	has_issues    ?bool
	has_wiki      ?bool
	has_projects  ?bool
	has_downloads ?bool
	// Merge settings
	allow_squash_merge     ?bool
	allow_merge_commit     ?bool
	allow_rebase_merge     ?bool
	delete_branch_on_merge ?bool
	allow_auto_merge       ?bool
	// Options
	dry_run bool
}

// Convert ?bool to C int representation (-1=none, 0=false, 1=true)
fn option_bool_to_int(opt ?bool) int {
	if val := opt {
		return if val { 1 } else { 0 }
	}
	return -1
}

// Performs GitHub settings update across repositories
// Applies repository configuration changes via GitHub API
pub fn github_settings(params GitHubSettingsParams) int {
	dry_run_flag := if params.dry_run { 1 } else { 0 }

	c_settings := CGitHubSettings{
		has_issues: option_bool_to_int(params.has_issues)
		has_wiki: option_bool_to_int(params.has_wiki)
		has_projects: option_bool_to_int(params.has_projects)
		has_downloads: option_bool_to_int(params.has_downloads)
		allow_squash_merge: option_bool_to_int(params.allow_squash_merge)
		allow_merge_commit: option_bool_to_int(params.allow_merge_commit)
		allow_rebase_merge: option_bool_to_int(params.allow_rebase_merge)
		delete_branch_on_merge: option_bool_to_int(params.delete_branch_on_merge)
		allow_auto_merge: option_bool_to_int(params.allow_auto_merge)
	}

	success_count := C.c_github_settings(
		params.base_dir.str,
		params.max_depth,
		c_settings,
		dry_run_flag
	)

	return success_count
}
