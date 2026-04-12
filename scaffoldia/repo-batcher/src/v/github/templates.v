// SPDX-License-Identifier: PMPL-1.0-or-later
//
// GitHub Issue & PR Templates
// Deploy issue templates and PR templates in bulk

module github

import os

// IssueTemplate represents a GitHub issue template
pub struct IssueTemplate {
pub:
	name        string  // Template name (e.g., "bug_report")
	filename    string  // File name (e.g., "bug_report.yml")
	content     string  // Template content (YAML or Markdown)
	description string  // Human-readable description
}

// TemplatesSetupParams contains parameters for templates setup
pub struct TemplatesSetupParams {
pub:
	repo_path      string
	issue_templates []IssueTemplate
	pr_template    string  // PR template content (optional)
	dry_run        bool
}

// TemplatesSetupResult contains the result of templates setup
pub struct TemplatesSetupResult {
pub:
	repo_path        string
	success          bool
	issue_templates_created int
	pr_template_created     bool
	message          string
}

// Default bug report template (YAML format)
pub fn default_bug_report_template() string {
	return 'name: Bug Report
description: File a bug report
title: "[Bug]: "
labels: ["bug", "triage"]
body:
  - type: markdown
    attributes:
      value: |
        Thanks for taking the time to fill out this bug report!

  - type: textarea
    id: what-happened
    attributes:
      label: What happened?
      description: Also tell us, what did you expect to happen?
      placeholder: Tell us what you see!
    validations:
      required: true

  - type: textarea
    id: reproduce
    attributes:
      label: Steps to reproduce
      description: How can we reproduce this bug?
      placeholder: |
        1. Go to \'...\'
        2. Click on \'...\'
        3. See error
    validations:
      required: true

  - type: textarea
    id: environment
    attributes:
      label: Environment
      description: What environment are you using?
      placeholder: |
        - OS: [e.g. macOS, Linux, Windows]
        - Version: [e.g. 1.0.0]
        - Browser: [if applicable]
    validations:
      required: false

  - type: textarea
    id: logs
    attributes:
      label: Relevant log output
      description: Please copy and paste any relevant log output.
      render: shell
    validations:
      required: false

  - type: checkboxes
    id: terms
    attributes:
      label: Code of Conduct
      description: By submitting this issue, you agree to follow our Code of Conduct
      options:
        - label: I agree to follow this project\'s Code of Conduct
          required: true
'
}

// Default feature request template (YAML format)
pub fn default_feature_request_template() string {
	return 'name: Feature Request
description: Suggest an idea for this project
title: "[Feature]: "
labels: ["enhancement"]
body:
  - type: markdown
    attributes:
      value: |
        Thanks for suggesting a new feature!

  - type: textarea
    id: problem
    attributes:
      label: Is your feature request related to a problem?
      description: A clear description of what the problem is.
      placeholder: I\'m always frustrated when [...]
    validations:
      required: true

  - type: textarea
    id: solution
    attributes:
      label: Describe the solution you\'d like
      description: A clear description of what you want to happen.
    validations:
      required: true

  - type: textarea
    id: alternatives
    attributes:
      label: Describe alternatives you\'ve considered
      description: Any alternative solutions or features you\'ve considered.
    validations:
      required: false

  - type: textarea
    id: context
    attributes:
      label: Additional context
      description: Add any other context or screenshots about the feature request.
    validations:
      required: false

  - type: checkboxes
    id: terms
    attributes:
      label: Code of Conduct
      description: By submitting this issue, you agree to follow our Code of Conduct
      options:
        - label: I agree to follow this project\'s Code of Conduct
          required: true
'
}

// Default documentation issue template
pub fn default_documentation_template() string {
	return 'name: Documentation Issue
description: Report a problem with documentation
title: "[Docs]: "
labels: ["documentation"]
body:
  - type: markdown
    attributes:
      value: |
        Thanks for helping improve our documentation!

  - type: textarea
    id: issue
    attributes:
      label: What\'s wrong with the documentation?
      description: A clear description of the documentation issue.
    validations:
      required: true

  - type: input
    id: url
    attributes:
      label: Documentation URL
      description: Link to the documentation page
      placeholder: https://github.com/owner/repo/wiki/Page
    validations:
      required: false

  - type: textarea
    id: suggestion
    attributes:
      label: Suggested fix
      description: How should the documentation be improved?
    validations:
      required: false
'
}

