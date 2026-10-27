# Test VueOn ACLs on Windows, including a file with deliberately removed access.
# Scoped to a unique temporary folder. Never changes a deployed VueOn player.
#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'This permissions integration test must run on an elevated Windows runner.'
}
$root = Join-Path $env:TEMP ('VueOnAclTest-' + [guid]::NewGuid().ToString('N'))
Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'Modules\VueOn.Permissions.psm1') -Force

try {
    Initialize-VueOnInstallationAcl -Root $root
    $file = Join-Path $root 'Runtime\Start-VueOn.ps1'
    [IO.File]::WriteAllText($file, 'VueOn temporary permissions test')

    # The original deployment created regular files with no effective grants.
    # Remove inherited access from a disposable file to simulate that case.
    $output = & icacls.exe $file '/inheritance:r' 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw ('Failed to prepare the temporary locked file: ' + ($output | Out-String))
    }
    Repair-VueOnFileAcl -Root $root -Path $file
    if (-not (Test-VueOnFileWritable -Path $file)) {
        throw 'The repair failed to restore write permission on the temporary file.'
    }

    $second = Join-Path $root 'Modules\VueOn.Branding.psm1'
    [IO.File]::WriteAllText($second,'Temporary branding module')
    $output = & icacls.exe $second '/inheritance:r' 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw ('Failed to lock temporary second file: ' + ($output | Out-String))
    }
    Repair-VueOnFileAcl -Root $root -Path $second
    Protect-VueOnInstallationAcl -Root $root

    foreach ($path in @($file,$second)) {
        if (-not (Test-VueOnFileWritable -Path $path)) {
            throw ('The VueOn ACL lockdown made a tested file unwritable: ' + $path)
        }
        $acl = Get-Acl -LiteralPath $path
        $administrators = @($acl.Access | Where-Object {
            $_.IdentityReference.Value -match 'Administrators|S-1-5-32-544' -and
            $_.FileSystemRights.ToString() -match 'FullControl'
        })
        if ($administrators.Count -lt 1) {
            throw ('Administrators Full Control missing on test file: ' + $path)
        }
    }
    Write-Host 'VueOn ACL integration test passed for two previously damaged files.'
} finally {
    if (Test-Path -LiteralPath $root) {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction Stop
    }
}
