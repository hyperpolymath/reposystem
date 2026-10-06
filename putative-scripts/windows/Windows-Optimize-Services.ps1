# Requires Run as Administrator
if (-Not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    # Automatically relaunch the script as Administrator
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"`$PSCommandPath`"" -Verb RunAs
    Exit
}

Write-Host "Disabling Maxim(R) Audio Service from Startup..."
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "MaximAudioSvc" -ErrorAction SilentlyContinue
Write-Host "[OK] MaximAudioSvc disabled."

Write-Host "Disabling Connected User Experiences and Telemetry (DiagTrack)..."
Stop-Service -Name "DiagTrack" -Force -ErrorAction SilentlyContinue
Set-Service -Name "DiagTrack" -StartupType Disabled -ErrorAction SilentlyContinue
Write-Host "[OK] DiagTrack disabled."

Write-Host "Disabling Downloaded Maps Manager (MapsBroker)..."
Stop-Service -Name "MapsBroker" -Force -ErrorAction SilentlyContinue
Set-Service -Name "MapsBroker" -StartupType Disabled -ErrorAction SilentlyContinue
Write-Host "[OK] MapsBroker disabled."

Write-Host ""
Write-Host "Optimizations applied successfully!"
Pause
