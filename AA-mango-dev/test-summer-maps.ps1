$ErrorActionPreference = 'Stop'
$src = Get-Content 'D:\Macro\AA mango\AA mango\Lib\GameMango.ahk' -Raw
$m = [regex]::Match($src, '(?ms)^ParseSummerMapName\([^\r\n]*\) \{.*?^\}')
if (!$m.Success) { throw 'FAIL: Summer map name fallback missing' }
$tests = @'
#Requires AutoHotkey v2.0
cases := [
 ["Travelling to... CURSED FESTIVAL (Summer)", "Cursed Festival"],
 ["Loading Magic Hills - Summer Hunt", "Magic Hill"],
 ["Shibuya District", "Shibuya District"],
 ["Hellish City", "Hellish City"],
 ["Planet Greenie", "Planet Greenie"],
 ["Snowy Town", "Snowy Town"],
 ["Cursed Festival | Shibuya District", ""],
 ["Summer Event Forecast Cursed Festival", ""],
 ["Puppet Island", ""],
 ["", ""]
]
for item in cases {
 if (ParseSummerMapName(item[1]) != item[2]) {
  FileAppend("FAIL summer map case " A_Index "`n", "*")
  ExitApp(1)
 }
}
FileAppend("PASS 10 Summer map aliases/ambiguity/hub/unsupported cases`n", "*")
ExitApp(0)
'@
$out = Join-Path $env:TEMP 'aa-summer-map-tests.ahk'
Set-Content -LiteralPath $out -Value ($tests + "`n" + $m.Value) -Encoding utf8
$p = Start-Process 'C:\Users\thoan\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe' -ArgumentList ('/ErrorStdOut "' + $out + '"') -NoNewWindow -Wait -PassThru
if ($p.ExitCode -ne 0) { throw "Summer test exit=$($p.ExitCode)" }
