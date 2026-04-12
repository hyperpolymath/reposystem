;; SPDX-License-Identifier: PMPL-1.0-or-later
;; Scaffoldia - Dialect roles and audience stance definitions
;; Defines how project scaffolds adapt based on target audience and purpose

(use-modules (srfi srfi-1)
             (ice-9 match))

;; Dialect: The "voice" or stance a project takes toward its audience
;; Each dialect influences file structure, documentation style, and defaults

(define *dialects*
  '((professional
     (description . "Enterprise/business-focused projects")
     (files . ("CONTRIBUTING.md" "CODE_OF_CONDUCT.md" "GOVERNANCE.md"
               "CHANGELOG.md" "SECURITY.md" ".github/ISSUE_TEMPLATE/"
               ".github/PULL_REQUEST_TEMPLATE.md"))
     (readme-style . formal)
     (license-preference . ("Apache-2.0" "MIT" "MPL-2.0"))
     (ci-preference . comprehensive))

    (educational
     (description . "Learning-focused, tutorial-style projects")
     (files . ("docs/tutorial.md" "docs/getting-started.md"
               "examples/" "exercises/"))
     (readme-style . tutorial)
     (license-preference . ("MIT" "CC0-1.0" "Unlicense"))
     (ci-preference . minimal))

    (research
     (description . "Academic/research projects")
     (files . ("CITATION.cff" "docs/methodology.md" "data/"
               "notebooks/" "paper/"))
     (readme-style . academic)
     (license-preference . ("GPL-3.0" "AGPL-3.0" "MIT"))
     (ci-preference . reproducibility))

    (experimental
     (description . "Proof-of-concept, exploratory projects")
     (files . ("NOTES.md" "TODO.md" "sketches/"))
     (readme-style . informal)
     (license-preference . ("MIT" "Unlicense"))
     (ci-preference . none))

    (library
     (description . "Reusable library/package projects")
     (files . ("docs/api.md" "docs/reference/" "examples/"
               "CHANGELOG.md" "benchmarks/"))
     (readme-style . technical)
     (license-preference . ("MIT" "Apache-2.0" "MPL-2.0"))
     (ci-preference . comprehensive))

    (application
     (description . "End-user application projects")
     (files . ("docs/user-guide.md" "docs/installation.md"
               "config/" "CHANGELOG.md"))
     (readme-style . user-focused)
     (license-preference . ("GPL-3.0" "AGPL-3.0" "MPL-2.0"))
     (ci-preference . standard))

    (infrastructure
     (description . "DevOps/infrastructure projects")
     (files . ("docs/runbook.md" "docs/architecture.md"
               "terraform/" "ansible/" "k8s/"))
     (readme-style . operational)
     (license-preference . ("Apache-2.0" "MPL-2.0"))
     (ci-preference . deployment))))

;; Role: The primary purpose/function of the project
(define *roles*
  '((cli . "Command-line interface tool")
    (web-app . "Web application")
    (api . "API service/server")
    (library . "Reusable library/package")
    (framework . "Development framework")
    (plugin . "Extension/plugin for another system")
    (config . "Configuration management")
    (data-pipeline . "Data processing pipeline")
    (ml-model . "Machine learning model/system")
    (game . "Game or interactive entertainment")
    (embedded . "Embedded/IoT system")
    (compiler . "Language compiler/interpreter")
    (editor . "Text/code editor or IDE")))

;; Get dialect definition
(define (get-dialect name)
  (assoc name *dialects*))

;; Get role definition
(define (get-role name)
  (assoc name *roles*))

;; Get files for a dialect
(define (dialect-files dialect-name)
  (let ((dialect (get-dialect dialect-name)))
    (if dialect
        (cdr (assoc 'files (cdr dialect)))
        '())))

;; Get readme style for dialect
(define (dialect-readme-style dialect-name)
  (let ((dialect (get-dialect dialect-name)))
    (if dialect
        (cdr (assoc 'readme-style (cdr dialect)))
        'standard)))

;; Get license preferences for dialect
(define (dialect-licenses dialect-name)
  (let ((dialect (get-dialect dialect-name)))
    (if dialect
        (cdr (assoc 'license-preference (cdr dialect)))
        '("MIT"))))

;; Combine role and dialect to determine full file set
(define (determine-files language role dialect)
  (let* ((base-files (language-base-files language))
         (role-files (role-specific-files role))
         (dialect-files (dialect-files dialect)))
    (delete-duplicates
     (append base-files role-files dialect-files))))

;; Base files for each language
(define (language-base-files language)
  (match language
    ('rust '("Cargo.toml" "src/main.rs" "src/lib.rs"))
    ('haskell '("*.cabal" "src/" "app/" "test/"))
    ('rescript '("rescript.json" "src/" "deno.json"))
    ('gleam '("gleam.toml" "src/" "test/"))
    (_ '())))

;; Role-specific files
(define (role-specific-files role)
  (match role
    ('cli '("src/cli.rs" "docs/usage.md"))
    ('web-app '("src/routes/" "src/components/" "static/"))
    ('api '("src/handlers/" "src/models/" "openapi.yaml"))
    ('library '("src/lib/" "docs/api.md" "examples/"))
    ('framework '("src/core/" "docs/guide/" "templates/"))
    ('plugin '("manifest.json" "src/plugin.rs"))
    ('config '("schemas/" "examples/" "docs/reference.md"))
    ('data-pipeline '("pipelines/" "schemas/" "tests/fixtures/"))
    ('ml-model '("models/" "data/" "notebooks/" "experiments/"))
    ('compiler '("src/parser/" "src/lexer/" "src/codegen/" "stdlib/"))
    (_ '())))

;; Generate README template based on dialect and role
(define (readme-template dialect role project-name description)
  (let ((style (dialect-readme-style dialect)))
    (match style
      ('formal
       (string-append
        "# " project-name "\n\n"
        description "\n\n"
        "## Overview\n\n"
        "## Installation\n\n"
        "## Usage\n\n"
        "## Configuration\n\n"
        "## Contributing\n\n"
        "## License\n"))
      ('tutorial
       (string-append
        "# " project-name " 📚\n\n"
        description "\n\n"
        "## What you'll learn\n\n"
        "## Prerequisites\n\n"
        "## Getting Started\n\n"
        "## Step-by-step Guide\n\n"
        "## Exercises\n\n"
        "## Further Reading\n"))
      ('academic
       (string-append
        "# " project-name "\n\n"
        description "\n\n"
        "## Abstract\n\n"
        "## Methodology\n\n"
        "## Results\n\n"
        "## Citation\n\n"
        "## Reproducibility\n\n"
        "## License\n"))
      (_
       (string-append
        "# " project-name "\n\n"
        description "\n\n"
        "## Installation\n\n"
        "## Usage\n\n"
        "## License\n")))))

;; Export for CLI integration
(define (apply-dialect project-path dialect role)
  "Apply dialect-specific files and configurations to a project."
  (let ((files (determine-files 'unknown role dialect)))
    files))
