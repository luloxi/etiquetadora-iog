# Advance one blank label (TSPL FORMFEED) on 4BARCODE 4B-2054G.
param(
    [string]$Printer = "4BARCODE 4B-2054G"
)

$ErrorActionPreference = "Stop"

$rawHelper = @"
using System;
using System.Runtime.InteropServices;

public class RawPrinterHelperFeed {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
    public class DOCINFOA {
        [MarshalAs(UnmanagedType.LPStr)] public string pDocName;
        [MarshalAs(UnmanagedType.LPStr)] public string pOutputFile;
        [MarshalAs(UnmanagedType.LPStr)] public string pDataType;
    }
    [DllImport("winspool.drv", EntryPoint = "OpenPrinterA", SetLastError = true, CharSet = CharSet.Ansi)]
    public static extern bool OpenPrinter(string szPrinter, out IntPtr hPrinter, IntPtr pd);
    [DllImport("winspool.drv", SetLastError = true)] public static extern bool ClosePrinter(IntPtr hPrinter);
    [DllImport("winspool.drv", EntryPoint = "StartDocPrinterA", SetLastError = true, CharSet = CharSet.Ansi)]
    public static extern bool StartDocPrinter(IntPtr hPrinter, int level, [In, MarshalAs(UnmanagedType.LPStruct)] DOCINFOA di);
    [DllImport("winspool.drv", SetLastError = true)] public static extern bool EndDocPrinter(IntPtr hPrinter);
    [DllImport("winspool.drv", SetLastError = true)] public static extern bool StartPagePrinter(IntPtr hPrinter);
    [DllImport("winspool.drv", SetLastError = true)] public static extern bool EndPagePrinter(IntPtr hPrinter);
    [DllImport("winspool.drv", SetLastError = true)] public static extern bool WritePrinter(IntPtr hPrinter, IntPtr pBytes, int dwCount, out int dwWritten);

    public static void SendBytes(string printerName, byte[] bytes, string docName) {
        IntPtr hPrinter;
        if (!OpenPrinter(printerName, out hPrinter, IntPtr.Zero))
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(), "OpenPrinter");
        try {
            var di = new DOCINFOA();
            di.pDocName = docName;
            di.pDataType = "RAW";
            if (!StartDocPrinter(hPrinter, 1, di))
                throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(), "StartDocPrinter");
            try {
                StartPagePrinter(hPrinter);
                IntPtr p = Marshal.AllocCoTaskMem(bytes.Length);
                try {
                    Marshal.Copy(bytes, 0, p, bytes.Length);
                    int written;
                    if (!WritePrinter(hPrinter, p, bytes.Length, out written))
                        throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(), "WritePrinter");
                } finally { Marshal.FreeCoTaskMem(p); }
                EndPagePrinter(hPrinter);
            } finally { EndDocPrinter(hPrinter); }
        } finally { ClosePrinter(hPrinter); }
    }
}
"@

if (-not ([System.Management.Automation.PSTypeName]"RawPrinterHelperFeed").Type) {
    Add-Type -TypeDefinition $rawHelper -Language CSharp
}

$usb = Get-PnpDevice | Where-Object {
    $_.InstanceId -like '*VID_2D84*' -or $_.FriendlyName -like '*4BARCODE 4B-2054G*'
} | Where-Object { $_.Status -eq 'OK' }
if (-not $usb) {
    throw "The 4BARCODE is not connected. Plug it in and try again."
}

$wmi = Get-WmiObject -Class Win32_Printer -Filter "Name='$Printer'"
if ($wmi -and $wmi.WorkOffline) {
    $wmi.WorkOffline = $false
    $null = $wmi.Put()
}

# FORMFEED advances to the next gap without drawing anything.
# SIZE/GAP keep the same 10x15 cm stock as the name labels.
$tspl = @"
SIZE 100 mm,150 mm
GAP 3 mm,0
SET TEAR ON
SET PEEL OFF
FORMFEED

"@
$tspl = $tspl -replace "`n", "`r`n"
$bytes = [System.Text.Encoding]::ASCII.GetBytes($tspl)
Write-Host "Feeding one blank 10x15 cm label..."
[RawPrinterHelperFeed]::SendBytes($Printer, $bytes, "Feed one label")
Write-Host "Sent FORMFEED."
