# SPDX-License-Identifier: PMPL-1.0
# Wolfi-based container for bitfuckit
# Build: nerdctl build -t bitfuckit:latest .
# Run: nerdctl run -it --rm bitfuckit:latest --help

# Stage 1: Build environment
FROM cgr.dev/chainguard/wolfi-base:latest AS builder

# Install Ada compiler and build dependencies
RUN apk add --no-cache \
    gcc \
    gnat \
    gprbuild \
    curl-dev \
    make \
    git

WORKDIR /build
COPY . .

# Build the binary
RUN gprbuild -P bitfuckit.gpr -j0 -XLIBRARY_TYPE=static

# Stage 2: Minimal runtime image
FROM cgr.dev/chainguard/wolfi-base:latest

# Runtime dependencies only
RUN apk add --no-cache \
    curl \
    git \
    ca-certificates

# Create non-root user
RUN addgroup -S bitfuckit && adduser -S bitfuckit -G bitfuckit

# Copy binary from builder
COPY --from=builder /build/bin/bitfuckit /usr/local/bin/bitfuckit

# Copy completions and docs
COPY --from=builder /build/completions /usr/share/bitfuckit/completions
COPY --from=builder /build/doc /usr/share/bitfuckit/doc

# Set ownership
RUN chown -R bitfuckit:bitfuckit /usr/share/bitfuckit

# Runtime config
USER bitfuckit
WORKDIR /home/bitfuckit

# Config directory
VOLUME ["/home/bitfuckit/.config/bitfuckit"]

# Default command
ENTRYPOINT ["/usr/local/bin/bitfuckit"]
CMD ["--help"]

# Labels
LABEL org.opencontainers.image.title="bitfuckit"
LABEL org.opencontainers.image.description="The Bitbucket CLI Atlassian never made"
LABEL org.opencontainers.image.version="0.2.0"
LABEL org.opencontainers.image.vendor="hyperpolymath"
LABEL org.opencontainers.image.licenses="PMPL-1.0-or-later"
LABEL org.opencontainers.image.source="https://github.com/hyperpolymath/bitfuckit"
LABEL org.opencontainers.image.base.name="cgr.dev/chainguard/wolfi-base"
