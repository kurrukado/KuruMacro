$ErrorActionPreference = 'Stop'
$source = Get-Content -LiteralPath 'D:\Macro\AA mango\AA mango\Lib\GameMango.ahk' -Raw
$functions = foreach ($name in @('ParseSummerMapName','ParseSummerTitleName','AppendSummerMapPattern')) {
    $m = [regex]::Match($source, '(?ms)^' + $name + '\([^\r\n]*\) \{.*?^\}')
    if (!$m.Success) { throw "FAIL missing behavior: $name" }
    $m.Value
}
$test = @'
#Requires AutoHotkey v2.0
#Include D:\Macro\AA mango\AA mango\Lib\FindText.ahk
global SummerMapPatterns := Map()
Assert(value, message) {
    if !value
        throw Error(message)
}
testPath := A_Temp "\aa-summer-append-" DllCall("GetCurrentProcessId") ".ahk"
try {
    Assert(ParseSummerTitleName("Puppet Island (Summer)") = "Puppet Island", "Unknown Summer map title must be retained")
    Assert(ParseSummerTitleName("Magic Hills (Summer)") = "Magic Hill", "Known title must retain canonical route")
    for bad in ["Summer Event Forecast", "Join Matchmaking", "Weather: Sunny", "Vote Start", "(Summer)", "Please enter this text"]
        Assert(ParseSummerTitleName(bad) = "", "Non-title rejected: " bad)
    original := "; existing patterns`r`nGreenie := 'keep me'`r`n"
    FileAppend(original, testPath, "UTF-8-RAW")
    pattern := "|<>*100$8." FindText().bit2base64("00000000" "00111100" "00100100" "00111100" "00000000")
    Assert(AppendSummerMapPattern("Puppet Island", pattern, testPath), "New binary pattern must append")
    saved := FileRead(testPath, "UTF-8")
    Assert(SubStr(saved, 1, StrLen(original)) = original, "Existing patterns must remain byte-for-byte text")
    Assert(InStr(saved, 'SummerMapPatterns["Puppet Island"] :='), "New pattern assignment must name actual map")
    Assert(!AppendSummerMapPattern("Puppet Island", pattern, testPath), "Duplicate must not overwrite")
    Assert(FileRead(testPath, "UTF-8") = saved, "Duplicate must leave file unchanged")
    for bad in ["bad`ncode", 'bad"name', "", "Weather: Sunny"] {
        try {
            AppendSummerMapPattern(bad, pattern, testPath)
            throw Error("Unsafe name accepted")
        } catch ValueError {
        }
    }
    try {
        AppendSummerMapPattern("Snowy Town", "not a binary pattern", testPath)
        throw Error("Invalid pattern accepted")
    } catch ValueError {
    }
    Assert(FileRead(testPath, "UTF-8") = saved, "Invalid input must not write")
    FileAppend("PASS Summer title recognition, append-only pattern persistence, duplicate and unsafe-input guards`n", "*")
} catch as err {
    FileAppend("FAIL " err.Message " @ " err.Line "`n", "*")
    ExitApp(1)
} finally {
    if FileExist(testPath)
        FileDelete(testPath)
}
ExitApp(0)
'@
$out = 'D:\Macro\AA-mango-dev\summer-title-capture-fixture.ahk'
Set-Content -LiteralPath $out -Value ($test + "`n" + ($functions -join "`n`n")) -Encoding utf8
$p = Start-Process 'C:\Users\thoan\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe' -ArgumentList ('/ErrorStdOut "' + $out + '"') -Wait -PassThru -NoNewWindow
if ($p.ExitCode -ne 0) { throw "Summer capture test exit=$($p.ExitCode)" }
