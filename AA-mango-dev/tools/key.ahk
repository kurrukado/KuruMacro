#Requires AutoHotkey v2.0
; Send a key to the Roblox window.
; Usage: AutoHotkey64.exe key.ahk <key>   e.g. key.ahk "{Tab}"

if (A_Args.Length < 1)
    ExitApp(1)

hwnd := WinExist("ahk_exe RobloxPlayerBeta.exe")
if !hwnd {
    FileAppend("ERR no roblox window`n", "*")
    ExitApp(2)
}

WinActivate(hwnd)
Sleep(300)
FileAppend("sending " A_Args[1] " active=" (WinActive(hwnd) ? 1 : 0) "`n", "*")
SendInput(A_Args[1])
Sleep(100)
ExitApp(0)
