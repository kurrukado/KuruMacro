; Public hooks called by placement/upgrade and Smart calibration.

ServiceSummerCards(force := false) {
    global mode, CARD_ENABLED, rblxID, CARD_OFFER_ACTIVE
    static busy := false, lastCheck := 0
    if (busy || !CARD_ENABLED || mode != "Summer Event" || !WinActive(rblxID))
        return false
    if (!force && A_TickCount - lastCheck < 350)
        return false
    lastCheck := A_TickCount
    busy := true
    try {
        if (!CARD_OFFER_ACTIVE && !CardScreenVisible())
            return false
        ; Cancel the placement ghost before voting. The caller reselects its slot.
        SendEvent("q")
        WaitForCardChoice(mode)
        return true
    } finally {
        busy := false
        lastCheck := A_TickCount
    }
}

UnitActionAllowed() {
    global rblxID, mode, CARD_ACTION_BUSY, CARD_INPUT_BLOCKED, CARD_OFFER_ACTIVE
    if (!WinActive(rblxID) || CARD_ACTION_BUSY || CARD_OFFER_ACTIVE)
        return false
    if CARD_INPUT_BLOCKED {
        if CardScreenVisible()
            return false
        CARD_INPUT_BLOCKED := false
    }
    if (mode = "Summer Event" && CardScreenVisible()) {
        CARD_INPUT_BLOCKED := true
        return false
    }
    ; Results take priority over selecting/placing/upgrading another unit.
    return !ResultScreenReady()
}

CardEngineBlocksInput() {
    global CARD_ACTION_BUSY, CARD_INPUT_BLOCKED
    return CARD_ACTION_BUSY || CARD_INPUT_BLOCKED
}
