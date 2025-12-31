# SPDX-License-Identifier: AGPL-3.0-or-later
# SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
#
# Container Recipes for Reposystem
# ================================
# Usage: just -f container.just <recipe>
# Or include in main justfile

# Container runtime (prefer nerdctl, fallback to podman, then docker)
container_runtime := `which nerdctl 2>/dev/null || which podman 2>/dev/null || which docker 2>/dev/null || echo "nerdctl"`

# Image names
dev_image := "reposystem:dev"
prod_image := "reposystem:latest"
registry := "ghcr.io/hyperpolymath"

# ============================================================================
# BUILD RECIPES
# ============================================================================

# Build development container
container-build-dev:
    @echo "Building development container..."
    {{container_runtime}} build \
        -f Containerfile.dev \
        -t {{dev_image}} \
        .
    @echo "✓ Development container built: {{dev_image}}"

# Build production container
container-build-prod:
    @echo "Building production container..."
    {{container_runtime}} build \
        -f Containerfile \
        -t {{prod_image}} \
        .
    @echo "✓ Production container built: {{prod_image}}"

# Build all containers
container-build: container-build-dev container-build-prod
    @echo "✓ All containers built"

# ============================================================================
# RUN RECIPES
# ============================================================================

# Run development container interactively
container-dev:
    @echo "Starting development container..."
    {{container_runtime}} run -it --rm \
        -v {{justfile_directory()}}:/workspace:Z \
        -v ~/repos:/data:ro \
        --name reposystem-dev \
        {{dev_image}}

# Run production container
container-run *args:
    @echo "Running reposystem..."
    {{container_runtime}} run -it --rm \
        -v ~/repos:/data:ro \
        {{prod_image}} {{args}}

# Run scan command
container-scan path="/data":
    {{container_runtime}} run -it --rm \
        -v {{path}}:/data:ro \
        {{prod_image}} scan /data

# Run export command
container-export format="dot":
    {{container_runtime}} run -it --rm \
        -v ~/repos:/data:ro \
        -v {{justfile_directory()}}/output:/output:Z \
        {{prod_image}} export --format {{format}} > output/ecosystem.{{format}}

# ============================================================================
# UTILITY RECIPES
# ============================================================================

# Shell into running container
container-shell:
    {{container_runtime}} exec -it reposystem-dev /bin/bash

# View container logs
container-logs:
    {{container_runtime}} logs reposystem-dev

# Stop development container
container-stop:
    {{container_runtime}} stop reposystem-dev || true

# Clean up containers and images
container-clean:
    @echo "Cleaning up containers..."
    {{container_runtime}} rm -f reposystem-dev 2>/dev/null || true
    {{container_runtime}} rmi {{dev_image}} 2>/dev/null || true
    {{container_runtime}} rmi {{prod_image}} 2>/dev/null || true
    @echo "✓ Cleanup complete"

# Show container status
container-status:
    @echo "=== Container Status ==="
    @echo ""
    @echo "Runtime: {{container_runtime}}"
    @echo ""
    @echo "Images:"
    @{{container_runtime}} images | grep reposystem || echo "  (none)"
    @echo ""
    @echo "Running:"
    @{{container_runtime}} ps | grep reposystem || echo "  (none)"

# ============================================================================
# REGISTRY RECIPES
# ============================================================================

# Tag for registry
container-tag version:
    {{container_runtime}} tag {{prod_image}} {{registry}}/reposystem:{{version}}
    {{container_runtime}} tag {{prod_image}} {{registry}}/reposystem:latest

# Push to registry
container-push version:
    @echo "Pushing to {{registry}}..."
    {{container_runtime}} push {{registry}}/reposystem:{{version}}
    {{container_runtime}} push {{registry}}/reposystem:latest

# Sign container image (requires cosign)
container-sign version:
    @echo "Signing container image..."
    cosign sign {{registry}}/reposystem:{{version}}

# ============================================================================
# COMPOSE RECIPES (for multi-container setup)
# ============================================================================

# Start compose stack
compose-up:
    {{container_runtime}} compose up -d

# Stop compose stack
compose-down:
    {{container_runtime}} compose down

# View compose logs
compose-logs:
    {{container_runtime}} compose logs -f
