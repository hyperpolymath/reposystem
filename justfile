# SPDX-License-Identifier: AGPL-3.0-or-later
# justfile for vex-SATELLITE_NAME

set shell := ["bash", "-uc"]

default:
    @just --list

# Build the project
build:
    cargo build --release

# Run tests
test:
    cargo test

# Run checks (clippy + fmt)
check:
    cargo fmt --check
    cargo clippy -- -D warnings

# Format code
fmt:
    cargo fmt

# Clean build artifacts
clean:
    cargo clean

# Generate vexometer traces
trace input:
    cargo run --release -- --trace {{input}}

# Run with vexometer validation
validate before after:
    @echo "Comparing vexometer scores..."
    @echo "Before: {{before}}"
    @echo "After: {{after}}"
