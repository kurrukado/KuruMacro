#Requires AutoHotkey v2.0
; Try SendPlay, which uses a different injection path than SendInput and
; is the documented workaround for games that filter synthetic input.
; Usage: AutoHotkey64.exe sendplay.ahk <clientX> <clientY>

if (A_Args.Length < 2)
    ExitApp(1)

cx := Integer(A_Args[1])
cy := Integer(A_Args[2])

hwnd := WinExist("ahk_exe RobloxPlayerBeta.exe")
if !hwnd
    ExitApp(2)

WinActivate(hwnd)
Sleep(400)

WinGetClientPos(&ox, &oy, , , hwnd)
sx := ox + cx
sy := oy + cy

try {
    SendMode("Play")
    CoordMode("Mouse", "Screen")
    MouseMove(sx, sy)
    Sleep(200)
    MouseClick("Left", sx, sy, 1, 0)
    Sleep(200)
    FileAppend("sendplay ok screen=(" sx "," sy ")`n", "*")
} catch as e {
    FileAppend("sendplay failed: " e.Message "`n", "*")
}
ExitApp(0)
