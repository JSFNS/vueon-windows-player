# Repair VueOn desktop branding in the existing VueOnPlayer Windows session.
# No administrator access, Windows reset, or reinstallation is required.
#Requires -Version 5.1
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
try {
    if ($env:USERNAME -ine 'VueOnPlayer') {
        throw 'Sign into Windows as VueOnPlayer first. Do not use Run as administrator for this repair.'
    }

    $packageRoot = Split-Path -Parent $PSScriptRoot
    $installedRoot = Join-Path $env:ProgramData 'VueOnPlayer'
    $module = Join-Path $packageRoot 'Modules\VueOn.Desktop.psm1'
    $wallpaper = Join-Path $packageRoot 'Branding\VueOn-Wallpaper.png'
    if (-not (Test-Path -LiteralPath $module -PathType Leaf)) {
        throw 'The updated VueOn Desktop module is missing. Download a fresh ZIP.'
    }
    if (-not (Test-Path -LiteralPath $wallpaper -PathType Leaf)) {
        $wallpaper = Join-Path $installedRoot 'Branding\VueOn-Wallpaper.png'
    }
    if (-not (Test-Path -LiteralPath $wallpaper -PathType Leaf)) {
        throw 'VueOn wallpaper PNG is missing.'
    }

    $localDir = Join-Path $env:LOCALAPPDATA 'VueOn\Branding'
    $target = Join-Path $localDir 'VueOn-Wallpaper.png'
    Import-Module -Name $module -Force -ErrorAction Stop

    $explorerReady = $false
    for ($i = 0; $i -lt 15; $i++) {
        if (Get-Process -Name explorer -ErrorAction SilentlyContinue) {
            $explorerReady = $true
            break
        }
        Start-Sleep -Seconds 2
    }
    if (-not $explorerReady) {
        throw 'Windows desktop (Explorer) did not start; try again after signing in normally.'
    }
    $null = Set-VueOnDesktopWallpaper -SourceImagePath $wallpaper -DestinationImagePath $target
    if (-not (Test-VueOnDesktopWallpaper -DestinationImagePath $target)) {
        throw 'Wallpaper verification failed.'
    }
    Write-Host 'SUCCESS: VueOn desktop wallpaper applied.' -ForegroundColor Green
    Write-Host ('Installed image: ' + $target)
    Write-Host 'Press Windows+D to see the desktop behind the full-screen VueOn player.'

    # Put the supported manual Windows Pro/Home branding files somewhere easy
    # to select through the native Windows Personalization settings.
    $pictures = Join-Path $env:USERPROFILE 'Pictures\VueOn'
    $null = New-Item -Path $pictures -ItemType Directory -Force
    foreach ($file in @('VueOn-LockScreen.png','VueOn-Account.png')) {
        $candidate = Join-Path (Join-Path $packageRoot 'Branding') $file
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            $candidate = Join-Path (Join-Path $installedRoot 'Branding') $file
        }
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            Copy-Item -LiteralPath $candidate -Destination (Join-Path $pictures $file) -Force
        }
    }
    Write-Host ''
    Write-Host 'Windows 11 Home/Pro lock screen (manual, one-time):' -ForegroundColor Cyan
    Write-Host 'Settings > Personalization > Lock screen > Picture > Browse photos'
    Write-Host ('Choose ' + (Join-Path $pictures 'VueOn-LockScreen.png'))
    Write-Host 'Enable "Show the lock screen background picture on the sign-in screen" if displayed.'
    Write-Host ''
    Write-Host 'VueOn account photo (manual, one-time): Settings > Accounts > Your info > Choose a file'
    Write-Host ('Choose ' + (Join-Path $pictures 'VueOn-Account.png'))
    exit 0
} catch {
    Write-Host ('VueOn branding repair failed: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
