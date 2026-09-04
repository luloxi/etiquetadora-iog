# Print a centered-name label on 4BARCODE 4B-2054G (TSPL, 203 dpi).
# Label: 10 cm wide x 15 cm tall.
# Usage:
#   powershell.exe -ExecutionPolicy Bypass -File print-label.ps1
#   powershell.exe -ExecutionPolicy Bypass -File print-label.ps1 -Name "Luciano Oliva"
#   powershell.exe -ExecutionPolicy Bypass -File print-label.ps1 -Name "Ana Perez" -Copies 2

param(
    [string]$Name = "Luciano Oliva",
    [string]$Printer = "4BARCODE 4B-2054G",
    [int]$Copies = 1,
    [int]$Dpi = 203,
    [double]$WidthCm = 10,
    [double]$HeightCm = 15,
    [double]$GapMm = 3,
    [double]$FontSize = 28,
    [int]$Rotate = 90
)

$ErrorActionPreference = "Stop"

$rawHelper = @"
using System;
using System.Runtime.InteropServices;

public class RawPrinterHelper {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
    public class DOCINFOA {
        [MarshalAs(UnmanagedType.LPStr)] public string pDocName;
        [MarshalAs(UnmanagedType.LPStr)] public string pOutputFile;
        [MarshalAs(UnmanagedType.LPStr)] public string pDataType;
    }

    [DllImport("winspool.drv", EntryPoint = "OpenPrinterA", SetLastError = true, CharSet = CharSet.Ansi)]
    public static extern bool OpenPrinter([MarshalAs(UnmanagedType.LPStr)] string szPrinter, out IntPtr hPrinter, IntPtr pd);

    [DllImport("winspool.drv", EntryPoint = "ClosePrinter", SetLastError = true)]
    public static extern bool ClosePrinter(IntPtr hPrinter);

    [DllImport("winspool.drv", EntryPoint = "StartDocPrinterA", SetLastError = true, CharSet = CharSet.Ansi)]
    public static extern bool StartDocPrinter(IntPtr hPrinter, Int32 level, [In, MarshalAs(UnmanagedType.LPStruct)] DOCINFOA di);

    [DllImport("winspool.drv", EntryPoint = "EndDocPrinter", SetLastError = true)]
    public static extern bool EndDocPrinter(IntPtr hPrinter);

    [DllImport("winspool.drv", EntryPoint = "StartPagePrinter", SetLastError = true)]
    public static extern bool StartPagePrinter(IntPtr hPrinter);

    [DllImport("winspool.drv", EntryPoint = "EndPagePrinter", SetLastError = true)]
    public static extern bool EndPagePrinter(IntPtr hPrinter);

    [DllImport("winspool.drv", EntryPoint = "WritePrinter", SetLastError = true)]
    public static extern bool WritePrinter(IntPtr hPrinter, IntPtr pBytes, Int32 dwCount, out Int32 dwWritten);

    public static void SendBytes(string printerName, byte[] bytes, string docName) {
        IntPtr hPrinter;
        if (!OpenPrinter(printerName.Normalize(), out hPrinter, IntPtr.Zero)) {
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(), "OpenPrinter failed: " + printerName);
        }
        try {
            DOCINFOA di = new DOCINFOA();
            di.pDocName = docName;
            di.pDataType = "RAW";
            if (!StartDocPrinter(hPrinter, 1, di)) {
                throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(), "StartDocPrinter failed");
            }
            try {
                StartPagePrinter(hPrinter);
                IntPtr p = Marshal.AllocCoTaskMem(bytes.Length);
                try {
                    Marshal.Copy(bytes, 0, p, bytes.Length);
                    int written;
                    if (!WritePrinter(hPrinter, p, bytes.Length, out written)) {
                        throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(), "WritePrinter failed");
                    }
                } finally {
                    Marshal.FreeCoTaskMem(p);
                }
                EndPagePrinter(hPrinter);
            } finally {
                EndDocPrinter(hPrinter);
            }
        } finally {
            ClosePrinter(hPrinter);
        }
    }
}
"@

if (-not ([System.Management.Automation.PSTypeName]"RawPrinterHelper").Type) {
    Add-Type -TypeDefinition $rawHelper -Language CSharp
}

Add-Type -AssemblyName System.Drawing

