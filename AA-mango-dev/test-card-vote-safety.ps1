$ErrorActionPreference = 'Stop'
$src = Get-Content 'D:\Macro\AA mango\AA mango\Lib\GameMango.ahk' -Raw
$parts = foreach ($name in @('HandleCardScreen','WaitForCardChoice')) {
    $m = [regex]::Match($src, '(?ms)^' + $name + '\([^\r\n]*\) \{.*?^\}')
    if (!$m.Success) { throw "Missing $name" }
    $m.Value
}
Set-Content -LiteralPath 'D:\Macro\AA-mango-dev\card-vote-functions-test.ahk' -Value ($parts -join "`n`n") -Encoding utf8
$p = Start-Process 'C:\Users\thoan\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe' -ArgumentList '/ErrorStdOut "D:\Macro\AA-mango-dev\test-card-vote-safety.ahk"' -NoNewWindow -Wait -PassThru
if ($p.ExitCode -ne 0) { throw "Card vote test exit=$($p.ExitCode)" }
