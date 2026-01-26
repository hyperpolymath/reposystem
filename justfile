# SPDX-License-Identifier: PMPL-1.0-or-later
# SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
#
# Reposystem Justfile
# ===================
# Development task runner
# Usage: just <recipe>

# Default recipe: show available commands
default:
    @just --list

# ============================================================================
# BUILD RECIPES
# ============================================================================

# Build everything
build: build-rescript build-rust
    @echo "✓ Build complete"

# Build ReScript core
build-rescript:
    @echo "Building ReScript..."
    cd src && deno task build

# Build Rust CLI
build-rust:
    @echo "Building Rust CLI..."
    cargo build --release

# Build for development (debug mode)
build-dev:
    @echo "Building for development..."
    cd src && deno task build:dev
    cargo build

# Clean build artifacts
clean:
    @echo "Cleaning..."
    rm -rf target/
    rm -rf src/_build/
    rm -rf node_modules/
    @echo "✓ Clean complete"

# ============================================================================
# TEST RECIPES
# ============================================================================

# Run all tests
test: test-rescript test-rust test-integration
    @echo "✓ All tests passed"

# Test ReScript code
test-rescript:
    @echo "Testing ReScript..."
    cd src && deno test

# Test Rust code
test-rust:
    @echo "Testing Rust..."
    cargo test

# Integration tests
test-integration:
    @echo "Running integration tests..."
    ./tests/integration/run.sh

# Test with coverage
test-coverage:
    @echo "Running tests with coverage..."
    cargo tarpaulin --out Html
    @echo "Coverage report: target/tarpaulin/tarpaulin-report.html"

# Watch mode testing
test-watch:
    cargo watch -x test

# ============================================================================
# LINT & FORMAT RECIPES
# ============================================================================

# Check all formatting and linting
check: fmt-check lint
    @echo "✓ All checks passed"

# Format all code
fmt:
    @echo "Formatting..."
    deno fmt src/
    cargo fmt
    @echo "✓ Formatting complete"

# Check formatting without changing
fmt-check:
    @echo "Checking format..."
    deno fmt --check src/
    cargo fmt --check

# Run linters
lint:
    @echo "Linting..."
    deno lint src/
    cargo clippy -- -D warnings

# Fix linting issues
lint-fix:
    @echo "Fixing lint issues..."
    cargo clippy --fix --allow-dirty

# ============================================================================
# DOCUMENTATION RECIPES
# ============================================================================

# Build all documentation
docs:
    @echo "Building documentation..."
    asciidoctor -D docs/html README.adoc ROADMAP.adoc spec/*.adoc
    cargo doc --no-deps
    @echo "✓ Documentation built in docs/html/"

# Check documentation links
docs-check:
    @echo "Checking documentation..."
    asciidoctor -D /tmp/docs-check README.adoc 2>&1 | grep -i "error" && exit 1 || true
    @echo "✓ Documentation valid"

# Serve documentation locally
docs-serve:
    @echo "Serving documentation at http://localhost:8000"
    python3 -m http.server 8000 --directory docs/html/

# Serve the web UI locally
web-serve:
    @echo "Serving web UI at http://localhost:801"
    python3 -m http.server 801 --directory web/

# Serve the web UI locally on a custom port
web-serve-port port:
    @echo "Serving web UI at http://localhost:{{port}}"
    python3 -m http.server {{port}} --directory web/

# ============================================================================
# RELEASE RECIPES
# ============================================================================

# Prepare release
release-prep version:
    @echo "Preparing release {{version}}..."
    scripts/bump-version.sh {{version}}
    just check
    just test
    just docs
    @echo "✓ Release {{version}} prepared"

# Create release tag
release-tag version:
    @echo "Creating release tag v{{version}}..."
    git tag -s "v{{version}}" -m "Release v{{version}}"
    @echo "✓ Tag created. Push with: git push origin v{{version}}"

# Build release binaries
release-build:
    @echo "Building release binaries..."
    cargo build --release --target x86_64-unknown-linux-gnu
    cargo build --release --target x86_64-apple-darwin
    cargo build --release --target x86_64-pc-windows-msvc
    @echo "✓ Binaries in target/*/release/"

# ============================================================================
# DEVELOPMENT RECIPES
# ============================================================================

# Start development environment
dev:
    @echo "Starting development environment..."
    just build-dev
    @echo "Ready for development"

# Watch and rebuild on changes
watch:
    cargo watch -x build

# Run the CLI in development mode
run *args:
    cargo run -- {{args}}

# Open REPL for ReScript
repl:
    cd src && deno repl

# ============================================================================
# GRAPH RECIPES (reposystem-specific)
# ============================================================================

