# RSR-Certified Justfile
# https://github.com/casey/just
#
# RSR Standard: Build automation via Justfile

set shell := ["bash", "-uc"]

# Default recipe - show help
default:
    @just --list

# ============================================================
# BUILD
# ============================================================

# Build all packages in release mode
build:
    cargo build --release

# Build in debug mode
build-debug:
    cargo build

# Build only the engine
build-engine:
    cargo build --release -p rsr-engine

# Build only the LSP
build-lsp:
    cargo build --release -p rsr-lsp

# ============================================================
# TEST
# ============================================================

# Run all tests
test:
    cargo test --all-features

# Run tests with output
test-verbose:
    cargo test --all-features -- --nocapture

# Run clippy lints
lint:
    cargo clippy --all-targets --all-features -- -D warnings

# Check formatting
fmt-check:
    cargo fmt --all -- --check

# Format code
fmt:
    cargo fmt --all

# ============================================================
# COMPLIANCE
# ============================================================

# Check this repository's RSR compliance
check:
    cargo run --release -p rsr-engine -- check .

# Check compliance in strict mode
check-strict:
    cargo run --release -p rsr-engine -- check . --strict --tier gold

# Initialize RSR config
init:
    cargo run --release -p rsr-engine -- init . --tier silver

# Generate compliance badge
badge:
    cargo run --release -p rsr-engine -- badge silver -o badges/self-compliance.svg

# ============================================================
# DEVELOPMENT
# ============================================================

# Run the server locally
serve:
    cargo run --release -p rsr-engine -- serve --host 127.0.0.1 --port 8080

# Run in watch mode (requires cargo-watch)
watch:
    cargo watch -x "run -p rsr-engine -- serve --host 127.0.0.1 --port 8080"

# Run the LSP server
lsp:
    cargo run --release -p rsr-lsp

# ============================================================
# CONTAINER
# ============================================================

# Build container image
container-build:
    podman build -f container/Containerfile -t rsr-certified:latest .

# Run container
container-run:
    podman run -p 8080:8080 rsr-certified:latest

# Start full stack with compose
compose-up:
    cd container && podman-compose up -d

# Stop compose stack
compose-down:
    cd container && podman-compose down

# View compose logs
compose-logs:
    cd container && podman-compose logs -f

# ============================================================
# DATABASE
# ============================================================

# Start only databases (for development)
db-up:
    cd container && podman-compose up -d dragonfly surrealdb arangodb

# Stop databases
db-down:
    cd container && podman-compose down dragonfly surrealdb arangodb

# Connect to SurrealDB CLI
db-surreal:
    podman exec -it rsr-surrealdb /surreal sql --conn ws://localhost:8000 --user root --pass changeme --ns rsr --db compliance

# Open ArangoDB web UI info
db-arango:
    @echo "ArangoDB Web UI: http://localhost:8529"
    @echo "Username: root"
    @echo "Password: changeme (or ARANGODB_ROOT_PASSWORD)"

# ============================================================
# RELEASE
# ============================================================

# Create a new release
release version:
    @echo "Creating release v{{version}}"
    git tag -a "v{{version}}" -m "Release v{{version}}"
    @echo "Push with: git push origin v{{version}}"

# Build release artifacts for all platforms
release-build:
    cargo build --release --target x86_64-unknown-linux-musl
    cargo build --release --target aarch64-unknown-linux-musl

# ============================================================
# DOCUMENTATION
# ============================================================

# Generate documentation
docs:
    cargo doc --no-deps --all-features

# Open documentation in browser
docs-open:
    cargo doc --no-deps --all-features --open

# ============================================================
# CLEANUP
# ============================================================

# Clean build artifacts
clean:
    cargo clean

# Clean everything including container volumes
clean-all: clean
    cd container && podman-compose down -v

# ============================================================
# CI/CD HELPERS
# ============================================================

# Run all CI checks
ci: fmt-check lint test check
    @echo "All CI checks passed!"

# Pre-commit hook
pre-commit: fmt lint test
    @echo "Pre-commit checks passed!"
