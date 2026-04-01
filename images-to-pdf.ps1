<#
.SYNOPSIS
    Converts images in a folder to a single PDF using pure .NET.

.DESCRIPTION
    Processes JPG/PNG/BMP/TIFF images, optionally resizes, converts to grayscale,
    and compiles them into a PDF using Microsoft Print to PDF.

    This script uses System.Drawing for image processing and the virtual
    "Microsoft Print to PDF" printer for PDF generation. No external dependencies.

.PARAMETER InputFolder
    Path to folder containing source images. Must exist and be accessible.

.PARAMETER OutputPdf
    Optional output PDF path. Defaults to <foldername>.pdf in InputFolder.

.PARAMETER Quality
    JPEG compression quality (1-100). Lower = smaller file, lower quality. Default: 70.

.PARAMETER MaxDimension
    Maximum width/height in pixels. Images larger are scaled down proportionally.
    Set to 0 to disable resizing. Default: 1500.

.PARAMETER NoGrayscale
    Switch to preserve color. Default behavior converts to grayscale for smaller files.

.PARAMETER NoFullPage
    Switch to keep original page margins instead of filling the entire page.

.EXAMPLE
    .\images-to-pdf.ps1 -InputFolder "C:\Scans\Book1"
    Creates Book1.pdf with default settings (grayscale, full-page, quality 70).

.EXAMPLE
    .\images-to-pdf.ps1 "C:\Scans\Book1" -NoGrayscale -Quality 90
    Creates a color PDF with higher quality compression.

.EXAMPLE
    .\images-to-pdf.ps1 "C:\Scans\Book1" -MaxDimension 0 -OutputPdf "C:\Output\result.pdf"
    No resizing, custom output path.

.NOTES
    Author: asuspades
    Version: 1.0.0
    Created: 2026-04-01
    Requires:
      - Windows 10/11 or Windows Server 2016+
      - PowerShell 5.1+ (Windows PowerShell)
      - "Microsoft Print to PDF" feature enabled
      - .NET Framework 4.7+ (System.Drawing)
    
    ⚠️  Not compatible with PowerShell 7+ on non-Windows platforms.
    ⚠️  System.Drawing has known limitations with very large images or certain formats.

.LINK
    https://github.com/asuspades/images-to-pdf/
#>

# SPDX-License-Identifier: MIT
# Repository: https://github.com/asuspades/images-to-pdf/

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateScript({
        if (-not (Test-Path $_ -PathType Container)) {
            throw "InputFolder does not exist: $_"
        }
        # Prevent path traversal/injection attempts
        if ($_ -match '[;|&`$()]') {
            throw "InputFolder contains invalid characters"
        }
        $true
    })]
    [string]$InputFolder,

    [Parameter(Position = 1)]
    [ValidateScript({
        if ($PSItem -and $PSItem -match '[;|&`$()]') {
            throw "OutputPdf contains invalid characters"
        }
        $true
    })]
    [string]$OutputPdf,

    [ValidateRange(1, 100)]
    [int]$Quality = 70,

    [ValidateScript({ $_ -ge 0 })]
    [int]$MaxDimension = 1500,

    [switch]$NoGrayscale,
    [switch]$NoFullPage
)

begin {
    # Platform check
    if ($env:OS -ne 'Windows_NT') {
        Write-Error "This script requires Windows operating system."
        exit 1
    }

    # Dependency check: Microsoft Print to PDF
    $pdfPrinter = Get-Printer -Name "Microsoft Print to PDF" -ErrorAction SilentlyContinue
    if (-not $pdfPrinter) {
        Write-Error "Printer 'Microsoft Print to PDF' not found. Please enable it via: Settings > Apps > Optional Features > Add a feature."
        exit 1
    }

    # Load required assembly
    try {
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to load System.Drawing assembly. Ensure .NET Framework 4.7+ is installed."
        exit 1
    }

    # Initialize state
    $doGrayscale = -not $NoGrayscale
    $doFullPage  = -not $NoFullPage
    $tempDir = $null
    $cleanupPerformed = $false
}

