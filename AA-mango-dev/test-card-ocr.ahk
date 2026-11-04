#Requires AutoHotkey v2.0
#Warn All, Off
#Include D:\Macro\AA mango\AA mango\Lib\OCR-main\Lib\OCR.ahk
for cardIndex in [1, 2, 3] {
    for suffix in ["", "-contrast"] {
        result := OCR.FromFile("D:\Macro\AA-mango-dev\Debug\card-ocr-" cardIndex suffix ".png", "en-US", 3)
        FileAppend(cardIndex suffix ": " result.Text "`n", "*")
    }
}
ExitApp(0)
