# SPDX-License-Identifier: AGPL-3.0-or-later
# mustfile - Mustfile Task Runner for RSR Projects
# https://just.systems/man/en/
#
# IMPORTANT: This file MUST be named "Justfile" (capital J) for RSR compliance.
# Mustfile files MUST also be named "Mustfile" (capital M).
#
# Run `just` to see all available recipes
# Run `just cookbook` to generate docs/just-cookbook.adoc
# Run `just combinations` to see matrix recipe options

set shell := ["bash", "-uc"]
set dotenv-load := true
set positional-arguments := true

# Project metadata
project := "must"
version := "0.1.0"
tier := "infrastructure"  # 1 | 2 | infrastructure

# ═══════════════════════════════════════════════════════════════════════════════
# DEFAULT & HELP
# ═══════════════════════════════════════════════════════════════════════════════

# Show all available recipes with descriptions
default:
    @just --list --unsorted

# Show detailed help for a specific recipe
help recipe="":
    #!/usr/bin/env bash
    if [ -z "{{recipe}}" ]; then
        just --list --unsorted
        echo ""
        echo "Usage: just help <recipe>"
        echo "       just cookbook     # Generate full documentation"
        echo "       just combinations # Show matrix recipes"
    else
        just --show "{{recipe}}" 2>/dev/null || echo "Recipe '{{recipe}}' not found"
    fi

# Show this project's info
info:
    @echo "Project: {{project}}"
    @echo "Version: {{version}}"
    @echo "RSR Tier: {{tier}}"
    @echo "Recipes: $(just --summary | wc -w)"
    @[ -f STATE.scm ] && grep -oP '\(phase\s+\.\s+\K[^)]+' STATE.scm | head -1 | xargs -I{} echo "Phase: {}" || true

# ═══════════════════════════════════════════════════════════════════════════════
# BUILD & COMPILE
# ═══════════════════════════════════════════════════════════════════════════════

# Build the project (debug mode)
build *args:
    @echo "Building {{project}} (debug)..."
    gprbuild -P must.gpr -XMODE=debug {{args}}

# Build in release mode with optimizations
build-release *args:
    @echo "Building {{project}} (release)..."
    gprbuild -P must.gpr -XMODE=release {{args}}

# Build and watch for changes (requires entr)
build-watch:
    @echo "Watching for changes..."
    find src -name '*.ad[sb]' | entr -c just build

# Clean build artifacts [reversible: rebuild with `just build`]
clean:
    @echo "Cleaning..."
    gnatclean -P must.gpr || true
    rm -rf obj/ bin/

# Deep clean including caches [reversible: rebuild]
clean-all: clean
    rm -rf .cache .tmp

# ═══════════════════════════════════════════════════════════════════════════════
# TEST & QUALITY
# ═══════════════════════════════════════════════════════════════════════════════

# Run all tests
test *args: build
    @echo "Running tests..."
    bin/must --version
    bin/must --help
    @echo "Tests passed!"

# Run tests with verbose output
test-verbose: build
    @echo "Running tests (verbose)..."
    bin/must --version
    bin/must --list || echo "No mustfile in current dir (expected)"

# Verify the tool works
test-smoke: build
    @echo "Smoke test..."
    bin/must init || true
    bin/must --list
    bin/must check || true
    rm -f mustfile.toml

# ═══════════════════════════════════════════════════════════════════════════════
# LINT & FORMAT
# ═══════════════════════════════════════════════════════════════════════════════

# Format all source files [reversible: git checkout]
fmt:
    @echo "Formatting Ada source files..."
    @if command -v gnatpp > /dev/null 2>&1; then \
        find src -name "*.adb" -o -name "*.ads" | xargs -I{} gnatpp -rnb --max-line-length=120 {} 2>/dev/null || true; \
        echo "Formatting complete"; \
    else \
        echo "gnatpp not found - install GNAT Studio or libadalang-tools for formatting"; \
    fi

# Check formatting without changes
fmt-check:
    #!/usr/bin/env bash
    echo "Checking Ada formatting..."
    if command -v gnatpp > /dev/null 2>&1; then
        diff_files=$(find src -name "*.adb" -o -name "*.ads" | while read -r f; do
            gnatpp -rnb --max-line-length=120 --pipe "$f" 2>/dev/null | diff -q "$f" - > /dev/null 2>&1 || echo "$f"
        done)
        if [ -n "$diff_files" ]; then
            echo "Files need formatting:"
            echo "$diff_files"
            exit 1
        fi
        echo "All files properly formatted"
    else
        echo "gnatpp not found - skipping format check"
    fi

