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

function Update-VueOnUserBranding {
    # Windows can reset the desktop theme while Explorer initializes. Only
    # apply once the interactive desktop shell is running and keep checking.
    if (-not (Get-Process -Name 'explorer' -ErrorAction SilentlyContinue)) {
        return $false
    }
    $source = Join-Path $installRoot 'Branding\VueOn-Wallpaper.png'
    $module = Join-Path $installRoot 'Modules\VueOn.Desktop.psm1'
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        Write-VueOnLog 'VueOn wallpaper asset missing; the viewer will continue.'
        return $false
    }
    if (-not (Test-Path -LiteralPath $module -PathType Leaf)) {
        Write-VueOnLog 'VueOn desktop branding module missing; the viewer will continue.'
        return $false
    }
    Import-Module $module -Force -ErrorAction Stop
    $dest = Join-Path $localRoot 'Branding\VueOn-Wallpaper.png'
    if (Test-VueOnDesktopWallpaper -DestinationImagePath $dest) {
        return $true
    }
    $null = Set-VueOnDesktopWallpaper -SourceImagePath $source -DestinationImagePath $dest
    Write-VueOnLog ('Wallpaper applied and verified for VueOnPlayer: ' + $dest)
    return $true
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
    # Open the viewer independently. Wallpaper failure must never block signage.
    try { Start-VueOnBrowser } catch { Write-VueOnLog ('Initial launch issue: ' + $_.Exception.Message) }
    $lastBrandingCheck = [datetime]::MinValue
    Start-Sleep -Seconds $startDelaySeconds
    while ($true) {
        try {
            if (-not (Test-Path -LiteralPath $maintenance)) { Start-VueOnBrowser }
        } catch { Write-VueOnLog ('Watchdog error: ' + $_.Exception.Message) }

        # Reapply only if the current user's wallpaper is missing or changed.
        # Retries naturally cover Explorer starting after the scheduled task.
        if (((Get-Date) - $lastBrandingCheck).TotalSeconds -ge 30) {
            $lastBrandingCheck = Get-Date
            try { $null = Update-VueOnUserBranding }
            catch { Write-VueOnLog ('Wallpaper setup will retry: ' + $_.Exception.Message) }
        }
        Start-Sleep -Seconds $checkIntervalSeconds
    }
} finally {
    try { $mutex.ReleaseMutex() } catch { }
    $mutex.Dispose()
}
