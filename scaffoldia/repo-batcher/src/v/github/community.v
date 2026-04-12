// SPDX-License-Identifier: PMPL-1.0-or-later
//
// GitHub Community Health Files
// Deploy standard community files across repositories

module github

import os

// CommunityFile represents a community health file
pub struct CommunityFile {
pub:
	path    string  // Relative path in repo (e.g., ".github/CONTRIBUTING.md")
	content string  // File content
	name    string  // Human-readable name
}

// CommunitySetupParams contains parameters for community setup
pub struct CommunitySetupParams {
pub:
	repo_path   string
	files       []CommunityFile
	create_pr   bool   // Create PR instead of direct commit
	dry_run     bool
}

// CommunitySetupResult contains the result of community setup
pub struct CommunitySetupResult {
pub:
	repo_path     string
	success       bool
	files_created int
	files_updated int
	files_skipped int
	message       string
}

// Standard community file templates
pub fn default_code_of_conduct() string {
	return '# Code of Conduct

## Our Pledge

We as members, contributors, and leaders pledge to make participation in our
community a harassment-free experience for everyone, regardless of age, body
size, visible or invisible disability, ethnicity, sex characteristics, gender
identity and expression, level of experience, education, socio-economic status,
nationality, personal appearance, race, religion, or sexual identity
and orientation.

## Our Standards

Examples of behavior that contributes to a positive environment:

* Using welcoming and inclusive language
* Being respectful of differing viewpoints and experiences
* Gracefully accepting constructive criticism
* Focusing on what is best for the community
* Showing empathy towards other community members

Examples of unacceptable behavior:

* The use of sexualized language or imagery
* Trolling, insulting or derogatory comments, and personal or political attacks
* Public or private harassment
* Publishing others\' private information without explicit permission
* Other conduct which could reasonably be considered inappropriate

## Enforcement

Instances of abusive, harassing, or otherwise unacceptable behavior may be
reported to the project maintainers. All complaints will be reviewed and
investigated promptly and fairly.

## Attribution

This Code of Conduct is adapted from the [Contributor Covenant](https://www.contributor-covenant.org),
version 2.0.
'
}

pub fn default_contributing() string {
	return '# Contributing

Thank you for your interest in contributing!

## Getting Started

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m "Add amazing feature"`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Code Style

- Follow existing code style
- Write clear, descriptive commit messages
- Add tests for new features
- Update documentation as needed

## Reporting Bugs

Please use the issue tracker to report bugs. Include:

- Clear description of the problem
- Steps to reproduce
- Expected vs actual behavior
- Environment details (OS, version, etc.)

## Feature Requests

We welcome feature requests! Please:

- Check if the feature already exists or is planned
- Describe the use case and benefits
- Be open to discussion and iteration

## Pull Request Process

1. Update the README.md with details of changes if applicable
2. Ensure all tests pass
3. Request review from maintainers
4. Address any feedback promptly

## License

By contributing, you agree that your contributions will be licensed under the
same license as the project.
'
}

pub fn default_security() string {
	return '# Security Policy

## Supported Versions

We release patches for security vulnerabilities. Currently supported versions:

| Version | Supported          |
| ------- | ------------------ |
| latest  | :white_check_mark: |

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

Instead, please report them via:

- GitHub Security Advisories (preferred)
- Email to the maintainers

Please include:

- Type of vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if available)

You should receive a response within 48 hours. If the issue is confirmed,
we will:

1. Develop and test a fix
2. Release a security advisory
3. Release a patched version
4. Publicly disclose the vulnerability

## Security Best Practices

When using this project:

- Keep dependencies up to date
- Use the latest stable version
- Follow security guidelines in documentation
- Report any suspicious behavior

Thank you for helping keep this project secure!
'
}

pub fn default_support() string {
	return '# Support

## Documentation

- [README](README.md) - Project overview and quick start
- [Contributing Guide](CONTRIBUTING.md) - How to contribute
- [Wiki](../../wiki) - Detailed documentation

## Getting Help

### Questions and Discussions

For general questions and discussions, please use:

- GitHub Discussions (if enabled)
- Issue tracker for specific problems
- Community forums or chat

### Bug Reports

If you find a bug:

1. Check if it\'s already reported in [Issues](../../issues)
2. If not, create a new issue with:
   - Clear description
   - Steps to reproduce
   - Expected behavior
   - Actual behavior
   - Environment details

### Feature Requests

We welcome feature requests! Please:

1. Check [existing issues](../../issues) first
2. Create a new issue describing:
   - The use case
   - Proposed solution
   - Alternative solutions considered
   - Additional context

## Response Times

- Security issues: 48 hours
- Bug reports: 1 week
- Feature requests: 2 weeks
- General questions: Best effort

## Commercial Support

For commercial support or consulting, please contact the maintainers directly.
'
}

pub fn default_funding() string {
	return '# Funding

# Sponsor this project

github: hyperpolymath

# Other sponsorship options
# patreon: your-username
# open_collective: your-project
# ko_fi: your-username
# custom: ["https://example.com"]
'
}

// Deploy community files to a repository
pub fn setup_community_files(params CommunitySetupParams) !CommunitySetupResult {
	if params.dry_run {
		return CommunitySetupResult{
			repo_path: params.repo_path
			success: true
			files_created: params.files.len
			files_updated: 0
			files_skipped: 0
			message: '[DRY RUN] Would deploy ${params.files.len} community files'
		}
	}

	mut created := 0
	mut updated := 0
	mut skipped := 0

	// Ensure .github directory exists
	github_dir := os.join_path(params.repo_path, '.github')
	os.mkdir_all(github_dir) or {
		return CommunitySetupResult{
			repo_path: params.repo_path
			success: false
			files_created: 0
			files_updated: 0
			files_skipped: 0
			message: 'Failed to create .github directory: ${err}'
		}
	}

	// Deploy each file
	for file in params.files {
		file_path := os.join_path(params.repo_path, file.path)
		file_dir := os.dir(file_path)

		// Ensure parent directory exists
		os.mkdir_all(file_dir) or {
			eprintln('Failed to create directory ${file_dir}: ${err}')
			continue
		}

		// Check if file already exists
		if os.exists(file_path) {
			// Read existing content to check if update needed
			existing := os.read_file(file_path) or { '' }
			if existing == file.content {
				skipped++
				continue
			}
			updated++
		} else {
			created++
		}

		// Write file
		os.write_file(file_path, file.content) or {
			eprintln('Failed to write ${file_path}: ${err}')
			continue
		}

		println('  ✓ ${file.name} -> ${file.path}')
	}

	return CommunitySetupResult{
		repo_path: params.repo_path
		success: true
		files_created: created
		files_updated: updated
		files_skipped: skipped
		message: 'Created ${created}, updated ${updated}, skipped ${skipped} files'
	}
}

// Get standard community files set
pub fn standard_community_files() []CommunityFile {
	return [
		CommunityFile{
			path: '.github/CODE_OF_CONDUCT.md'
			content: default_code_of_conduct()
			name: 'Code of Conduct'
		},
		CommunityFile{
			path: '.github/CONTRIBUTING.md'
			content: default_contributing()
			name: 'Contributing Guide'
		},
		CommunityFile{
			path: '.github/SECURITY.md'
			content: default_security()
			name: 'Security Policy'
		},
		CommunityFile{
			path: '.github/SUPPORT.md'
			content: default_support()
			name: 'Support Guide'
		},
		CommunityFile{
			path: '.github/FUNDING.yml'
			content: default_funding()
			name: 'Funding Config'
		},
	]
}

// Deploy community files to multiple repositories
pub fn setup_community_batch(repos []string, files []CommunityFile, dry_run bool) []CommunitySetupResult {
	mut results := []CommunitySetupResult{}

	for repo in repos {
		println('Setting up community files for ${repo}...')
		result := setup_community_files(CommunitySetupParams{
			repo_path: repo
			files: files
			create_pr: false
			dry_run: dry_run
		}) or {
			CommunitySetupResult{
				repo_path: repo
				success: false
				files_created: 0
				files_updated: 0
				files_skipped: 0
				message: 'Error: ${err}'
			}
		}
		results << result
		println('  ${result.message}')
	}

	return results
}

// Print community setup summary
pub fn print_community_summary(results []CommunitySetupResult) {
	mut success := 0
	mut failed := 0
	mut total_created := 0
	mut total_updated := 0
	mut total_skipped := 0

	for result in results {
		if result.success {
			success++
			total_created += result.files_created
			total_updated += result.files_updated
			total_skipped += result.files_skipped
		} else {
			failed++
		}
	}

	println('')
	println('=== Community Files Setup Summary ===')
	println('Total repositories: ${results.len}')
	println('Successful: ${success}')
	println('Failed: ${failed}')
	println('')
	println('Files created: ${total_created}')
	println('Files updated: ${total_updated}')
	println('Files skipped: ${total_skipped}')
	println('')
}
