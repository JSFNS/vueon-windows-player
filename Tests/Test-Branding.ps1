# Validate packaged official images and fallback image rendering without setting policies.
#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'Modules\VueOn.Branding.psm1') -Force
foreach ($file in @('VueOn-Wallpaper.png','VueOn-LockScreen.png','VueOn-Account.png')) {
    $path = Join-Path $root ('Branding\' + $file)
    $image = [System.Drawing.Image]::FromFile($path)
    try {
        if ($image.Width -lt 256 -or $image.Height -lt 256) {
            throw ('Invalid dimensions for packaged image: ' + $path)
        }
        Write-Host ('Asset OK: ' + $file + ' (' + $image.Width + 'x' + $image.Height + ')')
    } finally { $image.Dispose() }
}
$temp = Join-Path $env:TEMP ('VueOnBrandTest-' + [guid]::NewGuid().ToString('N'))
try {
    foreach($kind in @('Wallpaper','LockScreen','Account')) {
        $file = Join-Path $temp ($kind+'.png')
        New-VueOnBrandImage -Path $file -Kind $kind
        $test = [System.Drawing.Image]::FromFile($file)
        try {
            if ($kind -eq 'Account') {
                if ($test.Width -ne 448 -or $test.Height -ne 448) { throw 'Account fallback dimensions wrong.' }
            } elseif ($test.Width -ne 1920 -or $test.Height -ne 1080) {
                throw ('Fallback dimensions wrong for '+$kind)
            }
        } finally { $test.Dispose() }
    }
    Write-Host 'Fallback branding generator tests passed.'

# Static Windows desktop tests. A CI service account cannot impersonate
# the interactive VueOnPlayer desktop; verify the actual image after reboot.
$desktop = Get-Content -LiteralPath (Join-Path $root 'Modules\VueOn.Desktop.psm1') -Raw
$runtime = Get-Content -LiteralPath (Join-Path $root 'Runtime\Start-VueOn.ps1') -Raw
$installer = Get-Content -LiteralPath (Join-Path $root 'Install-VueOn.ps1') -Raw
$repair = Get-Content -LiteralPath (Join-Path $root 'Maintenance\Repair-Branding.ps1') -Raw
$launcher = Get-Content -LiteralPath (Join-Path $root 'Repair-VueOn-Branding.cmd') -Raw

if ($desktop -notmatch 'SystemParametersInfoW' -or
    $desktop -notmatch 'Test-VueOnDesktopWallpaper' -or
    $desktop -notmatch 'Get-LastWin32Error') {
    throw 'VueOn desktop wallpaper needs an explicit Windows API call and verification.'
}
if ($runtime -notmatch 'Update-VueOnUserBranding' -or
    $runtime -notmatch 'Get-Process -Name .explorer.' -or
    $runtime -notmatch 'TotalSeconds -ge 30') {
    throw 'Watchdog must apply wallpaper after Explorer starts, and retry periodically.'
}
if ($installer -notmatch 'Modules\\VueOn.Desktop.psm1' -or
    $installer -notmatch 'Maintenance\\Repair-Branding.ps1') {
    throw 'Installer must deploy the branding module and non-destructive repair script.'
}
if ($repair -notmatch 'VueOnPlayer' -or
    $repair -match 'Enable-VueOnAutoLogon|Disable-VueOnAutoLogon|New-LocalUser|Remove-LocalUser') {
    throw 'Repair must run only in VueOnPlayer session and must not touch Windows accounts or autologon.'
}
if ($launcher -notmatch 'Maintenance\\Repair-Branding.ps1') {
    throw 'The one-click branding repair launcher is missing its script target.'
}
Write-Host 'Desktop wallpaper recovery and installer regression checks passed.'
} finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
