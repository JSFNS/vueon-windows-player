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
} finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
