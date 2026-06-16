Add-Type -AssemblyName System.Drawing
$src = Join-Path $PSScriptRoot "mainPlayer.jpeg"
$dst = Join-Path $PSScriptRoot "mainPlayer.png"
$img = [System.Drawing.Image]::FromFile($src)
$img.Save($dst, [System.Drawing.Imaging.ImageFormat]::Png)
$img.Dispose()
Write-Output "Saved $dst"
