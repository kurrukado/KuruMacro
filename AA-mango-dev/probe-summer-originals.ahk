#Requires AutoHotkey v2.0
#SingleInstance Off
#Warn All, Off
#Include D:\Macro\AA mango\AA mango\Lib\OCR-main\Lib\OCR.ahk
#Include D:\Macro\AA mango\AA mango\Lib\AHKv2-Gdip-master\Gdip_All.ahk
#Include card-contrast-helper-test.ahk
token := Gdip_Startup()
Loop Files A_ScriptDir "\SumnmerCards\*.png" {
    FileAppend(A_LoopFileName "`n", "*")
    for x in [150,327,504] {
        try FileAppend(RegExReplace(ReadFileROI(A_LoopFileFullPath,x,242,152,195), "\s+", " ") "`n", "*")
        catch as e
            FileAppend(e.Message "`n", "*")
    }
}
Gdip_Shutdown(token)
ExitApp
ReadFileROI(path, x := 0, y := 0, w := 0, h := 0) {
    image := 0, bitmap := 0, dc := 0, previous := 0
    try {
        image := Gdip_CreateBitmapFromFile(path)
        Gdip_GetImageDimensions(image, &iw, &ih)
        bitmap := Gdip_CreateHBITMAPFromBitmap(image)
        dc := DllCall("gdi32\CreateCompatibleDC", "Ptr", 0, "Ptr")
        previous := DllCall("gdi32\SelectObject", "Ptr", dc, "Ptr", bitmap, "Ptr")
        return ReadHighContrastText(x, y, w ? w : iw, h ? h : ih, 3, dc)
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


