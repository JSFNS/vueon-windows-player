#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Run as administrator.' }
Remove-Item -LiteralPath (Join-Path $env:ProgramData 'VueOnPlayer\maintenance.flag') -ErrorAction SilentlyContinue
Write-Host 'Maintenance disabled. Watchdog will resume in about five seconds.'
