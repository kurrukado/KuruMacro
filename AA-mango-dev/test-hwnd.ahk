#Requires AutoHotkey v2.0
out := ""
h1 := WinExist("ahk_exe RobloxPlayerBeta.exe")
h2 := WinExist("Roblox")
pname := h2 ? WinGetProcessName(h2) : "none"
out .= "h_exe=" . h1 . " h_roblox=" . h2 . " pname=" . pname . "`n"
FileAppend(out, "D:\Macro\AA-mango-dev\test-hwnd-out.txt", "UTF-8")
ExitApp(0)
