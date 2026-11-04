#Requires AutoHotkey v2.0
#Warn All, Off
#Include upgrade-loops-functions-test.ahk
global successfulCoordinates := [], PriorityUpgrade := {Value: 0}
global priority1 := {Text: "1"}, priority2 := {Text: "2"}, priority3 := {Text: "3"}
global priority4 := {Text: "4"}, priority5 := {Text: "5"}, priority6 := {Text: "6"}
global called := Map(), physical := false, monitors := 0, maxChecks := 0
ProcessLog(*) {
}
UpgradeUnit(x, y, slot) {
    global called, physical
    called[x] := called.Has(x) ? called[x] + 1 : 1
    if (called[x] > 3)
        throw Error("Repeated completed coordinate")
    physical := x = 30
    return physical ? true : "limit"
}
MaxUpgrade() {
    global physical, maxChecks
    maxChecks++
    return physical
}
MonitorStage() {
    global monitors
    monitors++
}
CheckForXp() {
    return false
}
CheckAbility(*) {
}
FixClick(*) {
}
MahogoraAbility(*) {
}
Reconnect(*) {
}
CheckEndAndRoute(*) {
}
Wave40Reached(*) {
}
try {
    for priorityEnabled in [0, 1] {
        PriorityUpgrade.Value := priorityEnabled
        successfulCoordinates := [{x: 10, y: 10, slot: 1}, {x: 20, y: 20, slot: 1}, {x: 30, y: 30, slot: 2}]
        called := Map(), physical := false, monitors := 0, maxChecks := 0
        UpgradeUnits()
        if successfulCoordinates.Length || monitors != 1 || called.Count != 3 || maxChecks != 1
            throw Error("Upgrade loop invariant, priority=" priorityEnabled)
        for x, count in called
            if count != 1
                throw Error("A completed copy was upgraded again")
    }
    FileAppend("PASS normal and priority loops: two capped copies + one physical MAX, correct removal/routing`n", "*")
    ExitApp(0)
} catch as err {
    FileAppend("FAIL " err.Message " @ " err.Line "`n", "*")
    ExitApp(1)
}