process {
    try {
        # Resolve and validate input path
        $InputFolder = (Resolve-Path $InputFolder -ErrorAction Stop).Path
        Write-Verbose "Input folder: $InputFolder"

        # Determine output path
        if (-not $OutputPdf) {
            $folderName = Split-Path $InputFolder -Leaf
            $OutputPdf = Join-Path $InputFolder "$folderName.pdf"
        }
        Write-Verbose "Output PDF: $OutputPdf"

        # Remove existing output (with ShouldProcess support)
        if (Test-Path $OutputPdf) {
            if ($PSCmdlet.ShouldProcess("Remove existing PDF: $OutputPdf", "Delete file")) {
                Remove-Item $OutputPdf -Force -ErrorAction Stop
            }
        }

        # Gather and validate images
        $images = Get-ChildItem -Path $InputFolder -File -ErrorAction Stop |
            Where-Object { $_.Extension -match '\.(jpg|jpeg|png|bmp|tiff?)$' } |
            Sort-Object Name

        if ($images.Count -eq 0) {
            Write-Error "No supported images found in: $InputFolder (supported: jpg, jpeg, png, bmp, tiff, tif)"
            exit 1
        }

        $totalCount = $images.Count
        $originalSize = ($images | Measure-Object -Property Length -Sum).Sum

        Write-Host "Found $totalCount images ($([math]::Round($originalSize / 1MB, 1)) MB total)"
        Write-Host "Settings: quality=$Quality, max=$($MaxDimension -eq 0 ? 'unlimited' : "${MaxDimension}px"), grayscale=$doGrayscale, fullpage=$doFullPage"
        Write-Verbose "Images: $($images.Name -join ', ')"
        Write-Host ""

        # -- Stage 1: Recompress images to temp folder --------------------------
        Write-Verbose "Stage 1: Recompressing images..."

        $tempDir = Join-Path $env:TEMP "img2pdf_$(Get-Random)"
        New-Item -ItemType Directory -Path $tempDir -Force -ErrorAction Stop | Out-Null
        Write-Verbose "Temp directory: $tempDir"

        # JPEG encoder setup
        $jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
            Where-Object { $_.MimeType -eq 'image/jpeg' }
        if (-not $jpegCodec) {
            throw "JPEG encoder not found. System.Drawing may be misconfigured."
        }

        $encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
        $encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
            [System.Drawing.Imaging.Encoder]::Quality, [long]$Quality
        )

        $compressedSize = 0
        $resizedCount = 0
        $errorCount = 0

        for ($i = 0; $i -lt $images.Count; $i++) {
            $file = $images[$i]
            $pct = [math]::Round((($i + 1) / $totalCount) * 100)
            Write-Host -NoNewline "`r  [$pct%] ($($i+1)/$totalCount) $($file.Name)"

            try {
                # Use FileStream to avoid GDI+ file locking issues
                $fs = $null
                $img = $null
                $bmp = $null
                $g = $null
                $attrs = $null

                $fs = [System.IO.File]::OpenRead($file.FullName)
                $img = [System.Drawing.Image]::FromStream($fs, $false, $false)

                $w = $img.Width; $h = $img.Height

                # Determine target size
                $needsResize = ($MaxDimension -gt 0) -and ($w -gt $MaxDimension -or $h -gt $MaxDimension)
                if ($needsResize) {
                    $ratio = [Math]::Min($MaxDimension / $w, $MaxDimension / $h)
                    $newW = [int]($w * $ratio); $newH = [int]($h * $ratio)
                    $resizedCount++
                    Write-Verbose "  Resizing $($file.Name): ${w}x${h} -> ${newW}x${newH}"
                } else {
                    $newW = $w; $newH = $h
                }

                # Create output bitmap (24bpp RGB for JPEG compatibility)
                $bmp = New-Object System.Drawing.Bitmap($newW, $newH, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
                $g = [System.Drawing.Graphics]::FromImage($bmp)
                $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality

                if ($doGrayscale) {
                    # Grayscale conversion using ITU-R BT.601 luminance weights
                    $cm = New-Object System.Drawing.Imaging.ColorMatrix
                    $cm.Matrix00 = 0.299; $cm.Matrix01 = 0.299; $cm.Matrix02 = 0.299; $cm.Matrix03 = 0; $cm.Matrix04 = 0
                    $cm.Matrix10 = 0.587; $cm.Matrix11 = 0.587; $cm.Matrix12 = 0.587; $cm.Matrix13 = 0; $cm.Matrix14 = 0
                    $cm.Matrix20 = 0.114; $cm.Matrix21 = 0.114; $cm.Matrix22 = 0.114; $cm.Matrix23 = 0; $cm.Matrix24 = 0
                    $cm.Matrix30 = 0;     $cm.Matrix31 = 0;     $cm.Matrix32 = 0;     $cm.Matrix33 = 1; $cm.Matrix34 = 0
                    $cm.Matrix40 = 0;     $cm.Matrix41 = 0;     $cm.Matrix42 = 0;     $cm.Matrix43 = 0; $cm.Matrix44 = 1

                    $attrs = New-Object System.Drawing.Imaging.ImageAttributes
                    $attrs.SetColorMatrix($cm)
                    $destRect = New-Object System.Drawing.Rectangle(0, 0, $newW, $newH)
                    $g.DrawImage($img, $destRect, 0, 0, $w, $h, [System.Drawing.GraphicsUnit]::Pixel, $attrs)
                } else {
                    $g.DrawImage($img, 0, 0, $newW, $newH)
                }

                # Save recompressed image
                $outPath = Join-Path $tempDir $file.Name
                $bmp.Save($outPath, $jpegCodec, $encoderParams)
                $compressedSize += (Get-Item $outPath -ErrorAction Stop).Length

            }
            catch {
                $errorCount++
                Write-Host ""
                Write-Warning "ERROR processing $($file.Name): $($_.Exception.Message)"
                Write-Verbose $_.ScriptStackTrace

                # Fallback: copy original file
                Write-Verbose "  Falling back to original file"
                Copy-Item $file.FullName (Join-Path $tempDir $file.Name) -Force -ErrorAction SilentlyContinue
                $compressedSize += $file.Length
            }
            finally {
                # Ensure all disposable objects are cleaned up
                if ($attrs) { try { $attrs.Dispose() } catch {} }
                if ($g)     { try { $g.Dispose() } catch {} }
                if ($img)   { try { $img.Dispose() } catch {} }
                if ($fs)    { try { $fs.Dispose() } catch {} }
                if ($bmp)   { try { $bmp.Dispose() } catch {} }
            }
        }

        Write-Host ""
        Write-Host "Recompressed: $([math]::Round($originalSize / 1MB, 1)) MB -> $([math]::Round($compressedSize / 1MB, 1)) MB ($resizedCount resized, $errorCount errors)"
        Write-Verbose "Temp images: $((Get-ChildItem $tempDir).Count) files"

        # -- Stage 2: Build PDF via Print-to-PDF --------------------------------
        Write-Host "Building PDF..."
        Write-Verbose "Using printer: Microsoft Print to PDF"

        $tempImages = Get-ChildItem $tempDir -File | Sort-Object Name
        if ($tempImages.Count -eq 0) {
            throw "No images in temp folder -- nothing to build."
        }

        $doc = New-Object System.Drawing.Printing.PrintDocument
        $doc.PrinterSettings.PrinterName = "Microsoft Print to PDF"
        $doc.PrinterSettings.PrintToFile = $true
        $doc.PrinterSettings.PrintFileName = $OutputPdf

        if ($doFullPage) {
            $doc.DefaultPageSettings.Margins = New-Object System.Drawing.Printing.Margins(0, 0, 0, 0)
        }

        $script:idx = 0

        $doc.add_PrintPage({
            param($sender, $e)

            $imgFile = $tempImages[$script:idx]
            $stream = $null
            $img = $null

            try {
                $stream = [System.IO.File]::OpenRead($imgFile.FullName)
                $img = [System.Drawing.Image]::FromStream($stream, $false, $false)

                $bounds = if ($doFullPage) { $e.PageBounds } else { $e.MarginBounds }

                $ratio = [Math]::Min($bounds.Width / $img.Width, $bounds.Height / $img.Height)
                $w = [int]($img.Width * $ratio); $h = [int]($img.Height * $ratio)
                $x = $bounds.X + (($bounds.Width - $w) / 2)
                $y = $bounds.Y + (($bounds.Height - $h) / 2)
                
                $e.Graphics.DrawImage($img, $x, $y, $w, $h)
            }
            finally {
                if ($img)   { try { $img.Dispose() } catch {} }
                if ($stream){ try { $stream.Dispose() } catch {} }
            }

            $script:idx++
            $e.HasMorePages = $script:idx -lt $tempImages.Count
        })

        # Execute print job
        $doc.Print()

    }
    catch {
        Write-Error "Unhandled error: $($_.Exception.Message)"
        Write-Verbose $_.ScriptStackTrace
        throw
    }
}

end {
    # Cleanup temp directory
    if ($tempDir -and (Test-Path $tempDir)) {
        Write-Verbose "Cleaning up temp directory: $tempDir"
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Final status
    if (Test-Path $OutputPdf) {
        $finalSize = [math]::Round((Get-Item $OutputPdf).Length / 1MB, 1)
        $reduction = if ($originalSize -gt 0) {
            [math]::Round((1 - (Get-Item $OutputPdf).Length / $originalSize) * 100)
        } else { 0 }
        
        Write-Host ""
        Write-Host "✓ Done -> $OutputPdf" -ForegroundColor Green
        Write-Host "  Final: $finalSize MB ($reduction% smaller than source images)"
    }
    else {
        Write-Error "PDF was not created. Verify that 'Microsoft Print to PDF' is enabled and you have write permissions to the output location."
        exit 1
    }
}
