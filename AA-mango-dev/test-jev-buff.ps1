$ErrorActionPreference = 'Stop'
$project = 'D:\Macro\AA mango\AA mango'
$source = Get-Content -LiteralPath "$project\Lib\GameMango.ahk" -Raw
$section = $source.Substring($source.IndexOf('global CARD_ENABLED :='))
Set-Content -LiteralPath 'D:\Macro\AA-mango-dev\jev-card-functions-test.ahk' -Value $section -Encoding utf8
$ahk = 'C:\Users\thoan\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe'
$p = Start-Process -FilePath $ahk -ArgumentList '/ErrorStdOut /Validate "D:\Macro\AA mango\AA mango\Main.ahk"' -NoNewWindow -Wait -PassThru
if ($p.ExitCode -ne 0) { throw "Main validation failed: $($p.ExitCode)" }
$p = Start-Process -FilePath $ahk -ArgumentList '/ErrorStdOut "D:\Macro\AA-mango-dev\test-jev-buff.ahk"' -NoNewWindow -Wait -PassThru
if ($p.ExitCode -ne 0) { throw "Card test failed: $($p.ExitCode)" }
