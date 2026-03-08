# Gitvisor Task Runner
# Run `just` to see all available commands

# Default recipe - show help
default:
    @just --list

# ============================================================================
# SETUP
# ============================================================================

# Initial project setup
setup: setup-elixir setup-rescript setup-ada setup-julia
    @echo "Setup complete!"

# Setup Elixir backend
setup-elixir:
    cd backend && mix deps.get
    cd backend && mix compile

# Setup ReScript frontend
setup-rescript:
    cd frontend && deno task setup

# Setup Ada TUI
setup-ada:
    cd tui && gprbuild -P gitvisor_tui.gpr -p

# Setup Julia analytics
setup-julia:
    cd analytics && julia --project=. -e 'using Pkg; Pkg.instantiate()'

# ============================================================================
# DEVELOPMENT
# ============================================================================

# Start development servers
dev: dev-backend dev-frontend

# Start backend in development mode
dev-backend:
    cd backend && iex -S mix phx.server

# Start frontend in development mode
dev-frontend:
    cd frontend && deno task dev

# Start TUI in development mode
dev-tui:
    cd tui && ./bin/gitvisor_tui

# Run Julia analytics REPL
dev-analytics:
    cd analytics && julia --project=.

# ============================================================================
# TESTING
# ============================================================================

# Run all tests
test: test-elixir test-rescript test-ada test-julia
    @echo "All tests complete!"

# Test Elixir backend
test-elixir:
    cd backend && mix test

# Test ReScript frontend
test-rescript:
    cd frontend && deno task test

# Test Ada TUI
test-ada:
    cd tui && gprbuild -P gitvisor_tui_tests.gpr && ./bin/run_tests

# Test Julia analytics
test-julia:
    cd analytics && julia --project=. -e 'using Pkg; Pkg.test()'

# ============================================================================
# BUILD
# ============================================================================

# Build all components for production
build: build-backend build-frontend build-tui
    @echo "Build complete!"

# Build Elixir backend release
build-backend:
    cd backend && MIX_ENV=prod mix release

# Build ReScript frontend
build-frontend:
    cd frontend && deno task build

# Build Ada TUI
build-tui:
    cd tui && gprbuild -P gitvisor_tui.gpr -XMODE=release

# ============================================================================
# DATABASE
# ============================================================================

# Start local databases
db-start:
    @echo "Starting databases..."
    # Add database startup commands

# Stop local databases
db-stop:
    @echo "Stopping databases..."
    # Add database shutdown commands

# Run database migrations
db-migrate:
    cd backend && mix ecto.migrate

# ============================================================================
# DOCUMENTATION
# ============================================================================

# Build documentation
docs:
    asciidoctor README.adoc -o docs/index.html
    cd backend && mix docs

# Serve documentation locally
docs-serve:
    cd docs && python -m http.server 8000

# ============================================================================
# CONTAINER
# ============================================================================

# Build container image
container-build:
    nerdctl build -t gitvisor:latest .

# Run container
container-run:
    nerdctl run -it --rm -p 4000:4000 gitvisor:latest

# ============================================================================
# LINTING & FORMATTING
# ============================================================================

# Format all code
fmt:
    cd backend && mix format
    cd frontend && deno fmt
    cd tui && gnatpp -P gitvisor_tui.gpr

# Lint all code
lint:
    cd backend && mix credo --strict
    cd frontend && deno lint

# ============================================================================
# STATIC SITE (Documentation/Marketing)
# ============================================================================

# Build static site with Serum
site-serum:
    cd site && mix serum.build

# Build static site with Zola
site-zola:
    cd site-zola && zola build

# Serve static site locally
site-serve:
    cd site && mix serum.server

# ============================================================================
# RSR COMPLIANCE
# ============================================================================

# Check RSR compliance
rsr-check:
    @echo "Checking RSR compliance..."
    @test -f README.adoc && echo "✓ README.adoc" || echo "✗ README.adoc missing"
    @test -f LICENSE.txt && echo "✓ LICENSE.txt" || echo "✗ LICENSE.txt missing"
    @test -f SECURITY.md && echo "✓ SECURITY.md" || echo "✗ SECURITY.md missing"
    @test -f CODE_OF_CONDUCT.adoc && echo "✓ CODE_OF_CONDUCT.adoc" || echo "✗ CODE_OF_CONDUCT.adoc missing"
    @test -f CONTRIBUTING.adoc && echo "✓ CONTRIBUTING.adoc" || echo "✗ CONTRIBUTING.adoc missing"
    @test -f GOVERNANCE.adoc && echo "✓ GOVERNANCE.adoc" || echo "✗ GOVERNANCE.adoc missing"
    @test -f flake.nix && echo "✓ flake.nix" || echo "✗ flake.nix missing"
    @test -d .well-known && echo "✓ .well-known/" || echo "✗ .well-known/ missing"

# ============================================================================
# UTILITIES
# ============================================================================

# Clean build artifacts
clean:
    cd backend && mix clean
    cd frontend && rm -rf dist node_modules
    cd tui && gprclean -P gitvisor_tui.gpr
    rm -rf _build deps

# Update dependencies
update:
    cd backend && mix deps.update --all
    cd frontend && deno task update
    cd analytics && julia --project=. -e 'using Pkg; Pkg.update()'
