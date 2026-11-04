# ================================================================
#  AA mango dev harness - smoke test
#  Chay:  powershell -ExecutionPolicy Bypass -File run-tests.ps1
#
#  LUU Y: buoc 2 se dung macro dang chay (Main.ahk la #SingleInstance Force).
# ================================================================

$ErrorActionPreference = 'Continue'
$ahk = "C:\Users\thoan\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe"
$dev = "C:\Users\thoan\Downloads\AA-mango-dev"

function Line($t) { Write-Host "`n=== $t ===" -ForegroundColor Cyan }

Line "0. Kiem tra moi truong"
if (!(Test-Path $ahk)) { Write-Host "KHONG THAY AutoHotkey64.exe: $ahk" -ForegroundColor Red; exit 1 }
Write-Host "AHK : $ahk"
$rblx = Get-Process RobloxPlayerBeta -ErrorAction SilentlyContinue
if ($rblx) { Write-Host "Roblox: dang chay (PID $($rblx.Id -join ', '))" }
else { Write-Host "Roblox: KHONG chay - buoc 1 se fail" -ForegroundColor Yellow }

Line "1. Snapshot --auto (chi chup, khong dung game)"
& $ahk "$dev\Harness\Snapshot.ahk" --auto
Write-Host "exit=$LASTEXITCODE"
if (Test-Path "$dev\Debug\latest.json") {
    Get-Content "$dev\Debug\latest.json" -Raw
} else {
    Write-Host "KHONG tao duoc latest.json" -ForegroundColor Red
}

Line "2. TestState CheckLobby (state chi doc, khong click)"
& $ahk "$dev\Harness\TestState.ahk" CheckLobby
Write-Host "exit=$LASTEXITCODE"

Line "3. File trong Debug"
if (Test-Path "$dev\Debug") {
    Get-ChildItem "$dev\Debug" -File |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 8 Name, Length, LastWriteTime |
        Format-Table -AutoSize
}

Write-Host "`nXong. Copy toan bo output nay gui lai." -ForegroundColor Green
