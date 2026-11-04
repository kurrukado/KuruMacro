#Requires AutoHotkey v2.0
#Warn All, Off
#Include result-transition-function-test.ahk
global mode := "Summer Event", SummerAwaitingMatch := true, SummerMapName := "Cursed Festival"
global starts := 0, restarts := 0, restartedMap := "", detected := "Snowy Town", phases := []
ReadResultScreen() {
    global phases
    return {Text: "Areas Play", phase: phases.Length ? phases.RemoveAt(1) : ""}
}
ResultScreenPhase(result) {
    return result.phase
}
ProcessLog(*) {
}
StartSelectedMode() {
    global starts
    starts++
    return "started"
}
DetectSummerMap(*) {
    global detected
    return detected
}
RestartStage(mapName := "") {
    global restarts, restartedMap
    restarts++, restartedMap := mapName
    return "restarted"
}
Assert(ok, label) {
    if !ok
        throw Error(label)
}
try {
    phases := ["choices", ""]
    Assert(ContinueAfterResult("lobby") = "started", "Lobby must re-enter selected mode")
    Assert(starts = 1 && restarts = 0 && !SummerAwaitingMatch && SummerMapName = "", "Lobby clears queue/map cache")
    SummerMapName := "Cursed Festival"
    Assert(ContinueAfterResult("replay") = "restarted", "Summer replay restart")
    Assert(restartedMap = "Snowy Town" && SummerMapName = "Snowy Town", "Replay detects actual new map")
    detected := "", countBefore := restarts
    Assert(ContinueAfterResult("replay") = false && restarts = countBefore, "Unknown map never uses stale route")
    mode := "Infinite"
    Assert(ContinueAfterResult("replay") = "restarted" && restartedMap = "", "Other modes retain normal detection")
    FileAppend("PASS 4 result transition cases: lobby rejoin, replay re-detection, stale-map refusal, normal replay`n", "*")
    ExitApp(0)
} catch as err {
    FileAppend("FAIL " err.Message " @ " err.Line "`n", "*")
    ExitApp(1)
}
