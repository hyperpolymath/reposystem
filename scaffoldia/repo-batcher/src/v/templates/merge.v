// SPDX-License-Identifier: PMPL-1.0-or-later
//
// Template Merge Operations
// Convert existing repos into template form while preserving content

module templates

import os

// TemplateMergeConfig defines what to merge
pub struct TemplateMergeConfig {
pub:
	add_github_workflows    bool // Add standard workflows
	add_scm_files           bool // Add .machine_readable SCM files
	add_bot_directives      bool // Add .bot_directives
	add_contractiles        bool // Add contractiles directory
	add_justfile            bool // Add justfile
	add_editorconfig        bool // Add .editorconfig
	preserve_existing       bool // Don't overwrite existing files
	template_source         string // Path to template repo or 'default'
}

// TemplateMergeResult holds merge result for one repo
pub struct TemplateMergeResult {
pub:
	repo_path       string
	success         bool
	files_added     int
	files_preserved int
	files_updated   int
	message         string
}

// Default merge config - safe defaults
pub fn default_merge_config() TemplateMergeConfig {
	return TemplateMergeConfig{
		add_github_workflows: true
		add_scm_files: true
		add_bot_directives: true
		add_contractiles: true
		add_justfile: true
		add_editorconfig: true
		preserve_existing: true
		template_source: 'default'
	}
}

// Apply template merge to a repository
pub fn apply_template_merge(repo_path string, config TemplateMergeConfig, dry_run bool) !TemplateMergeResult {
	mut files_added := 0
	mut files_preserved := 0
	mut files_updated := 0

	// Verify repo exists
	if !os.exists(repo_path) {
		return error('Repository does not exist: ${repo_path}')
	}

	// Add GitHub workflows
	if config.add_github_workflows {
		result := merge_github_workflows(repo_path, config.preserve_existing, dry_run) or {
			return error('Failed to merge workflows: ${err}')
		}
		files_added += result.added
		files_preserved += result.preserved
		files_updated += result.updated
	}

	// Add SCM files
	if config.add_scm_files {
		result := merge_scm_files(repo_path, config.preserve_existing, dry_run) or {
			return error('Failed to merge SCM files: ${err}')
		}
		files_added += result.added
		files_preserved += result.preserved
		files_updated += result.updated
	}

	// Add bot directives
	if config.add_bot_directives {
		result := merge_bot_directives(repo_path, config.preserve_existing, dry_run) or {
			return error('Failed to merge bot directives: ${err}')
		}
		files_added += result.added
		files_preserved += result.preserved
		files_updated += result.updated
	}

	// Add contractiles
	if config.add_contractiles {
		result := merge_contractiles(repo_path, config.preserve_existing, dry_run) or {
			return error('Failed to merge contractiles: ${err}')
		}
		files_added += result.added
		files_preserved += result.preserved
		files_updated += result.updated
	}

	// Add justfile
	if config.add_justfile {
		result := merge_justfile(repo_path, config.preserve_existing, dry_run) or {
			return error('Failed to merge justfile: ${err}')
		}
		files_added += result.added
		files_preserved += result.preserved
		files_updated += result.updated
	}

	// Add editorconfig
	if config.add_editorconfig {
		result := merge_editorconfig(repo_path, config.preserve_existing, dry_run) or {
			return error('Failed to merge editorconfig: ${err}')
		}
		files_added += result.added
		files_preserved += result.preserved
		files_updated += result.updated
	}

	return TemplateMergeResult{
		repo_path: repo_path
		success: true
		files_added: files_added
		files_preserved: files_preserved
		files_updated: files_updated
		message: 'Merged template: ${files_added} added, ${files_preserved} preserved, ${files_updated} updated'
	}
}

// MergeStats tracks merge statistics
struct MergeStats {
	added     int
	preserved int
	updated   int
}

// Merge GitHub workflows
fn merge_github_workflows(repo_path string, preserve bool, dry_run bool) !MergeStats {
	mut stats := MergeStats{}

	workflows_dir := os.join_path(repo_path, '.github', 'workflows')

	if !dry_run {
		os.mkdir_all(workflows_dir) or {
			return error('Failed to create workflows directory: ${err}')
		}
	}

	// Standard workflows to add
	workflows := [
		'hypatia-scan.yml',
		'codeql.yml',
		'scorecard.yml',
		'quality.yml',
		'mirror.yml',
	]

	for workflow in workflows {
		workflow_path := os.join_path(workflows_dir, workflow)

		if os.exists(workflow_path) && preserve {
			stats.preserved++
		} else {
			if !dry_run {
				// Create workflow from template
				content := get_default_workflow_content(workflow) or {
					return error('Failed to get workflow template: ${err}')
				}
				os.write_file(workflow_path, content) or {
					return error('Failed to write workflow: ${err}')
				}
			}

			if os.exists(workflow_path) {
				stats.updated++
			} else {
				stats.added++
			}
		}
	}

	return stats
}

