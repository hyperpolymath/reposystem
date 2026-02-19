#!/usr/bin/env fish
# entrypoint.fish - Fish shell entrypoint for Must
# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (C) 2025 Jonathan D.A. Jewell

if not command -v must &> /dev/null
    if test -x "./bin/must"
        exec ./bin/must $argv
    else
        echo "Error: 'must' not found. Build with 'just build' or install." >&2
        exit 1
    end
end

exec must $argv
