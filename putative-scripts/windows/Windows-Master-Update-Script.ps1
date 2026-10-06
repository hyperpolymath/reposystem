# Requires Run as Administrator
if (-Not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell -ArgumentList "-NoExit -ExecutionPolicy Bypass -File `"C:\Users\USER\OneDrive\Desktop\Master-Update-Script.ps1`"" -Verb RunAs
    Exit
}

Write-Host "========================================="
Write-Host "       MASTER SYSTEM UPDATER RUNNING     "
Write-Host "========================================="
Write-Host ""

Write-Host ">>> Updating Windows Packages via Winget..."
winget upgrade --all --accept-source-agreements --accept-package-agreements

Write-Host "`n>>> Updating Packages via Chocolatey..."
if (Get-Command choco -ErrorAction SilentlyContinue) {
    choco upgrade all -y
} else {
    Write-Host "Chocolatey not found."
}

Write-Host "`n>>> Updating Packages via Scoop..."
if (Get-Command scoop -ErrorAction SilentlyContinue) {
    scoop update
    scoop update *
} else {
    Write-Host "Scoop not found."
}

Write-Host "`n>>> Updating Developer Toolchains (Windows)..."
if (Get-Command rustup -ErrorAction SilentlyContinue) {
    Write-Host "--> Updating Rust (rustup)..."
    rustup update
}
if (Get-Command cargo -ErrorAction SilentlyContinue) {
    Write-Host "--> Updating Cargo Binaries (requires cargo-update crate)..."
    cargo install-update -a
}
if (Get-Command npm -ErrorAction SilentlyContinue) {
    Write-Host "--> Updating npm (self)..."
    npm install -g npm@latest
}
if (Get-Command python -ErrorAction SilentlyContinue) {
    Write-Host "--> Updating pip (self)..."
    python -m pip install --upgrade pip
}
if (Get-Command mix -ErrorAction SilentlyContinue) {
    Write-Host "--> Updating Elixir Hex and Rebar (Windows)..."
    mix local.hex --force
    mix local.rebar --force
}

Write-Host "`n>>> Updating WSL (Debian Linux) and Toolchains..."
if (Get-Command wsl -ErrorAction SilentlyContinue) {
    Write-Host "--> Running APT updates..."
    wsl -d Debian -u root -- bash -c "apt-get update && apt-get upgrade -y && apt-get autoremove -y"
    
    Write-Host "--> Updating Elixir/Hex in WSL (if installed)..."
    wsl -d Debian -- bash -c "if command -v mix > /dev/null 2>&1; then mix local.hex --force && mix local.rebar --force; fi"
}

Write-Host "`n========================================="
Write-Host "       DEEP SYSTEM HEALTH CHECKS         "
Write-Host "========================================="

Write-Host "`n>>> Running System File Checker (sfc)..."
sfc /scannow

Write-Host "`n>>> Running Windows Image Repair (DISM)..."
DISM /Online /Cleanup-Image /RestoreHealth

Write-Host "`n>>> Running Drive Optimizer (TRIM/Defrag) for C: ..."
Optimize-Volume -DriveLetter C -ReTrim -Verbose

Write-Host "`n========================================="
Write-Host "    ALL UPDATES & SCANS COMPLETED!       "
Write-Host "========================================="
Pause
