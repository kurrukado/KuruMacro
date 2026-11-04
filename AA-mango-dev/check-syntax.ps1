# ================================================================
#  check-syntax.ps1 - kiem tra syntax cac file .ahk
#
#  Dung /Validate cua AHK v2: load script roi thoat, KHONG chay.
#  Exit code 0 = load duoc. Khac 0 = loi syntax (in ra stderr).
#
#  Main.ahk #Include toan bo Lib\ nen validate Main.ahk la du cho
#  phan loi chinh. Cac script le o thu muc goc duoc check rieng.
#
#  Chay:  powershell -ExecutionPolicy Bypass -File check-syntax.ps1
# ================================================================

$ahk  = "C:\Users\thoan\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe"
$root = "C:\Users\thoan\Downloads\AA mango\AA mango"

if (!(Test-Path $ahk)) { Write-Host "KHONG THAY: $ahk" -ForegroundColor Red; exit 1 }

# Main.ahk truoc (bao trum Lib\), roi cac script le o goc
$targets = @("$root\Main.ahk") + @(
    Get-ChildItem $root -Filter *.ahk -File |
        Where-Object { $_.Name -ne "Main.ahk" } |
        Select-Object -ExpandProperty FullName
)

$bad = 0
foreach ($t in $targets) {
    $name = Split-Path $t -Leaf
    $err  = & $ahk /ErrorStdOut /Validate $t 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host ("  OK    " + $name) -ForegroundColor Green
    } else {
        $bad++
        Write-Host ("  FAIL  " + $name) -ForegroundColor Red
        $err | ForEach-Object { Write-Host ("        " + $_) -ForegroundColor Yellow }
    }
}

Write-Host ""
if ($bad -eq 0) {
    Write-Host ("Tat ca " + $targets.Count + " file load duoc.") -ForegroundColor Green
} else {
    Write-Host ($bad.ToString() + " / " + $targets.Count + " file LOI.") -ForegroundColor Red
}
exit $bad
