#Requires AutoHotkey v2.0
#SingleInstance Force
; ================================================================
;  TestState.ahk - run ONE macro state and print the result
;
;    AutoHotkey64.exe TestState.ahk DetectMap
;    AutoHotkey64.exe TestState.ahk PlacingUnits 60000
;
;  What happens:
;    - starts Main.ahk in --run mode (one function, then exit)
;    - waits for Debug\state_<Name>.json
;    - prints that JSON to stdout
;
;  Exit codes: 0 = result file produced, 1 = usage, 2 = no result
;  (2 usually means the macro failed to load, i.e. a syntax error).
;
;  NOTE: Main.ahk is #SingleInstance Force, so starting a test stops
;  any macro that is currently running. That is intended.
; ================================================================

#Include "C:\Users\thoan\Downloads\AA-mango-dev\Harness\lib\Common.ahk"
#Include "C:\Users\thoan\Downloads\AA mango\AA mango\Lib\AHKv2-Gdip-master\Gdip_All.ahk"

global AHK_EXE := "C:\Users\thoan\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe"
global MAIN    := "C:\Users\thoan\Downloads\AA mango\AA mango\Main.ahk"

if (A_Args.Length < 1) {
    FileAppend("Usage: TestState.ahk <FunctionName> [timeoutMs]`n", "*")
    ExitApp(1)
}

EnsureDirs()

fn     := A_Args[1]
timeout := A_Args.Length >= 2 ? Integer(A_Args[2]) : 30000
out    := DEBUG_DIR . "\state_" . fn . ".json"

if !FileExist(AHK_EXE) {
    FileAppend("ERROR: AutoHotkey64.exe not found at " . AHK_EXE . "`n", "*")
    ExitApp(1)
}

try FileDelete(out)

pid := Run('"' . AHK_EXE . '" "' . MAIN . '" --run ' . fn . ' "' . out . '" ' . timeout)

started := A_TickCount
limit   := timeout + 15000
alive   := true

while (A_TickCount - started < limit) {
    if FileExist(out)
        break
    if (!ProcessExist(pid)) {
        alive := false
        break
    }
    Sleep(150)
}

if FileExist(out) {
    FileAppend(FileRead(out, "UTF-8"), "*")
    ExitApp(0)
}

if (!alive) {
    FileAppend("ERROR: Main.ahk exited before writing a result.`n"
        . "       Most likely a load-time error (syntax) in one of the .ahk files.`n", "*")
} else {
    FileAppend("ERROR: no result after " . limit . " ms; process still running.`n", "*")
}
ExitApp(2)
