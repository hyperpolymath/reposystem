@echo off
REM entrypoint.cmd - Windows CMD entrypoint for Must
REM SPDX-License-Identifier: AGPL-3.0-or-later
REM Copyright (C) 2025 Jonathan D.A. Jewell

where must >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    must %*
    exit /b %ERRORLEVEL%
)

if exist ".\bin\must.exe" (
    .\bin\must.exe %*
    exit /b %ERRORLEVEL%
)

echo Error: 'must' not found. Build with 'just build' or install. 1>&2
exit /b 1
