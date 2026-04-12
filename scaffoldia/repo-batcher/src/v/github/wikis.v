// SPDX-License-Identifier: PMPL-1.0-or-later
//
// GitHub Wiki Setup
// Initialize wikis with first page to enable automation

module github

import os

// WikiSetupParams contains parameters for wiki initialization
pub struct WikiSetupParams {
pub:
	repo_owner   string
	repo_name    string
	home_content string  // Content for Home.md (first page)
	dry_run      bool
}

// WikiSetupResult contains the result of wiki setup
pub struct WikiSetupResult {
pub:
	repo_path    string
	success      bool
	wiki_existed bool
	message      string
}

// Setup wiki for a repository
// This solves the "first page problem" where wikis aren't usable until
// someone manually creates the first page through the UI
pub fn setup_wiki(params WikiSetupParams) !WikiSetupResult {
	repo_full := '${params.repo_owner}/${params.repo_name}'

	if params.dry_run {
		return WikiSetupResult{
			repo_path: repo_full
			success: true
			wiki_existed: false
			message: '[DRY RUN] Would initialize wiki'
		}
	}

	// Step 1: Enable wiki feature via API
	println('  Enabling wiki feature...')
	enable_result := os.execute('gh api -X PATCH "/repos/${repo_full}" -f has_wiki=true')
	if enable_result.exit_code != 0 {
		return WikiSetupResult{
			repo_path: repo_full
			success: false
			wiki_existed: false
			message: 'Failed to enable wiki feature: ${enable_result.output}'
		}
	}

	// Step 2: Check if wiki already exists
	println('  Checking if wiki exists...')
	check_result := os.execute('gh api "/repos/${repo_full}/pages" 2>/dev/null')
	wiki_exists := check_result.exit_code == 0

	if wiki_exists {
		return WikiSetupResult{
			repo_path: repo_full
			success: true
			wiki_existed: true
			message: 'Wiki already initialized'
		}
	}

	// Step 3: Initialize wiki with first page
	// GitHub quirk: wiki repo doesn't exist until first page is created
	// We'll use git directly to create it
	println('  Creating first wiki page...')

	tmp_dir := os.join_path(os.temp_dir(), 'repo-batcher-wiki-${params.repo_name}')

	// Clean up any existing temp directory
	os.rmdir_all(tmp_dir) or {}

	// Initialize local git repo
	os.execute('git init "${tmp_dir}"') or {
		return WikiSetupResult{
			repo_path: repo_full
			success: false
			wiki_existed: false
			message: 'Failed to initialize temp git repo'
		}
	}

	// Create Home.md with content
	home_path := os.join_path(tmp_dir, 'Home.md')
	os.write_file(home_path, params.home_content) or {
		os.rmdir_all(tmp_dir) or {}
		return WikiSetupResult{
			repo_path: repo_full
			success: false
			wiki_existed: false
			message: 'Failed to write Home.md: ${err}'
		}
	}

	// Set up git remote and push
	wiki_url := 'https://github.com/${repo_full}.wiki.git'

	commands := [
		'cd "${tmp_dir}" && git add Home.md',
		'cd "${tmp_dir}" && git config user.name "repo-batcher"',
		'cd "${tmp_dir}" && git config user.email "noreply@hyperpolymath.net"',
		'cd "${tmp_dir}" && git commit -m "Initialize wiki with Home page"',
		'cd "${tmp_dir}" && git remote add origin ${wiki_url}',
		'cd "${tmp_dir}" && git push -u origin master || git push -u origin main',
	]

	for cmd in commands {
		result := os.execute(cmd)
		if result.exit_code != 0 && !cmd.contains('||') {
			os.rmdir_all(tmp_dir) or {}
			return WikiSetupResult{
				repo_path: repo_full
				success: false
				wiki_existed: false
				message: 'Git command failed: ${result.output}'
			}
		}
	}

	// Clean up temp directory
	os.rmdir_all(tmp_dir) or {}

	return WikiSetupResult{
		repo_path: repo_full
		success: true
		wiki_existed: false
		message: 'Wiki initialized with Home page'
	}
}

// Setup wikis for multiple repositories
pub fn setup_wikis_batch(repos []string, home_content string, dry_run bool) []WikiSetupResult {
	mut results := []WikiSetupResult{}

	for repo in repos {
		// Parse owner/repo format
		parts := repo.split('/')
		if parts.len != 2 {
			results << WikiSetupResult{
				repo_path: repo
				success: false
				wiki_existed: false
				message: 'Invalid repo format (expected owner/repo)'
			}
			continue
		}

		println('Setting up wiki for ${repo}...')
		result := setup_wiki(WikiSetupParams{
			repo_owner: parts[0]
			repo_name: parts[1]
			home_content: home_content
			dry_run: dry_run
		}) or {
			WikiSetupResult{
				repo_path: repo
				success: false
				wiki_existed: false
				message: 'Error: ${err}'
			}
		}
		results << result
		println('  ${if result.success { '✓' } else { '✗' }} ${result.message}')
	}

	return results
}

// Generate default Home.md content
pub fn default_home_content(repo_name string) string {
	return '# ${repo_name} Wiki

Welcome to the ${repo_name} wiki!

## Getting Started

This wiki was automatically initialized by repo-batcher.

## Contents

- [Home](Home)

## Contributing

Feel free to contribute to this wiki by editing pages or creating new ones.
'
}

// Print wiki setup summary
pub fn print_wiki_summary(results []WikiSetupResult) {
	mut success := 0
	mut already_existed := 0
	mut failed := 0

	for result in results {
		if result.success {
			if result.wiki_existed {
				already_existed++
			} else {
				success++
			}
		} else {
			failed++
		}
	}

	println('')
	println('=== Wiki Setup Summary ===')
	println('Total repositories: ${results.len}')
	println('Successfully initialized: ${success}')
	println('Already existed: ${already_existed}')
	println('Failed: ${failed}')
	println('')
}
