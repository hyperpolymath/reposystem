if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell -ArgumentList "-NoExit -ExecutionPolicy Bypass -File `"C:\Users\USER\OneDrive\Desktop\Setup-Pathroot.ps1`"" -Verb RunAs
    Exit
}

Write-Host "Creating Windows _pathroot devtools architecture..."

New-Item -ItemType Directory -Force -Path "C:\devtools"
Set-Content -Path "C:\_pathroot" -Value "C:\devtools"

$envbase = @"
{
  "env": "devtools",
  "profile": "default",
  "platform": "windows"
}
"@

Set-Content -Path "C:\devtools\_envbase" -Value $envbase

Write-Host "Success! C:\_pathroot and C:\devtools\_envbase created."
Write-Host "You can close this window."
