#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn VarUnset, Off
#Warn All, Off
#NoTrayIcon
SendMode "Event"
SetWorkingDir(A_ScriptDir)
#Include %A_ScriptDir%\lib/Image.ahk
#Include %A_ScriptDir%\Lib\Interface\MacroAppearance.ahk
#Include %A_ScriptDir%\lib/GUI.ahk
#Include %A_ScriptDir%\lib/GameMango.ahk
#Include %A_ScriptDir%\lib/Functions.ahk
#Include %A_ScriptDir%\lib/webhooksettings.ahk
#Include %A_ScriptDir%\Lib\FindText.ahk
#include %A_ScriptDir%\Lib\OCR-main\Lib\OCR.ahk
#Include %A_ScriptDir%\Lib\Shared\HighContrastText.ahk
#Include %A_ScriptDir%\Lib\CardEngine\CardEngine.ahk
#Include %A_ScriptDir%\Lib\Experimental.ahk

global UnitPlacements := Map()
loop 6 {
    UnitPlacements[A_Index] := []
}

LoadUnitCoordsFromFile()
