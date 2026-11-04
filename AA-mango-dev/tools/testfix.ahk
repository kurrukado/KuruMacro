#Requires AutoHotkey v2.0
; End-to-end replay of the fixed StartStory() path with the verified
; red-disc check for the promo toast close buttons.

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
Sleep(800)

old := A_CoordModeMouse
CoordMode("Pixel", "Client")
CoordMode("Mouse", "Client")

dismissed := 0
Loop 4 {
    yStart := 55
    clicked := false
    Loop 12 {
        if !PixelSearch(&px, &py, 758, yStart, 778, 320, 0xE00000, 40)
            break
        c := PixelGetColor(px + 8, py + 8, "RGB")
        r := (c >> 16) & 0xFF
        g := (c >> 8) & 0xFF
        b := c & 0xFF
        if (r > 180 && g < 60 && b < 60) {
            MouseMove(px + 8, py + 8)
            Sleep(120)
            MouseClick("Left")
            Sleep(450)
            clicked := true
            break
        }
        yStart := py + 2
    }
    if !clicked
        break
    dismissed++
}
FileAppend("toasts dismissed: " dismissed "`n", "*")

MouseMove(690, 248)
Sleep(200)
MouseClick("Left")
Sleep(1000)

CoordMode("Mouse", old)
FileAppend("clicked first world card`n", "*")
ExitApp(0)
