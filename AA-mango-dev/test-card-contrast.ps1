$ErrorActionPreference = 'Stop'
$source = Get-Content -LiteralPath 'D:\Macro\AA mango\AA mango\Lib\GameMango.ahk' -Raw
$helper = [regex]::Match($source, '(?ms)^ReadHighContrastText\([^\r\n]*\) \{.*?^\}')
if (!$helper.Success) { throw 'Missing contrast OCR helper' }
Set-Content -LiteralPath 'D:\Macro\AA-mango-dev\card-contrast-helper-test.ahk' -Value $helper.Value -Encoding utf8
$p = Start-Process -FilePath 'C:\Users\thoan\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe' -ArgumentList '/ErrorStdOut "D:\Macro\AA-mango-dev\test-card-contrast.ahk"' -NoNewWindow -Wait -PassThru
if ($p.ExitCode -ne 0) { throw "Contrast OCR test failed: $($p.ExitCode)" }
