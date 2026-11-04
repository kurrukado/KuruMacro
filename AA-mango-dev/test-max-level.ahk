#Requires AutoHotkey v2.0
#Warn All, Off
#Include max-level-functions-test.ahk
global UnitData := [], mode := "Infinite"
global testMessages := []
class TestInput {
    __New(value) {
        this.Text := value
    }
    Focus() {
    }
}
ProcessLog(message) {
    global testMessages
    testMessages.Push(message)
}
Assert(value, message) {
    if !value
        throw Error(message)
}
try {
    Assert(NormalizeUnitMaxLevel(" off `r") = "OFF", "OFF normalization")
    Assert(NormalizeUnitMaxLevel("MAX") = "OFF", "Legacy MAX becomes OFF")
    Assert(NormalizeUnitMaxLevel("") = "OFF", "Empty defaults to OFF")
    Assert(NormalizeUnitMaxLevel("0") = "OFF", "Legacy zero becomes OFF")
    Assert(NormalizeUnitMaxLevel("20") = "20", "Upper bound")
    values := ["OFF", "1", "2", "5", "10", "20"]
    for value in values
        UnitData.Push({MaxLevel: TestInput(value)})
    DirCreate(A_ScriptDir "\Settings")
    settingsPath := A_ScriptDir "\Settings\Configuration.txt"
    Assert(!FileExist(settingsPath), "Test must use an empty dev configuration")
    SaveSettings()
    original := FileRead(settingsPath)
    for unit in UnitData
        unit.MaxLevel.Text := "changed"
    readInSettings()
    for index, value in values
        Assert(UnitData[index].MaxLevel.Text = value, "Round-trip slot " index)
    Assert(GetUnitUpgradeLimit(1) = 0, "OFF disables limit")
    Assert(GetUnitUpgradeLimit(6) = 20, "Dropdown text is the cap, not selection index")
    UnitData[3].MaxLevel.Text := "-1"
    Assert(SaveSettings() = false, "Invalid value rejected")
    Assert(FileRead(settingsPath) = original, "Invalid save preserves existing settings")
    Assert(InStr(testMessages[-1], "Unit 3"), "Error identifies slot")
    FileDelete(settingsPath)
    ; Simulate a legacy config with no MaxLevel keys.
    FileAppend("Mode=Infinite`n", settingsPath)
    for unit in UnitData
        unit.MaxLevel.Text := "OFF"
    readInSettings()
    for unit in UnitData
        Assert(unit.MaxLevel.Text = "OFF", "Legacy configuration keeps OFF")
    FileDelete(settingsPath)
    FileAppend("PASS normalization, 6-slot save/load, invalid-save protection, legacy config`n", "*")
    ExitApp(0)
} catch as err {
    FileAppend("FAIL " err.Message " @ " err.Line "`n", "*")
    ExitApp(1)
}