// Merge SCM files
fn merge_scm_files(repo_path string, preserve bool, dry_run bool) !MergeStats {
	mut stats := MergeStats{}

	scm_dir := os.join_path(repo_path, '.machine_readable')

	if !dry_run {
		os.mkdir_all(scm_dir) or {
			return error('Failed to create .machine_readable directory: ${err}')
		}
	}

	// Standard SCM files
	scm_files := [
		'META.scm',
		'ECOSYSTEM.scm',
		'STATE.scm',
		'CHECKLIST.scm',
		'ROADMAP.scm',
		'CHANGELOG.scm',
	]

	for scm_file in scm_files {
		scm_path := os.join_path(scm_dir, scm_file)

		if os.exists(scm_path) && preserve {
			stats.preserved++
		} else {
			if !dry_run {
				content := get_default_scm_content(scm_file, repo_path) or {
					return error('Failed to get SCM template: ${err}')
				}
				os.write_file(scm_path, content) or {
					return error('Failed to write SCM file: ${err}')
				}
			}

			if os.exists(scm_path) {
				stats.updated++
			} else {
				stats.added++
			}
		}
	}

	return stats
}

// Merge bot directives
fn merge_bot_directives(repo_path string, preserve bool, dry_run bool) !MergeStats {
	mut stats := MergeStats{}

	directives_dir := os.join_path(repo_path, '.bot_directives')

	if !dry_run {
		os.mkdir_all(directives_dir) or {
			return error('Failed to create .bot_directives directory: ${err}')
		}
	}

	// Standard bot directive files
	directive_files := [
		'rhodibot.scm',      // Release optimization
		'echidnabot.scm',    // Ecosystem health
		'sustainabot.scm',   // Sustainability
		'glambot.scm',       // Git log analysis
		'seambot.scm',       // Security/efficiency analysis
		'finishbot.scm',     // Task completion
	]

	for directive_file in directive_files {
		directive_path := os.join_path(directives_dir, directive_file)

		if os.exists(directive_path) && preserve {
			stats.preserved++
		} else {
			if !dry_run {
				content := get_default_bot_directive(directive_file, repo_path) or {
					return error('Failed to get bot directive template: ${err}')
				}
				os.write_file(directive_path, content) or {
					return error('Failed to write bot directive: ${err}')
				}
			}

			if os.exists(directive_path) {
				stats.updated++
			} else {
				stats.added++
			}
		}
	}

	return stats
}

// Merge contractiles directory
fn merge_contractiles(repo_path string, preserve bool, dry_run bool) !MergeStats {
	mut stats := MergeStats{}

	contractiles_dir := os.join_path(repo_path, 'contractiles')

	if !dry_run {
		os.mkdir_all(contractiles_dir) or {
			return error('Failed to create contractiles directory: ${err}')
		}

		// Create README in contractiles
		readme_path := os.join_path(contractiles_dir, 'README.md')
		if !os.exists(readme_path) || !preserve {
			content := get_contractiles_readme()
			os.write_file(readme_path, content) or {
				return error('Failed to write contractiles README: ${err}')
			}
			stats.added++
		} else {
			stats.preserved++
		}
	} else {
		stats.added++ // Would add README
	}

	return stats
}

// Merge justfile
fn merge_justfile(repo_path string, preserve bool, dry_run bool) !MergeStats {
	mut stats := MergeStats{}

	justfile_path := os.join_path(repo_path, 'justfile')

	if os.exists(justfile_path) && preserve {
		stats.preserved++
	} else {
		if !dry_run {
			content := get_default_justfile(repo_path) or {
				return error('Failed to get justfile template: ${err}')
			}
			os.write_file(justfile_path, content) or {
				return error('Failed to write justfile: ${err}')
			}
		}

		if os.exists(justfile_path) {
			stats.updated++
		} else {
			stats.added++
		}
	}

	return stats
}

// Merge editorconfig
fn merge_editorconfig(repo_path string, preserve bool, dry_run bool) !MergeStats {
	mut stats := MergeStats{}

	editorconfig_path := os.join_path(repo_path, '.editorconfig')

	if os.exists(editorconfig_path) && preserve {
		stats.preserved++
	} else {
		if !dry_run {
			content := get_default_editorconfig()
			os.write_file(editorconfig_path, content) or {
				return error('Failed to write .editorconfig: ${err}')
			}
		}

		if os.exists(editorconfig_path) {
			stats.updated++
		} else {
			stats.added++
		}
	}

	return stats
}