# Run linter
lint:
    @echo "Linting Ada source files..."
    @echo "Compiling with strict warnings (acts as linter)..."
    gprbuild -P must.gpr -XMODE=debug -gnatwa -gnatwe -q || exit 1
    @echo "Lint passed - no warnings"

# Run all quality checks
quality: fmt-check lint test
    @echo "All quality checks passed!"

# Fix all auto-fixable issues [reversible: git checkout]
fix: fmt
    @echo "Fixed all auto-fixable issues"

# ═══════════════════════════════════════════════════════════════════════════════
# RUN & EXECUTE
# ═══════════════════════════════════════════════════════════════════════════════

# Run the application
run *args: build
    bin/must {{args}}

# Run with verbose output
run-verbose *args: build
    bin/must --verbose {{args}}

# Install to /usr/local/bin
install: build-release
    @echo "Installing must to /usr/local/bin..."
    sudo cp bin/must /usr/local/bin/
    @echo "Installed: $(which must)"

# ═══════════════════════════════════════════════════════════════════════════════
# DEPENDENCIES
# ═══════════════════════════════════════════════════════════════════════════════

# Install all dependencies
deps:
    @echo "Checking Ada/GNAT dependencies..."
    @command -v gnat > /dev/null 2>&1 || { echo "ERROR: gnat not found - install GNAT"; exit 1; }
    @command -v gprbuild > /dev/null 2>&1 || { echo "ERROR: gprbuild not found - install gprbuild"; exit 1; }
    @echo "GNAT: $(gnat --version | head -1)"
    @echo "gprbuild: $(gprbuild --version | head -1)"
    @echo "All dependencies satisfied (Ada projects have no external runtime dependencies)"

# Audit dependencies for vulnerabilities
deps-audit:
    @echo "Auditing for vulnerabilities..."
    @echo "Ada/GNAT security checks:"
    @echo "  - No external package dependencies (self-contained)"
    @echo "  - GNAT compiler version: $(gnat --version | head -1)"
    @echo ""
    @echo "Running supply chain checks..."
    @if command -v trivy > /dev/null 2>&1; then \
        trivy fs --severity HIGH,CRITICAL --quiet . || true; \
    else \
        echo "  trivy not installed - skipping container/filesystem scan"; \
    fi
    @if command -v gitleaks > /dev/null 2>&1; then \
        gitleaks detect --source . --no-git --quiet || true; \
    else \
        echo "  gitleaks not installed - skipping secret scan"; \
    fi
    @echo "Audit complete"

# ═══════════════════════════════════════════════════════════════════════════════
# DOCUMENTATION
# ═══════════════════════════════════════════════════════════════════════════════

# Generate all documentation
docs:
    @mkdir -p docs/generated docs/man
    just cookbook
    just man
    @echo "Documentation generated in docs/"

# Generate justfile cookbook documentation
cookbook:
    #!/usr/bin/env bash
    mkdir -p docs
    OUTPUT="docs/just-cookbook.adoc"
    echo "= {{project}} Justfile Cookbook" > "$OUTPUT"
    echo ":toc: left" >> "$OUTPUT"
    echo ":toclevels: 3" >> "$OUTPUT"
    echo "" >> "$OUTPUT"
    echo "Generated: $(date -Iseconds)" >> "$OUTPUT"
    echo "" >> "$OUTPUT"
    echo "== Recipes" >> "$OUTPUT"
    echo "" >> "$OUTPUT"
    just --list --unsorted | while read -r line; do
        if [[ "$line" =~ ^[[:space:]]+([a-z_-]+) ]]; then
            recipe="${BASH_REMATCH[1]}"
            echo "=== $recipe" >> "$OUTPUT"
            echo "" >> "$OUTPUT"
            echo "[source,bash]" >> "$OUTPUT"
            echo "----" >> "$OUTPUT"
            echo "just $recipe" >> "$OUTPUT"
            echo "----" >> "$OUTPUT"
            echo "" >> "$OUTPUT"
        fi
    done
    echo "Generated: $OUTPUT"

