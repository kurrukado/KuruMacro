$ErrorActionPreference = 'Stop'
$project = 'D:\Macro\AA mango\AA mango'
$source = Get-Content -LiteralPath "$project\Lib\GameMango.ahk" -Raw
$names = @('ParseUnitUpgradeLevel', 'ApplyUnitUpgradeLimit')
$parts = foreach ($name in $names) {
    $m = [regex]::Match($source, '(?ms)^' + $name + '\([^\r\n]*\) \{.*?^\}')
    if (!$m.Success) { throw "FAIL: missing $name" }
    $m.Value
}
$parts -join "`n`n" | Set-Content -LiteralPath 'D:\Macro\AA-mango-dev\upgrade-limit-functions-test.ahk' -Encoding utf8
$p = Start-Process -FilePath 'C:\Users\thoan\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe' -ArgumentList '/ErrorStdOut "D:\Macro\AA-mango-dev\test-upgrade-limit.ahk"' -NoNewWindow -Wait -PassThru
if ($p.ExitCode -ne 0) { throw "FAIL exit=$($p.ExitCode)" }