$dotsPerMm = $Dpi / 25.4
$widthDots = [Math]::Max(8, [int][Math]::Round($WidthCm * 10 * $dotsPerMm))
$heightDots = [Math]::Max(8, [int][Math]::Round($HeightCm * 10 * $dotsPerMm))
# BITMAP width is in bytes; pad to a multiple of 8 pixels.
$widthDots = [int]([Math]::Ceiling($widthDots / 8.0) * 8)
$widthBytes = [int]($widthDots / 8)

$usb = Get-PnpDevice | Where-Object {
    $_.InstanceId -like '*VID_2D84*' -or $_.FriendlyName -like '*4BARCODE 4B-2054G*'
} | Select-Object -First 5
$connected = $usb | Where-Object { $_.Status -eq 'OK' -or $_.Present }
if (-not $connected) {
    $problems = ($usb | ForEach-Object { $_.ProblemDescription } | Where-Object { $_ } | Select-Object -First 1)
    if (-not $problems) { $problems = "Code 45: the USB printer is not plugged in." }
    throw "The 4BARCODE 4B-2054G is not connected. Plug it in (USB) and turn it on. Windows says: $problems"
}

# If Windows marked the USB printer offline, jobs sit in the queue forever.
$wmi = Get-WmiObject -Class Win32_Printer -Filter "Name='$Printer'"
if ($wmi -and $wmi.WorkOffline) {
    Write-Host "Printer was offline; bringing it online..."
    $wmi.WorkOffline = $false
    $null = $wmi.Put()
}

Write-Host "Printer : $Printer"
Write-Host "Name    : $Name"
Write-Host "Size    : ${WidthCm}cm x ${HeightCm}cm  ($widthDots x $heightDots dots @ ${Dpi} dpi)"
Write-Host "Copies  : $Copies"
Write-Host "Rotate  : $Rotate deg"

$bmp = New-Object System.Drawing.Bitmap $widthDots, $heightDots, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$bmp.SetResolution($Dpi, $Dpi)
$g = [System.Drawing.Graphics]::FromImage($bmp)
try {
    $g.Clear([System.Drawing.Color]::White)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

    $margin = [int]($dotsPerMm * 5) # 5 mm inset
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
    $sf.Trimming = [System.Drawing.StringTrimming]::None
    $sf.FormatFlags = [System.Drawing.StringFormatFlags]::LineLimit

    # Name tags wrap on spaces only: "Luciano Oliva" -> two centered lines.
    $parts = @($Name.Trim() -split '\s+' | Where-Object { $_ })
    if ($parts.Count -ge 2) {
        $layoutText = ($parts[0..($parts.Count - 2)] -join ' ') + "`n" + $parts[-1]
    } else {
        $layoutText = $Name.Trim()
    }

    # Rotate around the label center so the words read 90° from the previous layout.
    $g.TranslateTransform(($widthDots / 2.0), ($heightDots / 2.0))
    $g.RotateTransform([float]$Rotate)
    $rotW = if (($Rotate % 180) -eq 0) { $widthDots } else { $heightDots }
    $rotH = if (($Rotate % 180) -eq 0) { $heightDots } else { $widthDots }
    $rect = [System.Drawing.RectangleF]::new(
        [float](-$rotW / 2.0 + $margin),
        [float](-$rotH / 2.0 + $margin),
        [float]($rotW - 2 * $margin),
        [float]($rotH - 2 * $margin)
    )

    $size = [double]$FontSize
    $font = $null
    $minSize = 10.0
    while ($size -ge $minSize) {
        if ($font) { $font.Dispose() }
        $font = New-Object System.Drawing.Font "Arial", $size, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Point)
        $chars = 0
        $lines = 0
        $measured = $g.MeasureString($layoutText, $font, [System.Drawing.SizeF]::new($rect.Width, $rect.Height), $sf, [ref]$chars, [ref]$lines)
        $fits = ($measured.Width -le $rect.Width) -and ($measured.Height -le $rect.Height) -and ($chars -ge $layoutText.Length)
        if ($fits) { break }
        $size -= 1
    }

    Write-Host ("Font    : Arial Bold {0:N0} pt" -f $size)
    Write-Host ("Layout  : " + ($layoutText -replace "`n", " / "))
    $g.DrawString($layoutText, $font, [System.Drawing.Brushes]::Black, $rect, $sf)
    $font.Dispose()
    $sf.Dispose()
} finally {
    $g.Dispose()
}

