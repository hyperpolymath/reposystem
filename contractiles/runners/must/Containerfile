# Containerfile for Must - task runner + template engine + enforcer
# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (C) 2025 Jonathan D.A. Jewell
#
# Build: podman build -t must:latest -f Containerfile .
# Run:   podman run --rm -it must:latest --help
# Shell: podman run --rm -it --entrypoint /bin/bash must:latest

# Stage 1: Build environment with GNAT Ada compiler
FROM docker.io/library/debian:bookworm-slim AS builder

# Install GNAT Ada compiler and build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gnat \
    gprbuild \
    make \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /build

# Copy source files
COPY must.gpr .
COPY src/ src/
COPY templates/ templates/

# Build release binary
RUN gprbuild -P must.gpr -XMODE=release -j0

# Verify binary works
RUN ./bin/must --version && ./bin/must --help

# Stage 2: Minimal runtime image
FROM docker.io/library/debian:bookworm-slim AS runtime

# Install minimal runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user for security
RUN useradd -m -s /bin/bash must

# Copy binary from builder
COPY --from=builder /build/bin/must /usr/local/bin/must

# Copy templates (needed for template operations)
COPY --from=builder /build/templates /opt/must/templates

# Set ownership
RUN chown -R must:must /opt/must

# Switch to non-root user
USER must
WORKDIR /home/must

# Default entrypoint
ENTRYPOINT ["/usr/local/bin/must"]
CMD ["--help"]