# Generate man page
man:
    #!/usr/bin/env bash
    mkdir -p docs/man
    printf '%s\n' \
      ".TH RSR-TEMPLATE-REPO 1 \"$(date +%Y-%m-%d)\" \"{{version}}\" \"RSR Template Manual\"" \
      ".SH NAME" \
      "{{project}} \\- RSR standard repository template" \
      ".SH SYNOPSIS" \
      ".B just" \
      "[recipe] [args...]" \
      ".SH DESCRIPTION" \
      "Canonical template for RSR (Rhodium Standard Repository) projects." \
      ".SH AUTHOR" \
      "Hyperpolymath <hyperpolymath@proton.me>" \
      > docs/man/{{project}}.1
    echo "Generated: docs/man/{{project}}.1"

# ═══════════════════════════════════════════════════════════════════════════════
# CONTAINERS (nerdctl-first, podman-fallback)
# ═══════════════════════════════════════════════════════════════════════════════

# Detect container runtime: nerdctl > podman > docker
[private]
container-cmd:
    #!/usr/bin/env bash
    if command -v nerdctl >/dev/null 2>&1; then
        echo "nerdctl"
    elif command -v podman >/dev/null 2>&1; then
        echo "podman"
    elif command -v docker >/dev/null 2>&1; then
        echo "docker"
    else
        echo "ERROR: No container runtime found (install nerdctl, podman, or docker)" >&2
        exit 1
    fi

# Build container image
container-build tag="latest":
    #!/usr/bin/env bash
    CTR=$(just container-cmd)
    if [ -f Containerfile ]; then
        echo "Building with $CTR..."
        $CTR build -t {{project}}:{{tag}} -f Containerfile .
    else
        echo "No Containerfile found"
    fi

# Run container
container-run tag="latest":
    #!/usr/bin/env bash
    CTR=$(just container-cmd)
    $CTR run --rm -it {{project}}:{{tag}}

# Push container image
container-push registry="ghcr.io/hyperpolymath" tag="latest":
    #!/usr/bin/env bash
    CTR=$(just container-cmd)
    $CTR tag {{project}}:{{tag}} {{registry}}/{{project}}:{{tag}}
    $CTR push {{registry}}/{{project}}:{{tag}}

# ═══════════════════════════════════════════════════════════════════════════════
# CI & AUTOMATION
# ═══════════════════════════════════════════════════════════════════════════════

# Run full CI pipeline locally
ci: deps quality
    @echo "CI pipeline complete!"

# Install git hooks
install-hooks:
    @mkdir -p .git/hooks
    @printf '%s\n' '#!/bin/bash' 'just fmt-check || exit 1' 'just lint || exit 1' > .git/hooks/pre-commit
    @chmod +x .git/hooks/pre-commit
    @echo "Git hooks installed"

# ═══════════════════════════════════════════════════════════════════════════════
# SECURITY
# ═══════════════════════════════════════════════════════════════════════════════

# Run security audit
security: deps-audit
    @echo "=== Security Audit ==="
    @command -v gitleaks >/dev/null && gitleaks detect --source . --verbose || true
    @command -v trivy >/dev/null && trivy fs --severity HIGH,CRITICAL . || true
    @echo "Security audit complete"

# Generate SBOM
sbom:
    @mkdir -p docs/security
    @command -v syft >/dev/null && syft . -o spdx-json > docs/security/sbom.spdx.json || echo "syft not found"

# ═══════════════════════════════════════════════════════════════════════════════
# VALIDATION & COMPLIANCE
# ═══════════════════════════════════════════════════════════════════════════════

# Validate RSR compliance
validate-rsr:
    #!/usr/bin/env bash
    echo "=== RSR Compliance Check ==="
    MISSING=""
    for f in .editorconfig .gitignore Justfile RSR_COMPLIANCE.adoc README.adoc; do
        [ -f "$f" ] || MISSING="$MISSING $f"
    done
    for d in .well-known; do
        [ -d "$d" ] || MISSING="$MISSING $d/"
    done
    for f in .well-known/security.txt .well-known/ai.txt .well-known/humans.txt; do
        [ -f "$f" ] || MISSING="$MISSING $f"
    done
    if [ ! -f "guix.scm" ] && [ ! -f ".guix-channel" ] && [ ! -f "flake.nix" ]; then
        MISSING="$MISSING guix.scm/flake.nix"
    fi
    if [ -n "$MISSING" ]; then
        echo "MISSING:$MISSING"
        exit 1
    fi
    echo "RSR compliance: PASS"

