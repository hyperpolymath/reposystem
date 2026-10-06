#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Launch Claude Code inside one of your git repos so cloud features
    (/ultraplan, "Claude Code on the web", /code-review ultra) actually start.

.DESCRIPTION
    Cloud agents refuse to launch unless the current working directory is a git
    repository. When Claude Code is started from a shortcut with no "Start in"
    folder (or from Win+R), its cwd defaults to C:\Windows\System32, producing:

        ultraplan: cannot launch cloud session -
        Cloud agents require a git repository (checked: C:\Windows\System32).

    This script resolves a repo under your WSL Debian developer tree (or any
    path you pass), verifies git recognises it, then starts `claude` there.
    Anything after the repo name is forwarded to claude (e.g. an initial prompt).

.PARAMETER Repo
    Repo name (looked up under the known roots) or an explicit path.
    Omit to get an interactive numbered picker.

.PARAMETER Wsl
    Launch claude *inside* WSL Debian instead of the Windows build. Use this if
    the Windows build is flaky over the \\wsl.localhost UNC path (git "dubious
    ownership", slow FS). Requires claude to be installed inside Debian.

.EXAMPLE
    .\Launch-ClaudePlan.ps1 statistikles
.EXAMPLE
    .\Launch-ClaudePlan.ps1 -Repo idaptik-ums "/ultraplan refactor the UMS bridge"
.EXAMPLE
    .\Launch-ClaudePlan.ps1            # interactive picker
.EXAMPLE
    .\Launch-ClaudePlan.ps1 statistikles -Wsl
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Repo,

    [switch]$Wsl,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ClaudeArgs
)

$ErrorActionPreference = 'Stop'

# --- WSL Debian roots that hold git repos (UNC view from Windows) -----------
# NB: distro is Debian now (Ubuntu was deregistered 2026-07-10). If you ever
# rename/replace the distro, update $DistroUnc.
$DistroUnc = '\\wsl.localhost\Debian'
$DevRoot   = "$DistroUnc\home\hyperpolymath\developer"
$RepoRoots = @(
    "$DevRoot\hyper-repos",
    "$DevRoot\meta-repos",
    "$DevRoot\repos"
)

function Get-GitRepos {
    foreach ($root in $RepoRoots) {
        if (-not (Test-Path $root)) { continue }
        Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue |
            Where-Object { Test-Path (Join-Path $_.FullName '.git') }
    }
}

function Resolve-RepoPath([string]$name) {
    if ([string]::IsNullOrWhiteSpace($name)) { return $null }
    if (Test-Path $name) { return (Resolve-Path $name).Path }   # explicit path wins
    foreach ($root in $RepoRoots) {
        $candidate = Join-Path $root $name
        if (Test-Path (Join-Path $candidate '.git')) { return $candidate }
    }
    return $null
}

# Convert a \\wsl.localhost\Debian\home\... path to a Linux /home/... path.
function ConvertTo-WslPath([string]$uncPath) {
    $prefix = "$DistroUnc"
    $rel = $uncPath.Substring($prefix.Length)          # \home\hyperpolymath\...
    return ($rel -replace '\\', '/')                    # /home/hyperpolymath/...
}

# --- Pick the target repo ---------------------------------------------------
$target = $null
if ($Repo) {
    $target = Resolve-RepoPath $Repo
    if (-not $target) {
        Write-Error "No git repo named '$Repo' found under: $($RepoRoots -join ', ')"
        exit 1
    }
}
else {
    $repos = @(Get-GitRepos | Sort-Object Name)
    if (-not $repos) {
        Write-Error "No git repos found under: $($RepoRoots -join ', '). Is WSL running?"
        exit 1
    }
    Write-Host "Select a repo to launch Claude Code in:`n"
    for ($i = 0; $i -lt $repos.Count; $i++) {
        '{0,3}: {1}' -f ($i + 1), $repos[$i].Name | Write-Host
    }
    $sel = Read-Host "`nNumber (1-$($repos.Count))"
    $idx = 0
    if (-not [int]::TryParse($sel, [ref]$idx) -or $idx -lt 1 -or $idx -gt $repos.Count) {
        Write-Error 'Invalid selection.'
        exit 1
    }
    $target = $repos[$idx - 1].FullName
}

# --- Launch -----------------------------------------------------------------
if ($Wsl) {
    # Native launch inside Debian: no UNC, no dubious-ownership issues.
    $linuxPath = ConvertTo-WslPath $target
    $fwd = if ($ClaudeArgs) { ' ' + ($ClaudeArgs -join ' ') } else { '' }
    Write-Host "`nLaunching Claude Code (WSL Debian) in: $linuxPath`n" -ForegroundColor Green
    wsl.exe -d Debian -- bash -lc "cd '$linuxPath' && claude$fwd"
    exit $LASTEXITCODE
}

# Windows build, cwd on the UNC path.
Push-Location $target
try {
    git rev-parse --is-inside-work-tree *> $null 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "git does not recognise '$target' as a work tree."
        Write-Warning "If this is a 'dubious ownership' error, whitelist it:"
        Write-Warning "  git config --global --add safe.directory '$target'"
        Write-Warning "or re-run with -Wsl to launch inside Debian instead."
    }
    Write-Host "`nLaunching Claude Code in: $target`n" -ForegroundColor Green
    if ($ClaudeArgs) { claude @ClaudeArgs } else { claude }
}
finally {
    Pop-Location
}
