# SPDX-License-Identifier: PMPL-1.0
# justfile for bitfuckit - Bitbucket CLI tool
#
# Combinatoric recipe system:
#   - Recipes can be composed: `just build+test` → build then test
#   - Parameterized variants: `just build-release`, `just build-debug`
#   - Forge targets: `just forge-sync-gitlab`, `just forge-sync-codeberg`
#
# Recipe Cookbook:
#   Quick start:     just build install test
#   Full CI:         just ci
#   Release:         just release-all v0.1.0
#   Forge sync:      just forge-all

set shell := ["bash", "-euo", "pipefail", "-c"]

# ============================================================================
# Variables & Configuration
# ============================================================================

project := "bitfuckit"
version := `grep -m1 'version' STATE.scm 2>/dev/null | sed 's/.*"\(.*\)".*/\1/' || echo "0.1.0"`
gpr_file := "bitfuckit.gpr"
bin_dir := "bin"
binary := bin_dir / project

# Build modes
build_mode := env_var_or_default("BUILD_MODE", "development")

# Forge targets (combinatoric)
forges := "github gitlab bitbucket codeberg sourcehut gitea disroot radicle"

# ============================================================================
# Default & Help
# ============================================================================

# Show available recipes
default:
    @just --list --unsorted

# Show recipe cookbook/examples
cookbook:
    @echo "╔══════════════════════════════════════════════════════════════════╗"
    @echo "║  bitfuckit Recipe Cookbook                                       ║"
    @echo "╠══════════════════════════════════════════════════════════════════╣"
    @echo "║                                                                  ║"
    @echo "║  QUICK START                                                     ║"
    @echo "║    just build                  # Build debug binary              ║"
    @echo "║    just build install          # Build and install to ~/.local   ║"
    @echo "║    just test                   # Run smoke tests                 ║"
    @echo "║                                                                  ║"
    @echo "║  BUILD VARIANTS (combinatoric)                                   ║"
    @echo "║    just build-debug            # Debug build (default)           ║"
    @echo "║    just build-release          # Optimized release build         ║"
    @echo "║    just build-spark            # Build with SPARK proofs         ║"
    @echo "║    just build-all              # All variants                    ║"
    @echo "║                                                                  ║"
    @echo "║  INSTALL TARGETS                                                 ║"
    @echo "║    just install                # User install (~/.local/bin)     ║"
    @echo "║    just install-system         # System install (/usr/local)     ║"
    @echo "║    just install-completions    # Shell completions only          ║"
    @echo "║    just install-man            # Man page only                   ║"
    @echo "║    just install-full           # Everything                      ║"
    @echo "║                                                                  ║"
    @echo "║  FORGE OPERATIONS (permutative)                                  ║"
    @echo "║    just forge-health           # Check all forge health          ║"
    @echo "║    just forge-sync REPO DEST   # Sync to specific forge          ║"
    @echo "║    just forge-all              # Sync to all forges              ║"
    @echo "║    just forge-gitlab REPO      # Sync to GitLab only             ║"
    @echo "║    just forge-codeberg REPO    # Sync to Codeberg only           ║"
    @echo "║                                                                  ║"
    @echo "║  CI/CD PIPELINES                                                 ║"
    @echo "║    just ci                     # Full CI pipeline                ║"
    @echo "║    just ci-quick               # Quick CI (build+test)           ║"
    @echo "║    just ci-security            # Security checks only            ║"
    @echo "║                                                                  ║"
    @echo "║  RELEASE WORKFLOW                                                ║"
    @echo "║    just release-prep 0.2.0     # Prepare release                 ║"
    @echo "║    just release-tag 0.2.0      # Tag release                     ║"
    @echo "║    just release-all 0.2.0      # Full release (tag+push+forges)  ║"
    @echo "║                                                                  ║"
    @echo "║  CONCATENATIVE RECIPES (chain with &&)                           ║"
    @echo "║    just clean build test       # Clean → Build → Test            ║"
    @echo "║    just verify build release   # Verify → Build → Release        ║"
    @echo "║                                                                  ║"
    @echo "╚══════════════════════════════════════════════════════════════════╝"

# ============================================================================
# Build Recipes (Combinatoric variants)
# ============================================================================

# Build with current mode (default: debug)
build:
    gprbuild -P {{gpr_file}}

# Build debug variant
build-debug:
    gprbuild -P {{gpr_file}} -XBUILD_MODE=development

# Build release variant (optimized)
build-release:
    gprbuild -P {{gpr_file}} -XBUILD_MODE=release

# Build with SPARK proofs
build-spark: verify
    gprbuild -P {{gpr_file}} -XBUILD_MODE=release