// Get default workflow content
fn get_default_workflow_content(workflow_name string) !string {
	return match workflow_name {
		'hypatia-scan.yml' { get_hypatia_workflow() }
		'codeql.yml' { get_codeql_workflow() }
		'scorecard.yml' { get_scorecard_workflow() }
		'quality.yml' { get_quality_workflow() }
		'mirror.yml' { get_mirror_workflow() }
		else { error('Unknown workflow: ${workflow_name}') }
	}
}

// Get default SCM content (implementations below)
fn get_default_scm_content(scm_file string, repo_path string) !string {
	repo_name := os.file_name(repo_path)

	return match scm_file {
		'META.scm' { get_meta_scm_template(repo_name) }
		'ECOSYSTEM.scm' { get_ecosystem_scm_template(repo_name) }
		'STATE.scm' { get_state_scm_template(repo_name) }
		'CHECKLIST.scm' { get_checklist_scm_template(repo_name) }
		'ROADMAP.scm' { get_roadmap_scm_template(repo_name) }
		'CHANGELOG.scm' { get_changelog_scm_template(repo_name) }
		else { error('Unknown SCM file: ${scm_file}') }
	}
}

// Get default bot directive
fn get_default_bot_directive(directive_file string, repo_path string) !string {
	repo_name := os.file_name(repo_path)

	return match directive_file {
		'rhodibot.scm' { get_rhodibot_directive(repo_name) }
		'echidnabot.scm' { get_echidnabot_directive(repo_name) }
		'sustainabot.scm' { get_sustainabot_directive(repo_name) }
		'glambot.scm' { get_glambot_directive(repo_name) }
		'seambot.scm' { get_seambot_directive(repo_name) }
		'finishbot.scm' { get_finishbot_directive(repo_name) }
		else { error('Unknown bot directive: ${directive_file}') }
	}
}

// Template content functions (to be implemented in separate file)
fn get_hypatia_workflow() string {
	return '; SPDX-License-Identifier: PMPL-1.0-or-later
; Hypatia neurosymbolic security scanning
; TODO: Implement full workflow
'
}

fn get_codeql_workflow() string {
	return '# SPDX-License-Identifier: PMPL-1.0-or-later
# CodeQL analysis workflow
# TODO: Implement full workflow
'
}

fn get_scorecard_workflow() string {
	return '# SPDX-License-Identifier: PMPL-1.0-or-later
# OpenSSF Scorecard workflow
# TODO: Implement full workflow
'
}

fn get_quality_workflow() string {
	return '# SPDX-License-Identifier: PMPL-1.0-or-later
# Quality checks workflow
# TODO: Implement full workflow
'
}

fn get_mirror_workflow() string {
	return '# SPDX-License-Identifier: PMPL-1.0-or-later
# Repository mirroring workflow
# TODO: Implement full workflow
'
}

fn get_contractiles_readme() string {
	return '# Contractiles

This directory contains contractile specifications for this project.

Contractiles are formal specifications that define project contracts,
interfaces, and guarantees.

## Structure

- `api/` - API contracts
- `guarantees/` - Formal guarantees
- `interfaces/` - Interface specifications
'
}

fn get_default_justfile(repo_path string) !string {
	return '# SPDX-License-Identifier: PMPL-1.0-or-later
# Justfile for project automation

# List available recipes
default:
    @just --list

# Run tests
test:
    echo "Running tests..."

# Build project
build:
    echo "Building project..."

# Format code
fmt:
    echo "Formatting code..."
'
}

fn get_default_editorconfig() string {
	return '# SPDX-License-Identifier: PMPL-1.0-or-later
# EditorConfig: https://editorconfig.org

root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
indent_style = space
indent_size = 2

[*.{md,adoc}]
trim_trailing_whitespace = false

[*.{v,go,rs}]
indent_size = 4

[Makefile]
indent_style = tab
'
}

// SCM template functions
fn get_meta_scm_template(repo_name string) string {
	return ';; SPDX-License-Identifier: PMPL-1.0-or-later
;; META.scm - Meta-level information

(define meta
  \'((project-name "${repo_name}")
    (license "PMPL-1.0-or-later")
    (author "Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>")
    (description "TODO: Add project description")
    (architecture-decisions
     ())
    (development-practices
     ())))
'
}

fn get_ecosystem_scm_template(repo_name string) string {
	return ';; SPDX-License-Identifier: PMPL-1.0-or-later
;; ECOSYSTEM.scm - Ecosystem position

(define ecosystem
  \'((project-name "${repo_name}")
    (version "1.0.0")
    (type "library")
    (purpose "TODO: Define purpose")
    (position-in-ecosystem "standalone")
    (related-projects
     ())))
