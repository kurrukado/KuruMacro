; White title masks measured from saved Summer Choose/Weather screenshots.
; No OCR is used by this visibility gate.
global CARD_VISUAL_PATTERNS := "|<CardChoose>FFFFFF-303030$130.000000000000000000000001U0000000000000001000A60000000000000000C007yM0000000000000000s00ztU0000000000000003U07U6M3U60s700a061aNVi00Q0TkzVyDkz0Ds1yTtyTs01U1zXyDwk7S1zUDtzbtzU06076QQknUss7C0kCCQCC00Q0MNVn37nz0MM30stUss01s1Vb7AA7i01nUA3Xa3XU03za6DsznCQE7y0zbyM7yNa7yMMzVyDlz0Ds1yTtUTtaM31VUs1UC1s0RU1UNa0N6NU000000000000000000000U|<CardWeather>FFFFFF-303030$170.0000000000000000000100000000000U0000000000U00000F023U0000TyQ0000000008Q000004s1ltU000Dzr00000000077000000C08ys0001ztk000000001lk000003U0CC00001kRU7048Es38zRU71A0sv0bzsQ000Q7y3w3bCTVzTry3wzUTjwRzzDk0071zVzUNnDwzntzVzjk63z7TzX0001kQQss7zr7QQQQQsvU1kstnXUs000Q77Dy0ztzr7777Dys0DiCQss7k0071lny0DSTlllllnyC00PXbC60A001kQQQE3rXWDwSQQQHU1ystnVkz8W0Q773w0MkTVz3b73ws0ziCQsSTrRk20UUS06A3kAUMUUS403V1241VkW8000000000000000000000000000000000000000000000000000000008"

CardVisualVisible(force := false) {
    global rblxID, mode, CARD_VISUAL_PATTERNS
    static lastNegative := 0, lastWindow := 0
    if (mode != "Summer Event" || !WinActive(rblxID))
        return false
    hwnd := WinExist(rblxID)
    if (!force && hwnd = lastWindow && A_TickCount - lastNegative < 200)
        return false
    try {
        WinGetClientPos(&cx, &cy, &cw, &ch, rblxID)
        sx := cw / 800, sy := ch / 599
        visible := !!FindText(&x, &y, cx + Round(260*sx), cy + Round(140*sy)
            , cx + Round(600*sx), cy + Round(185*sy), 0, 0, CARD_VISUAL_PATTERNS, 1, 0, 0, 20, 10, 1, sx, sy)
        if !visible
            lastNegative := A_TickCount, lastWindow := hwnd
        return visible
    }
    return false
}

ColorNear(c1, c2, tol) {
    return Abs(((c1 >> 16) & 0xFF) - ((c2 >> 16) & 0xFF)) <= tol
        && Abs(((c1 >> 8) & 0xFF) - ((c2 >> 8) & 0xFF)) <= tol
        && Abs((c1 & 0xFF) - (c2 & 0xFF)) <= tol
}

CardScreenVisible(force := false) {
    return CardVisualVisible(force)
}

CardSlotOf(x) {
    global CARD_STRIP

    w := CARD_STRIP.x2 - CARD_STRIP.x1
    if (w <= 0)
        return 0

    idx := Floor(x / (w / 3)) + 1
    return (idx >= 1 && idx <= 3) ? idx : 0
}