$rectFull = New-Object System.Drawing.Rectangle 0, 0, $widthDots, $heightDots
$locked = $bmp.LockBits($rectFull, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$bitmapData = New-Object byte[] ($widthBytes * $heightDots)
try {
    $stride = $locked.Stride
    $src = New-Object byte[] ($stride * $heightDots)
    [System.Runtime.InteropServices.Marshal]::Copy($locked.Scan0, $src, 0, $src.Length)
    for ($y = 0; $y -lt $heightDots; $y++) {
        $row = $y * $stride
        for ($x = 0; $x -lt $widthDots; $x++) {
            $i = $row + ($x * 4)
            $b = $src[$i]; $gch = $src[$i + 1]; $r = $src[$i + 2]
            $luma = (0.299 * $r) + (0.587 * $gch) + (0.114 * $b)
            # This clone treats 1 as unprinted (white) and 0 as burned (black).
            # Set bits on the paper/background so letters stay 0 = black.
            if ($luma -ge 160) {
                $byteIndex = ($y * $widthBytes) + [int][Math]::Floor($x / 8)
                $bit = 7 - ($x % 8)
                $bitmapData[$byteIndex] = $bitmapData[$byteIndex] -bor [byte](1 -shl $bit)
            }
        }
    }
} finally {
    $bmp.UnlockBits($locked)
    $bmp.Dispose()
}

function Get-AsciiBytes([string]$text) {
    return [System.Text.Encoding]::ASCII.GetBytes($text)
}

$ms = New-Object System.IO.MemoryStream
$crlf = "`r`n"
$header = @(
    "SIZE $($WidthCm * 10) mm,$($HeightCm * 10) mm",
    "GAP $GapMm mm,0",
    "DENSITY 8",
    "SPEED 4",
    "DIRECTION 1",
    "REFERENCE 0,0",
    "SET TEAR ON",
    "CLS",
    "BITMAP 0,0,$widthBytes,$heightDots,0,"
) -join $crlf
$tail = $crlf + "PRINT $Copies,1" + $crlf

$hBytes = Get-AsciiBytes $header
$tBytes = Get-AsciiBytes $tail
$ms.Write($hBytes, 0, $hBytes.Length)
$ms.Write($bitmapData, 0, $bitmapData.Length)
$ms.Write($tBytes, 0, $tBytes.Length)
$payload = $ms.ToArray()
$ms.Dispose()

$preview = Join-Path $env:TEMP "label-preview.png"
$previewBmp = New-Object System.Drawing.Bitmap $widthDots, $heightDots, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$previewBmp.SetResolution($Dpi, $Dpi)
$plock = $previewBmp.LockBits((New-Object System.Drawing.Rectangle 0, 0, $widthDots, $heightDots), [System.Drawing.Imaging.ImageLockMode]::WriteOnly, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
try {
    $stride = $plock.Stride
    $dst = New-Object byte[] ($stride * $heightDots)
    for ($y = 0; $y -lt $heightDots; $y++) {
        $row = $y * $stride
        for ($x = 0; $x -lt $widthDots; $x++) {
            $byteIndex = ($y * $widthBytes) + [int][Math]::Floor($x / 8)
            $bit = 7 - ($x % 8)
            $on = ($bitmapData[$byteIndex] -band [byte](1 -shl $bit)) -ne 0
            # Preview as the label looks: bit 0 = black, bit 1 = white.
            $val = if ($on) { [byte]255 } else { [byte]0 }
            $i = $row + ($x * 3)
            $dst[$i] = $val; $dst[$i + 1] = $val; $dst[$i + 2] = $val
        }
    }
    [System.Runtime.InteropServices.Marshal]::Copy($dst, 0, $plock.Scan0, $dst.Length)
} finally {
    $previewBmp.UnlockBits($plock)
}
$previewBmp.Save($preview, [System.Drawing.Imaging.ImageFormat]::Png)
$previewBmp.Dispose()
Write-Host "Preview : $preview"
Write-Host "Sending RAW TSPL ($($payload.Length) bytes)..."

[RawPrinterHelper]::SendBytes($Printer, $payload, "Label - $Name")
Write-Host "Sent to printer."
