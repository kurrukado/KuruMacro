$ErrorActionPreference = 'Stop'
$src = Get-Content 'D:\Macro\AA mango\AA mango\Lib\GameMango.ahk' -Raw
$m = [regex]::Match($src, '(?ms)^ContinueAfterResult\([^\r\n]*\) \{.*?^\}')
if (!$m.Success) { throw 'ContinueAfterResult missing' }
Set-Content -LiteralPath 'D:\Macro\AA-mango-dev\result-transition-function-test.ahk' -Value $m.Value -Encoding utf8
$p = Start-Process 'C:\Users\thoan\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe' -ArgumentList '/ErrorStdOut "D:\Macro\AA-mango-dev\test-result-transitions.ahk"' -NoNewWindow -Wait -PassThru
if ($p.ExitCode -ne 0) { throw "Transition test exit=$($p.ExitCode)" }
