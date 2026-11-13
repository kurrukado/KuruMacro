; Card-only capture/OCR; common contrast processing is in Lib/Shared.

ReadCardCrop(dc, x, y, w, h, contrast := false) {
    if contrast
        return ReadHighContrastText(x, y, w, h, 3, dc)
    memory := 0, bitmap := 0, previous := 0
    try {
        memory := DllCall("gdi32\CreateCompatibleDC", "Ptr", dc, "Ptr")
        bitmap := DllCall("gdi32\CreateCompatibleBitmap", "Ptr", dc, "Int", w, "Int", h, "Ptr")
        if (!memory || !bitmap)
            throw Error("Card crop allocation failed")
        previous := DllCall("gdi32\SelectObject", "Ptr", memory, "Ptr", bitmap, "Ptr")
        if (!previous || previous = -1)
            throw Error("Card crop selection failed")
        if !DllCall("gdi32\BitBlt", "Ptr", memory, "Int", 0, "Int", 0, "Int", w, "Int", h
            , "Ptr", dc, "Int", x, "Int", y, "UInt", 0x00CC0020)
            throw Error("Card crop copy failed")
        DllCall("gdi32\SelectObject", "Ptr", memory, "Ptr", previous)
        previous := 0
        return OCR.FromBitmap(bitmap, "en-US", 3).Text
    } finally {
        if (previous && previous != -1 && memory)
            DllCall("gdi32\SelectObject", "Ptr", memory, "Ptr", previous)
        if bitmap
            DllCall("gdi32\DeleteObject", "Ptr", bitmap)
        if memory
            DllCall("gdi32\DeleteDC", "Ptr", memory)
    }
}

ReadCardNames(budgetMs, onlySlot := 0, expectedText := "") {
    global rblxID, CARD_READ_CONFLICTS
    CARD_READ_CONFLICTS := Map()
    names := ["", "", ""]
    if (budgetMs <= 0 || !WinActive(rblxID) || !CardScreenVisible(true))
        return names
    started := A_TickCount
    paddleNames := PaddleReadCardNames(budgetMs, onlySlot)
    if paddleNames is Array
        return paddleNames
    screen := 0, memory := 0, bitmap := 0, previous := 0
    try {
        WinGetClientPos(&cx, &cy, &cw, &ch, rblxID)
        if (cw <= 0 || ch <= 0 || cw > 4096 || ch > 4096)
            return names
        sx := cw / 800, sy := ch / 599
        slotLefts := [148, 325, 502]
        cropW := Round(152*sx), cropH := Round(195*sy)
        captureLeft := Round(slotLefts[onlySlot ? onlySlot : 1]*sx)
        captureRight := Round(slotLefts[onlySlot ? onlySlot : 3]*sx) + cropW
        captureTop := Round(210*sy)
        captureW := captureRight - captureLeft
        screen := DllCall("user32\GetDC", "Ptr", 0, "Ptr")
        memory := DllCall("gdi32\CreateCompatibleDC", "Ptr", screen, "Ptr")
        bitmap := DllCall("gdi32\CreateCompatibleBitmap", "Ptr", screen, "Int", captureW, "Int", cropH, "Ptr")
        if (!screen || !memory || !bitmap)
            throw Error("Card offer capture allocation failed")
        previous := DllCall("gdi32\SelectObject", "Ptr", memory, "Ptr", bitmap, "Ptr")
        if (!previous || previous = -1)
            throw Error("Card offer bitmap selection failed")
        if !DllCall("gdi32\BitBlt", "Ptr", memory, "Int", 0, "Int", 0, "Int", captureW, "Int", cropH
            , "Ptr", screen, "Int", cx + captureLeft, "Int", cy + captureTop, "UInt", 0x00CC0020)
            throw Error("Card offer capture failed")
        ; All three slots and both OCR modes come from this ONE frozen frame.
        for i, left in slotLefts {
            if (onlySlot && i != onlySlot)
                continue
            if !WinActive(rblxID) || !CardScreenVisible(true)
                return ["", "", ""]
            if (A_TickCount - started >= budgetMs) {
                CARD_READ_CONFLICTS[i] := true
                continue
            }
            x := Round(left*sx) - captureLeft
            try {
                raw := ReadCardCrop(memory, x, 0, cropW, cropH)
                if (A_TickCount - started >= budgetMs) {
                    CARD_READ_CONFLICTS[i] := true
                    continue
                }
                raw := SubStr(Trim(RegExReplace(raw, "\s+", " ")), 1, 500)
                ; A second frame with the same signed effects confirms this choice.
                ; Do not veto it with a new, lossy contrast rendering of that frame.
                if (onlySlot && expectedText != "" && CardEffectsAgree(expectedText, raw)) {
                    names[i] := raw
                    continue
                }
                contrast := ReadCardCrop(memory, x, 0, cropW, cropH, true)
                raw := SubStr(Trim(RegExReplace(raw, "\s+", " ")), 1, 500)
                contrast := SubStr(Trim(RegExReplace(contrast, "\s+", " ")), 1, 500)
                if CardEffectsAgree(raw, contrast) || CardRawNeedsConfirmation(raw, contrast) {
                    names[i] := raw
                } else {
                    CARD_READ_CONFLICTS[i] := true
                    ProcessLog("Card OCR: slot " i " disagrees; raw=" raw "; contrast=" contrast "; excluding slot")
                }
            } catch as e {
                CARD_READ_CONFLICTS[i] := true
                ProcessLog("Card OCR: slot " i " capture/read failed; excluding slot")
            }
        }
    } catch as e {
        ProcessLog("Card OCR: offer capture failed; waiting without a blind vote")
    } finally {
        if (previous && previous != -1 && memory)
            DllCall("gdi32\SelectObject", "Ptr", memory, "Ptr", previous)
        if bitmap
            DllCall("gdi32\DeleteObject", "Ptr", bitmap)
        if memory
            DllCall("gdi32\DeleteDC", "Ptr", memory)
        if screen
            DllCall("user32\ReleaseDC", "Ptr", 0, "Ptr", screen)
    }
    try {
        WinGetClientPos(&nx, &ny, &nw, &nh, rblxID)
        if !WinActive(rblxID) || nx != cx || ny != cy || nw != cw || nh != ch
            return ["", "", ""]
    } catch {
        return ["", "", ""]
    }
    return names
}

CardRawNeedsConfirmation(raw, contrast) {
    ; A lossy contrast pass is not an opposing signed effect. The selected raw
    ; effect must still agree with a new frame immediately before the click.
    policy := AnalyzeCardEffects(raw)
    if (!policy.known || policy.blocked || Trim(contrast) = "")
        return false
    return !RegExMatch(contrast, "i)[+\-\x{2212}]\s*\d|\d|resist|spellproof")
}
