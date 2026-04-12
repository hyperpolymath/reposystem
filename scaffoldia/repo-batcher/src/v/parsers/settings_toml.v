// SPDX-License-Identifier: PMPL-1.0-or-later
//
// Settings TOML Parser
// Parses GitHub repository settings from TOML configuration files

module parsers

import toml
import github

// Parse GitHub settings from TOML file
pub fn parse_settings_toml(file_path string) !github.GitHubSettings {
	content := toml.parse_file(file_path) or {
		return error('Failed to parse TOML file: ${err}')
	}

	mut settings := github.GitHubSettings{
		repo_features: github.RepoFeatures{}
		merge_settings: github.MergeSettings{}
	}

	// Parse repository features
	if repo_table := content.value('repository') {
		if repo_map := repo_table.as_map() {
			settings.repo_features.has_issues = parse_bool_option(repo_map, 'has_issues')
			settings.repo_features.has_wiki = parse_bool_option(repo_map, 'has_wiki')
			settings.repo_features.has_projects = parse_bool_option(repo_map, 'has_projects')
			settings.repo_features.has_downloads = parse_bool_option(repo_map, 'has_downloads')
		}
	}

	// Parse merge settings
	if merge_table := content.value('merge') {
		if merge_map := merge_table.as_map() {
			settings.merge_settings.allow_squash_merge = parse_bool_option(merge_map, 'allow_squash_merge')
			settings.merge_settings.allow_merge_commit = parse_bool_option(merge_map, 'allow_merge_commit')
			settings.merge_settings.allow_rebase_merge = parse_bool_option(merge_map, 'allow_rebase_merge')
			settings.merge_settings.delete_branch_on_merge = parse_bool_option(merge_map, 'delete_branch_on_merge')
			settings.merge_settings.allow_auto_merge = parse_bool_option(merge_map, 'allow_auto_merge')
		}
	}

	return settings
}

// Parse boolean option from TOML map
fn parse_bool_option(map map[string]toml.Any, key string) ?bool {
	if val := map[key] {
		if b := val.bool() {
			return b
		}
	}
	return none
}

// Validate settings configuration
pub fn validate_settings(settings github.GitHubSettings) !bool {
	mut changes := 0

	// Count repository feature changes
	if _ := settings.repo_features.has_issues { changes++ }
	if _ := settings.repo_features.has_wiki { changes++ }
	if _ := settings.repo_features.has_projects { changes++ }
	if _ := settings.repo_features.has_downloads { changes++ }

	// Count merge setting changes
	if _ := settings.merge_settings.allow_squash_merge { changes++ }
	if _ := settings.merge_settings.allow_merge_commit { changes++ }
	if _ := settings.merge_settings.allow_rebase_merge { changes++ }
	if _ := settings.merge_settings.delete_branch_on_merge { changes++ }
	if _ := settings.merge_settings.allow_auto_merge { changes++ }

	// Must have at least one change
	if changes == 0 {
		return error('No settings changes specified')
	}

	// Too many changes might be dangerous
	if changes > 20 {
		return error('Too many simultaneous changes (${changes} > 20)')
	}

	return true
}

// Generate example settings TOML
pub fn generate_example_toml() string {
	return '# GitHub Repository Settings Configuration
#
# All settings are optional. Omit a setting to leave it unchanged.
# Use true/false to enable/disable features.

[repository]
has_issues = true
has_wiki = false
has_projects = true
has_downloads = false

[merge]
allow_squash_merge = true
allow_merge_commit = false
allow_rebase_merge = false
delete_branch_on_merge = true
allow_auto_merge = false
'
}
