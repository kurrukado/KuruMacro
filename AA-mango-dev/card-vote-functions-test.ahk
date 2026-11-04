HandleCardScreen(mode := "") {
    global CARD_X, CARD_Y, CARD_DEADLINE_MS, CARD_READ_BUDGET_MS

    if (CARD_Y = 0 || CARD_X[1] = 0) {
        ProcessLog("Card: chua do toa do the - bo qua")
        return 0
    }

    t0 := A_TickCount
    names := ReadCardNames(CARD_READ_BUDGET_MS)
    elapsed := A_TickCount - t0

    if (!IsObject(names) || names.Length < 3 || Trim(names[1] names[2] names[3]) = "") {
        ProcessLog("Card: OCR chua du du lieu; khong bam mu")
        return 0
    }

    pick := ChooseCard(names, &reason)
    elapsed := A_TickCount - t0 ; include network time

    if (elapsed > CARD_DEADLINE_MS) {
        ProcessLog("Card: qua deadline; khong gui click tre")
        return 0
    }

    ProcessLog("Card: " names[1] " | " names[2] " | " names[3]
        . " -> chon " pick " (" reason ", ocr " elapsed "ms, jev " JEV_LAST_MS "ms)")

    if (pick < 1 || pick > 3 || !CardScreenVisible()) {
        ProcessLog("Card: offer da dong hoac mat focus; bo qua vote")
        return 0
    }
    oldMode := A_CoordModeMouse
    CoordMode "Mouse", "Client"
    try {
        ; Selection is a vote; the panel remains visible until everyone votes.
        ; Send exactly one vote per offer, never a blind retry on a different card.
        FixClick(CARD_X[pick], CARD_Y)
    } finally {
        CoordMode "Mouse", oldMode
    }

    SaveCardHistory(mode, names, pick, elapsed, reason)
    return pick
}

WaitForCardChoice(modeName := "") {
    if !CardScreenVisible()
        return false
    ; A unit panel can cover the entire left card. Close only a positively
    ; identified panel before OCR; never score effects hidden underneath it.
    CloseUnitPanel()
    if FindUnitPanel(&panelX, &panelY) {
        ProcessLog("Card: panel unit van che the; khong doc noi dung bi che")
        return false
    }
    Sleep(700)
    voted := false
    deadline := A_TickCount + 15000
    while CardScreenVisible() {
        if (A_TickCount >= deadline)
            throw Error("Card vote UI remained open past its expected timer")
        if !voted
            voted := HandleCardScreen(modeName) > 0
        Sleep(300)
    }
    return voted
}
