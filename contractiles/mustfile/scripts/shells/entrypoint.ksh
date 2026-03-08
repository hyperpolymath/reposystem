#!/usr/bin/env ksh
# entrypoint.ksh - Korn shell entrypoint for Must
# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (C) 2025 Jonathan D.A. Jewell

set -eu

if ! command -v must > /dev/null 2>&1; then
    if [[ -x "./bin/must" ]]; then
        exec ./bin/must "$@"
    else
        print -u2 "Error: 'must' not found. Build with 'just build' or install."
        exit 1
    fi
fi

exec must "$@"
