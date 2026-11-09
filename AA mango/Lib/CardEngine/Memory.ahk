; Persistent semantic memory is separate from short-lived match telemetry.
global CARD_MEMORY_SCHEMA := 1
global CARD_MEMORY := 0
global CARD_MEMORY_WRITABLE := true
global CARD_MATCH := 0
global CARD_MATCH_PATH := ""
global JEV_LAST_DETAILS := []
global JEV_LAST_MODEL := ""
global CARD_LAST_ANALYSIS := []
global CARD_OFFER_ACTIVE := false
global CARD_OFFER_SCORED := false
global CARD_OFFER_VOTED := false
OnExit(CardMemoryExit)
CleanupStaleCardMatches()

CanonicalCardText(text) {
    text := StrLower(StrReplace(StrReplace(text, Chr(0x2212), "-"), Chr(0xFF0B), "+"))
    return Trim(RegExReplace(text, "\s+", " ")) ; keep signs, numbers, decimals and percent
}

CardMemoryIdentity(text) {
    global mode, CARD_MEMORY_SCHEMA
    return JSON.stringify({game: "Anime Adventures", mode: mode, schema: CARD_MEMORY_SCHEMA, ratingProtocol: "weighted-utility-v1"
        , text: CanonicalCardText(text), weights: CardPriorityWeights()})
}

CardMemoryKey(identity) {
    ; CRC is only an index. Every lookup also compares the FULL identity.
    return Format("{:08X}", DllCall("ntdll\RtlComputeCrc32", "UInt", 0, "Ptr", StrPtr(identity), "UInt", StrLen(identity)*2, "UInt"))
}

CardMemoryLoad() {
    global CARD_MEMORY, CARD_MEMORY_SCHEMA, CARD_MEMORY_WRITABLE
    if IsObject(CARD_MEMORY)
        return CARD_MEMORY
    CARD_MEMORY := Map("schema", CARD_MEMORY_SCHEMA, "entries", Map())
    path := A_ScriptDir "\Settings\CardKnowledge.json"
    if !FileExist(path)
        return CARD_MEMORY
    try {
        saved := JSON.parse(FileRead(path, "UTF-8"), true)
        if !(saved is Map) || !saved.Has("schema") || saved["schema"] != CARD_MEMORY_SCHEMA
            || !saved.Has("entries") || !(saved["entries"] is Map)
            throw Error("Invalid card memory schema")
        CARD_MEMORY := saved
    } catch {
        CARD_MEMORY_WRITABLE := false
        ProcessLog("Card memory: unreadable/version-mismatched JSON; using memory-only fallback without overwriting the file")
    }
    return CARD_MEMORY
}

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

CardMemorySave() {
    global CARD_MEMORY_WRITABLE
    memory := CardMemoryLoad()
    if !CARD_MEMORY_WRITABLE
        return false
    entries := memory["entries"]
    ; Bound disk growth; eviction removes our oldest entry, never another file.
    while entries.Count > 1000 {
        oldest := "", oldestTime := "99999999999999"
        for key, value in entries {
            if (value is Map) && value.Has("lastSeen") && value["lastSeen"] < oldestTime
                oldest := key, oldestTime := value["lastSeen"]
        }
        if (oldest = "") {
            for key, value in entries {
                oldest := key
                break
            }
        }
        entries.Delete(oldest)
    }
    return CardWriteJSON(A_ScriptDir "\Settings\CardKnowledge.json", memory)
}

CardMemoryLookup(text) {
    global JEV_MODEL
    memory := CardMemoryLoad(), identity := CardMemoryIdentity(text), key := CardMemoryKey(identity)
    try {
        entry := memory["entries"][key]
        if !(entry is Map) || entry["identity"] != identity
            return 0
        if (entry["status"] != "local" && entry["status"] != "confirmed-model")
            return 0
        if (entry["status"] = "confirmed-model" && (entry["confidence"] < 0.90 || entry["modelAlias"] != JEV_MODEL))
            return 0
        if DateDiff(A_NowUTC, entry["lastSeen"], "Days") > 30
            return 0
        if !IsNumber(entry["score"]) || !IsNumber(entry["resistance"])
            return 0
        return {score: entry["score"], resistance: entry["resistance"], source: entry["status"]}
    }
    return 0
}

