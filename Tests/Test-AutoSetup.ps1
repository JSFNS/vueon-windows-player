# Confirm the official Microsoft executable can be downloaded and authenticated,
# and that absent registry values are handled without touching real Winlogon.
#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'Modules\VueOn.AutoSetup.psm1') -Force

$dir = Join-Path $env:TEMP ('VueOnAutoSetupTest-' + [guid]::NewGuid().ToString('N'))
$key = 'HKCU:\Software\VueOn-WinlogonStateTest-' + [guid]::NewGuid().ToString('N')
try {
    New-Item -Path $key -Force | Out-Null
    $empty = Get-VueOnWinlogonState -RegistryPath $key
    if ($empty.Enabled -or $empty.UserName -or $empty.Domain) {
        throw 'Missing Winlogon fields must be reported as unconfigured.'
    }
    New-ItemProperty -Path $key -Name 'DefaultUserName' -Value 'VueOnPlayer' -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $key -Name 'DefaultDomainName' -Value 'EXAMPLE' -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $key -Name 'AutoAdminLogon' -Value '1' -PropertyType String -Force | Out-Null
    $configured = Get-VueOnWinlogonState -RegistryPath $key
    if (-not $configured.Enabled -or $configured.UserName -ne 'VueOnPlayer' -or
        $configured.Domain -ne 'EXAMPLE') {
        throw 'Configured Winlogon registry state was not read correctly.'
    }
    $exe = Get-VueOnMicrosoftAutologon -Destination $dir
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
        throw 'Microsoft Autologon download or signature check failed.'
    }
    Write-Host 'Microsoft Autologon signature and registry state tests passed.'
} finally {
    Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
}
