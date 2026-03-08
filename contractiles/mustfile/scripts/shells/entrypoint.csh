#!/usr/bin/env csh
# entrypoint.csh - C shell entrypoint for Must
# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (C) 2025 Jonathan D.A. Jewell

if ( ! -X must ) then
    if ( -x ./bin/must ) then
        exec ./bin/must $argv:q
    else
        echo "Error: 'must' not found. Build with 'just build' or install."
        exit 1
    endif
endif

exec must $argv:q