// Default PR template (Markdown format)
pub fn default_pr_template() string {
	return '## Description

Please include a summary of the changes and the related issue. Please also include relevant motivation and context.

Fixes # (issue)

## Type of change

Please delete options that are not relevant.

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## How Has This Been Tested?

Please describe the tests that you ran to verify your changes.

- [ ] Test A
- [ ] Test B

## Checklist

- [ ] My code follows the style guidelines of this project
- [ ] I have performed a self-review of my code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have made corresponding changes to the documentation
- [ ] My changes generate no new warnings
- [ ] I have added tests that prove my fix is effective or that my feature works
- [ ] New and existing unit tests pass locally with my changes
- [ ] Any dependent changes have been merged and published
'
}

// Deploy issue and PR templates
pub fn setup_templates(params TemplatesSetupParams) !TemplatesSetupResult {
	if params.dry_run {
		return TemplatesSetupResult{
			repo_path: params.repo_path
			success: true
			issue_templates_created: params.issue_templates.len
			pr_template_created: params.pr_template != ''
			message: '[DRY RUN] Would deploy ${params.issue_templates.len} issue templates'
		}
	}

	mut issue_created := 0
	mut pr_created := false

	// Create issue template directory
	if params.issue_templates.len > 0 {
		issue_template_dir := os.join_path(params.repo_path, '.github', 'ISSUE_TEMPLATE')
		os.mkdir_all(issue_template_dir) or {
			return TemplatesSetupResult{
				repo_path: params.repo_path
				success: false
				issue_templates_created: 0
				pr_template_created: false
				message: 'Failed to create ISSUE_TEMPLATE directory: ${err}'
			}
		}

		// Deploy each issue template
		for template in params.issue_templates {
			template_path := os.join_path(issue_template_dir, template.filename)

			os.write_file(template_path, template.content) or {
				eprintln('Failed to write ${template.filename}: ${err}')
				continue
			}

			issue_created++
			println('  ✓ ${template.description} -> ${template.filename}')
		}
	}

	// Deploy PR template
	if params.pr_template != '' {
		github_dir := os.join_path(params.repo_path, '.github')
		os.mkdir_all(github_dir) or {}

		pr_path := os.join_path(github_dir, 'PULL_REQUEST_TEMPLATE.md')

		os.write_file(pr_path, params.pr_template) or {
			eprintln('Failed to write PR template: ${err}')
		}

		if os.exists(pr_path) {
			pr_created = true
			println('  ✓ Pull Request Template -> PULL_REQUEST_TEMPLATE.md')
		}
	}

	return TemplatesSetupResult{
		repo_path: params.repo_path
		success: true
		issue_templates_created: issue_created
		pr_template_created: pr_created
		message: 'Created ${issue_created} issue templates, PR template: ${pr_created}'
	}
}

// Get standard issue templates
pub fn standard_issue_templates() []IssueTemplate {
	return [
		IssueTemplate{
			name: 'bug_report'
			filename: 'bug_report.yml'
			content: default_bug_report_template()
			description: 'Bug Report Template'
		},
		IssueTemplate{
			name: 'feature_request'
			filename: 'feature_request.yml'
			content: default_feature_request_template()
			description: 'Feature Request Template'
		},
		IssueTemplate{
			name: 'documentation'
			filename: 'documentation.yml'
			content: default_documentation_template()
			description: 'Documentation Issue Template'
		},
	]
}

// Deploy templates to multiple repositories
pub fn setup_templates_batch(repos []string, issue_templates []IssueTemplate, pr_template string, dry_run bool) []TemplatesSetupResult {
	mut results := []TemplatesSetupResult{}

	for repo in repos {
		println('Setting up templates for ${repo}...')
		result := setup_templates(TemplatesSetupParams{
			repo_path: repo
			issue_templates: issue_templates
			pr_template: pr_template
			dry_run: dry_run
		}) or {
			TemplatesSetupResult{
				repo_path: repo
				success: false
				issue_templates_created: 0
				pr_template_created: false
				message: 'Error: ${err}'
			}
		}
		results << result
		println('  ${result.message}')
	}

	return results
}

// Print templates setup summary
pub fn print_templates_summary(results []TemplatesSetupResult) {
	mut success := 0
	mut failed := 0
	mut total_issue_templates := 0
	mut total_pr_templates := 0

	for result in results {
		if result.success {
			success++
			total_issue_templates += result.issue_templates_created
			if result.pr_template_created {
				total_pr_templates++
			}
		} else {
			failed++
		}
	}

	println('')
	println('=== Templates Setup Summary ===')
	println('Total repositories: ${results.len}')
	println('Successful: ${success}')
	println('Failed: ${failed}')
	println('')
	println('Issue templates deployed: ${total_issue_templates}')
	println('PR templates deployed: ${total_pr_templates}')
	println('')
}