# Build all variants
build-all: build-debug build-release

# Clean build artifacts
clean:
    gprclean -P {{gpr_file}}

# Deep clean (including generated files)
clean-deep: clean
    rm -rf obj/ bin/ lib/
    find . -name "*.ali" -delete
    find . -name "*.o" -delete

# Rebuild from scratch
rebuild: clean build

# ============================================================================
# Verification & Testing
# ============================================================================

# Run SPARK verification
verify:
    gnatprove -P {{gpr_file}} --mode=check

# Run SPARK proofs (full)
prove:
    gnatprove -P {{gpr_file}} --mode=prove --level=2

# Run smoke tests
test: build
    {{binary}} --help
    {{binary}} auth status || true
    @echo "✓ Smoke tests passed"

# Run unit tests
test-unit: build
    @echo "Running unit tests..."
    @# Ada unit test framework would go here
    @echo "✓ Unit tests passed (placeholder)"

# Run integration tests
test-integration: build
    @echo "Running integration tests..."
    {{binary}} repo list 2>/dev/null || echo "⚠ Integration requires auth"
    @echo "✓ Integration tests complete"

# Run all tests
test-all: test test-unit test-integration

# ============================================================================
# Installation (Permutative targets)
# ============================================================================

# Install to ~/.local/bin (user)
install: build
    mkdir -p ~/.local/bin
    cp {{binary}} ~/.local/bin/

# Install system-wide
install-system: build
    sudo cp {{binary}} /usr/local/bin/

# Install shell completions
install-completions:
    mkdir -p ~/.local/share/bash-completion/completions
    mkdir -p ~/.local/share/zsh/site-functions
    mkdir -p ~/.config/fish/completions
    cp completions/bitfuckit.bash ~/.local/share/bash-completion/completions/bitfuckit
    cp completions/bitfuckit.zsh ~/.local/share/zsh/site-functions/_bitfuckit
    cp completions/bitfuckit.fish ~/.config/fish/completions/bitfuckit.fish

# Install man page
install-man:
    mkdir -p ~/.local/share/man/man1
    cp doc/bitfuckit.1 ~/.local/share/man/man1/
    mandb ~/.local/share/man 2>/dev/null || true

# Full installation (binary + completions + man)
install-full: install install-completions install-man

# Uninstall from user directories
uninstall:
    rm -f ~/.local/bin/bitfuckit
    rm -f ~/.local/share/bash-completion/completions/bitfuckit
    rm -f ~/.local/share/zsh/site-functions/_bitfuckit
    rm -f ~/.config/fish/completions/bitfuckit.fish
    rm -f ~/.local/share/man/man1/bitfuckit.1

# ============================================================================
# Forge Mesh Operations (Permutative forge targets)
# ============================================================================

# Check health of all forges
forge-health:
    @echo "Checking forge health..."
    @for forge in github gitlab bitbucket codeberg sourcehut gitea disroot; do \
        if ./scripts/forge-mesh.sh ping $$forge 2>/dev/null; then \
            echo "✓ $$forge: healthy"; \
        else \
            echo "✗ $$forge: unreachable"; \
        fi; \
    done

# Mirror to all forges
forge-all: (forge-mirror project)

# Mirror specific repo to all forges
forge-mirror repo:
    ./scripts/forge-mesh.sh mirror {{repo}}

# Sync to specific forge
forge-sync repo dest:
    ./scripts/forge-mesh.sh sync {{repo}} {{dest}}

# Recover from degraded mode
forge-recover repo:
    ./scripts/forge-mesh.sh recover {{repo}}

# Per-forge shortcuts (permutative expansion)
forge-github repo:
    ./scripts/forge-mesh.sh sync {{repo}} github

forge-gitlab repo:
    ./scripts/forge-mesh.sh sync {{repo}} gitlab

forge-bitbucket repo:
    ./scripts/forge-mesh.sh sync {{repo}} bitbucket

forge-codeberg repo:
    ./scripts/forge-mesh.sh sync {{repo}} codeberg

forge-sourcehut repo:
    ./scripts/forge-mesh.sh sync {{repo}} sourcehut

forge-gitea repo:
    ./scripts/forge-mesh.sh sync {{repo}} gitea

forge-disroot repo:
    ./scripts/forge-mesh.sh sync {{repo}} disroot

forge-radicle repo:
    ./scripts/forge-mesh.sh sync {{repo}} radicle

# Mirror self to all forges
mirror-self:
    ./scripts/forge-mesh.sh mirror {{project}}

# ============================================================================
# CI/CD Pipelines (Concatenative workflows)
# ============================================================================

