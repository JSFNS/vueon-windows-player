# Remove VueOn scheduled startup and optional automatic login.
# Does not delete pairing storage or Windows local accounts.
#Requires -Version 5.1
[CmdletBinding()]
param([switch]$KeepAutologon)
$ErrorActionPreference = 'Stop'
$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this script in an elevated Windows PowerShell session.'
}
$root = Join-Path $env:ProgramData 'VueOnPlayer'
New-Item -Path (Join-Path $root 'maintenance.flag') -ItemType File -Force | Out-Null
Unregister-ScheduledTask -TaskName 'VueOnPlayer-Start' -Confirm:$false -ErrorAction SilentlyContinue
if (-not $KeepAutologon) {
    $module = Join-Path $root 'Modules\VueOn.Autologon.psm1'
    if (Test-Path -LiteralPath $module) {
        Import-Module $module -Force
        if (Disable-VueOnAutoLogon -UserName 'VueOnPlayer') {
            Write-Host 'VueOnPlayer auto-login disabled.'
        } else { Write-Host 'Autologon belonged to a different account; left unchanged.' }
    }
}
Write-Host 'VueOn startup disabled. Sign out or reboot to stop the current player session.'
Write-Host 'Accounts and local browser pairing data have NOT been deleted.'
Write-Host 'Optional cleanup: remove C:\ProgramData\VueOnPlayer after preserving logs.'
