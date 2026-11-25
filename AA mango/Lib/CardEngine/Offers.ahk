; Card engine: Offers. Runtime behavior preserved during extraction.

SaveCardHistory(mode, names, pick, elapsed, reason, randomVote := false) {
    try RecordCardMatch(names, pick, elapsed, reason, randomVote)
    catch
        ProcessLog("Card: history write failed; gameplay continues")
}

HandleCardScreen(mode) {
    global CARD_OFFER_DEADLINE, CARD_DEADLINE_MS, rblxID
    started := A_TickCount
    deadline := CARD_OFFER_DEADLINE > 0 ? CARD_OFFER_DEADLINE : started + CARD_DEADLINE_MS
    if !WinActive(rblxID)
        return 0
    window := WinExist(rblxID)
    geometry := SmartPlacementGeometry()
    fresh := () => A_TickCount < deadline && WinActive(rblxID)
        && WinExist(rblxID) = window && SmartPlacementGeometry() = geometry && CardScreenVisible(true)
    if geometry = "" || !fresh()
        return 0
    Sleep(900)
    cards := SummerQuantumReadCards(fresh, deadline)
    pick := SummerQuantumBestCard(cards)
    names := []
    for card in cards
        names.Push(card.name != "" ? card.name : card.text)
    if !pick {
        ProcessLog("Card: no readable card; waiting for the game to decide")
        SaveCardHistory(mode, names, 0, A_TickCount-started, "no readable card")
        return 0
    }
    if !SummerQuantumPressCard(pick, fresh, deadline) {
        ProcessLog("Card: Vote button not confirmed before the offer changed or expired")
        SaveCardHistory(mode, names, 0, A_TickCount-started, "vote not confirmed")
        return 0
    }
    ProcessLog("Card: Vote pressed for slot " pick " (" names[pick] ")")
    SaveCardHistory(mode, names, pick, A_TickCount-started, "Quantum priority")
    return pick
}

WaitForCardChoice(modeName := "") {
    global mode, rblxID, CARD_ACTION_BUSY, CARD_INPUT_BLOCKED, CARD_OFFER_DEADLINE, CARD_DEADLINE_MS
    global CARD_OFFER_ACTIVE, CARD_OFFER_SCORED, CARD_OFFER_VOTED
    if (mode != "Summer Event" || CARD_ACTION_BUSY || (!CARD_OFFER_ACTIVE && !CardScreenVisible(true)))
        return false
    if !CARD_OFFER_ACTIVE {
        CARD_OFFER_ACTIVE := true
        CARD_OFFER_DEADLINE := A_TickCount + CARD_DEADLINE_MS
        CARD_OFFER_SCORED := false, CARD_OFFER_VOTED := false
        try BeginCardOffer()
        catch
            ProcessLog("Card: offer history unavailable; continuing selection")
    }
    CARD_ACTION_BUSY := true
    voted := CARD_OFFER_VOTED
    watchdog := A_TickCount + 45000
    goneLooks := 0
    try {
        if !WinActive(rblxID) {
            CARD_INPUT_BLOCKED := true
            return voted
        }
        loop {
            if !WinActive(rblxID) {
                CARD_INPUT_BLOCKED := true
                return voted
            }
            if CardScreenVisible(true)
                goneLooks := 0
            else if ++goneLooks >= 3 {
                ClearCardOffer()
                ProcessLog("Card: board closed; resuming gameplay")
                return voted
            }
            if goneLooks {
                Sleep(300)
                continue
            }
            if (A_TickCount >= watchdog) {
                CARD_INPUT_BLOCKED := true
                ProcessLog("Card: UI exceeded its expected timer; preserving offer state and blocking unit actions")
                return voted
            }
            if !CARD_OFFER_SCORED && A_TickCount < CARD_OFFER_DEADLINE {
                ; Consume the attempt even if panel cleanup or OCR fails.
                CARD_OFFER_SCORED := true
                SendEvent("q")
                if CloseUnitPanel() {
                    voted := HandleCardScreen(modeName) > 0
                    CARD_OFFER_VOTED := voted
                } else {
                    ProcessLog("Card: unit panel still obscures the offer; skipping vote")
                }
            }
            Sleep(300)
        }
    } catch as e {
        CARD_INPUT_BLOCKED := true
        ProcessLog("Card: handler interrupted; preserving offer state until UI recovery")
        return false
    } finally {
        CARD_ACTION_BUSY := false
    }
}
