# images-to-pdf.ps1

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1-blue?logo=powershell)](https://github.com/PowerShell/PowerShell)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Windows](https://img.shields.io/badge/OS-Windows%2010%2F11-lightgrey)](#)
[![Release](https://img.shields.io/badge/release-v2.0.0-blue)](https://github.com/asuspades/images-to-pdf/releases)

> Pure .NET PowerShell script to convert image folders to PDF—**no ImageMagick, no external dependencies**.

Convert scanned book pages, documents, or photo collections into optimized PDFs using only built-in Windows components. Ideal for archiving B&W book scans with automatic grayscale conversion, resizing, and JPEG compression.

✨ **v2.0 New Feature**: Cover images (files with `cover` in the filename) are automatically preserved in full color, even when grayscale mode is enabled.

---

## ✨ Features

- 🔒 **Pure .NET**: Uses only `System.Drawing` and built-in Windows printers—no third-party tools
- 🎨 **Smart Processing**: Optional grayscale conversion (ITU-R BT.601), resizing, and quality control
- 🖼️ **Cover Detection**: Files with "cover" in the name stay in color automatically *(v2.0)*
- 📦 **Batch Optimized**: Processes entire folders with progress feedback and error resilience
- 🗜️ **Space Efficient**: Compresses images before PDF generation for smaller output files
- 🛡️ **Safe by Design**: Input validation, path sanitization, and automatic temp cleanup
- 📋 **Help-Ready**: Full comment-based help (`Get-Help ./images-to-pdf.ps1 -Full`)

---

## ⚠️ Requirements

| Component | Version/Notes |
|-----------|--------------|
| **Operating System** | Windows 10/11, Windows Server 2016+ |
| **PowerShell** | 5.1 (Windows PowerShell) |
| **.NET Framework** | 4.7 or later (for `System.Drawing`) |
| **Printer Feature** | "Microsoft Print to PDF" must be enabled |

### 🔍 Verify Your Environment

```powershell
# Check PowerShell version
$PSVersionTable.PSVersion

# Verify Microsoft Print to PDF is installed
Get-Printer -Name "Microsoft Print to PDF" -ErrorAction SilentlyContinue

# If missing, enable via:
# Settings > Apps > Optional Features > Add a feature > Microsoft Print to PDF
# OR PowerShell (Admin):
Add-WindowsCapability -Online -Name "Print.MicrosoftPrintToPDF~~~~0.0.1.0"
```

> ❗ **Not compatible** with PowerShell 7+ on Linux/macOS due to `System.Drawing` dependencies.

---

## 📦 Installation

### Option 1: Direct Download (Recommended)
1. Download [`images-to-pdf.ps1`](images-to-pdf.ps1) to your scripts folder
2. (Optional) Unblock the script if downloaded from the internet:
   ```powershell
   Unblock-File -Path .\images-to-pdf.ps1
   ```
3. Run directly or add to your `PATH`

### Option 2: Clone Repository
```powershell
git clone https://github.com/asuspades/images-to-pdf.git
cd images-to-pdf
```

### Option 3: PowerShell Gallery *(Coming Soon)*
```powershell
# Not yet published - watch this repo for updates
# Install-Script -Name images-to-pdf -Scope CurrentUser
```

---

## 🚀 Usage

### Basic Examples

```powershell
# Convert folder with default settings (grayscale, full-page, quality 70, max 1500px)
.\images-to-pdf.ps1 -InputFolder "C:\Scans\MyBook"

# Positional parameter shorthand
.\images-to-pdf.ps1 "C:\Scans\MyBook"

# Color PDF, preserve original margins
.\images-to-pdf.ps1 "C:\Scans\MyBook" -NoGrayscale -NoFullPage

# High-quality output, no resizing
.\images-to-pdf.ps1 "C:\Scans\MyBook" -Quality 95 -MaxDimension 0 -OutputPdf "C:\Output\book_hq.pdf"

# Dry run: see what would happen without making changes
.\images-to-pdf.ps1 "C:\Scans\MyBook" -WhatIf

# Verbose mode for troubleshooting
.\images-to-pdf.ps1 "C:\Scans\MyBook" -Verbose
```

### Cover Image Handling *(v2.0)*

Images with `cover` in the filename (case-insensitive) are automatically preserved in full color, even when `-NoGrayscale` is **not** specified:

```powershell
# Folder contains: cover.jpg, page001.jpg, page002.jpg
# Result: cover.jpg stays in color; pages converted to grayscale
.\images-to-pdf.ps1 "C:\Scans\MyBook"

# To force grayscale on ALL images (including covers):
.\images-to-pdf.ps1 "C:\Scans\MyBook" -NoGrayscale:$false  # default behavior
# Or explicitly override by renaming: cover.jpg -> page_cover.jpg (still matches)
# To bypass: rename cover file temporarily or use -NoGrayscale to keep everything in color
```

> 💡 **Tip**: Name your cover files `cover.jpg`, `Cover_Page.png`, `BACK-COVER.tif`, etc.—any variation with "cover" will be detected.

### Parameter Reference

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-InputFolder` | `string` | *(required)* | Path to folder containing source images (jpg, jpeg, png, bmp, tiff, tif) |
| `-OutputPdf` | `string` | `<folder>.pdf` | Optional custom output path for the PDF |
| `-Quality` | `int` | `70` | JPEG compression quality (1–100); lower = smaller file |
| `-MaxDimension` | `int` | `1500` | Max width/height in pixels; set `0` to disable resizing |
| `-NoGrayscale` | `switch` | `$false` | Preserve color for all images (overrides cover detection) |
| `-NoFullPage` | `switch` | `$false` | Keep page margins instead of filling the entire page |
| `-Verbose` | `switch` | `$false` | Show detailed processing information |
| `-WhatIf` | `switch` | `$false` | Preview actions without executing (safe mode) |
| `-Confirm` | `switch` | `$false` | Prompt before destructive operations |

---

## 🔒 Security & Privacy

This script is designed with security in mind:

- ✅ **No network activity**: All processing happens locally
- ✅ **Input validation**: Blocks path traversal and injection attempts (`;|&`$()`)
- ✅ **Controlled temp usage**: Creates isolated temp folder in `$env:TEMP`, auto-deleted after use
- ✅ **No source modification**: Original images are never altered
- ✅ **Transparent operations**: All file operations logged via `Write-Verbose`
- ✅ **Resource safety**: All `System.Drawing` objects properly disposed via `finally` blocks

> 🛡️ **Best Practice**: Always review scripts before execution. Run with `-Verbose` first to audit behavior.

---

## ⚠️ Known Limitations

| Limitation | Workaround/Note |
|------------|----------------|
| Uses deprecated `System.Drawing` | May have GDI+ issues with very large images (>10k px) or exotic formats |
| Relies on virtual printer | May trigger UAC or save prompts on some Windows configurations |
| Single-threaded processing | Large batches may take time; no parallelization |
| No OCR/text layer | Output is image-only PDF; use separate OCR tool if needed |
| Windows-only | Not compatible with PowerShell Core on non-Windows platforms |
| Cover detection is filename-based | Rename files if automatic detection doesn't match your needs |

---

## 🛠️ Troubleshooting

### ❌ "Printer 'Microsoft Print to PDF' not found"
```powershell
# Enable via PowerShell (Admin):
Add-WindowsCapability -Online -Name "Print.MicrosoftPrintToPDF~~~~0.0.1.0"

# Or via GUI:
# Settings > Apps > Optional Features > Add a feature > Microsoft Print to PDF
```

### ❌ "Failed to load System.Drawing assembly"
```powershell
# Ensure .NET Framework 4.7+ is installed:
# Download from: https://dotnet.microsoft.com/download/dotnet-framework
# Or enable via Windows Features
```

### ❌ "Out of memory" or GDI+ errors on large images
- Reduce `-MaxDimension` (e.g., `-MaxDimension 1000`)
- Process folders in smaller batches
- Ensure sufficient RAM and page file space

### ❌ PDF created but blank/corrupted
- Verify you have write permissions to the output folder
- Try a different output path (avoid network drives)
- Check Windows Event Viewer for printer subsystem errors

### ❌ Cover image still converted to grayscale
- Verify the filename contains "cover" (case-insensitive): `cover.jpg`, `Cover_Page.png`, `BACK-COVER.tif`
- Check verbose output: `.\images-to-pdf.ps1 "C:\Scans\Book" -Verbose` to see detection logs
- If needed, use `-NoGrayscale` to preserve color for all images

---

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

1. **Fork** the repository
2. **Create a feature branch**: `git checkout -b feat/your-idea`
3. **Test thoroughly** on multiple Windows versions if possible
4. **Follow PowerShell best practices**:
   - Use `Invoke-ScriptAnalyzer` for linting
   - Maintain comment-based help
   - Add tests for new logic (if applicable)
5. **Submit a Pull Request** with a clear description

### Development Tips
```powershell
# Install PSScriptAnalyzer for code quality checks
Install-Module PSScriptAnalyzer -Scope CurrentUser -Force

# Run analysis
Invoke-ScriptAnalyzer -Path .\images-to-pdf.ps1 -Recurse

# Test with verbose output
.\images-to-pdf.ps1 "C:\Test\Images" -Verbose

# Test cover detection
.\images-to-pdf.ps1 "C:\Test\BookWithCover" -Verbose | Select-String "Cover detected"
```

---

## 📄 License

Distributed under the **MIT License**. See [`LICENSE`](LICENSE) for details.

```
MIT License

Copyright (c) 2026 asuspades

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 📬 Support & Feedback

- 🐛 **Bug Reports**: [Open an Issue](https://github.com/asuspades/images-to-pdf/issues)
- 💡 **Feature Requests**: Use the [Discussions](https://github.com/asuspades/images-to-pdf/discussions) tab
- 🙋 **Questions**: Check the [FAQ](#-faq) or start a discussion

---

## ❓ FAQ

**Q: Can I use this with PowerShell 7?**  
A: Only on Windows. `System.Drawing` has limited support in PowerShell 7 on Windows, and none on Linux/macOS. For cross-platform needs, consider tools like `img2pdf` (Python) or `ImageMagick`.

**Q: Does this add a text layer or OCR?**  
A: No—this script creates image-only PDFs. For searchable PDFs, run the output through an OCR tool like Adobe Acrobat, ABBYY FineReader, or the free `ocrmypdf` (requires Python).

**Q: Why grayscale by default?**  
A: Grayscale significantly reduces file size for B&W book scans (often 30–50% smaller) with minimal quality loss. Use `-NoGrayscale` to preserve color for all images.

**Q: How does cover detection work?**  
A: Any image file whose name contains "cover" (case-insensitive) is automatically excluded from grayscale conversion. Examples: `cover.jpg`, `Cover_Page.png`, `BACK-COVER.tif`. Rename files to control this behavior.

**Q: Can I process subfolders recursively?**  
A: Not currently. This script processes only the top-level files in `-InputFolder`. For recursive processing, wrap the call in a loop or request the feature via GitHub Issues.

**Q: Is the output PDF searchable or selectable?**  
A: No—images are embedded as raster graphics. Text selection/search requires OCR post-processing.

---

## 🗓️ Changelog

### [2.0.0] - 2026-04-02
- ✨ **New**: Automatic cover image detection—files with "cover" in filename stay in color
- ✨ **New**: Verbose logging for cover detection and image processing steps
- 🔧 **Improved**: Summary output now reports number of covers preserved in color
- 🔧 **Improved**: All disposable objects wrapped in `finally` blocks for guaranteed cleanup
- 🔧 **Improved**: Parameter validation with clearer error messages
- 📚 **Docs**: Updated README with cover detection examples and troubleshooting

### [1.0.0] - 2026-04-01
- Initial public release
- Pure .NET image processing with System.Drawing
- Grayscale conversion, resizing, quality control
- PDF generation via Microsoft Print to PDF

---

> 💡 **Pro Tip**: Combine with [`ocrmypdf`](https://ocrmypdf.readthedocs.io/) for searchable PDFs:
> ```powershell
> # 1. Generate optimized PDF (covers stay in color automatically)
> .\images-to-pdf.ps1 "C:\Scans\Book" -OutputPdf "C:\Output\book_images.pdf"
> 
> # 2. Add OCR text layer (requires Python + ocrmypdf)
> ocrmypdf --deskew --clean "C:\Output\book_images.pdf" "C:\Output\book_searchable.pdf"
> ```

---

*Made with ❤️ for digital archivists, students, and anyone who loves tidy PDFs.*  
*Report issues or suggest improvements on [GitHub](https://github.com/asuspades/images-to-pdf).*
