# SPDX-License-Identifier: AGPL-3.0-or-later
# SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
#
# Reposystem Container Image
# ==========================
# Based on Wolfi for minimal, secure, distroless-like base
#
# Build with: nerdctl build -t reposystem:dev .
# Run with:   nerdctl run -it --rm -v ~/repos:/data reposystem:dev scan /data

# ============================================================================
# Stage 1: Builder (Rust + Deno)
# ============================================================================
FROM cgr.dev/chainguard/wolfi-base@sha256:0d8efc73b806c780206b69d62e1b8cb10e9e2eefa0e4452db81b9fa00b1a5175 AS builder

# Install build dependencies
RUN apk add --no-cache \
    rust \
    cargo \
    deno \
    git \
    graphviz \
    guile \
    nickel

# Set up working directory
WORKDIR /build

# Copy source files
COPY . .

# Build Rust CLI
RUN cargo build --release

# Build ReScript (via Deno)
RUN deno task build || true

# ============================================================================
# Stage 2: Runtime (Minimal Wolfi)
# ============================================================================
FROM cgr.dev/chainguard/wolfi-base@sha256:0d8efc73b806c780206b69d62e1b8cb10e9e2eefa0e4452db81b9fa00b1a5175 AS runtime

# Install runtime dependencies only
RUN apk add --no-cache \
    deno \
    graphviz \
    guile \
    libgcc

# Create non-root user
RUN addgroup -g 1000 reposystem && \
    adduser -u 1000 -G reposystem -D reposystem

# Copy built artifacts
COPY --from=builder /build/target/release/reposystem /usr/local/bin/reposystem
COPY --from=builder /build/src/_build /app/lib

# Copy documentation and specs
COPY --from=builder /build/README.adoc /app/
COPY --from=builder /build/spec /app/spec
COPY --from=builder /build/*.scm /app/

# Set permissions
RUN chown -R reposystem:reposystem /app

# Switch to non-root user
USER reposystem
WORKDIR /app

# Default data directory
VOLUME ["/data"]

# Environment
ENV REPOSYSTEM_DATA_DIR=/data
ENV RUST_LOG=info

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD reposystem --version || exit 1

# Default command
ENTRYPOINT ["reposystem"]
CMD ["--help"]

# ============================================================================
# Labels (OCI Image Spec)
# ============================================================================
LABEL org.opencontainers.image.title="Reposystem"
LABEL org.opencontainers.image.description="Railway yard for your repository ecosystem"
LABEL org.opencontainers.image.vendor="Hyperpolymath"
LABEL org.opencontainers.image.licenses="AGPL-3.0-or-later"
LABEL org.opencontainers.image.source="https://github.com/hyperpolymath/reposystem"
LABEL org.opencontainers.image.documentation="https://github.com/hyperpolymath/reposystem#readme"
