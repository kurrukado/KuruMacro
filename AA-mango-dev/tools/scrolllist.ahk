#Requires AutoHotkey v2.0
; Replay the scroll part of StartStory(): wheel up 20x over the map list.

hwnd := WinExist("ahk_exe RobloxPlayerBeta.exe")
if !hwnd
    ExitApp(2)

WinActivate(hwnd)
Sleep(300)

oldMouseMode := A_CoordModeMouse
CoordMode("Mouse", "Client")
MouseMove(700, 430)
Loop 20 {
    SendInput("{WheelUp}")
    Sleep(100)
}
CoordMode("Mouse", oldMouseMode)
Sleep(400)

FileAppend("scroll done`n", "*")
ExitApp(0)
