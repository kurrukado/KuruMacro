#Requires AutoHotkey v2.0
#Warn All, Off
#Include card-vote-functions-test.ahk
global CARD_X := [224,400,577], CARD_Y := 320, CARD_DEADLINE_MS := 5000, CARD_READ_BUDGET_MS := 3000, JEV_LAST_MS := 0
global visible := true, sequence := [], panelOpen := false, closeWorks := true, names := ["Damage +20%", "Enemy speed +20%", "Income +10%"]
global chooseCalls := 0, clicks := 0, history := 0, expireDuringChoice := false, choiceDelay := 0
ProcessLog(*) {
}
ReadCardNames(*) {
    global names
    return names
}
ChooseCard(cards, &reason) {
    global visible, expireDuringChoice, choiceDelay, chooseCalls
    chooseCalls++
    reason := "test"
    if choiceDelay
        Sleep(choiceDelay)
    if expireDuringChoice
        visible := false
    return 2
}
CardScreenVisible() {
    global visible, sequence
    return sequence.Length ? sequence.RemoveAt(1) : visible
}
FixClick(x,y) {
    global clicks
    if x != 400 || y != 320
        throw Error("Wrong vote target")
    clicks++
}
SaveCardHistory(*) {
    global history
    history++
}
CloseUnitPanel() {
    global panelOpen, closeWorks
    if closeWorks
        panelOpen := false
}
FindUnitPanel(&x,&y) {
    global panelOpen
    return panelOpen
}
Assert(ok,label) {
    if !ok
        throw Error(label)
}
try {
    expireDuringChoice := true
    Assert(HandleCardScreen() = 0 && clicks = 0, "Expired offer must not click")
    expireDuringChoice := false, visible := true, CARD_DEADLINE_MS := 0, choiceDelay := 20
    Assert(HandleCardScreen() = 0 && clicks = 0, "Deadline includes choice/API time")
    CARD_DEADLINE_MS := 5000, choiceDelay := 0
    Assert(HandleCardScreen() = 2 && clicks = 1 && history = 1, "Valid single vote")
    names := ["", "", ""]
    Assert(HandleCardScreen() = 0 && clicks = 1, "Blank OCR must not click")
    panelOpen := true, closeWorks := false, callsBefore := chooseCalls
    Assert(WaitForCardChoice() = false && chooseCalls = callsBefore && clicks = 1, "Panel still open must not score")
    names := ["Damage +20%", "Enemy speed +20%", "Income +10%"]
    closeWorks := true, sequence := [true, true, true, false], visible := false
    Assert(WaitForCardChoice() = true && clicks = 2 && chooseCalls = callsBefore + 1, "One vote then wait for dismissal")
    FileAppend("PASS 6 card safety cases: stale/focus gate, deadline, blank OCR, obscured card, single vote`n", "*")
    ExitApp(0)
} catch as err {
    FileAppend("FAIL " err.Message " @ " err.Line "`n", "*")
    ExitApp(1)
}
