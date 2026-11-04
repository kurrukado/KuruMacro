$ErrorActionPreference = 'Stop'
$src = Get-Content 'D:\Macro\AA mango\AA mango\Lib\GameMango.ahk' -Raw
$parts = foreach ($name in @('ChooseResultRoute','ClassifyResultScreen','ResultScreenPhase')) {
    $m = [regex]::Match($src, '(?ms)^' + $name + '\([^\r\n]*\) \{.*?^\}')
    if (!$m.Success) { throw "FAIL missing $name" }
    $m.Value
}
$test = @'
#Requires AutoHotkey v2.0
class MockResult {
    __New(text, y) {
        this.Text := text, this.y := y
    }
    FindString(*) {
        return {x: 260, y: this.y, w: 120, h: 20}
    }
}
cases := [
 ["XP Progress Total Time:14:29 Waves Completed:28 Next", "summary"],
 ["DEFEAT XP Progress Total Time:3:01 Next", "summary"],
 ["Victory XP Progress Waves Completed:20 Next", "summary"],
 ["Return to lobby Replay Waiting for Players:0/1", "choices"],
 ["Return to lobby Waiting for Players", "choices"],
 ["Settings Gameplay Teleport back to Spawn Return to Lobby", ""],
 ["Choose a card XP Progress Total Time Next", ""],
 ["Vote start Wave 2 Enemy health", ""],
 ["Next", ""],
 ["Victory", ""],
 ["Return to lobby", ""]
]
if (ChooseResultRoute(true) != "lobby" || ChooseResultRoute(false) != "replay")
    ExitApp(1)
for item in cases {
    if (ClassifyResultScreen(item[1]) != item[2]) {
        FileAppend("FAIL result case " A_Index "`n", "*")
        ExitApp(1)
    }
}
if (ResultScreenPhase(MockResult("Return to lobby", 100)) != "choices"
    || ResultScreenPhase(MockResult("Settings Gameplay Return to lobby", 410)) != ""
    || ResultScreenPhase(MockResult("Vote start Return to lobby", 100)) != ""
    || ResultScreenPhase(0) != "") {
    FileAppend("FAIL single matchmaking button geometry guards`n", "*")
    ExitApp(1)
}
FileAppend("PASS matchmaking/solo routes + 15 result-state/geometry cases, no title dependency`n", "*")
ExitApp(0)
'@
$out = Join-Path $env:TEMP 'aa-result-routing-tests.ahk'
Set-Content -LiteralPath $out -Value ($test + "`n" + ($parts -join "`n`n")) -Encoding utf8
$p = Start-Process 'C:\Users\thoan\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe' -ArgumentList ('/ErrorStdOut "' + $out + '"') -NoNewWindow -Wait -PassThru
if ($p.ExitCode -ne 0) { throw "Result test exit=$($p.ExitCode)" }
