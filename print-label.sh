#!/usr/bin/env bash
# Print a 10cm x 15cm centered-name label on the Windows 4BARCODE 4B-2054G.
# Usage: ./print-label.sh "Luciano Oliva"
#        ./print-label.sh "Ana Perez" 2
set -euo pipefail
NAME="${1:-Luciano Oliva}"
COPIES="${2:-1}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WINFILE="$(wslpath -w "$SCRIPT_DIR/print-label.ps1")"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$WINFILE" -Name "$NAME" -Copies "$COPIES"
