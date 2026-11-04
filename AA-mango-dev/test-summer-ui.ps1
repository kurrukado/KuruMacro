$ErrorActionPreference = 'Stop'
$root = 'D:\Macro\AA mango\AA mango'
$source = Get-Content -LiteralPath "$root\Lib\GameMango.ahk" -Raw
$match = [regex]::Match($source, '(?ms)^IsSummerEventText\(text\) \{.*?^\}')
if (!$match.Success) { throw 'FAIL: Summer Event UI recognition is missing' }
$test = @'
#Requires AutoHotkey v2.0
cases := [
    ["Summer Event`nForecast`nWeather: Rainy", true],
    ["SUMMER   EVENT`nPuppet Island (Summer)", true],
    ["Summer Event`nSpecial Rewards!", false],
    ["Select World`nPlanet Greenie", false],
    ["Summer Event`nWeather: Sunny", true],
    ["", false]
]
for item in cases {
    if (IsSummerEventText(item[1]) != item[2]) {
        FileAppend("FAIL case " A_Index "`n", "*")
        ExitApp(1)
    }
}
FileAppend("PASS 6/6 Summer UI cases`n", "*")
ExitApp(0)
'@
$out = Join-Path $env:TEMP 'aa-test-summer-ui.ahk'
Set-Content -LiteralPath $out -Value ($test + "`n" + $match.Value) -Encoding utf8
$proc = Start-Process -FilePath 'C:\Users\thoan\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe' -ArgumentList ('/ErrorStdOut "' + $out + '"') -Wait -PassThru -NoNewWindow
if ($proc.ExitCode -ne 0) { throw "FAIL exit=$($proc.ExitCode)" }
