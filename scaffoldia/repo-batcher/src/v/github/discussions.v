// SPDX-License-Identifier: PMPL-1.0-or-later
//
// GitHub Discussions Setup
// Enable and configure discussions in bulk

module github

import os
import json

// DiscussionCategory represents a discussion category
pub struct DiscussionCategory {
pub:
	name        string
	description string
	emoji       string  // Emoji for the category
}

// DiscussionsSetupParams contains parameters for discussions setup
pub struct DiscussionsSetupParams {
pub:
	repo_owner  string
	repo_name   string
	categories  []DiscussionCategory
	dry_run     bool
}

// DiscussionsSetupResult contains the result of discussions setup
pub struct DiscussionsSetupResult {
pub:
	repo_path           string
	success             bool
	discussions_enabled bool
	categories_created  int
	message             string
}

// Default discussion categories
pub fn default_discussion_categories() []DiscussionCategory {
	return [
		DiscussionCategory{
			name: 'Announcements'
			description: 'Project updates and announcements'
			emoji: '📢'
		},
		DiscussionCategory{
			name: 'Q&A'
			description: 'Questions and answers from the community'
			emoji: '🙋'
		},
		DiscussionCategory{
			name: 'Ideas'
			description: 'Share ideas for new features'
			emoji: '💡'
		},
		DiscussionCategory{
			name: 'Show and tell'
			description: 'Show off something you\'ve built'
			emoji: '🎨'
		},
		DiscussionCategory{
			name: 'General'
			description: 'General discussion about the project'
			emoji: '💬'
		},
	]
}

// Setup discussions for a repository
pub fn setup_discussions(params DiscussionsSetupParams) !DiscussionsSetupResult {
	repo_full := '${params.repo_owner}/${params.repo_name}'

	if params.dry_run {
		return DiscussionsSetupResult{
			repo_path: repo_full
			success: true
			discussions_enabled: false
			categories_created: params.categories.len
			message: '[DRY RUN] Would enable discussions with ${params.categories.len} categories'
		}
	}

	// Step 1: Check if discussions are already enabled
	println('  Checking discussions status...')
	check_result := os.execute('gh api "/repos/${repo_full}" --jq .has_discussions 2>/dev/null')

	if check_result.exit_code == 0 && check_result.output.trim() == 'true' {
		println('  Discussions already enabled')
		return DiscussionsSetupResult{
			repo_path: repo_full
			success: true
			discussions_enabled: true
			categories_created: 0
			message: 'Discussions already enabled'
		}
	}

	// Step 2: Enable discussions feature
	println('  Enabling discussions...')

	// Note: GitHub API doesn't have a direct endpoint to enable discussions
	// This requires GraphQL API or manual setup
	// For now, we'll document this limitation

	return DiscussionsSetupResult{
		repo_path: repo_full
		success: false
		discussions_enabled: false
		categories_created: 0
		message: 'Discussions must be enabled manually (GitHub API limitation)'
	}

	// TODO: Implement GraphQL mutation to enable discussions
	// mutation {
	//   updateRepository(input: {
	//     repositoryId: "REPO_ID"
	//     hasDiscussionsEnabled: true
	//   }) {
	//     repository {
	//       hasDiscussionsEnabled
	//     }
	//   }
	// }
}

// Check if discussions are enabled for a repository
pub fn check_discussions_enabled(repo_owner string, repo_name string) bool {
	repo_full := '${repo_owner}/${repo_name}'
	result := os.execute('gh api "/repos/${repo_full}" --jq .has_discussions 2>/dev/null')
	return result.exit_code == 0 && result.output.trim() == 'true'
}

// Setup discussions for multiple repositories
pub fn setup_discussions_batch(repos []string, categories []DiscussionCategory, dry_run bool) []DiscussionsSetupResult {
	mut results := []DiscussionsSetupResult{}

	for repo in repos {
		// Parse owner/repo format
		parts := repo.split('/')
		if parts.len != 2 {
			results << DiscussionsSetupResult{
				repo_path: repo
				success: false
				discussions_enabled: false
				categories_created: 0
				message: 'Invalid repo format (expected owner/repo)'
			}
			continue
		}

		println('Setting up discussions for ${repo}...')
		result := setup_discussions(DiscussionsSetupParams{
			repo_owner: parts[0]
			repo_name: parts[1]
			categories: categories
			dry_run: dry_run
		}) or {
			DiscussionsSetupResult{
				repo_path: repo
				success: false
				discussions_enabled: false
				categories_created: 0
				message: 'Error: ${err}'
			}
		}
		results << result
		println('  ${result.message}')
	}

	return results
}

// Print discussions setup summary
pub fn print_discussions_summary(results []DiscussionsSetupResult) {
	mut success := 0
	mut already_enabled := 0
	mut failed := 0

	for result in results {
		if result.success {
			if result.discussions_enabled {
				already_enabled++
			} else {
				success++
			}
		} else {
			failed++
		}
	}

	println('')
	println('=== Discussions Setup Summary ===')
	println('Total repositories: ${results.len}')
	println('Successfully enabled: ${success}')
	println('Already enabled: ${already_enabled}')
	println('Failed: ${failed}')
	println('')

	// Note about manual setup if needed
	if failed > 0 {
		println('Note: Discussions must be manually enabled in repository settings')
		println('due to GitHub API limitations. Use this tool to verify status.')
		println('')
	}
}
