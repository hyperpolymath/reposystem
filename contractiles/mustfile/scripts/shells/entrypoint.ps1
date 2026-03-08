#!/usr/bin/env pwsh
# entrypoint.ps1 - PowerShell Core entrypoint for Must
# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (C) 2025 Jonathan D.A. Jewell

$ErrorActionPreference = "Stop"

$mustPath = Get-Command must -ErrorAction SilentlyContinue

if (-not $mustPath) {
    if (Test-Path "./bin/must") {
        & "./bin/must" @args
        exit $LASTEXITCODE
    } else {
        Write-Error "Error: 'must' not found. Build with 'just build' or install."
        exit 1
    }
}

& must @args
exit $LASTEXITCODE
