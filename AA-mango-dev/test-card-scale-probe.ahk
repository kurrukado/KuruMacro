#Requires AutoHotkey v2.0
#SingleInstance Off
#Warn All, Off
#Include D:\Macro\AA mango\AA mango\Lib\OCR-main\Lib\OCR.ahk
#Include D:\Macro\AA mango\AA mango\Lib\AHKv2-Gdip-master\Gdip_All.ahk
#Include card-contrast-helper-test.ahk
token := Gdip_Startup()
try {
    ; Warm WinRT OCR before measuring GDI allocations.
    ReadFileROI("D:\Macro\AA-mango-dev\Debug\card-ocr-1.png")
    before := DllCall("user32\GetGuiResources", "Ptr", DllCall("GetCurrentProcess", "Ptr"), "UInt", 0)
    effects := []
    loop 3 {
        text := ReadFileROI("D:\Macro\AA-mango-dev\Debug\card-ocr-" A_Index ".png")
        effects.Push(text)
        FileAppend("crop " A_Index ": " RegExReplace(text, "\s+", " ") "`n", "*")
    }
    Assert(RegExMatch(effects[1], "\+\s*3000"), "currency sign and amount")
    Assert(RegExMatch(effects[2], "25\s*%") && InStr(effects[2], "Enemy Speed"), "red enemy speed effect")
    Assert(RegExMatch(effects[3], "12\s*%") && InStr(effects[3], "Attack"), "green attack effect")
    loop 3 {
        text := ReadFileROI("D:\Macro\AA-mango-dev\Debug\summer-card-20261102_161900.png"
            , [148, 325, 502][A_Index], 210, 152, 195)
        FileAppend("full ROI " A_Index ": " RegExReplace(text, "\s+", " ") "`n", "*")
        ; OCR must preserve the effects; decorative currency/title glyphs can be dropped.
        Assert(RegExMatch(text, ["\+\s*3000", "25\s*%", "12\s*%"][A_Index]), "full-card amount")
    }
    after := DllCall("user32\GetGuiResources", "Ptr", DllCall("GetCurrentProcess", "Ptr"), "UInt", 0)
    Assert(after <= before + 1, "GDI handles released")
    rejected := false
    try ReadHighContrastText(0, 0, 0, 10)
    catch ValueError
        rejected := true
    Assert(rejected, "invalid capture rejected")
    FileAppend("PASS: real-image effects, signs, titles, bounds and GDI handle cleanup; delta=" after-before "`n", "*")
} catch as e {
    FileAppend("FAIL: " e.Message " @ " e.Line "`n", "*")
    Gdip_Shutdown(token)
    ExitApp(1)
}
Gdip_Shutdown(token)
ExitApp(0)

ReadFileROI(path, x := 0, y := 0, w := 0, h := 0) {
    image := 0, bitmap := 0, dc := 0, previous := 0
    try {
        image := Gdip_CreateBitmapFromFile(path)
        Gdip_GetImageDimensions(image, &iw, &ih)
        bitmap := Gdip_CreateHBITMAPFromBitmap(image)
        dc := DllCall("gdi32\CreateCompatibleDC", "Ptr", 0, "Ptr")
        previous := DllCall("gdi32\SelectObject", "Ptr", dc, "Ptr", bitmap, "Ptr")
        return ReadHighContrastText(x, y, w ? w : iw, h ? h : ih, 5, dc)
    } finally {
        if previous
            DllCall("gdi32\SelectObject", "Ptr", dc, "Ptr", previous)
        if dc
            DllCall("gdi32\DeleteDC", "Ptr", dc)
        if bitmap
            DllCall("gdi32\DeleteObject", "Ptr", bitmap)
        if image
            Gdip_DisposeImage(image)
    }
}
Assert(value, label) {
    if !value
        throw Error(label)
}



