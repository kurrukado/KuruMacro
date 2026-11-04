#Requires AutoHotkey v2.0
; Replays the walk part of StoryMovement()/FarmMovement():
;   W 300ms, then D+W 4500ms, then release.
; Run after clicking Play so the character is in the portal hub.

hwnd := WinExist("ahk_exe RobloxPlayerBeta.exe")
if !hwnd
    ExitApp(2)

WinActivate(hwnd)
Sleep(400)

SendInput("{w down}")
Sleep(300)
SendInput("{w up}")
Sleep(300)

SendInput("{d down}")
SendInput("{w down}")
Sleep(4500)
SendInput("{d up}")
SendInput("{w up}")
Sleep(600)

FileAppend("walk done`n", "*")
ExitApp(0)
