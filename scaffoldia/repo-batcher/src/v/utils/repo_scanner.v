// SPDX-License-Identifier: PMPL-1.0-or-later
//
// Repository Scanner
// Discovers git repositories in directory tree

module utils

import os

// Finds all git repositories in base_dir up to max_depth
pub fn find_git_repos(base_dir string, max_depth int) []string {
	mut repos := []string{}

	// Check if base_dir itself is a git repo
	if os.is_dir(os.join_path(base_dir, '.git')) {
		repos << base_dir
		return repos
	}

	// Recursively scan for .git directories
	scan_for_repos(base_dir, 0, max_depth, mut repos)

	return repos
}

// Recursively scans for git repositories
fn scan_for_repos(dir string, depth int, max_depth int, mut repos []string) {
	if depth > max_depth {
		return
	}

	// List directory contents
	entries := os.ls(dir) or { return }

	for entry in entries {
		full_path := os.join_path(dir, entry)

		// Skip if not a directory
		if !os.is_dir(full_path) {
			continue
		}

		// Check if this is a .git directory
		if entry == '.git' {
			// Parent directory is a git repo
			repos << dir
			return // Don't scan inside .git
		}

		// Recursively scan subdirectory
		scan_for_repos(full_path, depth + 1, max_depth, mut repos)
	}
}

// Resolves target specification to list of repository paths
pub fn resolve_targets(targets string, base_dir string, max_depth int) []string {
	if targets.starts_with('@') {
		// Pattern-based selection
		pattern := targets[1..]

		return match pattern {
			'all-repos' {
				find_git_repos(base_dir, max_depth)
			}
			else {
				// Pattern matching like @rsr-*, @lithoglyph-*
				find_git_repos_matching(base_dir, pattern, max_depth)
			}
		}
	} else if targets.contains(',') {
		// Comma-separated list
		return targets.split(',').map(it.trim_space())
	} else if os.is_file(targets) {
		// File containing repo paths
		return read_repos_from_file(targets)
	} else if os.is_dir(targets) {
		// Single directory (could be single repo or directory of repos)
		return find_git_repos(targets, max_depth)
	} else {
		// Single repository path
		return [targets]
	}
}

// Finds repositories matching pattern
fn find_git_repos_matching(base_dir string, pattern string, max_depth int) []string {
	all_repos := find_git_repos(base_dir, max_depth)

	// Convert glob pattern to simple matching
	// @rsr-* -> match repos starting with "rsr-"
	prefix := pattern.replace('*', '')

	return all_repos.filter(fn [prefix] (repo string) bool {
		repo_name := os.file_name(repo)
		return repo_name.starts_with(prefix)
	})
}

// Reads repository paths from file
fn read_repos_from_file(path string) []string {
	content := os.read_file(path) or { return []string{} }
	lines := content.split_into_lines()

	return lines.filter(fn (line string) bool {
		trimmed := line.trim_space()
		return trimmed.len > 0 && !trimmed.starts_with('#')
	})
}

// Validates that path is a git repository
pub fn is_git_repo(path string) bool {
	git_dir := os.join_path(path, '.git')
	return os.is_dir(git_dir)
}

// Gets repository name from path
pub fn get_repo_name(path string) string {
	return os.file_name(path)
}
