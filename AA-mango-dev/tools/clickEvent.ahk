#Requires AutoHotkey v2.0
; Click using the legacy mouse_event path instead of SendInput.
; Usage: AutoHotkey64.exe clickEvent.ahk <clientX> <clientY>

if (A_Args.Length < 2)
    ExitApp(1)

cx := Integer(A_Args[1])
cy := Integer(A_Args[2])

hwnd := WinExist("ahk_exe RobloxPlayerBeta.exe")
if !hwnd
    ExitApp(2)

WinActivate(hwnd)
Sleep(250)

WinGetClientPos(&ox, &oy, &cw, &ch, hwnd)
sx := ox + cx
sy := oy + cy

SendMode("Event")
CoordMode("Mouse", "Screen")
MouseMove(sx, sy)
Sleep(150)
MouseClick("Left", sx, sy, 1, 0)
Sleep(120)
FileAppend("event-click client=(" cx "," cy ") screen=(" sx "," sy ")`n", "*")
ExitApp(0)
