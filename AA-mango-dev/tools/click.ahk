#Requires AutoHotkey v2.0
; Click at Roblox client coords using the same sequence as the macro's FixClick:
; move, nudge 1px right, then click back at the original spot. Roblox only
; registers a click after it has processed a fresh mouse-move event, which is
; why a plain absolute MouseClick is silently dropped.
; Usage: AutoHotkey64.exe click.ahk <clientX> <clientY> [holdMs]

if (A_Args.Length < 2)
    ExitApp(1)

cx := Integer(A_Args[1])
cy := Integer(A_Args[2])
holdMs := (A_Args.Length >= 3) ? Integer(A_Args[3]) : 50

hwnd := WinExist("ahk_exe RobloxPlayerBeta.exe")
if !hwnd
    ExitApp(2)

WinActivate(hwnd)
Sleep(250)

WinGetClientPos(&ox, &oy, , , hwnd)
sx := ox + cx
sy := oy + cy

old := A_CoordModeMouse
CoordMode("Mouse", "Screen")
MouseMove(sx, sy)
MouseMove(1, 0, , "R")
MouseClick("Left", -1, 0, , , , "R")
Sleep(holdMs)
CoordMode("Mouse", old)

FileAppend("fixclick client=(" cx "," cy ") screen=(" sx "," sy ")`n", "*")
ExitApp(0)