'
}

fn get_state_scm_template(repo_name string) string {
	return ';; SPDX-License-Identifier: PMPL-1.0-or-later
;; STATE.scm - Current project state

(define state
  \'((metadata
     (version "1.0.0")
     (project "${repo_name}")
     (updated "TODO"))
    (current-position
     (phase "initial")
     (overall-completion 0))
    (critical-next-actions
     ())))
'
}

fn get_checklist_scm_template(repo_name string) string {
	return ';; SPDX-License-Identifier: PMPL-1.0-or-later
;; CHECKLIST.scm - Project checklist

(define checklist
  \'((project "${repo_name}")
    (items
     ())))
'
}

fn get_roadmap_scm_template(repo_name string) string {
	return ';; SPDX-License-Identifier: PMPL-1.0-or-later
;; ROADMAP.scm - Project roadmap

(define roadmap
  \'((project "${repo_name}")
    (milestones
     ())))
'
}

fn get_changelog_scm_template(repo_name string) string {
	return ';; SPDX-License-Identifier: PMPL-1.0-or-later
;; CHANGELOG.scm - Project changelog

(define changelog
  \'((project "${repo_name}")
    (entries
     ())))
'
}

// Bot directive templates
fn get_rhodibot_directive(repo_name string) string {
	return ';; SPDX-License-Identifier: PMPL-1.0-or-later
;; rhodibot.scm - Release optimization directives

(define rhodibot-config
  \'((repo "${repo_name}")
    (release-strategy "semantic-versioning")
    (auto-release false)
    (changelog-generation true)))
'
}

fn get_echidnabot_directive(repo_name string) string {
	return ';; SPDX-License-Identifier: PMPL-1.0-or-later
;; echidnabot.scm - Ecosystem health directives

(define echidnabot-config
  \'((repo "${repo_name}")
    (health-checks
     ("dependencies" "security" "performance"))
    (monitoring-interval "daily")))
'
}

fn get_sustainabot_directive(repo_name string) string {
	return ';; SPDX-License-Identifier: PMPL-1.0-or-later
;; sustainabot.scm - Sustainability directives

(define sustainabot-config
  \'((repo "${repo_name}")
    (sustainability-checks
     ("dependencies" "maintenance" "documentation"))
    (auto-update-deps false)))
'
}

fn get_glambot_directive(repo_name string) string {
	return ';; SPDX-License-Identifier: PMPL-1.0-or-later
;; glambot.scm - Git log analysis directives

(define glambot-config
  \'((repo "${repo_name}")
    (analyze-commits true)
    (commit-message-style "conventional-commits")
    (report-frequency "weekly")))
'
}

fn get_seambot_directive(repo_name string) string {
	return ';; SPDX-License-Identifier: PMPL-1.0-or-later
;; seambot.scm - Security/efficiency analysis directives

(define seambot-config
  \'((repo "${repo_name}")
    (security-scans
     ("dependencies" "code" "containers"))
    (efficiency-analysis true)))
'
}

fn get_finishbot_directive(repo_name string) string {
	return ';; SPDX-License-Identifier: PMPL-1.0-or-later
;; finishbot.scm - Task completion directives

(define finishbot-config
  \'((repo "${repo_name}")
    (auto-close-stale-issues true)
    (stale-after-days 90)
    (track-completion true)))
'
}

// Batch apply template merge
pub fn apply_template_merge_batch(repos []string, config TemplateMergeConfig, dry_run bool) []TemplateMergeResult {
	mut results := []TemplateMergeResult{}

	for repo in repos {
		result := apply_template_merge(repo, config, dry_run) or {
			results << TemplateMergeResult{
				repo_path: repo
				success: false
				files_added: 0
				files_preserved: 0
				files_updated: 0
				message: 'Error: ${err}'
			}
			continue
		}

		results << result
	}

	return results
}

// Print merge summary
pub fn print_merge_summary(results []TemplateMergeResult) {
	mut total_added := 0
	mut total_preserved := 0
	mut total_updated := 0
	mut success_count := 0
	mut failed_count := 0

	println('Template Merge Results:')
	println('======================')
	println('')

	for result in results {
		if result.success {
			success_count++
			total_added += result.files_added
			total_preserved += result.files_preserved
			total_updated += result.files_updated
			println('✓ ${result.repo_path}')
			println('  ${result.message}')
		} else {
			failed_count++
			println('✗ ${result.repo_path}')
			println('  ${result.message}')
		}
	}

	println('')
	println('Summary:')
	println('  Success: ${success_count}')
	println('  Failed: ${failed_count}')
	println('  Files added: ${total_added}')
	println('  Files preserved: ${total_preserved}')
	println('  Files updated: ${total_updated}')
}
