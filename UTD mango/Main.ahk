#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon
SendMode "Event"
#Include %A_ScriptDir%\lib/Image.ahk
#Include %A_ScriptDir%\lib/GUI.ahk
#Include %A_ScriptDir%\lib/GameMango.ahk
#Include %A_ScriptDir%\lib/Functions.ahk
#Include %A_ScriptDir%\lib/webhooksettings.ahk
#Include %A_ScriptDir%\Lib\FindText.ahk
#include %A_ScriptDir%\Lib\OCR-main\Lib\OCR.ahk
#include %A_ScriptDir%\Lib\OCR-main\Lib\OCR.ahk

; Trong Main.ahk (Phần đầu file)

; ... (Các dòng Include) ...
Global UnitPlacements := Map()
Loop 6 {
    UnitPlacements[A_Index] := []
}

; THÊM DÒNG NÀY:
LoadUnitCoordsFromFile()