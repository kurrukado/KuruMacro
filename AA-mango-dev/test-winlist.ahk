#Requires AutoHotkey v2.0
DetectHiddenWindows(true)
SetTitleMatchMode(2)
list := WinGetList()
out := "Count=" . list.Length . "`n"
for hwnd in list {
    try {
        title := WinGetTitle(hwnd)
        pname := WinGetProcessName(hwnd)
        if (InStr(title, "Roblox") || InStr(pname, "Roblox")) {
            out .= "MATCH: hwnd=" . hwnd . " title='" . title . "' pname='" . pname . "'`n"
        }
    }
}
FileAppend(out, "D:\Macro\AA-mango-dev\test-winlist.txt", "UTF-8")
ExitApp(0)
