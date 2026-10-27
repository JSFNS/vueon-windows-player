# Generates a VueOn placeholder wallpaper if a PNG is not bundled.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function New-VueOnBrandImage {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    Add-Type -AssemblyName System.Drawing
    $image = [System.Drawing.Bitmap]::new(1920,1080)
    $canvas = [System.Drawing.Graphics]::FromImage($image)
    $canvas.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $canvas.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $bounds = [System.Drawing.Rectangle]::new(0,0,1920,1080)
    $brush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
        $bounds, [System.Drawing.Color]::FromArgb(9,17,34),
        [System.Drawing.Color]::FromArgb(12,35,57), 45.0)
    $white = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(245,250,255))
    $cyan = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(68,210,232))
    $subtle = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(157,178,196))
    $large = [System.Drawing.Font]::new('Segoe UI',96,[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel)
    $small = [System.Drawing.Font]::new('Segoe UI',30,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
    try {
        $canvas.FillRectangle($brush,$bounds)
        $vue = 'Vue'
        $on = 'On'
        $vueSize = $canvas.MeasureString($vue,$large)
        $onSize = $canvas.MeasureString($on,$large)
        $left = [single]((1920-$vueSize.Width-$onSize.Width)/2)
        $canvas.DrawString($vue,$large,$white,$left,425)
        $canvas.DrawString($on,$large,$cyan,($left+$vueSize.Width-8),425)
        $caption = 'Starting your display...'
        $capSize = $canvas.MeasureString($caption,$small)
        $canvas.DrawString($caption,$small,$subtle,([single]((1920-$capSize.Width)/2)),575)
        $image.Save($Path,[System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        foreach ($item in @($large,$small,$white,$cyan,$subtle,$brush,$canvas,$image)) { $item.Dispose() }
    }
}
Export-ModuleMember -Function New-VueOnBrandImage
