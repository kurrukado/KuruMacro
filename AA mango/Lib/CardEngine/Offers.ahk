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

SummerQuantumCardOrder() {
    static names := StrSplit("Attack|Boss Damage|Cooldown|Range|Yen|Random Blessings|Mud|Rain Barrel|Washout|Flash Flood|Torrent|Lightning Rod|Conductor|Supercell|Thunderhead|Bonfire|Permafrost|Frostbite|Ice Breaker|Whiteout|Dispel|Leyline|Mana Surge|Arcane Storm|Arcane Ward|Mana Ward|Mana Shield|Salvage|Low Tide|Tidal Surge|Tsunami|Phoenix|Cinders|Scorch|Firebreak|Updraft|Kite Strings|Grounded|Gale|Crosswind|Cyclone|Clear Skies|Wishing Star|Stardust|Starforged|Cosmic Rays|Buried Treasure|Rising Tide|Heatwave|Sand Armor|Dust Devil|Sandblast|Haboob|Explosive Deaths|Enemy Regen|Plated Enemies|Resistant Enemies|Spellproof Enemies|Enemy Shield|Enemy Speed|Enemy Health|Random Curses|Doomsday", "|")
    return names
}

SummerQuantumReadCards(fresh, deadline) {
    static centers := [225, 401, 577]
    cards := [{name:"",text:""}, {name:"",text:""}, {name:"",text:""}]
    names := SummerQuantumCardOrder()
    loop 3 {
        missing := 0
        for index, card in cards {
            if card.name != ""
                continue
            if A_TickCount >= deadline - 1100 || !fresh()
                return cards
            card.text := SummerQuantumReadRegion([centers[index]-72,212,144,32], 3)
            card.name := SummerQuantumMatchName(card.text, names)
            missing += card.name = ""
        }
        if !missing || A_Index = 3 || A_TickCount >= deadline - 1500
            break
        Sleep(400)
    }
    return cards
}

SummerQuantumBestCard(cards) {
    static rank := Map()
    if !rank.Count {
        for index, name in SummerQuantumCardOrder()
            rank[name] := index
    }
    best := 0, bestRank := rank.Count + 2
    for index, card in cards {
        if card.name = "" && StrLen(SummerQuantumClean(card.text)) < 3
            continue
        priority := rank.Get(card.name, rank.Count + 1)
        if priority < bestRank
            best := index, bestRank := priority
    }
    return best
}

SummerQuantumPressCard(pick, fresh, deadline) {
    static centers := [225, 401, 577]
    if !fresh()
        return false
    selected := false
    loop 3 {
        if !fresh()
            return false
        SummerQuantumCardClick(centers[pick], 320)
        checkUntil := Min(deadline, A_TickCount + 1500)
        while A_TickCount < checkUntil && fresh() {
            if SummerQuantumVoteButton() {
                selected := true
                break
            }
            Sleep(150)
        }
        if selected
            break
    }
    if !selected
        return false
    sent := false
    loop 2 {
        if !fresh() || !SummerQuantumVoteButton() || !fresh()
            break
        SummerQuantumCardClick(338, 497)
        sent := true
        checkUntil := Min(deadline, A_TickCount + 1200)
        while A_TickCount < checkUntil && fresh() {
            if !SummerQuantumVoteButton()
                return true
            Sleep(200)
        }
    }
    return sent
}

SummerQuantumVoteButton() {
    text := SummerQuantumClean(SummerQuantumReadRegion([285,482,110,30], 3))
    return text = "vote"
}

SummerQuantumCardClick(x, y) {
    global rblxID
    WinGetClientPos(,, &w, &h, rblxID)
    oldMode := A_CoordModeMouse
    CoordMode "Mouse", "Client"
    try FixClick(Round(x*w/800), Round(y*h/600))
    finally CoordMode "Mouse", oldMode
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

SummerQuantumReadRegion(area, zoom := 3) {
    global rblxID
    try {
        if !WinActive(rblxID)
            return ""
        WinGetClientPos(&cx, &cy, &w, &h, rblxID)
        sx := w/800, sy := h/600
        return OCR.FromRect(cx+Round(area[1]*sx), cy+Round(area[2]*sy)
            , Round(area[3]*sx), Round(area[4]*sy), "en-US", zoom).Text
    }
    return ""
}

SummerQuantumClean(text) => RegExReplace(StrLower(text), "[^a-z0-9]")

SummerQuantumMatchName(text, names) {
    clean := SummerQuantumClean(text)
    best := "", bestLen := 0
    for name in names {
        key := SummerQuantumClean(name)
        if StrLen(key) > bestLen && InStr(clean, key)
            best := name, bestLen := StrLen(key)
    }
    if best != "" || StrLen(clean) < 3
        return best
    bestScore := 0, second := 0
    for name in names {
        key := SummerQuantumClean(name)
        len := StrLen(key)
        if len > StrLen(clean)+2
            continue
        score := 0
        loop Max(1, StrLen(clean)-len+1)
            score := Max(score, 1-SummerQuantumDistance(key, SubStr(clean,A_Index,len))/len)
        if score > bestScore
            best := name, second := bestScore, bestScore := score
        else
            second := Max(second, score)
    }
    return bestScore >= 0.85 && bestScore-second >= 0.1 ? best : ""
}

SummerQuantumDistance(a, b) {
    row := [0]
    loop StrLen(b)
        row.Push(A_Index)
    loop parse a {
        ch := A_LoopField
        prev := row[1]
        row[1] := A_Index
        loop StrLen(b) {
            col := A_Index+1, old := row[col]
            row[col] := Min(row[col-1]+1, old+1, prev+(ch != SubStr(b,A_Index,1)))
            prev := old
        }
    }
    return row[row.Length]
}
