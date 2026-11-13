# VueOn Windows Player generated branding artwork for the desktop and sign-in.
# No external image service or credentials required.
#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-VueOnBrandImage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [ValidateSet('Wallpaper','LockScreen','Account')][string]$Kind = 'Wallpaper'
    )
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop

    $account = ($Kind -eq 'Account')
    $w = if ($account) { 448 } else { 1920 }
    $h = if ($account) { 448 } else { 1080 }
    $image = [System.Drawing.Bitmap]::new($w,$h)
    $canvas = [System.Drawing.Graphics]::FromImage($image)
    $bounds = [System.Drawing.Rectangle]::new(0,0,$w,$h)
    $gradient = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
        $bounds,[System.Drawing.Color]::FromArgb(7,18,35),
        [System.Drawing.Color]::FromArgb(10,49,76),35.0
    )
    $white = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(246,250,255))
    $cyan = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(0,174,240))
    $subtle = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(177,200,222))
    $headline = [System.Drawing.Font]::new('Segoe UI', $(if($account){178}else{112}), [System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel)
    $small = [System.Drawing.Font]::new('Segoe UI', $(if($account){25}else{34}), [System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
    $line = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(0,174,240),$(if($account){3}else{5}))
    try {
        $canvas.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $canvas.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
        $canvas.FillRectangle($gradient,$bounds)

        if ($account) {
            $letter = 'V'
            $size = $canvas.MeasureString($letter,$headline)
            $canvas.DrawString($letter,$headline,$white,[single](($w-$size.Width)/2),82)
            $label = 'VueOn'
            $labelSize = $canvas.MeasureString($label,$small)
            $canvas.DrawString($label,$small,$cyan,[single](($w-$labelSize.Width)/2),327)
            $canvas.DrawLine($line,120,318,328,318)
        } else {
            $left = 0.0
            $vue = 'Vue'
            $on = 'On'
            $vueSize = $canvas.MeasureString($vue,$headline)
            $onSize = $canvas.MeasureString($on,$headline)
            $left = [single](($w-$vueSize.Width-$onSize.Width)/2)
            $canvas.DrawString($vue,$headline,$white,$left,398)
            $canvas.DrawString($on,$headline,$cyan,($left+$vueSize.Width-8),398)
            $caption = if ($Kind -eq 'LockScreen') { 'Turn any screen on' } else { 'Starting your display...' }
            $capSize = $canvas.MeasureString($caption,$small)
            $canvas.DrawString($caption,$small,$subtle,[single](($w-$capSize.Width)/2),568)
            $canvas.DrawLine($line,825,660,1095,660)
        }

        $parent = Split-Path -Parent $Path
        if ($parent -and -not (Test-Path -LiteralPath $parent)) {
            $null = New-Item -Path $parent -ItemType Directory -Force
        }
        $image.Save($Path,[System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        foreach($item in @($line,$headline,$small,$white,$cyan,$subtle,$gradient,$canvas,$image)) {
            if($null -ne $item) { $item.Dispose() }
        }
    }
}

function Set-VueOnSupportedLockScreen {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ImagePath)
    if (-not (Test-Path -LiteralPath $ImagePath -PathType Leaf)) {
        throw ('VueOn sign-in image not found: ' + $ImagePath)
    }
    $editionKey = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $edition = [string]$editionKey.EditionID

    if ($edition -notmatch '^(Enterprise|Education|IoTEnterprise)') {
        # Windows 11 Home/Pro do not support forcing an offline lock image with
        # local GPO. A managed Pro PC may support it using Intune/Personalization CSP.
        return ('Image staged only for Windows ' + $edition +
            '. To use it, choose Settings > Personalization > Lock screen > Picture. ' +
            'Device-wide managed lock images on Pro require the supported CSP/MDM method.')
    }
    $key = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization'
    if (-not (Test-Path -LiteralPath $key)) {
        New-Item -Path $key -Force | Out-Null
    }
    $existing = Get-ItemProperty -LiteralPath $key -ErrorAction Stop
    $old = $existing.PSObject.Properties['LockScreenImage']
    if ($null -ne $old -and [string]$old.Value -and
        [string]$old.Value -ine $ImagePath) {
        return 'An existing managed lock-screen policy was found. VueOn did not overwrite it.'
    }
    New-ItemProperty -Path $key -Name 'LockScreenImage' -PropertyType String -Value $ImagePath -Force | Out-Null
    return 'VueOn lock-screen policy configured for supported Enterprise/Education edition; check after restart.'
}

Export-ModuleMember -Function New-VueOnBrandImage, Set-VueOnSupportedLockScreen
