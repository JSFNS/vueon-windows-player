# End-to-end Windows LogonUser password validation using a disposable local user.
# The account is removed in finally. No credentials are written to logs.
#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'The temporary-account credential test requires an elevated Windows runner.'
}
$module = Join-Path (Split-Path -Parent $PSScriptRoot) 'Modules\VueOn.Credentials.psm1'
Import-Module $module -Force
$name = 'VonT' + [Guid]::NewGuid().ToString('N').Substring(0,8)
$passwordText = [Guid]::NewGuid().ToString('N') + 'Aa9!'
$password = ConvertTo-SecureString $passwordText -AsPlainText -Force
$wrongPassword = ConvertTo-SecureString ([Guid]::NewGuid().ToString('N') + 'Aa9!') -AsPlainText -Force
try {
    New-LocalUser -Name $name -Password $password -Description 'VueOn test only (delete immediately)' -PasswordNeverExpires | Out-Null
    if (-not (Test-VueOnLocalPassword -UserName $name -Password $password)) {
        throw 'A freshly created local Windows account must pass password verification.'
    }
    if (Test-VueOnLocalPassword -UserName $name -Password $wrongPassword) {
        throw 'An incorrect password must never pass verification.'
    }
    Write-Host 'Local account password verification tests passed.'
} finally {
    Remove-LocalUser -Name $name -ErrorAction SilentlyContinue
    $passwordText = $null
}
