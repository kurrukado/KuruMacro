#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn VarUnset, Off
#Warn All, Off
#NoTrayIcon
SendMode "Event"
#Include %A_ScriptDir%\lib/Image.ahk
#Include %A_ScriptDir%\lib/GUI.ahk
#Include %A_ScriptDir%\lib/GameMango.ahk
#Include %A_ScriptDir%\lib/Functions.ahk
#Include %A_ScriptDir%\lib/webhooksettings.ahk
#Include %A_ScriptDir%\Lib\FindText.ahk
#include %A_ScriptDir%\Lib\OCR-main\Lib\OCR.ahk

global UnitPlacements := Map()
loop 6 {
    UnitPlacements[A_Index] := []
}

LoadUnitCoordsFromFile()


global __devTimerCb := ""

; ================================================================
;  Dev harness hook - single-state test runner.
;  Normal use is unchanged: launching this file with no arguments
;  behaves exactly as before.
;
;    AutoHotkey64.exe Main.ahk --run <FunctionName> [out.json] [timeoutMs]
;
;  Runs exactly one macro function, writes a JSON result, then exits.
;  This is what makes debugging take seconds instead of a full run.
; ================================================================
if (A_Args.Length >= 2 && A_Args[1] = "--run") {
    RunSingleState(A_Args[2]
        , A_Args.Length >= 3 ? A_Args[3] : ""
        , A_Args.Length >= 4 ? Integer(A_Args[4]) : 60000)
}

RunSingleState(fnName, outPath, timeoutMs := 60000) {
    global aaMainUI, __devTimerCb

    started := A_TickCount

    ; keep the macro window out of the way
    try aaMainUI.Hide()

    ; watchdog: a hanging state must not eat minutes of wall clock
    __devTimerCb := DevTimeout.Bind(outPath, fnName, timeoutMs)
    SetTimer(__devTimerCb, -timeoutMs)

    ok := false
    errMsg := ""
    try {
        %fnName%()
        ok := true
    } catch as e {
        errMsg := e.Message . " @ line " . e.Line . " in " . e.File
    }

    SetTimer(__devTimerCb, 0)

    WriteStateResult(outPath, fnName, ok, errMsg, A_TickCount - started, false)
    ExitApp(ok ? 0 : 1)
}

DevTimeout(outPath, fnName, timeoutMs) {
    WriteStateResult(outPath, fnName, false, "timeout after " . timeoutMs . " ms", timeoutMs, true)
    ExitApp(3)
}

WriteStateResult(outPath, fnName, ok, errMsg, ms, timedOut) {
    if (outPath = "")
        return

    try {
        SplitPath(outPath, &fname, &dir)
        if (dir != "" && !DirExist(dir))
            DirCreate(dir)

        e := StrReplace(errMsg, "\", "\\")
        e := StrReplace(e, '"', '\"')
        e := StrReplace(e, "`r", "")
        e := StrReplace(e, "`n", "\n")

        clientW := 0
        clientH := 0
        try {
            if WinExist("ahk_exe RobloxPlayerBeta.exe") {
                ddx := 0, ddy := 0
                WinGetClientPos(&ddx, &ddy, &clientW, &clientH, "ahk_exe RobloxPlayerBeta.exe")
            }
        }

        json := "{`n"
        json .= '  "state": "' . fnName . '",`n'
        json .= '  "ok": ' . (ok ? "true" : "false") . ",`n"
        json .= '  "timed_out": ' . (timedOut ? "true" : "false") . ",`n"
        json .= '  "ms": ' . ms . ",`n"
        json .= '  "client": {"w": ' . clientW . ', "h": ' . clientH . "},`n"
        json .= '  "error": "' . e . '"' . "`n"
        json .= "}`n"
        FileAppend(json, outPath, "UTF-8")
    }
}