# Parse PowerShell sources on Windows without running provisioning.
#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$files = @(Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object { $_.Extension -in '.ps1','.psm1' })
if ($files.Count -lt 6) { throw 'Critical PowerShell scripts are missing.' }
foreach ($file in $files) {
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) {
        $details = ($errors | ForEach-Object { "Line $($_.Extent.StartLineNumber): $($_.Message)" }) -join '; '
        throw "PowerShell parser failed for $($file.Name): $details"
    }
    Write-Host "Syntax OK: $($file.FullName.Substring($root.Length+1))"
}
$runtime = Get-Content -LiteralPath (Join-Path $root 'Runtime\Start-VueOn.ps1') -Raw
if ($runtime -notmatch 'portal\.vueon\.app/pair/') { throw 'Pairing URL missing.' }
if ($runtime -notmatch 'checkIntervalSeconds\s*=\s*5') { throw 'Expected five-second watchdog interval.' }
if ($runtime -notmatch 'startDelaySeconds\s*=\s*15') { throw 'Expected fifteen-second grace period.' }
if ($runtime -match '--inprivate|--kiosk|--guest') { throw 'InPrivate/guest/kiosk would break pairing.' }
if ($runtime -match 'Remove-Item.{0,100}EdgeProfile') { throw 'Do not clear the pairing profile.' }
$installer = Get-Content -LiteralPath (Join-Path $root 'Install-VueOn.ps1') -Raw
if ($installer -match 'Clear-Tpm|Disable-WindowsDefender|Set-MpPreference.*Disable') { throw 'Unsafe Windows security override.' }
# Regression checks for v0.1.0 through v0.1.2 permission defects.
# Never grant directory-only (OI)/(CI) flags to regular files.
$permissionsPath = Join-Path $root 'Modules\VueOn.Permissions.psm1'
if (-not (Test-Path -LiteralPath $permissionsPath -PathType Leaf)) {
    throw 'Missing VueOn.Permissions.psm1'
}
$permissions = Get-Content -LiteralPath $permissionsPath -Raw
if ($installer -match "icacls\.exe[^\r\n]*'/grant:r'[^\r\n]*'/T'") {
    throw 'Recursive icacls grant on files is prohibited.'
}
if ($installer -match 'function Set-InstallDirectoryAccess|function Repair-ExistingVueOnFileAcl') {
    throw 'Installer still contains the old permissions algorithm.'
}
if ($installer -notmatch 'Initialize-VueOnInstallationAcl' -or
    $installer -notmatch 'Repair-VueOnFileAcl' -or
    $installer -notmatch 'Protect-VueOnInstallationAcl') {
    throw 'Installer must prepare, repair and protect VueOn files using the permissions module.'
}
if ($permissions -notmatch [regex]::Escape("'*S-1-5-32-544:F'") -or
    $permissions -notmatch [regex]::Escape("'*S-1-5-32-545:RX'")) {
    throw 'Permissions module must grant explicit permissions on regular files.'
}
if ($permissions -match "icacls\.exe[^\r\n]*'/grant:r'[^\r\n]*'/T'") {
    throw 'Permissions module may not recursively apply directory ACEs to files.'
}
# The automatic sign-in in v0.1.3 failed on Windows 11 Home.
# Protect first-time provisioning from enabling unverified automatic login.
$batch = Get-Content -LiteralPath (Join-Path $root 'Install-VueOn.cmd') -Raw
if ($batch -notmatch '\-SkipAutoLogon' -or $batch -match '\-ConfigureBios|\-EnableAutoLogon') {
    throw 'The default launch command must avoid BIOS writes and automatic login.'
}
if ($installer -notmatch 'Intentionally deferred: verify manual VueOnPlayer login first') {
    throw 'Installer must require manual VueOnPlayer sign-in before enabling autologon.'
}
Write-Host 'All static checks passed.'
