; Persistent semantic memory is separate from short-lived match telemetry.
global CARD_MATCH := 0
global CARD_MATCH_PATH := ""
global CARD_OFFER_ACTIVE := false
global CARD_OFFER_SCORED := false
global CARD_OFFER_VOTED := false
OnExit(CardMemoryExit)
CleanupStaleCardMatches()

CardWriteJSON(path, data) {
    ; All callers supply fixed DEV-owned paths, never paths from OCR/API data.
    if (path = "")
        return false
    temporary := path ".new"
    try {
        file := FileOpen(temporary, "w", "UTF-8-RAW")
        if !IsObject(file)
            throw Error("Could not open card JSON")
        try file.Write(JSON.stringify(data))
        finally file.Close()
        FileMove(temporary, path, 1)
        return true
    } catch {
        ProcessLog("Card memory: JSON write failed; continuing with in-memory state")
        return false
    }
}

BeginCardMatch(mapName) {
    global CARD_MATCH, CARD_MATCH_PATH, mode
    EndCardMatch("stage-replaced")
    ClearCardOffer()
    root := A_ScriptDir "\Logs\Matches"
    try {
        if !DirExist(root)
            DirCreate(root)
    } catch {
        root := ""
        ProcessLog("Card match: temporary folder unavailable; keeping match analysis in memory")
    }
    id := FormatTime(, "yyyyMMddHHmmss") "-" DllCall("GetCurrentProcessId") "-" A_TickCount
    CARD_MATCH_PATH := root != "" ? root "\match-" id ".json" : ""
    CARD_MATCH := Map("id", id, "owner", "AA-mango-dev-card-engine", "game", "Anime Adventures", "mode", mode, "map", mapName
        , "started", A_NowUTC, "offerSequence", 0, "votesTotal", 0, "votedCards", [], "events", [])
    CardWriteJSON(CARD_MATCH_PATH, CARD_MATCH)
    return id
}

BeginCardOffer() {
    global CARD_MATCH, CARD_MATCH_PATH
    if IsObject(CARD_MATCH) {
        CARD_MATCH["offerSequence"] += 1
        CARD_MATCH["events"].Push({event: "offer-open", time: A_NowUTC, offer: CARD_MATCH["offerSequence"]})
        CardWriteJSON(CARD_MATCH_PATH, CARD_MATCH)
    }
}

RecordCardMatch(names, pick, elapsed, reason, randomVote := false) {
    global CARD_MATCH, CARD_MATCH_PATH
    if !IsObject(CARD_MATCH)
        return
    events := CARD_MATCH["events"]
    events.Push({time: A_NowUTC, offer: CARD_MATCH["offerSequence"], cards: names
        , pick: pick, elapsedMs: elapsed, reason: reason, analysis: [], ai: []})
    if events.Length > 200
        events.RemoveAt(1)
    if (pick >= 1 && pick <= names.Length) {
        CARD_MATCH["votesTotal"] += 1
        if !randomVote {
            policy := AnalyzeCardEffects(names[pick])
            CARD_MATCH["votedCards"].Push({text: names[pick], effects: policy.signature
                , source: reason, offer: CARD_MATCH["offerSequence"], confirmation: "vote-only"})
            if CARD_MATCH["votedCards"].Length > 100
                CARD_MATCH["votedCards"].RemoveAt(1)
        }
    }
    CardWriteJSON(CARD_MATCH_PATH, CARD_MATCH)
}

EndCardMatch(reason := "end", expectedId := "") {
    global CARD_MATCH, CARD_MATCH_PATH
    if !IsObject(CARD_MATCH)
        return
    if (expectedId != "" && CARD_MATCH["id"] != expectedId)
        return ; an older recursive stage must not delete a newer stage's file
    path := CARD_MATCH_PATH, prefix := A_ScriptDir "\Logs\Matches\match-"
    CARD_MATCH := 0, CARD_MATCH_PATH := ""
    ClearCardOffer()
    if (SubStr(path, 1, StrLen(prefix)) != prefix || !RegExMatch(SubStr(path, StrLen(prefix)+1), "^[0-9-]+\.json$"))
        return
    try {
        if FileExist(path)
            FileDelete(path)
        if FileExist(path ".new")
            FileDelete(path ".new")
    } catch {
        ProcessLog("Card match: temporary JSON cleanup failed; file retained for manual inspection")
    }
}

CardMemoryExit(*) {
    try EndCardMatch("exit")
}

CleanupStaleCardMatches() {
    root := A_ScriptDir "\Logs\Matches\"
    ; Startup only; DEV's Main refuses concurrent PROD and uses one DEV instance.
    Loop Files root "match-*.json" {
        path := A_LoopFileFullPath
        if (SubStr(path, 1, StrLen(root)) != root)
            continue
        try {
            value := JSON.parse(FileRead(path, "UTF-8"), true)
            if !(value is Map) || value["owner"] != "AA-mango-dev-card-engine"
                || A_LoopFileName != "match-" value["id"] ".json"
                continue
            FileDelete(path)
            if FileExist(path ".new")
                FileDelete(path ".new")
        } catch {
            ProcessLog("Card match: stale temporary file could not be cleaned; retaining it")
        }
    }
}

ClearCardOffer() {
    global CARD_OFFER_ACTIVE, CARD_OFFER_SCORED, CARD_OFFER_VOTED, CARD_OFFER_DEADLINE, CARD_INPUT_BLOCKED
    CARD_OFFER_ACTIVE := false, CARD_OFFER_SCORED := false, CARD_OFFER_VOTED := false
    CARD_OFFER_DEADLINE := 0, CARD_INPUT_BLOCKED := false
}
