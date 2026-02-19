#!/usr/bin/env bash
# entrypoint.bash - Bash shell entrypoint for Must
# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (C) 2025 Jonathan D.A. Jewell

set -euo pipefail

# Ensure must is available
if ! command -v must &> /dev/null; then
    if [[ -x "./bin/must" ]]; then
        exec ./bin/must "$@"
    else
        echo "Error: 'must' not found. Build with 'just build' or install." >&2
        exit 1
    fi
fi

exec must "$@"
