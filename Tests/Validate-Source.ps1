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
# Auto logon is optional, verified before launch, and uses Microsoft's signed GUI.
$batch = Get-Content -LiteralPath (Join-Path $root 'Install-VueOn.cmd') -Raw
if ($batch -match '-SkipAutoLogon|-ConfigureBios' -or $batch -notmatch '-MigrateLegacyStartup') {
    throw 'Default installation must prompt about auto logon, not skip it or change BIOS.'
}
if ($installer -notmatch 'Invoke-VueOnAutoLogonWizard' -or
    $installer -notmatch "Read-Host 'Set up automatic Windows sign-in now") {
    throw 'Installer must offer validated interactive Microsoft automatic login.'
}
if ($installer -match 'Enable-VueOnAutoLogon\s+-UserName') {
    throw 'Do not call the unverified early-release custom LSA password setter.'
}
$setup = Get-Content -LiteralPath (Join-Path $root 'Modules\VueOn.AutoSetup.psm1') -Raw
$credentials = Get-Content -LiteralPath (Join-Path $root 'Modules\VueOn.Credentials.psm1') -Raw
if ($setup -notmatch 'Get-AuthenticodeSignature' -or
    $setup -notmatch 'Test-VueOnLocalPassword' -or
    $setup -notmatch 'Start-Process -FilePath') {
    throw 'Official Microsoft Autologon must be signature-checked and preceded by password verification.'
}
if ($setup -match '(?i)ArgumentList.{0,150}Password' -or
    $setup -match '(?i)cmd\.exe.*Password') {
    throw 'Never expose the VueOn password in executable command-line arguments.'
}
if ($credentials -notmatch 'LogonUserW' -or
    $credentials -notmatch 'ZeroFreeGlobalAllocUnicode') {
    throw 'Windows password validation must use LogonUserW and clear the secret buffer.'
}

# The package must carry actual, official VueOn artwork for all three targets.
foreach ($image in @('VueOn-Wallpaper.png','VueOn-LockScreen.png','VueOn-Account.png')) {
    if (-not (Test-Path -LiteralPath (Join-Path $root ('Branding\' + $image)) -PathType Leaf)) {
        throw ('Branding image is missing: ' + $image)
    }
}
if ($installer -notmatch 'Set-VueOnSupportedLockScreen' -or
    $installer -notmatch 'VueOn-Account.png') {
    throw 'Installer must stage the account and sign-in artwork.'
}
Write-Host 'All static checks passed.'
