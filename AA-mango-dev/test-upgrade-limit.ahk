#Requires AutoHotkey v2.0
#Warn All, Off
#Include upgrade-limit-functions-test.ahk
global reads := [], presses := 0, testMessages := []
ProcessLog(text) {
    global testMessages
    testMessages.Push(text)
}
MockRead() {
    global reads
    if !reads.Length
        throw Error("Unexpected extra read")
    return reads.RemoveAt(1)
}
MockPress() {
    global presses
    presses++
}
Assert(ok, label) {
    if !ok
        throw Error(label)
}
CheckRun(levels, limit, expectedPresses, expectedResult) {
    global reads := levels.Clone(), presses := 0
    result := ApplyUnitUpgradeLimit(limit, 1, MockRead, MockPress)
    Assert(presses = expectedPresses, "press count, target " limit)
    Assert(result = expectedResult, "result, target " limit)
}
try {
    Assert(ParseUnitUpgradeLevel("Upgrade [0]") = 0, "initial level")
    Assert(ParseUnitUpgradeLevel("Upgrade [ 20 ]") = 20, "level 20")
    Assert(ParseUnitUpgradeLevel("UPGRADE (2)") = 2, "OCR parentheses")
    Assert(ParseUnitUpgradeLevel("Upgrade [MAX]") = 21, "physical max")
    Assert(ParseUnitUpgradeLevel("Upgrade 1500 yen") = -1, "price is not a level")
    Assert(ParseUnitUpgradeLevel("Level 100 Upgrade") = -1, "unit experience is not upgrade")
    Assert(ParseUnitUpgradeLevel("Upgrade [21]") = -1, "out of supported range")
    Assert(ParseUnitUpgradeLevel("Upgrade [2] Upgrade [3]") = -1, "ambiguous levels")
    Assert(ParseUnitUpgradeLevel("UPG [0]") = 0, "new panel label")
    Assert(ParseUnitUpgradeLevel("upgo") = 0, "measured isolated gold zero glyph")
    Assert(ParseUnitUpgradeLevel("upgI") = 1, "isolated one glyph")
    Assert(ParseUnitUpgradeLevel("upgo other text") = -1, "no broad glyph guessing")
    CheckRun([2], 2, 0, "limit")
    CheckRun([3], 2, 0, "limit")
    CheckRun([0, 1], 1, 1, "limit")
    CheckRun([0, 1, 1, 2], 2, 2, "limit")
    CheckRun([0, 0], 2, 1, false)
    CheckRun([-1], 2, 0, false)
    CheckRun([0, -1], 2, 1, false)
    CheckRun([21], 20, 0, "limit")
    CheckRun([0, 1, 1, 2, 2, 3], 20, 3, true)
    ; Two independent placed copies of the same slot are each checked.
    CheckRun([1], 1, 0, "limit")
    CheckRun([0, 1], 1, 1, "limit")
    FileAppend("PASS 23 parser/capped-upgrade cases; no overshoot, no blind retry, separate copies`n", "*")
    ExitApp(0)
} catch as err {
    FileAppend("FAIL " err.Message " @ " err.Line "`n", "*")
    ExitApp(1)
}
