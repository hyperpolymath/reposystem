# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

# Gitvisor Container Image
# Based on Wolfi for minimal attack surface

# =============================================================================
# Stage 1: Build Elixir backend
# =============================================================================
FROM cgr.dev/chainguard/wolfi-base:latest AS backend-builder

# Install build dependencies
RUN apk add --no-cache \
    elixir \
    erlang \
    erlang-dev \
    git \
    build-base

WORKDIR /app/backend

# Copy and fetch dependencies
COPY backend/mix.exs backend/mix.lock ./
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get --only prod

# Copy source and compile
COPY backend/lib ./lib
COPY backend/config ./config
COPY backend/priv ./priv

ENV MIX_ENV=prod
RUN mix compile && mix release

# =============================================================================
# Stage 2: Build ReScript frontend
# =============================================================================
FROM cgr.dev/chainguard/wolfi-base:latest AS frontend-builder

RUN apk add --no-cache \
    deno \
    nodejs \
    npm

WORKDIR /app/frontend

# Copy and build frontend
COPY frontend/package.json frontend/rescript.json ./
COPY frontend/deno.json ./
RUN npm install

COPY frontend/src ./src
RUN npx rescript build && deno task build

# =============================================================================
# Stage 3: Build Ada TUI
# =============================================================================
FROM cgr.dev/chainguard/wolfi-base:latest AS tui-builder

RUN apk add --no-cache \
    gnat \
    gprbuild

WORKDIR /app/tui

COPY tui/gitvisor_tui.gpr ./
COPY tui/src ./src

RUN gprbuild -P gitvisor_tui.gpr -XMODE=release

# =============================================================================
# Stage 4: Runtime image
# =============================================================================
FROM cgr.dev/chainguard/wolfi-base:latest AS runtime

# Install runtime dependencies only
RUN apk add --no-cache \
    erlang \
    libstdc++ \
    openssl \
    ca-certificates

# Create non-root user
RUN adduser -D -u 1000 gitvisor
USER gitvisor

WORKDIR /app

# Copy backend release
COPY --from=backend-builder --chown=gitvisor:gitvisor \
    /app/backend/_build/prod/rel/gitvisor ./

# Copy frontend build
COPY --from=frontend-builder --chown=gitvisor:gitvisor \
    /app/frontend/dist ./priv/static

# Copy TUI binary
COPY --from=tui-builder --chown=gitvisor:gitvisor \
    /app/tui/bin/gitvisor_tui ./bin/

# Expose Phoenix port
EXPOSE 4000

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:4000/api/v1/health || exit 1

# Run the Phoenix server
CMD ["bin/gitvisor", "start"]
