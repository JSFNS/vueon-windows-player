# VueOn Windows Player session launcher + five-second watchdog.
# Runs in the restricted VueOnPlayer interactive session; NEVER as SYSTEM.
# Leave this process running for the lifetime of the desktop session.
#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$installRoot = Join-Path $env:ProgramData 'VueOnPlayer'
$localRoot = Join-Path $env:LOCALAPPDATA 'VueOn'
$profilePath = Join-Path $localRoot 'EdgeProfile'
$logPath = Join-Path $localRoot 'VueOn-Watchdog.log'
$maintenance = Join-Path $installRoot 'maintenance.flag'
$viewerUrl = 'https://portal.vueon.app/pair/'
$startDelaySeconds = 15
$checkIntervalSeconds = 5

New-Item -Path $localRoot -ItemType Directory -Force | Out-Null
$created = $false
$mutex = [System.Threading.Mutex]::new($true, 'Local\VueOnPlayerWatchdog', [ref]$created)
if (-not $created) { $mutex.Dispose(); exit 0 }

function Write-VueOnLog([string]$Message) {
    try {
        if ((Test-Path -LiteralPath $logPath) -and (Get-Item -LiteralPath $logPath).Length -gt 1048576) {
            Move-Item -LiteralPath $logPath -Destination "$logPath.old" -Force
        }
        Add-Content -LiteralPath $logPath -Encoding UTF8 -Value ('{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message)
    } catch { }
}

function Set-VueOnUserBranding {
    $source = Join-Path $installRoot 'Branding\VueOn-Wallpaper.png'
    if (-not (Test-Path -LiteralPath $source)) { Write-VueOnLog 'Branding asset missing.'; return }
    $destDir = Join-Path $localRoot 'Branding'
    New-Item -Path $destDir -ItemType Directory -Force | Out-Null
    $dest = Join-Path $destDir 'VueOn-Wallpaper.png'
    Copy-Item -LiteralPath $source -Destination $dest -Force
    $desktopKey = 'HKCU:\Control Panel\Desktop'
    Set-ItemProperty -Path $desktopKey -Name 'WallpaperStyle' -Value '10'
    Set-ItemProperty -Path $desktopKey -Name 'TileWallpaper' -Value '0'
    Set-ItemProperty -Path $desktopKey -Name 'ScreenSaveActive' -Value '0'
    $advanced = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    New-Item -Path $advanced -Force | Out-Null
    New-ItemProperty -Path $advanced -Name 'HideIcons' -PropertyType DWord -Value 1 -Force | Out-Null
    if (-not ('VueOnWallpaperApi' -as [type])) {
        Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
public static class VueOnWallpaperApi {
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool SystemParametersInfo(uint action, uint parameter, string value, uint flags);
}
'@
    }
    if (-not [VueOnWallpaperApi]::SystemParametersInfo(20, 0, $dest, 3)) {
        Write-VueOnLog 'Wallpaper update failed; desktop remains usable.'
    }
}

function Get-VueOnEdgePath {
    foreach ($candidate in @(
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe")) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) { return $candidate }
    }
    return $null
}

function Test-VueOnBrowserRunning {
    $processes = @(Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" -ErrorAction Stop)
    $root = @($processes | Where-Object {
        $cmd = [string]$_.CommandLine
        $cmd.IndexOf($profilePath, [StringComparison]::OrdinalIgnoreCase) -ge 0 -and
        $cmd.IndexOf('--type=', [StringComparison]::OrdinalIgnoreCase) -lt 0
    })
    return ($root.Count -gt 0)
}

function Start-VueOnBrowser {
    if (Test-Path -LiteralPath $maintenance) { return }
    $edge = Get-VueOnEdgePath
    if (-not $edge) { Write-VueOnLog 'Microsoft Edge missing.'; return }
    if (Test-VueOnBrowserRunning) { return }
    New-Item -Path $profilePath -ItemType Directory -Force | Out-Null
    $args = '--user-data-dir="{0}" --app="{1}" --start-fullscreen --no-first-run --disable-background-mode' -f $profilePath, $viewerUrl
    Start-Process -FilePath $edge -ArgumentList $args | Out-Null
    Write-VueOnLog 'Launched VueOn viewer.'
}

try {
    if ($env:USERNAME -ine 'VueOnPlayer') {
        Write-VueOnLog ('Unexpected user: ' + $env:USERNAME)
        exit 1
    }
    try { Set-VueOnUserBranding } catch { Write-VueOnLog ('Branding issue: ' + $_.Exception.Message) }
    try { Start-VueOnBrowser } catch { Write-VueOnLog ('Initial launch issue: ' + $_.Exception.Message) }
    Start-Sleep -Seconds $startDelaySeconds
    while ($true) {
        try {
            if (-not (Test-Path -LiteralPath $maintenance)) { Start-VueOnBrowser }
        } catch { Write-VueOnLog ('Watchdog error: ' + $_.Exception.Message) }
        Start-Sleep -Seconds $checkIntervalSeconds
    }
} finally {
    try { $mutex.ReleaseMutex() } catch { }
    $mutex.Dispose()
}
