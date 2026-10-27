#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Run as administrator.' }
$root = Join-Path $env:ProgramData 'VueOnPlayer'
if (-not (Test-Path -LiteralPath $root)) { throw 'VueOn Player is not installed.' }
New-Item -Path (Join-Path $root 'maintenance.flag') -ItemType File -Force | Out-Null
Write-Host 'Maintenance enabled. VueOn will not automatically relaunch Edge.'