# Scan local repos
scan path="~/repos":
    @echo "Scanning {{path}}..."
    cargo run -- scan {{path}}

# Export graph to DOT
export-dot output="ecosystem.dot":
    @echo "Exporting to {{output}}..."
    cargo run -- export --format dot > {{output}}

# Export graph to JSON
export-json output="ecosystem.json":
    @echo "Exporting to {{output}}..."
    cargo run -- export --format json > {{output}}

# Export graph JSON into web UI folder
web-export output="web/export.json":
    @echo "Exporting to {{output}}..."
    cargo run -- export --format json > {{output}}

# Render graph to SVG
render-svg input="ecosystem.dot" output="ecosystem.svg":
    @echo "Rendering {{input}} to {{output}}..."
    dot -Tsvg {{input}} -o {{output}}
    @echo "✓ Rendered to {{output}}"

# Full export pipeline
export-all:
    just export-dot
    just export-json
    just render-svg
    @echo "✓ All exports complete"

# ============================================================================
# SECURITY RECIPES
# ============================================================================

# Run security audit
audit:
    @echo "Running security audit..."
    cargo audit
    @echo "Checking for secrets..."
    git secrets --scan || true
    @echo "✓ Audit complete"

# Generate SBOM
sbom:
    @echo "Generating SBOM..."
    cargo sbom > sbom.json
    @echo "✓ SBOM generated: sbom.json"

# Check dependencies
deps-check:
    @echo "Checking dependencies..."
    cargo outdated
    @echo ""
    @echo "Checking for vulnerabilities..."
    cargo audit

# ============================================================================
# CI/CD RECIPES
# ============================================================================

# Run CI checks locally
ci: check test docs audit
    @echo "✓ CI checks passed"

# Run pre-commit checks
pre-commit:
    @echo "Running pre-commit checks..."
    just fmt-check
    just lint
    scripts/check-spdx-headers.sh
    @echo "✓ Pre-commit checks passed"

# Run pre-push checks
pre-push: pre-commit test
    @echo "✓ Pre-push checks passed"

# ============================================================================
# STATE FILE RECIPES
# ============================================================================

# Update STATE.scm
state-update:
    @echo "Updating STATE.scm..."
    scripts/update-state.sh
    @echo "✓ STATE.scm updated"

# Validate all .scm files
scm-validate:
    @echo "Validating Scheme files..."
    guile -c "(load \"STATE.scm\")" || exit 1
    guile -c "(load \"ECOSYSTEM.scm\")" || exit 1
    guile -c "(load \"META.scm\")" || exit 1
    guile -c "(load \"PLAYBOOK.scm\")" || exit 1
    guile -c "(load \"AGENTIC.scm\")" || exit 1
    guile -c "(load \"NEUROSYM.scm\")" || exit 1
    @echo "✓ All .scm files valid"

# ============================================================================
# HELP & INFO RECIPES
# ============================================================================

# Show project status
status:
    @echo "=== Reposystem Status ==="
    @echo ""
    @echo "Git:"
    git status --short
    @echo ""
    @echo "Build:"
    @test -f target/release/reposystem && echo "  CLI: ✓ built" || echo "  CLI: ✗ not built"
    @echo ""
    @echo "Tests:"
    @cargo test --quiet 2>/dev/null && echo "  Rust: ✓ passing" || echo "  Rust: ✗ failing"

# Show all available recipes with descriptions
help:
    @echo "=== Reposystem Justfile ==="
    @echo ""
    @echo "Build:"
    @echo "  just build          Build everything"
    @echo "  just build-dev      Build for development"
    @echo "  just clean          Clean build artifacts"
    @echo ""
    @echo "Test:"
    @echo "  just test           Run all tests"
    @echo "  just test-coverage  Run tests with coverage"
    @echo "  just test-watch     Watch mode testing"
    @echo ""
    @echo "Lint & Format:"
    @echo "  just check          Check format and lint"
    @echo "  just fmt            Format all code"
    @echo "  just lint           Run linters"
    @echo ""
    @echo "Documentation:"
    @echo "  just docs           Build documentation"
    @echo "  just docs-serve     Serve docs locally"
    @echo ""
    @echo "Graph Operations:"
    @echo "  just scan           Scan local repos"
    @echo "  just export-all     Export DOT, JSON, SVG"
    @echo ""
    @echo "Security:"
    @echo "  just audit          Security audit"
    @echo "  just sbom           Generate SBOM"
    @echo ""
    @echo "CI/CD:"
    @echo "  just ci             Run all CI checks"
    @echo "  just pre-commit     Pre-commit hooks"
    @echo "  just pre-push       Pre-push hooks"
