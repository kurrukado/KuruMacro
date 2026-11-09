; Card engine: Offers. Runtime behavior preserved during extraction.

SaveCardHistory(mode, names, pick, elapsed, reason) {
    RecordCardMatch(names, pick, elapsed, reason)
}

HandleCardScreen(mode, &scored) {
    global CARD_X, CARD_Y, CARD_DEADLINE_MS, CARD_READ_BUDGET_MS, CARD_OFFER_DEADLINE, rblxID
    t0 := A_TickCount
    deadline := CARD_OFFER_DEADLINE > 0 ? CARD_OFFER_DEADLINE : t0 + CARD_DEADLINE_MS
    remaining := deadline - A_TickCount
    if (remaining <= 0 || !WinActive(rblxID)) {
        scored := true
        return 0
    }
    names := ReadCardNames(Min(CARD_READ_BUDGET_MS, remaining))
    readable := false
    for text in names {
        if (Trim(text) != "")
            readable := true
    }
    if !readable {
        if A_TickCount >= deadline {
            scored := true
            ProcessLog("Card: OCR remained ambiguous until the deadline; no vote sent")
            SaveCardHistory(mode, names, 0, A_TickCount - t0, "ambiguous OCR")
        }
        return 0
    }
    if !CardScreenVisible(true)
        return 0
    scored := true ; retry only if the fresh-frame confirmation fails, before deadline
    pick := ChooseCard(names, &reason, deadline)
    elapsed := A_TickCount - t0
    ProcessLog("Card: " names[1] " | " names[2] " | " names[3] " -> selected " pick " (" reason ")")
    if (pick < 1 || pick > 3 || A_TickCount >= deadline || !WinActive(rblxID) || !CardScreenVisible(true)) {
        ProcessLog("Card: no vote sent; " (pick < 1 || pick > 3 ? "no coherent choice" : A_TickCount >= deadline ? "decision exceeded timer" : "focus or card board lost"))
        SaveCardHistory(mode, names, 0, elapsed, "not voted: " reason)
        return 0
    }
    ; Re-read the current offer. Never click a score calculated for a changed board.
    fresh := ReadCardNames(Min(1500, Max(0, deadline - A_TickCount - 250)), pick, names[pick])
    ; Confirm the selected card; rereading six crops could consume the entire timer.
    if !CardEffectsAgree(names[pick], fresh[pick]) {
            ProcessLog("Card: offer changed or OCR disagreed before click; discarding stale decision")
            SaveCardHistory(mode, names, 0, A_TickCount - t0, "stale/conflicting offer")
            scored := false ; a transient OCR failure can retry while this offer is visible
            return 0
    }
    if (fresh[pick] = "" || A_TickCount >= deadline || !WinActive(rblxID) || !CardScreenVisible(true)) {
        ProcessLog("Card: no vote sent; confirmation expired or focus/card board lost")
        SaveCardHistory(mode, names, 0, A_TickCount - t0, "expired/focus lost")
        return 0
    }
    WinGetClientPos(,, &cw, &ch, rblxID)
    oldMode := A_CoordModeMouse
    CoordMode "Mouse", "Client"
    try FixClick(Round(CARD_X[pick] * cw / 800), Round(CARD_Y * ch / 599))
    finally CoordMode "Mouse", oldMode
    ProcessLog("Card: vote sent for slot " pick)
    SaveCardHistory(mode, names, pick, A_TickCount - t0, reason)
    return pick
}

WaitForCardChoice(modeName := "") {
    global mode, rblxID, CARD_ACTION_BUSY, CARD_INPUT_BLOCKED, CARD_OFFER_DEADLINE, CARD_DEADLINE_MS
    global CARD_OFFER_ACTIVE, CARD_OFFER_SCORED, CARD_OFFER_VOTED
    if (mode != "Summer Event" || CARD_ACTION_BUSY || (!CARD_OFFER_ACTIVE && !CardScreenVisible()))
        return false
    if !CARD_OFFER_ACTIVE {
        CARD_OFFER_ACTIVE := true
        CARD_OFFER_DEADLINE := A_TickCount + CARD_DEADLINE_MS
        CARD_OFFER_SCORED := false, CARD_OFFER_VOTED := false
        BeginCardOffer()
    }
    CARD_ACTION_BUSY := true
    voted := CARD_OFFER_VOTED, scored := CARD_OFFER_SCORED
    watchdog := A_TickCount + 15000
    try {
        if !WinActive(rblxID) {
            CARD_INPUT_BLOCKED := true
            return voted
        }
        SendEvent("q")
        CloseUnitPanel(true)
        ProcessLog("Card: cleared unit UI using empty space beside the hotbar")
        obscured := FindUnitPanel(&panelX, &panelY)
        loop {
            if !WinActive(rblxID) {
                CARD_INPUT_BLOCKED := true
                return voted
            }
            if !CardScreenVisible(true) {
                Sleep(300)
                if !WinActive(rblxID) {
                    CARD_INPUT_BLOCKED := true
                    return voted
                }
                if !CardScreenVisible(true) {
                    ClearCardOffer() ; two fresh negative frames end one offer
                    return voted
                }
            }
            if (A_TickCount >= watchdog) {
                CARD_INPUT_BLOCKED := true
                ProcessLog("Card: UI exceeded its expected timer; preserving offer state and blocking unit actions")
                return voted
            }
            if obscured {
                CloseUnitPanel(true)
                obscured := FindUnitPanel(&panelX, &panelY)
            }
            if (!obscured && !scored) {
                voted := HandleCardScreen(modeName, &scored) > 0
                CARD_OFFER_SCORED := scored, CARD_OFFER_VOTED := voted
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
