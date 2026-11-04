#Requires AutoHotkey v2.0
#SingleInstance Force
; ================================================================
;  Snapshot.ahk - capture the Roblox client area
;
;  Agent / headless:
;    AutoHotkey64.exe Snapshot.ahk --auto
;      -> Debug\auto_<ts>_raw.png  (pixels, 1:1 with client coords)
;      -> Debug\auto_<ts>_grid.png (same + 100px grid + labels)
;      -> Debug\auto_<ts>.json     (window / client / screen / dpi)
;      -> Debug\latest.json        (stable path for the agent)
;
;  Interactive: run without args, F9 = capture, F10 = quit.
; ================================================================

#Include "C:\Users\thoan\Downloads\AA-mango-dev\Harness\lib\Common.ahk"
#Include "C:\Users\thoan\Downloads\AA mango\AA mango\Lib\AHKv2-Gdip-master\Gdip_All.ahk"

EnsureDirs()

if (A_Args.Length >= 1 && A_Args[1] = "--auto") {
    p := TakeSnapshot("auto")
    if (p = "") {
        FileAppend("ERROR: Roblox window not found (ahk_exe RobloxPlayerBeta.exe)`n", "*")
        ExitApp(1)
    }
    try FileCopy(p, DEBUG_DIR . "\latest.json", true)
    FileAppend(p . "`n", "*")
    ExitApp(0)
}

Capture() {
    p := TakeSnapshot("shot")
    if (p = "") {
        ToolTip("Roblox window not found")
        SetTimer(() => ToolTip(), -1500)
        return
    }
    try FileCopy(p, DEBUG_DIR . "\latest.json", true)
    SplitPath(p, &fname)
    ToolTip("Saved: " . fname)
    SetTimer(() => ToolTip(), -1500)
    FileAppend(p . "`n", "*")
}

Hotkey("F9", Capture)
Hotkey("F10", (*) => ExitApp())

TrayTip("Snapshot ready - F9 capture, F10 quit")
