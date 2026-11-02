$ErrorActionPreference = 'Stop'

# Render the repository's path-only SVG sources using Windows' vector renderer.
# Run this script, then `dart run flutter_launcher_icons` for Android launchers.
Add-Type -AssemblyName PresentationCore, WindowsBase
$brandRoot = Split-Path -Parent $PSScriptRoot

function Export-BrandIcon {
    param(
        [string]$Source,
        [string]$Destination,
        [int]$Width,
        [int]$Height,
        [bool]$WhiteBackground = $false
    )

    [xml]$svg = Get-Content -LiteralPath (Join-Path $brandRoot $Source) -Raw
    $viewBox = @($svg.DocumentElement.GetAttribute('viewBox').Split(' ') | ForEach-Object {
        [double]::Parse($_, [Globalization.CultureInfo]::InvariantCulture)
    })
    $scale = [Math]::Min($Width / $viewBox[2], $Height / $viewBox[3])
    $offsetX = ($Width - $viewBox[2] * $scale) / 2 - $viewBox[0] * $scale
    $offsetY = ($Height - $viewBox[3] * $scale) / 2 - $viewBox[1] * $scale
    $fills = @{}
    foreach ($match in [regex]::Matches($svg.DocumentElement.InnerText, '\.([\w-]+)\s*\{\s*fill:\s*([^;]+);')) {
        $fills[$match.Groups[1].Value] = $match.Groups[2].Value.Trim()
    }
    if ($fills.Count -lt 2) { throw "No brand colors found in $Source" }

    $visual = New-Object System.Windows.Media.DrawingVisual
    $drawing = $visual.RenderOpen()
    if ($WhiteBackground) {
        $drawing.DrawRectangle([System.Windows.Media.Brushes]::White, $null,
            (New-Object System.Windows.Rect(0, 0, $Width, $Height)))
    }
    $matrix = New-Object System.Windows.Media.Matrix($scale, 0, 0, $scale, $offsetX, $offsetY)
    $drawing.PushTransform((New-Object System.Windows.Media.MatrixTransform($matrix)))
    foreach ($node in $svg.SelectNodes("//*[local-name()='path']")) {
        $fill = $fills[$node.GetAttribute('class')]
        if (-not $fill -or $fill -eq 'none') { continue }
        $brush = [System.Windows.Media.BrushConverter]::new().ConvertFromInvariantString($fill)
        $geometry = [System.Windows.Media.Geometry]::Parse($node.GetAttribute('d'))
        $drawing.DrawGeometry($brush, $null, $geometry)
    }
    $drawing.Pop()
    $drawing.Close()

    $bitmap = New-Object System.Windows.Media.Imaging.RenderTargetBitmap(
        $Width, $Height, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
    $bitmap.Render($visual)
    $encoder = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
    $encoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $stream = [IO.File]::Create((Join-Path $brandRoot $Destination))
    try { $encoder.Save($stream) } finally { $stream.Dispose() }
}

Export-BrandIcon 'assets/icons/app_icon.svg' 'assets/icons/app_icon.png' 1024 1024 $true
Export-BrandIcon 'assets/icons/dompet-sheva-lightmode.svg' 'assets/icons/dompet-sheva-lightmode.png' 831 647
Export-BrandIcon 'assets/icons/dompet-sheva-darkmode.svg' 'assets/icons/dompet-sheva-darkmode.png' 831 647
Export-BrandIcon 'assets/icons/app_icon.svg' 'web/favicon.png' 32 32 $true
foreach ($size in @(192, 512)) {
    Export-BrandIcon 'assets/icons/app_icon.svg' "web/icons/Icon-$size.png" $size $size $true
    Export-BrandIcon 'assets/icons/app_icon.svg' "web/icons/Icon-maskable-$size.png" $size $size $true
}
Write-Output 'Rendered blue brand icons from SVG sources.'
