ContinueAfterResult(action) {
    global mode, SummerAwaitingMatch, SummerMapName
    deadline := A_TickCount + 45000
    while (A_TickCount < deadline) {
        result := ReadResultScreen()
        if IsObject(result) && ResultScreenPhase(result) = "" {
            if (action != "lobby" || RegExMatch(result.Text, "i)\bareas\b"))
                break
        }
        Sleep(500)
    }
    if (A_TickCount >= deadline) {
        ProcessLog("Result UI: chua xac nhan chuyen canh; dung, khong click lap")
        return false
    }
    if (action = "lobby") {
        SummerAwaitingMatch := false
        SummerMapName := ""
        return StartSelectedMode()
    }
    if (mode = "Summer Event") {
        mapName := DetectSummerMap(60000) ; replay can rotate the actual map
        if (mapName = "")
            return false
        SummerMapName := mapName
        return RestartStage(mapName)
    }
    return RestartStage()
}
