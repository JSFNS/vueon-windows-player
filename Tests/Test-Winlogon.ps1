# Regression test: a fresh Windows 11 machine lacks optional Winlogon values.
# Test ONLY a temporary HKCU key. Never touch the real HKLM Winlogon settings.
#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$module = Join-Path (Split-Path -Parent $PSScriptRoot) 'Modules\VueOn.Autologon.psm1'
Import-Module -Name $module -Force -ErrorAction Stop

$key = 'HKCU:\Software\VueOn-WinlogonTest-' + [guid]::NewGuid().ToString('N')
try {
    New-Item -Path $key -Force -ErrorAction Stop | Out-Null

    # Test 1: DefaultUserName and AutoAdminLogon are both missing.
    if (Disable-VueOnPreviewAutoLogon -RegistryPath $key -UserName 'VueOnPlayer' -ComputerName 'TESTPC') {
        throw 'Missing registry values must not be treated as enabled auto login.'
    }

    # Test 2: enabled flag exists, but DefaultUserName is absent.
    New-ItemProperty -Path $key -Name 'AutoAdminLogon' -PropertyType String -Value '1' -Force | Out-Null
    if (Disable-VueOnPreviewAutoLogon -RegistryPath $key -UserName 'VueOnPlayer' -ComputerName 'TESTPC') {
        throw 'Missing DefaultUserName must not trigger a write.'
    }
    if ((Get-ItemPropertyValue -Path $key -Name 'AutoAdminLogon') -ne '1') {
        throw 'Unrelated autologon config was changed.'
    }

    # Test 3: an unrelated Windows account is still protected.
    New-ItemProperty -Path $key -Name 'DefaultUserName' -PropertyType String -Value 'OtherUser' -Force | Out-Null
    if (Disable-VueOnPreviewAutoLogon -RegistryPath $key -UserName 'VueOnPlayer' -ComputerName 'TESTPC') {
        throw 'An unrelated user auto login must not be altered.'
    }
    if ((Get-ItemPropertyValue -Path $key -Name 'AutoAdminLogon') -ne '1') {
        throw 'Existing other-user auto login was modified.'
    }

    # Test 4: same account but different domain must not be touched.
    Set-ItemProperty -Path $key -Name 'DefaultUserName' -Value 'VueOnPlayer'
    New-ItemProperty -Path $key -Name 'DefaultDomainName' -PropertyType String -Value 'OTHERDOMAIN' -Force | Out-Null
    if (Disable-VueOnPreviewAutoLogon -RegistryPath $key -UserName 'VueOnPlayer' -ComputerName 'TESTPC') {
        throw 'Wrong-domain auto login must not be disabled.'
    }

    # Test 5: verified VueOnPlayer on this device is disabled, for manual sign-in.
    Set-ItemProperty -Path $key -Name 'DefaultDomainName' -Value 'TESTPC'
    if (-not (Disable-VueOnPreviewAutoLogon -RegistryPath $key -UserName 'VueOnPlayer' -ComputerName 'TESTPC')) {
        throw 'Matching VueOnPlayer auto login must be disabled for first stage.'
    }
    if ((Get-ItemPropertyValue -Path $key -Name 'AutoAdminLogon') -ne '0') {
        throw 'VueOnPlayer auto login was not disabled.'
    }

    Write-Host 'Fresh Windows 11 missing-Winlogon-value regression tests passed.'
} finally {
    Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue
}