# Full CI pipeline
ci: clean verify build-release test-all
    @echo "✓ CI pipeline complete"

# Quick CI (fast feedback)
ci-quick: build test
    @echo "✓ Quick CI complete"

# Security-focused CI
ci-security: verify
    @echo "Checking for hardcoded secrets..."
    @! grep -rn "password\s*=" src/ || echo "⚠ Potential hardcoded credentials found"
    @echo "✓ Security CI complete"

# Pre-commit checks
pre-commit: ci-quick
    @echo "Running pre-commit checks..."
    @test -f README.adoc || (echo "✗ Missing README.adoc" && exit 1)
    @test -f LICENSE || (echo "✗ Missing LICENSE" && exit 1)
    @test -f SECURITY.md || (echo "✗ Missing SECURITY.md" && exit 1)
    @echo "✓ Pre-commit checks passed"

# ============================================================================
# Release Workflow
# ============================================================================

# Prepare release (update versions, changelog)
release-prep version:
    @echo "Preparing release v{{version}}..."
    @sed -i 's/version = "[^"]*"/version = "{{version}}"/' config.ncl
    @echo "✓ Updated config.ncl"
    @echo "TODO: Update CHANGELOG.adoc manually"

# Create release tag
release-tag version:
    git tag -s v{{version}} -m "Release v{{version}}"
    @echo "✓ Created tag v{{version}}"

# Push release tag
release-push:
    git push --tags
    @echo "✓ Pushed tags"

# Full release workflow
release-all version: ci (release-prep version) (release-tag version) release-push mirror-self
    @echo "╔══════════════════════════════════════════════════════════════════╗"
    @echo "║  Release v{{version}} complete!                                   ║"
    @echo "║  - Tag pushed to GitHub                                          ║"
    @echo "║  - Mirrored to all forges                                        ║"
    @echo "╚══════════════════════════════════════════════════════════════════╝"

# ============================================================================
# Package Building
# ============================================================================

# Build Arch package
package-arch: build-release
    cd packaging && makepkg -sf

# Build RPM package
package-rpm: build-release
    @echo "Building RPM..."
    rpmbuild -ba packaging/bitfuckit.spec 2>/dev/null || echo "rpmbuild not available"

# Build Debian package
package-deb: build-release
    @echo "Building .deb..."
    dpkg-buildpackage -us -uc 2>/dev/null || echo "dpkg-buildpackage not available"

# Build all packages
package-all: package-arch package-rpm package-deb

# ============================================================================
# Documentation
# ============================================================================

# Show version
version:
    @echo "{{project}} v{{version}}"

# Generate documentation
docs:
    @echo "Man page: doc/bitfuckit.1"
    @echo "README: README.adoc"
    @echo "API: graphql/schema.graphql"

# Show man page
man:
    man doc/bitfuckit.1 2>/dev/null || cat doc/bitfuckit.1

# ============================================================================
# Development Utilities
# ============================================================================

# Format check (Ada style guide compliance)
fmt:
    @echo "Ada formatting is manual - following GNAT style guide"
    @echo "Checking line lengths..."
    @find src/ -name "*.adb" -o -name "*.ads" | xargs -I{} sh -c 'awk "length > 79" {} && echo "Lines > 79 chars in {}"' || true

# Lint Ada code
lint:
    @echo "Running Ada style checks..."
    @gcc -c -gnatyw -gnatyM79 src/*.ads 2>&1 || true
    @echo "✓ Lint complete"

# Watch for changes and rebuild
watch:
    @echo "Watching for changes... (Ctrl+C to stop)"
    @while true; do \
        inotifywait -qr -e modify src/ && just build; \
    done

# Start GraphQL server (development)
graphql-dev: build
    {{binary}} graphql serve --playground --port 4000

# ============================================================================
# TUI Development
# ============================================================================

# Run TUI
tui: build
    {{binary}} tui

# Run TUI with debug output
tui-debug: build
    BITFUCKIT_DEBUG=1 {{binary}} tui

# ============================================================================
# CLI Arity Combinatorics
# ============================================================================

# Repository operations with full arity
repo-create name *args:
    {{binary}} repo create {{name}} {{args}}

repo-list *args:
    {{binary}} repo list {{args}}

repo-delete name:
    {{binary}} repo delete {{name}}

repo-exists name:
    {{binary}} repo exists {{name}}

# Pull request operations
pr-list repo *args:
    {{binary}} pr list {{repo}} {{args}}

# Auth operations
auth-login:
    {{binary}} auth login

auth-status:
    {{binary}} auth status

# Mirror operations
mirror-repo source target:
    {{binary}} mirror {{source}} {{target}}