CardMemoryStoreLocal(text, policy) {
    if (!policy.known || policy.blocked)
        return
    memory := CardMemoryLoad(), identity := CardMemoryIdentity(text), key := CardMemoryKey(identity)
    try {
        old := memory["entries"][key]
        if old["identity"] = identity && old["status"] = "local"
            return
    }
    memory["entries"][key] := Map("identity", identity, "text", text, "status", "local"
        , "score", policy.score, "resistance", policy.resistance, "effects", policy.signature
        , "confidence", 1, "confirmations", 1, "lastSeen", A_NowUTC)
    CardMemorySave()
}

CardMemoryStoreAI(text, detail) {
    global CARD_MATCH, JEV_MODEL
    if (!IsObject(detail) || !detail.accepted || detail.confidence < 0.90)
        return
    memory := CardMemoryLoad(), identity := CardMemoryIdentity(text), key := CardMemoryKey(identity)
    evidence := IsObject(CARD_MATCH) ? CARD_MATCH["id"] ":" CARD_MATCH["offerSequence"] : ""
    if (evidence = "")
        return ; only runtime offers can contribute learning evidence
    count := 1, confidence := detail.confidence
    try {
        old := memory["entries"][key]
        if (old["identity"] = identity && old["category"] = detail.category && old["polarity"] = detail.polarity
            && Abs(old["score"] - detail.score) <= Max(2, Min(10, Abs(old["score"])*0.25)) && old["modelAlias"] = JEV_MODEL) {
            if (old["evidence"] = evidence)
                return
            count := old["confirmations"] + 1
            confidence := Min(old["confidence"], confidence)
        }
    }
    memory["entries"][key] := Map("identity", identity, "text", text
        , "status", count >= 2 ? "confirmed-model" : "provisional"
        , "score", detail.score, "resistance", detail.resistance
        , "category", detail.category, "polarity", detail.polarity
        , "confidence", confidence, "confirmations", count, "evidence", evidence
        , "modelAlias", JEV_MODEL, "modelUsed", detail.modelUsed, "lastSeen", A_NowUTC)
    CardMemorySave()
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
    global CARD_MATCH, CARD_MATCH_PATH, JEV_LAST_DETAILS, CARD_LAST_ANALYSIS
    JEV_LAST_DETAILS := [], CARD_LAST_ANALYSIS := []
    if IsObject(CARD_MATCH) {
        CARD_MATCH["offerSequence"] += 1
        CARD_MATCH["events"].Push({event: "offer-open", time: A_NowUTC, offer: CARD_MATCH["offerSequence"]})
        CardWriteJSON(CARD_MATCH_PATH, CARD_MATCH)
    }
}

CardMatchContext() {
    global CARD_MATCH, mode
    if !IsObject(CARD_MATCH)
        return {mode: mode, votedCards: []}
    recent := [], selected := CARD_MATCH["votedCards"]
    first := Max(1, selected.Length - 7)
    for i, card in selected {
        if i >= first
            recent.Push(card)
    }
    return {mode: CARD_MATCH["mode"], map: CARD_MATCH["map"], votedCards: recent, activeEffectsConfirmed: false}
}

RecordCardMatch(names, pick, elapsed, reason) {
    global CARD_MATCH, CARD_MATCH_PATH, CARD_LAST_ANALYSIS, JEV_LAST_DETAILS
    if !IsObject(CARD_MATCH)
        return
    events := CARD_MATCH["events"]
    events.Push({time: A_NowUTC, offer: CARD_MATCH["offerSequence"], cards: names
        , pick: pick, elapsedMs: elapsed, reason: reason, analysis: CARD_LAST_ANALYSIS, ai: JEV_LAST_DETAILS})
    if events.Length > 200
        events.RemoveAt(1)
    if (pick >= 1 && pick <= names.Length) {
        CARD_MATCH["votesTotal"] += 1
        policy := AnalyzeCardEffects(names[pick])
        CARD_MATCH["votedCards"].Push({text: names[pick], effects: policy.signature
            , source: reason, offer: CARD_MATCH["offerSequence"], confirmation: "vote-only"})
        if CARD_MATCH["votedCards"].Length > 100
            CARD_MATCH["votedCards"].RemoveAt(1)
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
