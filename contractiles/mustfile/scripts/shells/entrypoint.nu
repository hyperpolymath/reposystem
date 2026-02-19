#!/usr/bin/env nu
# entrypoint.nu - Nushell entrypoint for Must
# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (C) 2025 Jonathan D.A. Jewell

def main [...args: string] {
    let must_path = if (which must | is-empty) {
        if ("./bin/must" | path exists) {
            "./bin/must"
        } else {
            print -e "Error: 'must' not found. Build with 'just build' or install."
            exit 1
        }
    } else {
        "must"
    }

    run-external $must_path ...$args
}
