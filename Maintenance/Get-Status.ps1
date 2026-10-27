# Read-only deployment health check. Actual pairing and video playback require on-screen verification.
#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Join-Path $env:ProgramData 'VueOnPlayer'
$reportPath = Join-Path $root 'deployment-report.json'
$registry = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
$task = Get-ScheduledTask -TaskName 'VueOnPlayer-Start' -ErrorAction SilentlyContinue
$bios = $null
if (Test-Path -LiteralPath (Join-Path $root 'Modules\VueOn.Bios.psm1')) {
    Import-Module (Join-Path $root 'Modules\VueOn.Bios.psm1') -Force
    $bios = Invoke-VueOnPowerRecovery
}
[pscustomobject]@{
    Machine = $env:COMPUTERNAME
    Installed = (Test-Path -LiteralPath $reportPath)
    AutoLoginAccount = [string]$registry.DefaultUserName
    AutoLoginEnabled = ($registry.AutoAdminLogon -eq '1')
    StartupTaskPresent = ($null -ne $task)
    StartupTaskState = if ($task) { [string]$task.State } else { 'Missing' }
    Maintenance = (Test-Path -LiteralPath (Join-Path $root 'maintenance.flag'))
    BiosPowerRecovery = if ($bios) { $bios.PowerRecovery } else { 'Unknown' }
    BiosStatus = if ($bios) { $bios.Message } else { 'Not detected' }
    Pairing = 'Verify manually in the VueOn portal after restart'
} | Format-List
Write-Host 'Latest installer report: ' $reportPath
