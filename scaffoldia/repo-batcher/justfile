# SPDX-License-Identifier: PMPL-1.0-or-later
# justfile for repo-batcher

# Default recipe
default:
    @just --list

# Build the project
build:
    @echo "Building repo-batcher..."
    # Compile ATS2 core
    cd src/ats2 && patscc -o ../../build/librepobatcher.a operations/*.dats
    # Compile V CLI
    v -prod -o build/repo-batcher src/v/main.v
    @echo "Build complete: build/repo-batcher"

# Build in development mode (faster, less optimized)
build-dev:
    @echo "Building repo-batcher (dev mode)..."
    v -o build/repo-batcher src/v/main.v
    @echo "Build complete: build/repo-batcher"

# Run smoke test (structure validation, no build required)
test-smoke:
    @echo "Running smoke test..."
    ./tests/smoke_test.sh

# Run tests
test:
    @echo "Running tests..."
    # V integration tests
    v run tests/integration_test.v
    @echo ""
    @echo "All tests passed!"

# Run real repository tests (dry-run only)
test-real:
    @echo "Running real repository tests (dry-run)..."
    ./tests/real_repo_test.sh

# Run performance benchmark
benchmark:
    @echo "Running performance benchmark..."
    ./benchmark/performance_test.sh

# Clean build artifacts
clean:
    rm -rf build/
    find . -name "*.o" -delete
    find . -name "*.a" -delete
    find . -name "*.so" -delete

# Install to system
install:
    @echo "Installing repo-batcher..."
    sudo cp build/repo-batcher /usr/local/bin/
    sudo chmod +x /usr/local/bin/repo-batcher
    mkdir -p ~/.config/repo-batcher/watch
    mkdir -p ~/.local/share/repo-batcher/logs
    mkdir -p ~/.local/share/repo-batcher/backups
    @echo "Installed to /usr/local/bin/repo-batcher"

# Uninstall from system
uninstall:
    sudo rm -f /usr/local/bin/repo-batcher
    @echo "Uninstalled repo-batcher"

# Format code
fmt:
    # V has built-in formatter
    v fmt -w src/v/

# Check code quality
check:
    @echo "Checking ATS2 code..."
    patsopt -tc -d src/ats2/operations/*.dats
    @echo "Checking V code..."
    v vet src/v/

# Create example config
setup-config:
    mkdir -p ~/.config/repo-batcher
    cp templates/config.example.toml ~/.config/repo-batcher/config.toml
    @echo "Config created at ~/.config/repo-batcher/config.toml"

# Run in dry-run mode (safe testing)
dry-run operation targets:
    ./build/repo-batcher {{operation}} --targets {{targets}} --dry-run

# Quick git-sync (ported from sync_repos.sh)
git-sync parallel="4" depth="2":
    ./build/repo-batcher git-sync --parallel {{parallel}} --depth {{depth}}

# Watch mode (daemon)
watch:
    ./build/repo-batcher watch

# Show version and help
help:
    ./build/repo-batcher --help