# Validate STATE.scm syntax
validate-state:
    @if [ -f "STATE.scm" ]; then \
        guile -c "(primitive-load \"STATE.scm\")" 2>/dev/null && echo "STATE.scm: valid" || echo "STATE.scm: INVALID"; \
    else \
        echo "No STATE.scm found"; \
    fi

# Full validation suite
validate: validate-rsr validate-state
    @echo "All validations passed!"

# ═══════════════════════════════════════════════════════════════════════════════
# STATE MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

# Update STATE.scm timestamp
state-touch:
    @if [ -f "STATE.scm" ]; then \
        sed -i 's/(updated . "[^"]*")/(updated . "'"$(date -Iseconds)"'")/' STATE.scm && \
        echo "STATE.scm timestamp updated"; \
    fi

# Show current phase from STATE.scm
state-phase:
    @grep -oP '\(phase\s+\.\s+\K[^)]+' STATE.scm 2>/dev/null | head -1 || echo "unknown"

# ═══════════════════════════════════════════════════════════════════════════════
# GUIX & NIX
# ═══════════════════════════════════════════════════════════════════════════════

# Enter Guix development shell (primary)
guix-shell:
    guix shell -D -f guix.scm

# Build with Guix
guix-build:
    guix build -f guix.scm

# Enter Nix development shell (fallback)
nix-shell:
    @if [ -f "flake.nix" ]; then nix develop; else echo "No flake.nix"; fi

# ═══════════════════════════════════════════════════════════════════════════════
# HYBRID AUTOMATION
# ═══════════════════════════════════════════════════════════════════════════════

# Run local automation tasks
automate task="all":
    #!/usr/bin/env bash
    case "{{task}}" in
        all) just fmt && just lint && just test && just docs && just state-touch ;;
        cleanup) just clean && find . -name "*.orig" -delete && find . -name "*~" -delete ;;
        update) just deps && just validate ;;
        *) echo "Unknown: {{task}}. Use: all, cleanup, update" && exit 1 ;;
    esac

# ═══════════════════════════════════════════════════════════════════════════════
# COMBINATORIC MATRIX RECIPES
# ═══════════════════════════════════════════════════════════════════════════════

# Build matrix: [debug|release] × [target] × [features]
build-matrix mode="debug" target="" features="":
    @echo "Build matrix: mode={{mode}} target={{target}} features={{features}}"
    # Customize for your build system

# Test matrix: [unit|integration|e2e|all] × [verbosity] × [parallel]
test-matrix suite="unit" verbosity="normal" parallel="true":
    @echo "Test matrix: suite={{suite}} verbosity={{verbosity}} parallel={{parallel}}"

# Container matrix: [build|run|push|shell|scan] × [registry] × [tag]
container-matrix action="build" registry="ghcr.io/hyperpolymath" tag="latest":
    @echo "Container matrix: action={{action}} registry={{registry}} tag={{tag}}"

# CI matrix: [lint|test|build|security|all] × [quick|full]
ci-matrix stage="all" depth="quick":
    @echo "CI matrix: stage={{stage}} depth={{depth}}"

# Show all matrix combinations
combinations:
    @echo "=== Combinatoric Matrix Recipes ==="
    @echo ""
    @echo "Build Matrix: just build-matrix [debug|release] [target] [features]"
    @echo "Test Matrix:  just test-matrix [unit|integration|e2e|all] [verbosity] [parallel]"
    @echo "Container:    just container-matrix [build|run|push|shell|scan] [registry] [tag]"
    @echo "CI Matrix:    just ci-matrix [lint|test|build|security|all] [quick|full]"
    @echo ""
    @echo "Total combinations: ~10 billion"

# ═══════════════════════════════════════════════════════════════════════════════
# VERSION CONTROL
# ═══════════════════════════════════════════════════════════════════════════════

# Show git status
status:
    @git status --short

# Show recent commits
log count="20":
    @git log --oneline -{{count}}

# ═══════════════════════════════════════════════════════════════════════════════
# UTILITIES
# ═══════════════════════════════════════════════════════════════════════════════

# Count lines of code
loc:
    @find . \( -name "*.rs" -o -name "*.ex" -o -name "*.res" -o -name "*.ncl" -o -name "*.scm" \) 2>/dev/null | xargs wc -l 2>/dev/null | tail -1 || echo "0"

# Show TODO comments
todos:
    @grep -rn "TODO\|FIXME" --include="*.rs" --include="*.ex" --include="*.res" . 2>/dev/null || echo "No TODOs"

# Open in editor
edit:
    ${EDITOR:-code} .
