#Requires AutoHotkey v2.0
#Warn All, Off
#Include D:\Macro\AA mango\AA mango\Lib\OCR-main\Lib\OCR.ahk
result := OCR.FromFile("D:\Macro\AA-mango-dev\Debug\unit-panel-crop.png", "en-US", 3)
FileAppend(result.Text "`n", "*")
ExitApp(0)
