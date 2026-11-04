#Requires AutoHotkey v2.0
#Warn All, Off
#Include max-level-functions-test.ahk
global UnitData := [], mode := "Infinite", MatchMaking := {Value: 1}
ProcessLog(*) {
}
try {
    testGui := Gui()
    items := ["OFF"]
    Loop 20
        items.Push(A_Index "")
    Loop 6
        UnitData.Push({MaxLevel: testGui.Add("DropDownList", "Choose1", items)})
    values := ["OFF", "1", "2", "5", "10", "20"]
    for index, unit in UnitData {
        if (unit.MaxLevel.Text != "OFF")
            throw Error("Default is not OFF")
        unit.MaxLevel.Text := values[index]
    }
    config := A_ScriptDir "\Settings\Configuration.txt"
    if FileExist(config)
        throw Error("Dev test config already exists")
    SaveSettings()
    MatchMaking.Value := 0
    for unit in UnitData
        unit.MaxLevel.Text := "OFF"
    readInSettings()
    if MatchMaking.Value != 1
        throw Error("Matchmaking enabled state did not roundtrip")
    for index, unit in UnitData {
        if (unit.MaxLevel.Text != values[index])
            throw Error("Real DropDownList roundtrip failed at slot " index)
    }
    if (GetUnitUpgradeLimit(1) != 0 || GetUnitUpgradeLimit(6) != 20)
        throw Error("Cap must use selected text, not 1-based Value")
    mode := "Summer Event"
    MatchMaking.Value := 0
    SaveSettings()
    MatchMaking.Value := 1
    readInSettings()
    if MatchMaking.Value != 0
        throw Error("Saved solo choice was forced back to matchmaking")
    FileDelete(config)
    testGui.Destroy()
    FileAppend("PASS real Windows dropdown + six-slot limits + matchmaking/solo persistence`n", "*")
    ExitApp(0)
} catch as err {
    FileAppend("FAIL " err.Message " @ " err.Line "`n", "*")
    ExitApp(1)
}
