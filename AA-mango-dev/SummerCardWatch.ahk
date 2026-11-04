#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn All, Off
#Include D:\Macro\AA mango\AA mango\Lib\OCR-main\Lib\OCR.ahk
#Include CaptureScreen-current.ahk
root := "D:\Macro\AA-mango-dev\Debug"
deadline := A_TickCount + 180000
lastCapture := 0
while (A_TickCount < deadline) {
    try {
        WinGetClientPos(&cx, &cy, &cw, &ch, "ahk_exe RobloxPlayerBeta.exe")
        if (cw != 800 || ch != 599)
            break
        result := OCR.FromRect(cx + 100, cy + 100, 600, 420, "en-US", 2)
        if RegExMatch(result.Text, "i)choose\s+a\s+card|vote\s+ends\s+in") && A_TickCount - lastCapture > 12000 {
            Sleep(500) ; let the three cards finish their entrance animation
            stamp := FormatTime(, "yyyyMMdd_HHmmss")
            CaptureScreen(cx, cy, cw, ch, root "\summer-card-" stamp ".png")
            lastCapture := A_TickCount
            result := OCR.FromRect(cx + 100, cy + 100, 600, 420, "en-US", 2)
            rows := ""
            for line in result.Lines {
                if line.Words.Length
                    rows .= Format("{}`t{}`t{}`n", line.Words[1].x + 100, line.Words[1].y + 100, line.Text)
            }
            FileAppend(rows, root "\summer-card-" stamp ".tsv", "UTF-8")
            lastCapture := A_TickCount
        }
    }
    Sleep(400)
}
ExitApp(0)
