#Requires AutoHotkey v2.0
; Click via WM_LBUTTONDOWN/UP posted straight to the Roblox window.
; Synthetic input injection is filtered by Roblox; window messages are not.
; Usage: AutoHotkey64.exe controlclick.ahk <clientX> <clientY>

if (A_Args.Length < 2)
    ExitApp(1)

cx := Integer(A_Args[1])
cy := Integer(A_Args[2])

hwnd := WinExist("ahk_exe RobloxPlayerBeta.exe")
if !hwnd
    ExitApp(2)

WinActivate(hwnd)
Sleep(300)

ControlClick("x" cx " y" cy, hwnd, , "Left", 1, "NA")
Sleep(300)
FileAppend("controlclick x" cx " y" cy "`n", "*")
ExitApp(0)
