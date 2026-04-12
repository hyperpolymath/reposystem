// SPDX-License-Identifier: PMPL-1.0-or-later
//
// GitHub Settings API Integration
// Implements bulk repository configuration via GitHub REST API

module github

import os
import json

// ========== Type Definitions ==========

pub struct RepoFeatures {
pub mut:
	has_issues    ?bool
	has_wiki      ?bool
	has_projects  ?bool
	has_downloads ?bool
}

pub struct MergeSettings {
pub mut:
	allow_squash_merge      ?bool
	allow_merge_commit      ?bool
	allow_rebase_merge      ?bool
	delete_branch_on_merge  ?bool
	allow_auto_merge        ?bool
}

pub struct GitHubSettings {
pub mut:
	repo_features  RepoFeatures
	merge_settings MergeSettings
}

pub struct SettingsResult {
pub:
	repo_path        string
	success          bool
	changes_applied  int
	message          string
}

// ========== GitHub API Client ==========

struct GitHubClient {
	dry_run bool
}

fn new_client(dry_run bool) GitHubClient {
	return GitHubClient{
		dry_run: dry_run
	}
}

// Execute gh api command
fn (c GitHubClient) gh_api(method string, endpoint string, data map[string]json.Any) !string {
	if c.dry_run {
		println('[DRY RUN] Would call: gh api ${method} ${endpoint}')
		println('[DRY RUN] With data: ${data}')
		return ''
	}

	mut args := ['api', '-X', method, endpoint]

	// Add JSON fields
	for key, value in data {
		match value {
			bool {
				args << '-F'
				args << '${key}=${value}'
			}
			string {
				args << '-f'
				args << '${key}=${value}'
			}
			else {
				args << '-f'
				args << '${key}=${value}'
			}
		}
	}

	result := os.execute('gh ${args.join(' ')}')

	if result.exit_code != 0 {
		return error('gh api failed: ${result.output}')
	}

	return result.output
}

// ========== Repository Feature Settings ==========

fn (c GitHubClient) apply_repo_features(repo string, features RepoFeatures) !(bool, int) {
	mut changes := 0
	mut data := map[string]json.Any{}

	// Build update payload
	if has_issues := features.has_issues {
		data['has_issues'] = json.Any(has_issues)
		changes++
	}
	if has_wiki := features.has_wiki {
		data['has_wiki'] = json.Any(has_wiki)
		changes++
	}
	if has_projects := features.has_projects {
		data['has_projects'] = json.Any(has_projects)
		changes++
	}
	if has_downloads := features.has_downloads {
		data['has_downloads'] = json.Any(has_downloads)
		changes++
	}

	if changes == 0 {
		return true, 0
	}

	endpoint := '/repos/${repo}'

	if c.dry_run {
		println('[DRY RUN] Would update ${repo} with ${changes} repo feature changes')
		return true, changes
	}

	c.gh_api('PATCH', endpoint, data) or {
		eprintln('Failed to update repo features for ${repo}: ${err}')
		return false, 0
	}

	return true, changes
}

// ========== Merge Settings ==========

fn (c GitHubClient) apply_merge_settings(repo string, settings MergeSettings) !(bool, int) {
	mut changes := 0
	mut data := map[string]json.Any{}

	// Build update payload
	if allow_squash := settings.allow_squash_merge {
		data['allow_squash_merge'] = json.Any(allow_squash)
		changes++
	}
	if allow_merge := settings.allow_merge_commit {
		data['allow_merge_commit'] = json.Any(allow_merge)
		changes++
	}
	if allow_rebase := settings.allow_rebase_merge {
		data['allow_rebase_merge'] = json.Any(allow_rebase)
		changes++
	}
	if delete_branch := settings.delete_branch_on_merge {
		data['delete_branch_on_merge'] = json.Any(delete_branch)
		changes++
	}
	if allow_auto := settings.allow_auto_merge {
		data['allow_auto_merge'] = json.Any(allow_auto)
		changes++
	}

	if changes == 0 {
		return true, 0
	}

	endpoint := '/repos/${repo}'

	if c.dry_run {
		println('[DRY RUN] Would update ${repo} with ${changes} merge setting changes')
		return true, changes
	}

	c.gh_api('PATCH', endpoint, data) or {
		eprintln('Failed to update merge settings for ${repo}: ${err}')
		return false, 0
	}

	return true, changes
}

// ========== Complete Settings Application ==========

pub fn apply_settings(repo string, settings GitHubSettings, dry_run bool) !SettingsResult {
	client := new_client(dry_run)

	// Apply repository features
	features_ok, features_count := client.apply_repo_features(repo, settings.repo_features) or {
		return SettingsResult{
			repo_path: repo
			success: false
			changes_applied: 0
			message: 'Failed to apply repository features: ${err}'
		}
	}

	// Apply merge settings
	merge_ok, merge_count := client.apply_merge_settings(repo, settings.merge_settings) or {
		return SettingsResult{
			repo_path: repo
			success: false
			changes_applied: features_count
			message: 'Failed to apply merge settings: ${err}'
		}
	}

	// Compute results
	success := features_ok && merge_ok
	total_changes := features_count + merge_count

	message := if dry_run {
		'[DRY RUN] Would apply ${total_changes} changes'
	} else if success {
		'Applied ${total_changes} changes successfully'
	} else {
		'Failed to apply all settings'
	}

	return SettingsResult{
		repo_path: repo
		success: success
		changes_applied: total_changes
		message: message
	}
}

// ========== Batch Operations ==========

pub fn apply_settings_batch(repos []string, settings GitHubSettings, dry_run bool) []SettingsResult {
	mut results := []SettingsResult{}

	for repo in repos {
		result := apply_settings(repo, settings, dry_run) or {
			SettingsResult{
				repo_path: repo
				success: false
				changes_applied: 0
				message: 'Error: ${err}'
			}
		}
		results << result
	}

	return results
}

// ========== Summary Statistics ==========

pub struct SettingsSummary {
pub:
	total_repos      int
	successful       int
	failed           int
	total_changes    int
}

pub fn compute_summary(results []SettingsResult) SettingsSummary {
	mut successful := 0
	mut failed := 0
	mut total_changes := 0

	for result in results {
		if result.success {
			successful++
			total_changes += result.changes_applied
		} else {
			failed++
		}
	}

	return SettingsSummary{
		total_repos: results.len
		successful: successful
		failed: failed
		total_changes: total_changes
	}
}

pub fn print_summary(summary SettingsSummary) {
	println('=== GitHub Settings Summary ===')
	println('Total repositories: ${summary.total_repos}')
	println('Successful: ${summary.successful}')
	println('Failed: ${summary.failed}')
	println('Total changes applied: ${summary.total_changes}')
	println('')
}

// ========== Authentication Check ==========

pub fn check_gh_auth() !bool {
	result := os.execute('gh auth status')
	return result.exit_code == 0
}

pub fn check_gh_cli_installed() !bool {
	result := os.execute('gh --version')
	return result.exit_code == 0
}
