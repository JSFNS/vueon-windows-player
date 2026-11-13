# Reliable VueOn desktop wallpaper application inside the signed-in player session.
# Desktop updates are delayed until Explorer has started.
#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Set-VueOnDesktopWallpaper {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SourceImagePath,
        [Parameter(Mandatory)][string]$DestinationImagePath
    )
    if ($env:USERNAME -ine 'VueOnPlayer') {
        throw 'Desktop branding must run as the signed-in VueOnPlayer account.'
    }
    if (-not (Test-Path -LiteralPath $SourceImagePath -PathType Leaf)) {
        throw ('VueOn wallpaper asset is missing: ' + $SourceImagePath)
    }
    $directory = Split-Path -Parent $DestinationImagePath
    New-Item -Path $directory -ItemType Directory -Force -ErrorAction Stop | Out-Null
    Copy-Item -LiteralPath $SourceImagePath -Destination $DestinationImagePath -Force -ErrorAction Stop

    $desktop = 'HKCU:\Control Panel\Desktop'
    Set-ItemProperty -Path $desktop -Name 'WallpaperStyle' -Value '10' -ErrorAction Stop
    Set-ItemProperty -Path $desktop -Name 'TileWallpaper' -Value '0' -ErrorAction Stop

    if (-not ('VueOnDesktopWallpaperApi' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class VueOnDesktopWallpaperApi {
    [DllImport("user32.dll", EntryPoint="SystemParametersInfoW",
        CharSet=CharSet.Unicode, SetLastError=true, ExactSpelling=true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool Apply(uint action, uint parameter,
        [MarshalAs(UnmanagedType.LPWStr)] string filename, uint flags);
}
'@ -ErrorAction Stop
    }
    if (-not [VueOnDesktopWallpaperApi]::Apply(0x14,0,$DestinationImagePath,0x03)) {
        $win32 = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        throw ('Windows refused VueOn wallpaper (Win32 error ' + $win32 + ').')
    }

    # Verify Windows accepted the image instead of quietly reporting success.
    $wallpaperValue = Get-ItemPropertyValue -Path $desktop -Name 'Wallpaper' -ErrorAction Stop
    if ([string]$wallpaperValue -ine $DestinationImagePath) {
        throw ('Windows did not retain the VueOn wallpaper. Actual: ' + $wallpaperValue)
    }
    $advanced = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    if (-not (Test-Path -LiteralPath $advanced)) { New-Item -Path $advanced -Force | Out-Null }
    New-ItemProperty -Path $advanced -Name 'HideIcons' -PropertyType DWord -Value 1 -Force | Out-Null
    return $DestinationImagePath
}

function Test-VueOnDesktopWallpaper {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$DestinationImagePath)
    if (-not (Test-Path -LiteralPath $DestinationImagePath -PathType Leaf)) { return $false }
    $current = Get-ItemPropertyValue -Path 'HKCU:\Control Panel\Desktop' -Name 'Wallpaper' -ErrorAction SilentlyContinue
    return ($null -ne $current -and [string]$current -ieq $DestinationImagePath)
}

Export-ModuleMember -Function Set-VueOnDesktopWallpaper, Test-VueOnDesktopWallpaper
