#Requires AutoHotkey v2.0

global macroStartTime := A_TickCount
global stageStartTime := A_TickCount
global BossRoomCompleted := false
global SaveChestsForBoss := true

;HotKeys
Hotkey(F1Key, (*) => moveRobloxWindow())
Hotkey(F2Key, (*) => StartMacro())
Hotkey(F3Key, (*) => Reload())
Hotkey(F4Key, (*) => TogglePause())

IsLeaderboardOpen(&closeX := 565, &closeY := 73) {
    if !CapysGetClientBox(&cx, &cy, &cw, &ch, &targetWin) || !WinActive("ahk_id " targetWin)
        return false
    sx := cw / 800, sy := ch / 599
    txt := CapysOcrRect(545, 65, 250, 55, 3, true)
    hasText := RegExMatch(txt, "i)\b(?:people|total|player|cash|damage|yen|kills|wins)\b") > 0

    oldPix := A_CoordModePixel
    CoordMode "Pixel", "Screen"
    try {
        for cand in [[641, 73], [565, 73]] {
            px := cx + Round(cand[1] * sx), py := cy + Round(cand[2] * sy)
            hits := 0, gaps := 0
            for d in [-3, -2, -1, 0, 1, 2, 3] {
                c1 := PixelGetColor(px + d, py + d, "RGB")
                if Min((c1 >> 16) & 255, (c1 >> 8) & 255, c1 & 255) >= 150
                    hits++
                if (d != 0) {
                    c2 := PixelGetColor(px + d, py - d, "RGB")
                    if Min((c2 >> 16) & 255, (c2 >> 8) & 255, c2 & 255) >= 150
                        hits++
                }
            }
            for pt in [[0, -5], [0, 5], [-5, 0], [5, 0]] {
                cg := PixelGetColor(px + pt[1], py + pt[2], "RGB")
                if Min((cg >> 16) & 255, (cg >> 8) & 255, cg & 255) >= 150
                    gaps++
            }
            if (hits >= 8 && gaps <= 1) {
                if hasText {
                    closeX := cand[1], closeY := cand[2]
                    return true
                }
                belowWhite := 0
                loop 6 {
                    rowY := py + Round((10 + (A_Index - 1) * 3) * sy)
                    loop 12 {
                        colX := px + Round(((A_Index - 1) * 5) * sx)
                        cb := PixelGetColor(colX, rowY, "RGB")
                        if Min((cb >> 16) & 255, (cb >> 8) & 255, cb & 255) >= 150
                            belowWhite++
                    }
                }
                if (belowWhite >= 6) {
                    closeX := cand[1], closeY := cand[2]
                    return true
                }
            }
        }
    } finally {
        CoordMode "Pixel", oldPix
    }
    if hasText {
        closeX := 565, closeY := 73
        return true
    }
    return false
}

CloseLeaderboard() {
    loop 2 {
        if !IsLeaderboardOpen(&closeX, &closeY)
            return true
        if !CapysGetClientBox(&cx, &cy, &cw, &ch, &targetWin)
            return false
        if !WinActive("ahk_id " targetWin) {
            try WinActivate("ahk_id " targetWin)
            Sleep(100)
        }
        sx := cw / 800, sy := ch / 599
        oldMouse := A_CoordModeMouse
        CoordMode "Mouse", "Screen"
        try FixClick(cx + Round(closeX * sx), cy + Round(closeY * sy))
        finally CoordMode "Mouse", oldMouse
        Sleep(200)
        if !IsLeaderboardOpen() {
            ProcessLog("Leaderboard closed safely")
            return true
        }
    }
    if IsLeaderboardOpen() {
        SendEvent("{Tab down}")
        Sleep(65)
        SendEvent("{Tab up}")
        Sleep(150)
    }
    return !IsLeaderboardOpen()
}

ClosePlayerLeaderBoard() {
    CoordMode "Pixel", "Client"
    Sleep(300)
    SendInput("{Tab}") ; Closes Player leaderboard
    Sleep(300)
    FixClick(650, 77)
    Sleep(500)

    ; Chat is handled by CloseChat(), which inspects the button before clicking.
    ; Toggling it here as well closed the log and then reopened it.
}

GetDefaultPlacementPoints() {
    return [
        {x: 400, y: 300}, {x: 430, y: 300}, {x: 370, y: 300},
        {x: 400, y: 330}, {x: 400, y: 270}, {x: 430, y: 330},
        {x: 370, y: 330}, {x: 430, y: 270}, {x: 370, y: 270},
        {x: 460, y: 300}, {x: 340, y: 300}, {x: 400, y: 360},
        {x: 400, y: 240}, {x: 460, y: 330}, {x: 340, y: 330},
        {x: 460, y: 270}, {x: 340, y: 270}, {x: 460, y: 360},
        {x: 340, y: 360}, {x: 460, y: 240}, {x: 340, y: 240}
    ]
}

FormatHandledRoute(route) {
    return (route = "replay" || route = "lobby" || route = "reconnected") ? route : "handled"
}

CheckPlacementLimit() {
    if !CapysGetClientBox(&cx, &cy, &cw, &ch, &targetWin) || !WinActive("ahk_id " targetWin)
        return false

    sx := cw / 800, sy := ch / 599
    hdc := DllCall("user32\GetDC", "Ptr", 0, "Ptr")
    if !hdc
        return false
    red := 0
    try {
        loop 24 {
            x := cx + Round((170 + (A_Index - 1) * 20) * sx)
            for baseY in [417, 425, 433, 455, 465, 475] {
                c := DllCall("gdi32\GetPixel", "Ptr", hdc, "Int", x, "Int", cy + Round(baseY * sy), "UInt")
                if (c != 0xFFFFFFFF && (c & 255) > 160 && ((c >> 8) & 255) < 125 && ((c >> 16) & 255) < 125)
                    red++
            }
        }
    } finally {
        DllCall("user32\ReleaseDC", "Ptr", 0, "Ptr", hdc)
    }
    if (red < 3)
        return false

    text := CapysOcrRect(110, 400, 585, 100, 3, true)
    if (text = "")
        return false
    return !!RegExMatch(text, "i)unique\s+units?\s+may\s+not\s+be\s+placed|cannot\s+place\s+more\s+than|can['’]?t\s+place\s+more\s+than|\blimit\b")
}

IsPointNearPlaced(x, y, radius := 24) {
    global successfulCoordinates
    rSq := radius * radius
    for placedCoord in successfulCoordinates {
        dx := placedCoord.x - x, dy := placedCoord.y - y
        if (dx * dx + dy * dy < rSq)
            return true
    }
    return false
}

PlacingUnits() {
    global successfulCoordinates, UnitPlacements, rblxID, mode
    global enabled1, enabled2, enabled3, enabled4, enabled5, enabled6
    global placement1, placement2, placement3, placement4, placement5, placement6

    LoadUnitCoordsFromFile()
    successfulCoordinates := []

    farmSlots := [], otherSlots := []
    requestedTotal := 0
    loop 6 {
        slot := A_Index
        enControl := "enabled" slot
        plcControl := "placement" slot
        count := Integer(%plcControl%.Text)
        if (!%enControl%.Value || count <= 0)
            continue

        requestedTotal += count
        targetPoints := []
        if (IsSet(UnitPlacements) && UnitPlacements.Has(slot) && UnitPlacements[slot].Length > 0) {
            ProcessLog("Unit " slot ": using CUSTOM positions from map (" UnitPlacements[slot].Length " points)")
            for pt in UnitPlacements[slot]
                targetPoints.Push({x: pt[1], y: pt[2]})
        } else {
            ProcessLog("Unit " slot ": using standard distribution points")
            targetPoints := GetDefaultPlacementPoints()
        }
        slots := GetUnitPlacementType(slot) = "Farm" ? farmSlots : otherSlots
        slots.Push({slot: slot, target: count, placed: 0, points: targetPoints, nextIdx: 1, limitHit: false, exhausted: false})
    }

    pendingSlots := farmSlots.Length ? farmSlots : otherSlots
    if !pendingSlots.Length {
        ProcessLog("No Units Selected - Returning")
        return FormatHandledRoute(MonitorStage())
    }

    ProcessLog("Starting placement...")
    placedTotal := 0
    lastAfkTick := A_TickCount
    nextCheckAt := 0

    loop {
        if (A_TickCount >= nextCheckAt) {
            if (CapysResultScreenVisible()) {
                return FormatHandledRoute(HandleStageResult())
            }
            if (IsSet(mode) && mode = "Summer Event")
                ServiceSummerCards()
            Reconnect(&reconnected)
            if reconnected
                return "reconnected"
            nextCheckAt := A_TickCount + 700
        }

        if (A_TickCount - lastAfkTick >= 60000) {
            FixClick(560, 560)
            lastAfkTick := A_TickCount
        }

        placedInPass := 0

        for entry in pendingSlots {
            if (entry.limitHit || entry.exhausted || entry.placed >= entry.target)
                continue

            ptsLen := entry.points.Length
            if !ptsLen {
                entry.exhausted := true
                continue
            }

            attemptsThisPass := 0
            checkedAll := 0
            anyFreeSpot := false

            while (entry.placed < entry.target && !entry.limitHit && checkedAll < ptsLen) {
                idx := Mod(entry.nextIdx - 1 + checkedAll, ptsLen) + 1
                checkedAll++
                pt := entry.points[idx]

                ; Capys 24px minimum hitbox spacing to avoid clicking existing units
                if IsPointNearPlaced(pt.x, pt.y, 24)
                    continue

                anyFreeSpot := true
                abilityDone := false
                result := PlaceUnit(pt.x, pt.y, entry.slot, &abilityDone)
                if (result = "ended") {
                    return FormatHandledRoute(HandleStageResult())
                }
                if (result = "limit") {
                    ProcessLog("Slot " entry.slot ": Placement limit reached (unique/max reached); finishing slot")
                    entry.limitHit := true
                    break
                }
                if (result = true) {
                    entry.placed++
                    placedTotal++
                    placedInPass++
                    successfulCoordinates.Push({x: pt.x, y: pt.y, slot: entry.slot, misses: 0, priorityDone: false, abilityDone: abilityDone})
                    ProcessLog("Placed Unit " entry.slot " (" entry.placed "/" entry.target ") at " pt.x "," pt.y)
                    entry.nextIdx := Mod(idx, ptsLen) + 1
                } else {
                    attemptsThisPass++
                    entry.nextIdx := Mod(idx, ptsLen) + 1
                }

                if (A_TickCount >= nextCheckAt) {
                    if (CapysResultScreenVisible()) {
                        return FormatHandledRoute(HandleStageResult())
                    }
                    if (IsSet(mode) && mode = "Summer Event")
                        ServiceSummerCards()
                    Reconnect(&reconnected)
                    if reconnected
                        return "reconnected"
                    nextCheckAt := A_TickCount + 700
                }

                ; If lacking Yen / terrain failed 2 tries this pass, rotate to next slot instead of stalling
                if (attemptsThisPass >= 2)
                    break
            }

            if (!anyFreeSpot && entry.placed < entry.target && !entry.limitHit) {
                ProcessLog("Slot " entry.slot ": all placement points occupied/within 24px (" entry.placed "/" entry.target ")")
                entry.exhausted := true
            }
        }

        remaining := 0
        for entry in pendingSlots {
            if (!entry.limitHit && !entry.exhausted && entry.placed < entry.target)
                remaining++
        }
        if !remaining {
            if pendingSlots == otherSlots || !otherSlots.Length
                break
            pendingSlots := otherSlots
            continue
        }

        if !placedInPass
            Sleep(500)
    }

    ProcessLog("Placed total: " placedTotal "/" requestedTotal " units")
    return UpgradeUnits()
}

ProcessUpgradeUnitAt(idx, &anyUpgradedInPass, &routeOut) {
    global successfulCoordinates, mode
    routeOut := ""

    if (CapysResultScreenVisible()) {
        successfulCoordinates := []
        routeOut := FormatHandledRoute(HandleStageResult())
        return "stop"
    }
    if (IsSet(mode) && mode = "Summer Event")
        ServiceSummerCards()
    Reconnect(&handled)
    if handled {
        routeOut := "reconnected"
        return "stop"
    }

    coord := successfulCoordinates[idx]
    res := UpgradeSingleUnit(coord.x, coord.y, coord.slot, coord)
    if (res = "ended" || CapysResultScreenVisible()) {
        successfulCoordinates := []
        routeOut := FormatHandledRoute(HandleStageResult())
        return "stop"
    }
    if (res = "max" || res = "limit") {
        ProcessLog("Unit slot " coord.slot " at " coord.x "," coord.y " maxed/reached limit")
        successfulCoordinates.RemoveAt(idx)
        anyUpgradedInPass := true
        return "removed"
    }
    if (res = "no-panel") {
        coord.misses := coord.HasOwnProp("misses") ? coord.misses + 1 : 1
        if (coord.misses >= 5) {
            ProcessLog("Unit slot " coord.slot " at " coord.x "," coord.y " unreachable after 5 panel checks; removing")
            successfulCoordinates.RemoveAt(idx)
            return "removed"
        }
        return "next"
    }
    coord.misses := 0
    if (res = true)
        anyUpgradedInPass := true
    return "next"
}

UpgradeUnits() {
    global successfulCoordinates, PriorityUpgrade, priority1, priority2, priority3, priority4, priority5, priority6
    global rblxID, mode

    if (!successfulCoordinates.Length) {
        ProcessLog("No placed units to upgrade; monitoring stage...")
        return FormatHandledRoute(MonitorStage())
    }

    ProcessLog("Starting batch upgrade...")
    lastAfkTick := A_TickCount

    while (successfulCoordinates.Length) {
        if (CapysResultScreenVisible()) {
            ProcessLog("Stage ended during upgrade cycle; proceeding to results")
            successfulCoordinates := []
            return FormatHandledRoute(HandleStageResult())
        }

        if (IsSet(mode) && mode = "Summer Event")
            ServiceSummerCards()

        Reconnect(&handled)
        if handled
            return "reconnected"

        if (A_TickCount - lastAfkTick >= 60000) {
            FixClick(560, 560)
            lastAfkTick := A_TickCount
        }

        anyUpgradedInPass := false

        if (PriorityUpgrade.Value) {
            for priorityNum in [1, 2, 3, 4, 5, 6] {
                for slot in [1, 2, 3, 4, 5, 6] {
                    prioControl := "priority" slot
                    if (%prioControl%.Text != priorityNum)
                        continue

                    i := 1
                    while (i <= successfulCoordinates.Length) {
                        if (successfulCoordinates[i].slot != slot) {
                            i++
                            continue
                        }
                        stepRes := ProcessUpgradeUnitAt(i, &anyUpgradedInPass, &routeOut)
                        if (stepRes = "stop")
                            return routeOut
                        if (stepRes = "removed")
                            continue
                        i++
                    }
                }
            }
        } else {
            i := 1
            while (i <= successfulCoordinates.Length) {
                stepRes := ProcessUpgradeUnitAt(i, &anyUpgradedInPass, &routeOut)
                if (stepRes = "stop")
                    return routeOut
                if (stepRes = "removed")
                    continue
                i++
            }
        }

        if (!anyUpgradedInPass) {
            Sleep(1000)
        }
    }

    ProcessLog("All units reached MAX or configured Max Level; monitoring stage...")
    return FormatHandledRoute(MonitorStage())
}

UpgradeSingleUnit(x, y, slot, coord := 0) {
    global rblxID, AutoAbilityBox, mode
    if !WinActive(rblxID) || !UnitActionAllowed()
        return false

    oldMouseMode := A_CoordModeMouse
    CoordMode "Mouse", "Client"
    try {
        if IsUnitPanelOpenFast() {
            SendEvent("q")
            Sleep(40)
            CloseUnitPanel()
        }

        FixClick(x, y)

        panelOpened := false
        loop 4 {
            Sleep(70)
            if IsUnitPanelOpenFast() {
                panelOpened := true
                break
            }
        }
        if !panelOpened {
            if (IsSet(mode) && InStr(mode, "Misty") && DismissDefensePanel())
                return "no-panel"
            if !FindSmartPlacementPanel()
                return "no-panel"
        } else if (IsSet(mode) && InStr(mode, "Misty") && DismissDefensePanel()) {
            return "no-panel"
        }

        ; Run Auto Ability ONCE per unit
        if !IsObject(coord) || !coord.HasOwnProp("abilityDone") || !coord.abilityDone {
            if AutoAbilityBox.Value
                CheckAbility()
            if IsObject(coord)
                coord.abilityDone := true
        }

        limit := GetUnitUpgradeLimit(slot)
        isMaxLimit := (limit = "MAX" || limit = "" || limit = "0" || limit = "OFF")
        targetLevel := isMaxLimit ? 999 : Integer(limit)

        curLvl := -1
        if MaxUpgrade(&curLvl, true) {
            CloseUnitPanel()
            return "max"
        }
        if (!isMaxLimit && curLvl >= 0 && curLvl >= targetLevel) {
            CloseUnitPanel()
            return "limit"
        }

        ; Capys Batch Upgrade: keep panel open and press R up to 8 times per pass
        prevLvl := curLvl
        upgradedCount := 0
        staleCount := 0
        pressIdx := 0
        maxBatch := isMaxLimit ? 8 : Max(1, Min(8, targetLevel - Max(0, curLvl)))

        while (pressIdx < maxBatch) {
            if (!IsUnitPanelOpenFast() && !FindSmartPlacementPanel())
                break

            SendEvent("{r down}")
            Sleep(60)
            SendEvent("{r up}")
            Sleep(350)
            pressIdx++

            if (CapysResultScreenVisible()) {
                CloseUnitPanel()
                return "ended"
            }
            if (IsSet(mode) && mode = "Summer Event")
                ServiceSummerCards()

            ; Check level every press for numeric targets, or at 1, 2, 4, 6, 8 for MAX
            if (!isMaxLimit || pressIdx = 1 || Mod(pressIdx, 2) = 0 || pressIdx = maxBatch) {
                afterLvl := -1
                if MaxUpgrade(&afterLvl, true) {
                    CloseUnitPanel()
                    return "max"
                }
                if (!isMaxLimit && afterLvl >= 0 && afterLvl >= targetLevel) {
                    CloseUnitPanel()
                    return "limit"
                }

                if ((prevLvl >= 0 && afterLvl > prevLvl) || (prevLvl < 0 && afterLvl > 0)) {
                    upgradedCount++
                    prevLvl := afterLvl
                    staleCount := 0
                } else {
                    staleCount += (!isMaxLimit || pressIdx = 1) ? 1 : 2
                    if (staleCount >= 2)
                        break ; Insufficient Yen for next level -> yield early
                }
            }
        }

        CloseUnitPanel()
        return upgradedCount > 0
    } finally {
        CoordMode "Mouse", oldMouseMode
    }
}

IsModeCancelOpen(&outX := 0, &outY := 0) {
    global ModeCancel, Greenie, mode
    if (mode = "Infinite" || mode = "Story" || mode = "Legend")
        return IsObject(WorldSelectorState())

    ; 1. Nhan dien qua anh Greenie_RGB.png cua Select World bang ImageSearch
    greenieImg := A_ScriptDir "\GameModeImages\Greenie_RGB.png"
    if FileExist(greenieImg) {
        CoordMode "Pixel", "Client"
        try {
            if ImageSearch(&px, &py, 0, 0, 800, 599, "*60 " greenieImg) {
                outX := px
                outY := py
                return true
            }
        }
    }

    ; 2. FindText voi dung sai 25% va vung tim kiem rong hon cho man 2K
    if (ok := (PixelSearch(&rx, &ry, 250, 550, 310, 595, 0xDC2626, 50) || FindText(&outX, &outY, 240, 480, 530, 620, 0.25, 0.25, ModeCancel)))
        return true

    ; Do not infer the map dialog from a single red pixel. Popups and game
    ; effects can contain the same color and send the macro into map selection
    ; while the player is still in the lobby.
    return false
}

; Walk a fixed lobby route until the map-selection dialog appears.
; Story mode always had this guard; every other mode looped forever when
; the route failed, which in the log looks like the macro silently hanging.
; Summer Event adapter (not tested end-to-end). UI input uses the same
; FixClick and Event movement as the existing macro. CAPTCHA in Function.ahk.
global SummerAwaitingMatch := false
global SummerMapName := ""
global SummerMapInterrupted := false

; try captcha
SummerReadUI(top := 0, height := 599) {
    global rblxID
    if (!WinExist(rblxID) && !WinExist("Roblox"))
        return ""
    try {
        targetWin := WinExist(rblxID) ? rblxID : "Roblox"
        WinGetClientPos(&cx, &cy, &cw, &ch, targetWin)
        if (cw <= 0 || ch <= 0)
            return ""
        return OCR.FromRect(cx, cy + top, cw, Min(height, ch - top), "en-US", 2).Text
    } catch {
        return ""
    }
}

SummerClick(x, y) {
    FixClick(x, y)
}

MapWalk(key, ms) {
    global rblxID
    if (tw := RefreshClientTarget()) && !WinActive("ahk_id " tw) {
        try WinActivate("ahk_id " tw)
        Sleep(100)
    }
    if !RegExMatch(key,"^[wasd]{1,2}$") || (StrLen(key)=2 && (SubStr(key,1,1)=SubStr(key,2,1)
        || (InStr(key,"w") && InStr(key,"s")) || (InStr(key,"a") && InStr(key,"d"))))
        || ms<20 || ms>10000 || !MapMovementReady()
        return false
    WinGetClientPos(&cx,&cy,&cw,&ch,rblxID)
    oldDelay:=A_KeyDelay, oldDuration:=A_KeyDuration
    SetKeyDelay(-1,-1)
    deadline:=A_TickCount+ms, nextScene:=A_TickCount+500
    release := (*) => SendEvent("{w up}{a up}{s up}{d up}")
    OnExit(release)
    try {
        down:=""
        loop parse key
            down.="{" A_LoopField " down}"
        SendEvent(down)
        SetTimer(release,-ms)
        while A_TickCount<deadline {
            if !WinActive(rblxID) || SmartPreviewInterrupted()
                return false
            WinGetClientPos(&nx,&ny,&nw,&nh,rblxID)
            if nx!=cx || ny!=cy || nw!=cw || nh!=ch
                return false
            if A_TickCount>=nextScene && deadline-A_TickCount>500 {
                if !MapMovementReady()
                    return false
                nextScene:=A_TickCount+500
            }
            Sleep(Min(20,Max(1,deadline-A_TickCount)))
        }
        return true
    } finally {
        SetTimer(release,0)
        try release()
        finally {
            OnExit(release,0)
            SetKeyDelay(oldDelay,oldDuration)
        }
    }
}

MapMovementReady() {
    global rblxID
    if !WinActive(rblxID) {
        ProcessLog("Map movement stopped: Roblox focus unavailable")
        return false
    }
    if SmartPreviewInterrupted(true) {
        ProcessLog("Map movement stopped: card/input interruption")
        return false
    }
    if CapysResultScreenVisible() || FindText(&x, &y, 330, 218, 474, 247, 0, 0, Disconnect) {
        ProcessLog("Map movement stopped: end screen or disconnect")
        return false
    }
    return true
}

; Compatibility for external callers. Map routes themselves use generic helpers.
SummerWalk(key, ms) => MapWalk(key, ms)
SummerMovementReady() => MapMovementReady()

SummerVerificationVisible() {
    global rblxID
    if (!WinExist(rblxID) && !WinExist("Roblox"))
        return false
    try {
        targetWin := WinExist(rblxID) ? rblxID : "Roblox"
        WinGetClientPos(&cx, &cy,,, targetWin)
        ; Only the title/instruction strip, excluding the challenge and entry field.
        prompt := OCR.FromRect(cx + 200, cy + 175, 400, 70, "en-US", 2).Text
        return !!RegExMatch(prompt, "i)captcha|please enter this text")
    } catch {
        return false
    }
}

SummerApproachQueue() {
    ; Đè W mượt mà cho tới khi bảng Join Matchmaking mở ra (tối đa 5s)
    SendInput("{w down}")
    deadline := A_TickCount + 5000
    while (A_TickCount < deadline) {
        if RegExMatch(SummerReadUI(), "i)join\s+matchmaking")
            break
        Sleep(100)
    }
    SendInput("{w up}")
    Sleep(200)
    return !!RegExMatch(SummerReadUI(), "i)join\s+matchmaking")
}

SummerWaitForVerification(timeoutMs := 180000) {
    if !SummerVerificationVisible()
        return true
    ProcessLog("Summer Event: waiting for manual verification; resuming when the dialog closes")
    deadline := A_TickCount + timeoutMs
    while SummerVerificationVisible() {
        if (A_TickCount >= deadline) {
            ProcessLog("Summer Event: verification wait timed out; no code entered or submitted")
            return false
        }
        Sleep(500)
    }
    return true
}

SummerHandleVerification(targetWin, autoRead) {
    win := "ahk_id " targetWin
    if !WinActive(win)
        return false
    if autoRead {
        CaptchaDetect(232, 290, 581, 350, 400, 340, true)
        Sleep(300)
    }
    return SummerWaitForVerification()
}

; Quantum card OCR, selection and voting.
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

SummerEventMode() {
    global rblxID, MatchMaking, SummerAwaitingMatch, SummerMapName, mode
    mode := "Summer Event"
    ProcessLog("Starting Summer Event Mode...")

    targetWin := WinExist(rblxID)
    if !targetWin
        targetWin := WinExist("Roblox")
    if !targetWin {
        ProcessLog("Summer Event: Roblox window not found!")
        return false
    }
    WinActivate("ahk_id " targetWin)
    Sleep(200)

    ; 1. Mở menu Play: FixClick(86, 300), Sleep 1500
    FixClick(86, 300)
    Sleep(1500)

    ; 2. Chọn thẻ Summer Event: FixClick(270, 324), Sleep 1500
    FixClick(270, 324)
    Sleep(1500)

    ; 3. Di chuyển sảnh đến hàng chờ: MapWalk("w", 3050), MapWalk("wa", 1216), Sleep 1000
    MapWalk("w", 3050)
    MapWalk("wa", 1216)
    Sleep(1000)

    ; 4. Nếu có hộp xác minh CAPTCHA, gọi CaptchaDetect (bảo toàn điểm gọi thứ 2 cho invariants)
    if SummerVerificationVisible() {
        SummerAwaitingMatch := true
        if !SummerHandleVerification(targetWin, true)
            return false
    } else if SummerVerificationVisible() && CaptchaDetect(232, 290, 581, 350, 400, 340, true) {
        Sleep(300)
    }

    ; 5. Ghép đội / Chơi: if (MatchMaking.Value) FindMatch() else PlayHere()
    if (MatchMaking.Value) {
        if (!FindMatch())
            return false
    } else {
        PlayHere()
    }

    ; 6. Vào trận
    SummerAwaitingMatch := false
    SummerMapName := "Summer Event"
    ProcessLog("Summer Event: waiting for the match to load...")
    return RestartStage("Summer Event")
}

MistyVillageMode() {
    global rblxID, MatchMaking, mode
    mode := "Misty Village"
    ProcessLog("Starting Misty Village Mode...")

    targetWin := WinExist(rblxID)
    if !targetWin
        targetWin := WinExist("Roblox")
    if !targetWin {
        ProcessLog("Misty Village: Roblox window not found!")
        return false
    }
    WinActivate("ahk_id " targetWin)
    Sleep(200)

    ; 1. Mở menu Play: FixClick(86, 300), Sleep 1500
    FixClick(86, 300)
    Sleep(1500)

    ; 2. Chọn thẻ Misty Village: FixClick(400, 324), Sleep 1500
    FixClick(400, 324)
    Sleep(1500)

    ; 3. Di chuyển sảnh đến cổng Misty: MapWalk("sd", 2530), Sleep 1000
    MapWalk("sd", 2530)
    Sleep(1000)

    ; 4. Mở bảng chọn Stage: mặc định Day (335, 324)
    FixClick(335, 324)
    Sleep(1000)

    ; 5. Vào trận: nếu MatchMaking.Value thì gọi FindMatch(), không thì PlayHere()
    if (MatchMaking.Value) {
        if (!FindMatch())
            return false
    } else {
        PlayHere()
    }

    return RestartStage("Misty Village")
}

MistyInfiniteMode() {
    global rblxID, MatchMaking, mode
    mode := "Misty Infinite"
    ProcessLog("Starting Misty Infinite Mode (Event Tower)...")

    targetWin := WinExist(rblxID)
    if !targetWin
        targetWin := WinExist("ahk_exe RobloxPlayerBeta.exe")
    if !targetWin
        targetWin := WinExist("Roblox")
    if !targetWin {
        ProcessLog("Misty Infinite: Roblox window not found!")
        return false
    }
    WinActivate("ahk_id " targetWin)
    Sleep(200)

    ; 1. Mở menu Play: FixClick(86, 300), Sleep 1500
    ProcessLog("Misty Infinite: opening Play menu...")
    FixClick(86, 300)
    Sleep(1500)

    ; 2. Chọn thẻ Misty Village: FixClick(400, 324), Sleep 1500
    ProcessLog("Misty Infinite: selecting Misty Village card...")
    FixClick(400, 324)
    Sleep(1500)

    ; 3. Di chuyển sảnh đến NPC Flutter: W 1.5s -> D 0.5s -> W 1s
    ProcessLog("Misty Infinite: walking to Flutter NPC (W 1.5s -> D 0.5s -> W 1s)")
    MapWalk("w", 1500)
    Sleep(150)
    MapWalk("d", 500)
    Sleep(150)
    MapWalk("w", 1000)
    Sleep(500)

    ; 4. Bấm phím E để tương tác với NPC Flutter
    ProcessLog("Misty Infinite: pressing E to interact with Flutter NPC...")
    Send("{e}")
    Sleep(600)

    ; Bấm vào chính giữa ô hội thoại (400, 410) để đoạn hội thoại load ra nhanh (bỏ qua animation gõ chữ)
    ProcessLog("Misty Infinite: clicking center of dialogue box (400, 410) to load dialogue instantly...")
    FixClick(400, 410)
    Sleep(800)

    ; 5. Bấm [View Event Tower] trên hộp thoại Flutter: toạ độ (278, 480)
    ProcessLog("Misty Infinite: clicking [View Event Tower] (278, 480)")
    FixClick(278, 480)
    Sleep(1500)

    ; 6. Bấm Start trên giao diện Event Tower: toạ độ (400, 438)
    ProcessLog("Misty Infinite: clicking Start (400, 438)")
    FixClick(400, 438)
    Sleep(1000)

    ; 7. Xử lý vào trận: MatchMaking -> FindMatch() hoặc Solo (Play Here -> Open -> Start)
    if (MatchMaking.Value) {
        if (!FindMatch())
            return false
    } else {
        FixClick(335, 326)
        Sleep(600)
        FixClick(253, 353)
        Sleep(600)
        FixClick(400, 465)
        Sleep(1000)
    }

    return RestartStage("Misty Village")
}

ArtifactsMode() {
    global rblxID, MatchMaking
    targetWin := WinExist(rblxID)
    if !targetWin
        targetWin := WinExist("ahk_exe RobloxPlayerBeta.exe")
    if !targetWin
        targetWin := WinExist("Roblox")
    if !targetWin {
        ProcessLog("Artifacts: Roblox window not found!")
        return false
    }
    WinActivate("ahk_id " targetWin)
    Sleep(200)

    ProcessLog("Artifacts mode: moving to portal (S4851ms -> A4346ms -> W268ms)")
    MapWalk("s", 4851)
    Sleep(150)
    MapWalk("a", 4346)
    Sleep(150)
    MapWalk("w", 268)
    Sleep(500)

    ; Interact with Artifacts portal
    SendEvent("{e}")
    Sleep(1000)

    ; Stage select / Start match
    FixClick(400, 324)
    Sleep(800)

    if (MatchMaking.Value) {
        if (!FindMatch())
            return false
    } else {
        PlayHere()
    }

    return RestartStage("Artifacts")
}

CursedWombMode() {
    global rblxID, MatchMaking
    targetWin := WinExist(rblxID)
    if !targetWin
        targetWin := WinExist("ahk_exe RobloxPlayerBeta.exe")
    if !targetWin
        targetWin := WinExist("Roblox")
    if !targetWin {
        ProcessLog("Cursed Womb: Roblox window not found!")
        return false
    }
    ProcessLog("Cursed Womb: Đang kích hoạt Roblox...")
    WinActivate("ahk_id " targetWin)
    Sleep(200)

    ProcessLog("Cursed Womb: Chọn Cursed Womb Key tại (219, 289)...")
    FixClick(219, 289)
    Sleep(800)

    ProcessLog("Cursed Womb: Bấm nút Select tại (333, 349)...")
    FixClick(333, 349)
    Sleep(800)

    if (MatchMaking.Value) {
        ProcessLog("Cursed Womb: Đang tìm trận (Matchmaking)...")
        if (!FindMatch())
            return false
    } else {
        ProcessLog("Cursed Womb: Chọn chơi đơn (Play Here)...")
        PlayHere()
    }

    ProcessLog("Cursed Womb: Vào trận, khởi động stage...")
    return RestartStage("Cursed Womb")
}

DismissVillageShopPopup() {
    if !CapysGetClientBox(&cx, &cy, &cw, &ch, &targetWin) || !WinActive("ahk_id " targetWin)
        return false

    sx := cw / 800, sy := ch / 599
    oldPixelMode := A_CoordModePixel
    oldMouseMode := A_CoordModeMouse
    CoordMode "Pixel", "Screen"
    CoordMode "Mouse", "Screen"
    try {
        ; 1. Check for "LEAVE THE SHOP?" prompt: green Leave (x 270..380) + red Stay (x 430..530) with OCR confirmation
        y := 240
        while (y <= 470) {
            rowMatch := true
            for pt in [[270, 1], [310, 1], [360, 1], [440, 0], [500, 0]] {
                rgb := PixelGetColor(cx + Round(pt[1] * sx), cy + Round(y * sy), "RGB")
                r := (rgb >> 16) & 0xFF, g := (rgb >> 8) & 0xFF, b := rgb & 0xFF
                if !(pt[2] ? (g > 130 && r < 130 && b < 80) : (r > 150 && g < 70 && b < 70)) {
                    rowMatch := false
                    break
                }
            }
            if rowMatch {
                words := StrLower(RegExReplace(CapysOcrRect(235, Max(0, y - 110), 330, 92, 2, true), "[^A-Za-z]", ""))
                if InStr(words, "shop") && (InStr(words, "leave") || InStr(words, "offers") || InStr(words, "village")) {
                    ProcessLog("Village Shop: OCR-verified Leave button at y=" y)
                    FixClick(cx + Round(321 * sx), cy + Round(y * sy))
                    Sleep(500)
                    return true
                }
            }
            y += 6
        }

        ; 2. Check for Village Shop close X around (582, 211) with OCR header confirmation
        cX := PixelGetColor(cx + Round(582 * sx), cy + Round(211 * sy), "RGB")
        rx := (cX >> 16) & 0xFF, gx := (cX >> 8) & 0xFF, bx := cX & 0xFF
        if (rx > 170 && gx < 100 && bx < 100) {
            headerWords := StrLower(RegExReplace(CapysOcrRect(195, 175, 340, 55, 2, true), "[^A-Za-z]", ""))
            if InStr(headerWords, "villageshop") || (InStr(headerWords, "village") && InStr(headerWords, "shop")) || InStr(headerWords, "ore") {
                ProcessLog("Village Shop: OCR-verified popup; clicking close X button")
                FixClick(cx + Round(582 * sx), cy + Round(211 * sy))
                Sleep(500)
                return true
            }
        }
    } finally {
        CoordMode "Pixel", oldPixelMode
        CoordMode "Mouse", oldMouseMode
    }
    return false
}

ParseSummerTitleName(text, nameOnlyHeader := false) {
    text := Trim(RegExReplace(text, "\s+", " "))
    if RegExMatch(text, "i)summer\s+event|forecast|weather|matchmaking|please\s+enter|captcha")
        return ""
    known := ParseSummerMapName(text)
    if (known != "")
        return known
    ; Unknown maps need an explicit in-match Summer suffix, not a board name.
    base:=Trim(RegExReplace(text,"i)(?:\s*(?:\(\s*summer\s*\)|\[\s*summer\s*\])|\s+summer\s+hunt)+$",""))
    if base!=text && RegExMatch(base,"^[A-Za-z][A-Za-z0-9 '\-]{1,55}$")
        return base
    if RegExMatch(text, "i)^([a-z][a-z0-9 '\-]{1,55}?)\s+summer\s+hunt$", &hunt)
        return Trim(hunt[1])
    if RegExMatch(text, "i)^([a-z][a-z0-9 '\-]{1,55}?)\s*[\[(]\s*summer\s*[\])]$", &title)
        return Trim(title[1])
    if nameOnlyHeader && RegExMatch(text,"^[A-Za-z][A-Za-z0-9 '\-]{1,55}$")
        return text
    return ""
}

AppendSummerMapPattern(name, pattern, path := "") {
    global SummerMapPatterns
    if !RegExMatch(name, "^[A-Za-z][A-Za-z0-9 '\-]{1,55}$")
        throw ValueError("Invalid Summer map name")
    if !RegExMatch(pattern, "^\|<>\*\d{1,3}\$\d{1,3}\.[0-9A-Za-z+/]+$") || !IsObject(FindText().PicInfo(pattern))
        throw ValueError("Invalid binary Summer pattern")
    if (path = "")
        path := A_ScriptDir "\Lib\Image.ahk"
    if SummerMapPatterns.Has(name)
        return false
    assignment := 'SummerMapPatterns["' name '"] :='
    ; Check disk as well: no overwrite if another run already appended it.
    if InStr(FileRead(path, "UTF-8"), assignment)
        return false
    FileAppend("`r`n; Summer title captured " FormatTime(, "yyyy-MM-dd HH:mm:ss")
        . " (not tested movement)`r`n" assignment ' "' pattern '"' "`r`n", path, "UTF-8-RAW")
    SummerMapPatterns[name] := pattern
    return true
}

CaptureSummerMapTitle() {
    global rblxID, SummerMapPatterns
    if !WinActive(rblxID) || SummerVerificationVisible()
        return ""
    text := SummerReadUI()
    if RegExMatch(text, "i)forecast|join\s+matchmaking|travelling\s+merchant")
        || !RegExMatch(text, "i)vote\s+start|level\s+modifiers|enemies\s+remaining")
        return ""
    WinGetClientPos(&cx, &cy,,, rblxID)
    result := OCR.FromRect(cx, cy + 40, 800, 170, "en-US", 2)
    for line in result.Lines {
        name := ParseSummerTitleName(line.Text)
        if (name = "")
            continue
        if SummerMapPatterns.Has(name)
            return name
        ; Re-read the same title rectangle before storing screen pixels.
        x := Max(0, Floor(line.x) - 3), y := Max(40, 40 + Floor(line.y) - 3)
        w := Min(800 - x, Ceil(line.w) + 6), h := Min(210 - y, Ceil(line.h) + 6)
        if (w < 20 || h < 8 || w > 600 || h > 70)
            continue
        Sleep(350)
        if !WinActive(rblxID) || SummerVerificationVisible()
            return ""
        fresh := OCR.FromRect(cx + x, cy + y, w, h, "en-US", 2).Text
        if (ParseSummerTitleName(fresh) != name)
            continue
        pattern := FindText().GetTextFromScreen(cx + x, cy + y, cx + x + w - 1, cy + y + h - 1, "*", 1)
        if (pattern = "" || !FindText(&px, &py, cx + x, cy + y, cx + x + w - 1, cy + y + h - 1, 0, 0, pattern))
            return ""
        if AppendSummerMapPattern(name, pattern)
            ProcessLog("Summer Event: added FindText title " name " to Image.ahk; existing patterns preserved")
        return name
    }
    return ""
}

ParseSummerMapName(text) {
    ; Board/forecast in the hub must not be mistaken for a loading title.
    if RegExMatch(text, "i)summer\s+event|forecast|travelling\s+merchant")
        return ""
    text:=Trim(RegExReplace(text,"\s+"," "))
    text:=Trim(RegExReplace(text,"i)(?:\s*(?:\(\s*summer\s*\)|\[\s*summer\s*\])|\s+summer\s+hunt)+$",""))
    aliases := Map("Planet Greenie", "planet\s+greenie", "Snowy Town", "snowy\s+town"
        , "Ant Kingdom", "ant(?:\s+kingdom|'kihgdom)", "Magic Town", "magic\s+town"
        , "Magic Hill", "magic\s+hills?", "Navy Bay", "navy\s+bay"
        , "Fiend City", "fiend\s+city", "Spirit World", "spirit\s+world"
        , "Haunted Academy", "haunted\s+academy", "Space Center", "space\s+center"
        , "Mountain Temple", "mountain\s+temple", "Cursed Festival", "cursed\s+festival"
        , "Nightmare Train", "nightmare\s+train", "Air Craft", "air\s*craft"
        , "Hellish City", "hellish(?:\s+city)?", "Shibuya District", "shibuya(?:\s+district)?"
        , "Sacred Planet", "sacred\s+planet", "Snowy Kingdom", "snowy\s+kingdom"
        , "Dungeon Throne", "dungeon\s+throne", "Rain Village", "rain\s+village")
    found := ""
    for name, pattern in aliases {
        if RegExMatch(text, "i)^" pattern "$") {
            if (found != "")
                return ""
            found := name
        }
    }
    return found
}

SummerFindMapImage(assetRoot := A_ScriptDir "\GameModeImages\SummerTitles") {
    global rblxID
    ; RGB title glyphs, not FindText binary/OCR. Tolerance0 passed stored
    ; independent frames and all cross-map negatives; increase only with evidence.
    static titles := Map("Dungeon Throne", ["DungeonThrone",139,17]
        , "Mountain Temple", ["MountainTemple",143,17], "Rain Village", ["RainVillage",98,17]
        , "Sacred Planet", ["SacredPlanet",115,13], "Ant Kingdom", ["AntKingdom",106,17]
        , "Nightmare Train", ["NightmareTrain",134,17]
        , "Nightmare Train large", ["NightmareTrainLarge",319,41,"Nightmare Train"])
    if !WinActive(rblxID)
        return ""
    oldMode := A_CoordModePixel, found := ""
    CoordMode "Pixel", "Screen"
    try {
        WinGetClientPos(&cx,&cy,&cw,&ch,rblxID)
        left:=cx+Round(cw*140/800), right:=cx+Round(cw*660/800)-1
        ; Roblox changes font/layout with viewport aspect ratio, not a linear
        ; cw/800 scale. Search the top band using measured native-size variants.
        top:=cy, bottom:=cy+Min(ch-1,Max(70,Round(ch*0.15)))
        for name, spec in titles {
            name:=spec.Length=4 ? spec[4] : name
            path:=assetRoot "\" spec[1] ".png"
            if !FileExist(path)
                continue
            w:=spec[2], h:=spec[3]
            if !ImageSearch(&x,&y,left,top,right,bottom,"*TransBlack *0 *w" w " *h" h " " path)
                continue
            ; Reject a name that is only a prefix/suffix of a longer green title.
            if (x>left && PixelSearch(&px,&py,left,y,x-1,y+h-1,0x00FF95,35))
                || (x+w<=right && PixelSearch(&px,&py,x+w,y,right,y+h-1,0x00FF95,35))
                continue
            if found!="" && found!=name
                return "" ; ambiguous evidence must not grant movement
            found:=name
        }
        return WinActive(rblxID) ? found : ""
    } catch {
        return "" ; missing/unreadable assets or geometry -> existing OCR fallback
    } finally {
        CoordMode "Pixel", oldMode
    }
}

SummerReadMapHeader() {
    global rblxID
    if !WinActive(rblxID)
        return ""
    try {
        WinGetClientPos(&cx,&cy,&cw,&ch,rblxID)
        ; Measured health-bar title at800x599; scale from actual client geometry.
        ; Map name is green; yellow Act/mode labels are excluded before OCR.
        return ReadHighContrastText(cx+Round(cw*140/800),cy+Round(ch*30/599),Round(cw*520/800),Round(ch*30/599),3,0,true)
    }
    return ""
}

DetectSummerMap(timeoutMs := 65000) {
    global rblxID, SummerMapInterrupted
    SummerMapInterrupted:=false
    deadline := A_TickCount + timeoutMs, previous := "", waitingLogged := false
    while (A_TickCount < deadline) {
        if !WinActive(rblxID) || SmartPreviewInterrupted(true) {
            SummerMapInterrupted:=true
            return ""
        }
        scene := SummerReadUI()
        if CapysResultScreenVisible() || RegExMatch(scene,"i)\bdefeat\b|\bvictory\b|xp\s+progress|waiting\s+for\s+players|disconnected|choose\s+a\s+card|return\s+to\s+lobby") {
            SummerMapInterrupted:=true
            return ""
        }
        found := scene!="" ? SummerFindMapImage() : "", source := "ImageSearch"
        if found="" && scene!="" {
            found:=ParseSummerTitleName(SummerReadMapHeader(),true), source:="OCR fallback"
        }
        if found="" && scene!="" {
            ; A fresh loading caption can precede the health-bar title.
            for line in StrSplit(SummerReadUI(40,170),"`n") {
                found := ParseSummerTitleName(line)
                if found!=""
                    break
            }
        }
        if found!="" && found=previous {
            if !WinActive(rblxID) || SmartPreviewInterrupted(true) {
                SummerMapInterrupted:=true
                return ""
            }
            ProcessLog("Summer Event: current map confirmed (" source "): " found)
            return found
        }
        previous := found
        if !waitingLogged {
            ProcessLog("Summer Event: waiting for a fresh map title")
            waitingLogged := true
        }
        Sleep(150)
    }
    ProcessLog("Summer Event: map title unreadable; returning without a title")
    return ""
}

SummerGreeniePlacementProbe() {
    if !PlaceUnit(470, 370, 1)
        throw Error("Summer placement probe: unit placement not confirmed")
    ProcessLog("Summer placement probe: confirmed slot 1 at 470,370")
}

SummerResetSpawn() {
    global rblxID
    WinActivate(rblxID)
    if !WinWaitActive(rblxID,, 2)
        throw Error("Roblox is not focused; spawn reset skipped")
    Sleep(150)
    text := SummerReadUI()
    if RegExMatch(text, "i)defeat|victory|xp\s+progress")
        throw Error("Summer spawn: an active match is required; result screen detected")
    if RegExMatch(text, "i)people\s+total") {
        SummerClick(565, 74)
        Sleep(200)
    }
    if !RegExMatch(SummerReadUI(), "i)teleport\s+back\s+to\s+spawn") {
        SummerClick(26, 573)
        Sleep(400)
    }
    WinGetClientPos(&cx, &cy,,, rblxID)
    result := OCR.FromRect(cx + 215, cy + 190, 360, 230, "en-US", 2)
    row := 0
    for line in result.Lines {
        if RegExMatch(line.Text, "i)teleport\s+back\s+to\s+spawn") {
            row := 190 + line.y + line.h // 2
            break
        }
    }
    if !row
        throw Error("Summer spawn: teleport row not confirmed")
    SummerClick(524, row)
    Sleep(500)
    SummerClick(582, 147)
    Sleep(300)
    if RegExMatch(SummerReadUI(), "i)teleport\s+back\s+to\s+spawn")
        throw Error("Summer spawn: Settings is still open")
}

MoveForSummerCourtyard() {
    try {
        SummerResetSpawn()
    } catch as err {
        ProcessLog("Summer courtyard spawn reset skipped: " err.Message)
        return false
    }
    PlacementCamera()
    if !MapWalk("a", 1200)
        return false
    Sleep(250)
    ProcessLog("Summer courtyard movement: spawn -> camera -> a 1200ms; beside enemy path")
    return true
}

SummerGameplayProbe() {
    global mode, SummerMapName, ModeDropdown, rblxID
    WinActivate(rblxID)
    WinWaitActive(rblxID,, 2)
    mode := "Summer Event"
    SummerMapName := "Cursed Festival"
    ModeDropdown.Text := "Summer Event"
    deadline := A_TickCount + 15000
    while RegExMatch(SummerReadUI(), "i)defeat|victory|waiting\s+for\s+players") {
        if (A_TickCount >= deadline)
            throw Error("Summer gameplay test: replay has not started")
        Sleep(300)
    }
    while !RegExMatch(SummerReadUI(), "i)vote\s+start|level\s+modifiers|enemies\s+remaining") {
        if (A_TickCount >= deadline)
            throw Error("Summer gameplay test: match UI has not loaded")
        Sleep(300)
    }
    MoveForSummerCourtyard()
    SummerClick(355, 104)
    Sleep(2500)
    PlacingUnits()
}

global MansionMapName := ""

InfinityMansionMode() {
    if !InfinityMansionEnter()
        return false
    return RestartStage("Infinity Mansion")
}

InfinityMansionEnter() {
    global mode, MatchMaking, MansionMapName
    mode := "Infinity Mansion"
    MatchMaking.Value := 0
    MansionMapName := ""
    if !InfinityMansionMovement()
        return false
    if !InfinityMansionClick("Start")
        return false
    if !InfinityMansionClick("Play Here")
        return false
    if !InfinityMansionConfirmPortal()
        return false
    if !InfinityMansionStartQueue()
        return false
    ProcessLog("Infinity Mansion: selected Play Here")
    return true
}

InfinityMansionMovement() {
    global rblxID
    if !WinExist(rblxID)
        return false
    WinActivate(rblxID)
    if !WinWaitActive(rblxID,,2)
        return false
    if InfinityMansionPanelOpen()
        return true
    if !InfinityMansionClick("Areas") || !InfinityMansionClick("Infinity Mansion")
        return false
    ; Wait for the Areas overlay to disappear after the teleport selection.
    deadline := A_TickCount + 8000
    while WinActive(rblxID) && A_TickCount < deadline {
        WinGetClientPos(&cx,&cy,&cw,&ch,rblxID)
        text := OCR.FromRect(cx,cy,cw,ch,"en-US",2).Text
        if !RegExMatch(text,"i)areas\s*\(click\s+to\s+teleport") {
            ProcessLog("Infinity Mansion route: A3259ms -> W577ms")
            if !MapWalk("a", 3259)
                return false
            Sleep(200)
            if !MapWalk("w", 577)
                return false
            Sleep(500)
            if InfinityMansionPanelOpen() {
                ProcessLog("Infinity Mansion route complete; room panel confirmed")
                return true
            }
            ProcessLog("Infinity Mansion route ended without the room panel; stopping")
            return false
        }
        Sleep(150)
    }
    ProcessLog("Infinity Mansion: teleport not confirmed; movement stopped")
    return false
}

InfinityMansionPanelOpen() {
    global rblxID
    if !WinActive(rblxID)
        return false
    try {
        WinGetClientPos(&cx,&cy,&cw,&ch,rblxID)
        text := OCR.FromRect(cx+Round(cw*.25),cy+Round(ch*.12),Round(cw*.5),Round(ch*.72),"en-US",2).Text
        return RegExMatch(text,"i)infinity\s+mansion") && RegExMatch(text,"i)\broom\s*\d")
            && RegExMatch(text,"i)\bstart\b")
    }
    return false
}

InfinityMansionConfirmPortal() {
    if !InfinityMansionClick("Open")
        return false
    ProcessLog("Infinity Mansion: confirmed Open Portal")
    return true
}

InfinityMansionStartQueue() {
    return InfinityMansionClick("Start",8000,true)
}

InfinityMansionQueueVisible(ui,cw) {
    ; The small waiting/countdown text is often omitted by Windows OCR.
    ; The queue's map/room label is in the left sidebar; the room picker is central.
    sidebar := ""
    for line in ui.Lines {
        if line.x < cw*.28
            sidebar .= line.Text " "
    }
    return RegExMatch(sidebar,"i)infinity\s+mansion") && RegExMatch(sidebar,"i)\broom\s*\d+")
}

InfinityMansionClick(label, timeoutMs := 5000, requireQueue := false) {
    global rblxID
    deadline := A_TickCount + timeoutMs
    previousTarget := 0
    oldMouse := A_CoordModeMouse
    CoordMode "Mouse","Screen"
    try {
        while WinActive(rblxID) && A_TickCount < deadline {
            WinGetClientPos(&cx,&cy,&cw,&ch,rblxID)
            ui := OCR.FromRect(cx,cy,cw,ch,"en-US",2)
            if requireQueue && !InfinityMansionQueueVisible(ui,cw) {
                previousTarget := 0
                Sleep(150)
                continue
            }
            target := 0
            try {
                if label = "Infinity Mansion"
                    target := ui.FindString("i)infinit\w* i)ma\w*ion",1,false,RegExMatch,
                        {x1:cw*.2,y1:ch*.2,x2:cw*.52,y2:ch*.8})
                else if label = "Open" {
                    if RegExMatch(ui.Text,"i)open\s+portal")
                        target := ui.FindString("Open",1,false,,{x1:cw*.2,y1:ch*.48,x2:cw*.42,y2:ch*.75})
                }
                else if requireQueue
                    target := ui.FindString(label,1,false,,{x1:cw*.3,y1:ch*.65,x2:cw*.7,y2:ch*.88})
                else
                    target := ui.FindString(label)
            }
            if IsObject(target) {
                if !IsObject(previousTarget) || Abs(previousTarget.x-target.x)>2 || Abs(previousTarget.y-target.y)>2
                    || Abs(previousTarget.w-target.w)>2 || Abs(previousTarget.h-target.h)>2 {
                    previousTarget := target
                    Sleep(150)
                    continue
                }
                WinGetClientPos(&nx,&ny,&nw,&nh,rblxID)
                if !WinActive(rblxID) || nx!=cx || ny!=cy || nw!=cw || nh!=ch
                    return false
                clickX := cx+Round(target.x+target.w/2)
                clickY := cy+Round(target.y+target.h/2)
                ProcessLog("Infinity Mansion: " label " target=" clickX "," clickY " client=" cw "x" ch)
                FixClick(clickX,clickY)
                ProcessLog("Infinity Mansion: clicked " label)
                return true
            }
            previousTarget := 0
            Sleep(150)
        }
    } catch as err {
        ProcessLog("Infinity Mansion: lobby control unreadable (" label ")")
    } finally {
        CoordMode "Mouse",oldMouse
    }
    ProcessLog("Infinity Mansion: " label " unavailable; navigation stopped")
    return false
}

InfinityMansionWalk(key, durationMs) {
    global rblxID
    if (key != "a" && key != "w") || durationMs < 20 || durationMs > 7000 || !WinActive(rblxID)
        return false
    WinGetClientPos(&cx,&cy,&cw,&ch,rblxID)
    release := (*) => SendInput("{a up}{w up}")
    deadline := A_TickCount + durationMs
    try {
        SendInput("{" key " down}")
        SetTimer(release,-durationMs)
        while A_TickCount < deadline {
            WinGetClientPos(&nx,&ny,&nw,&nh,rblxID)
            if !WinActive(rblxID) || nx!=cx || ny!=cy || nw!=cw || nh!=ch
                return false
            Sleep(Min(20,Max(1,deadline-A_TickCount)))
        }
        return true
    } finally {
        SetTimer(release,0)
        release()
    }
}

StoryMode() {
    global StoryDropdown, StoryActDropdown, MapDropdown, mode

    ; Get current map and act
    currentStoryMap := mode = "Infinite" ? MapDropdown.Text : StoryDropdown.Text
    currentStoryAct := mode = "Infinite" ? "Infinity" : StoryActDropdown.Text

    ; Execute the movement pattern
    ProcessLog("Moving to: " currentStoryMap)
    if !StoryMovement()
        return false

    ProcessLog("Starting: " currentStoryMap " - " currentStoryAct)
    if !StartStory()
        return false

    ; Pick the requested act in the map detail panel before confirming it.
    if !SelectStoryAct(currentStoryAct)
        return false

    if (currentStoryAct = "Infinity" && MatchMaking.Value) {
        if !FindMatch()
            return false
    } else if !WorldStartSolo() {
        return false
    }
    return RestartStage(currentStoryMap)
}

PortalMode() {
    global PortalDropdown

    ;get portal type
    currentPortalType := PortalDropdown.Text

    ; Execute the movement pattern
    while !IsModeCancelOpen(&X, &Y) {
        if !PortalMovement()
            return false
    }
    ProcessLog("Going to: - " currentPortalType)

    ; Handle play mode selection
    return RestartStage(currentPortalType)
}

FarmMode() {
    ProcessLog("Processing for Farm Mode")
    while !IsModeCancelOpen(&X, &Y) {
        if !FarmMovement()
            return false
    }
    ProcessLog("Going to Farm")
    PlayHere()
    return RestartStage("Farm")
}

InfQuestMode() {
    ProcessLog("Processing for Daily Infinite Quest")
    while !IsModeCancelOpen(&X, &Y) {
        if !InfQuestMovement()
            return false
    }

    if (MatchMaking.Value) { ;find match or play alone
        if (!FindMatch())
            return false
    } else {
        PlayHere()
    }
    ProcessLog("Entering Inf quest...")
    return RestartStage("Daily Infinite Quest")
}

LegendMode() {
    global LegendDropdown, LegendActDropdown

    ; Get current map and act
    currentLegendMap := LegendDropdown.Text
    currentLegendAct := LegendActDropdown.Text
    entry := WorldCardEntry(currentLegendMap,"legend")
    if !IsObject(entry) {
        ProcessLog("World selection: choose a Legend map")
        return false
    }

    ; Execute the movement pattern
    ProcessLog("Moving to: " currentLegendMap)
    if !StoryMovement()
        return false

    ProcessLog("Processing: " currentLegendMap " - " currentLegendAct)
    if !StartLegend(currentLegendMap, currentLegendAct)
        return false

    if MatchMaking.Value {
        if !FindMatch()
            return false
    } else if !WorldStartSolo() {
        return false
    }
    return RestartStage(entry["map"])
}

RaidMode() {
    global RaidDropdown, RaidActDropdown

    ; Get current map and act
    currentRaidMap := RaidDropdown.Text
    currentRaidAct := RaidActDropdown.Text

    ; Execute the movement pattern
    ProcessLog("Moving to: " currentRaidMap)
    RaidMovement()

    ; Start stage
    while !IsModeCancelOpen(&X, &Y) {
        RaidMovement()
    }
    ProcessLog("Processing: " currentRaidMap " - " currentRaidAct)
    StartRaid(currentRaidMap, currentRaidAct)

    ; Handle play mode selection
    if (MatchMaking.Value) {
        if (!FindMatch())
            return false
    } else {
        PlayHere()
    }
    return RestartStage(currentRaidMap)
}

InfinityCastleMode() {
    global InfinityCastleDropdown

    ; Get current difficulty
    currentDifficulty := InfinityCastleDropdown.Text

    ; Execute the movement pattern
    ProcessLog("Moving to Infinity Castle")
    InfCastleMovement()

    ; Start stage
    while !IsModeCancelOpen(&X, &Y) {
        InfCastleMovement()
    }
    ProcessLog("Starting Infinity Castle - " currentDifficulty)

    ; Select difficulty with direct clicks
    if (currentDifficulty = "Normal") {
        FixClick(418, 375)  ; Click Easy Mode
    } else {
        FixClick(485, 375)  ; Click Hard Mode
    }

    ;Start Inf Castle
    if (MatchMaking.Value) {
        if (!FindMatch())
            return false
    } else {
        PlayHere()
        if (ok := IsModeCancelOpen(&X, &Y)) {
            ClickUntilGone(0, 0, 325, 520, 489, 587, ModeCancel, -10, -120)
        }
    }
    return RestartStage("Infinity Castle")
}

DungeonMode() {
    ProcessLog("Entering Dungeon Mode (35, 404)")
    FixClick(35, 404)  ; Click Dungeon mode button (Capys direct click)
    Sleep(1000)
    loop 5 {
        if (ok := FindText(&X, &Y, 310, 395, 495, 440, 0.20, 0.20, EnterDungeon)) {
            FixClick(395, 380)
            Sleep(1000)
            break
        }
        Sleep(500)
    }

    if (MatchMaking.Value) {
        if (!FindMatch())
            return false
        return RestartStage("Dungeon")
    } else {
        ; Select dungeon route and enter
        return SelectDungeonRoute()
    }
}

ClickReplay() {
    return ClickEndMenu(120)
}

ClickNextLevel() {
    return ClickEndMenu(260)
}

ClickReturnToLobby() {
    return ClickEndMenu(0)
}

ClickEndMenu(offset) {
    global rblxID
    oldMode := A_CoordModeMouse
    CoordMode "Mouse", "Screen"
    try {
        clicked := false
        loop 5 {
            if !WinActive(rblxID) || SmartPreviewInterrupted(true)
                return false
            if !FindText(&x, &y, 80, 85, 739, 224, 0, 0, LobbyText "|" LobbyText2)
                return clicked || (A_Index > 1)
            FixClick(x + offset, y - 35)
            clicked := true
            Sleep(1000)
            if !FindText(&x, &y, 80, 85, 739, 224, 0, 0, LobbyText "|" LobbyText2)
                return true
        }
        ; Seamless Replay countdown wait (5-10s)
        if (offset != 0 && clicked) {
            deadline := A_TickCount + 15000
            while (A_TickCount < deadline) {
                if !WinActive(rblxID)
                    return false
                if !FindText(&x, &y, 80, 85, 739, 224, 0, 0, LobbyText "|" LobbyText2)
                    return true
                if FindVoteStart(&vx, &vy) || RegularMatchHudVisible()
                    return true
                Sleep(500)
            }
            return true
        }
        return WinActive(rblxID) && !FindText(&x, &y, 80, 85, 739, 224, 0, 0, LobbyText "|" LobbyText2)
    } finally {
        CoordMode "Mouse", oldMode
    }
}

MonitorEndScreen(dungeon := false) {
    global rblxID, mode, StoryDropdown, StoryActDropdown, ReturnLobbyBox, MatchMaking
    global NextLevelBox, NextRoomBox, ReplayBox, lastResult
    EndCardMatch("result-screen")

    deadline := A_TickCount + 60000
    beatsWithoutButton := 0

    while A_TickCount < deadline {
        Sleep(1000)
        Reconnect(&reconnected)
        if reconnected
            return "reconnected"

        if !CapysGetClientBox(&cx, &cy, &cw, &ch, &tw) || SmartPreviewInterrupted(true)
            continue

        ; Dismiss Village Shop / Leave popup if present (UPD 21.5)
        DismissVillageShopPopup()

        ; Close unit panel if still open
        if WinActive("ahk_id " tw) && (ok := FindText(&X, &Y, 300, 190, 360, 250, 0, 0, UnitExit)) {
            ClickUntilGone(0, 0, 300, 190, 360, 250, UnitExit, -4, -35)
        }

        ; Handle Next button / reward prompt ("Click anywhere to continue" - Capys OCR + FindText)
        if CapysReadReward() {
            beatsWithoutButton := 0
            if !WinActive("ahk_id " tw) {
                WinActivate("ahk_id " tw)
                Sleep(150)
            }
            if CapysGetClientBox(&cx, &cy, &cw, &ch) {
                sx := cw / 800, sy := ch / 599
                oldMode := A_CoordModeMouse
                CoordMode "Mouse", "Screen"
                try FixClick(cx + Round(400 * sx), cy + Round(450 * sy))
                finally CoordMode "Mouse", oldMode
            }
            continue
        }
        if (ok := FindText(&X, &Y, 260, 400, 390, 450, 0, 0, NextText)) {
            beatsWithoutButton := 0
            oldMode := A_CoordModeMouse
            CoordMode "Mouse", "Screen"
            try FixClick(X, Y - 40)
            finally CoordMode "Mouse", oldMode
            continue
        }

        ; Check if player already arrived in lobby
        if (ok := FindText(&X, &Y, 746, 514, 789, 530, 0, 0, AreaText)) {
            ProcessLog("End screen: lobby confirmed; returning to main loop")
            return CheckLobby()
        }

        ; Handle end screen buttons via Capys OCR Choice OR LobbyText FindText
        capysChoice := CapysReadChoice()
        hasCapysChoice := IsObject(capysChoice) && capysChoice["kind"] = "choice"
        if (hasCapysChoice || FindText(&X, &Y, 80, 85, 739, 224, 0, 0, LobbyText) || FindText(&X, &Y, 80, 85, 739, 224, 0, 0, LobbyText2)) {
            if (hasCapysChoice && capysChoice["ownerWait"]) {
                ProcessLog("End screen: waiting for party owner...")
                continue
            }
            ProcessLog("Tìm thấy End Choice - Chế độ hiện tại: " mode)

            ClickCapysEndBtn(bx, fallbackAction := "") {
                if (bx > 0 && CapysGetClientBox(&cx, &cy, &cw, &ch, &tw2)) {
                    if !WinActive("ahk_id " tw2) {
                        WinActivate("ahk_id " tw2)
                        Sleep(150)
                    }
                    sx := cw / 800, sy := ch / 599
                    oldMode := A_CoordModeMouse
                    CoordMode "Mouse", "Screen"
                    try {
                        waitUntil := A_TickCount + 15000
                        lastClickAt := 0
                        clicks := 0
                        while (A_TickCount < waitUntil) {
                            if (clicks < 4 && (lastClickAt = 0 || A_TickCount - lastClickAt >= 1200)) {
                                if CapysGetClientBox(&cx, &cy, &cw, &ch, &tw2) {
                                    sx := cw / 800, sy := ch / 599
                                    FixClick(cx + Round(bx * sx), cy + Round(121 * sy))
                                }
                                lastClickAt := A_TickCount
                                clicks++
                            }
                            Sleep(450)
                            if (fallbackAction != "lobby" && (FindVoteStart(&vx, &vy) || CapysReadWave() >= 1 || RegularMatchHudVisible() || SummerMatchStarted()))
                                return true
                            if (fallbackAction = "lobby" && FindText(&ax, &ay, 746, 514, 789, 530, 0, 0, AreaText))
                                return true
                            if (!IsObject(CapysReadChoice()) && !FindText(&lx, &ly, 80, 85, 739, 224, 0, 0, LobbyText "|" LobbyText2))
                                return true
                        }
                    } finally CoordMode "Mouse", oldMode
                    return !IsObject(CapysReadChoice()) || (FindVoteStart(&vx, &vy) || CapysReadWave() >= 1 || RegularMatchHudVisible() || SummerMatchStarted())
                }
                if CapysGetClientBox(,,,, &tw2) && !WinActive("ahk_id " tw2) {
                    WinActivate("ahk_id " tw2)
                    Sleep(150)
                }
                if (fallbackAction = "lobby")
                    return ClickReturnToLobby()
                if (fallbackAction = "next")
                    return ClickNextLevel()
                return ClickReplay()
            }

            if (MatchMaking.Value || ReturnLobbyBox.Value) {
                ProcessLog("Return Lobby")
                ClickCapysEndBtn(hasCapysChoice ? capysChoice["lobbyX"] : 0, "lobby")
                return CheckLobby()
            }

            if (mode = "Story") {
                ProcessLog("Handling Story end")
                if (StoryActDropdown.Text != "Infinity") {
                    if (NextLevelBox.Value && lastResult = "win") {
                        ProcessLog("Next match")
                        ClickCapysEndBtn(hasCapysChoice ? capysChoice["nextLevelX"] : 0, "next")
                    } else {
                        ProcessLog("Replay")
                        ClickCapysEndBtn(hasCapysChoice ? capysChoice["replayX"] : 0, "replay")
                    }
                    return "replay"
                } else {
                    ProcessLog("Story Infinity Return")
                    ClickCapysEndBtn(hasCapysChoice ? capysChoice["lobbyX"] : 0, "lobby")
                    return CheckLobby()
                }
            }
            else if (mode = "Portal" || mode = "Daily Infinite Quest") {
                ProcessLog("Return Lobby")
                ClickCapysEndBtn(hasCapysChoice ? capysChoice["lobbyX"] : 0, "lobby")
                return CheckLobby()
            }
            else if (mode = "Farm") {
                ProcessLog("Handling Farm end: Replay")
                ClickCapysEndBtn(hasCapysChoice ? capysChoice["replayX"] : 0, "replay")
                return "replay"
            }
            else if (mode = "Raid") {
                ProcessLog("Handling Raid end")
                if (ReturnLobbyBox.Value) {
                    ProcessLog("Return Lobby")
                    ClickCapysEndBtn(hasCapysChoice ? capysChoice["lobbyX"] : 0, "lobby")
                    return CheckLobby()
                } else {
                    ProcessLog("Replay Raid")
                    ClickCapysEndBtn(hasCapysChoice ? capysChoice["replayX"] : 0, "replay")
                    return "replay"
                }
            }
            else if (mode = "Infinity Castle") {
                ProcessLog("Handling Infinite Castle: Replay")
                ClickCapysEndBtn(hasCapysChoice ? capysChoice["replayX"] : 0, "replay")
                return "replay"
            }
            else if (mode = "Infinity Mansion") {
                ProcessLog("Handling Infinity Mansion end")
                if (NextRoomBox.Value && lastResult = "win") {
                    ProcessLog("Next Room")
                    ClickCapysEndBtn(hasCapysChoice ? capysChoice["nextLevelX"] : 0, "next")
                } else {
                    ProcessLog("Replay Mansion")
                    ClickCapysEndBtn(hasCapysChoice ? capysChoice["replayX"] : 0, "replay")
                }
                return "replay"
            }
            else if (mode = "Summer Event") {
                ProcessLog("Handling Summer Event end")
                if (ReturnLobbyBox.Value) {
                    ClickCapysEndBtn(hasCapysChoice ? capysChoice["lobbyX"] : 0, "lobby")
                    return CheckLobby()
                }
                ClickCapysEndBtn(hasCapysChoice ? capysChoice["replayX"] : 0, "replay")
                return "replay"
            }
            else if (mode = "Misty Village" || mode = "Misty Infinite") {
                ProcessLog("Handling " . mode . " end")
                if (lastResult = "lose" || ReturnLobbyBox.Value) {
                    ProcessLog(mode . ": returning to lobby (defeat or ReturnLobby checked)")
                    ClickCapysEndBtn(hasCapysChoice ? capysChoice["lobbyX"] : 0, "lobby")
                    return CheckLobby()
                }
                if (NextLevelBox.Value) {
                    ProcessLog(mode . ": Next Floor")
                    ClickCapysEndBtn(hasCapysChoice ? capysChoice["nextLevelX"] : 0, "next")
                } else {
                    ProcessLog(mode . ": Replay")
                    ClickCapysEndBtn(hasCapysChoice ? capysChoice["replayX"] : 0, "replay")
                }
                return "replay"
            }
            else {
                ProcessLog("Handling default end action")
                if (ReturnLobbyBox.Value) {
                    ProcessLog("Return Lobby")
                    ClickCapysEndBtn(hasCapysChoice ? capysChoice["lobbyX"] : 0, "lobby")
                    return CheckLobby()
                } else {
                    ProcessLog("Replay")
                    ClickCapysEndBtn(hasCapysChoice ? capysChoice["replayX"] : 0, "replay")
                    return "replay"
                }
            }
        }

        ; If neither NextText nor LobbyText found, click Capys summary Next button at (319, 394)
        beatsWithoutButton++
        if (beatsWithoutButton >= 3) {
            beatsWithoutButton := 0
            if CapysGetClientBox(&cx, &cy, &cw, &ch, &tw2) {
                if !WinActive("ahk_id " tw2)
                    try WinActivate("ahk_id " tw2)
                sx := cw / 800, sy := ch / 599
                oldMode := A_CoordModeMouse
                CoordMode "Mouse", "Screen"
                try FixClick(cx + Round(319 * sx), cy + Round(394 * sy))
                finally CoordMode "Mouse", oldMode
            }
        }
    }

    ProcessLog("End screen: timeout; recovering to lobby")
    if (ok := FindText(&X, &Y, 746, 514, 789, 530, 0, 0, AreaText))
        return CheckLobby()
    return RecoverToLobby()
}

ProcessMatchResult() {
    global Wins, loss, mode, stageStartTime, lastResult, MatchMaking
    ProcessLog("Checking win/loss status...")
    stageLength := FormatStageTime(A_TickCount - stageStartTime)

    CloseUnitPanel()
    if (ok := FindText(&X, &Y, 300, 190, 360, 250, 0, 0, UnitExit)) {
        ClickUntilGone(0, 0, 300, 190, 360, 250, UnitExit, -4, -35)
    }

    capysRes := CapysReadResult()
    if capysRes = "victory" {
        ProcessLog("Victory detected - Stage Length: " stageLength)
        Wins += 1
        lastResult := "win"
        SendWebhookWithTime(true, stageLength)
        if CapysGetClientBox(&cx, &cy, &cw, &ch) {
            oldM := A_CoordModeMouse
            CoordMode "Mouse", "Screen"
            try FixClick(cx + Round(319 * cw / 800), cy + Round(394 * ch / 599))
            finally CoordMode "Mouse", oldM
        }
    } else if capysRes = "defeat" {
        ProcessLog("Defeat detected - Stage Length: " stageLength)
        loss += 1
        lastResult := "lose"
        SendWebhookWithTime(false, stageLength)
    } else {
        lastResult := "unknown"
        ProcessLog("End screen visible; win/loss title unreadable")
    }

    if (mode = "Dungeon" && !MatchMaking.Value)
        return MonitorDungeonEnd()
    return MonitorEndScreen()
}

MonitorStage() {
    global Wins, loss, mode, StoryActDropdown, CARD_ENABLED, stageStartTime, lastResult

    lastClickTime := A_TickCount

    loop {
        Sleep(1000)

        ; Card picker (GAME layer)
        if CARD_ENABLED {
            WaitForCardChoice(mode)
        }

        if ((mode = "Story" && StoryActDropdown.Text = "Infinity") || (mode = "Farm") || (mode = "Daily Infinite Quest")) {
            timeElapsed := A_TickCount - lastClickTime
            if (timeElapsed >= 300000) {  ; 5 minutes
                ProcessLog("Processing for Anti-AFK...")
                FixClick(560, 560) ; Move click

                ; mahogora ability checker
                FixClick(239, 400)
                FixClick(298, 400)
                FixClick(358, 400)

                if (FindText(&x, &y, 0, 0, A_ScreenWidth, A_ScreenHeight, 0, 0, Wave40Inf)) {
                    Wave40Reached()
                }

                lastClickTime := A_TickCount
            }
        }

        if (CapysResultScreenVisible()) {
            return ProcessMatchResult()
        }

        Reconnect(&reconnected)
        if reconnected
            return "reconnected"
    }
}

HandleStageResult() {
    return ProcessMatchResult()
}

StoryMovement() {
    global rblxID, aaMainUIHwnd
    if WinExist("ahk_id " aaMainUIHwnd)
        WinSetAlwaysOnTop(false, "ahk_id " aaMainUIHwnd)
    if !WinExist(rblxID)
        return false
    WinActivate(rblxID)
    Sleep(150)
    if !WinActive(rblxID)
        return false
    if IsObject(WorldSelectorState())
        return true
    if !OpenRegularPlayArea()
        return false
    if IsObject(WorldSelectorState())
        return true
    ProcessLog("Story navigation: DW2620ms -> W2151ms")
    if !MapWalk("dw", 2620)
        return false
    Sleep(150)
    if !MapWalk("w", 2151)
        return false
    Sleep(500)
    return IsObject(WorldSelectorState())
}

;go to Walled City for worthy farm

FarmMovement() {
    global rblxID, aaMainUIHwnd

    WinSetAlwaysOnTop(false, "ahk_id " aaMainUIHwnd)
    if WinExist(rblxID)
        WinActivate(rblxID)
    Sleep(150)
    oldMouseMode := A_CoordModeMouse
    CoordMode "Mouse", "Screen"
    FixClick(85, 330) ; click Play in the current lobby layout
    CoordMode "Mouse", oldMouseMode
    sleep (1000)

    ;move to game choose
    SendInput ("{w down}")
    Sleep(300)
    SendInput ("{w up}")
    Sleep(300)
    SendInput ("{d down}")
    SendInput ("{w down}")
    Sleep(4500)
    SendInput ("{d up}")
    SendInput ("{w up}")
    Sleep(500)
    FixClick(640, 70)

    ;enter nav mode
    SendInput("{LShift down}\{LShift up}")
    Sleep(500)

    ;select farm mode
    loop 3 {
        SendInput("{s}")
        Sleep(500)
    }

    ;choose farm mode
    SendInput("{Enter}")
    Sleep(500)

    ;exit nav mode
    SendInput("{LShift down}\{LShift up}")
    Sleep(500)
}

Wave40Reached(&handled := false) {
    handled := false
    global rblxID, ShowUpgradeUIOnLeftImg, mode, MatchMaking
    if (mode = "Summer Event" && !MatchMaking.Value)
        return false

    ; This function is also called while placing units. Do not inspect or click
    ; the lobby teleport menu unless Wave 40 is actually visible.
    if !FindText(&x, &y, 186, 97, 256, 124, 0, 0, Wave40Inf)
        return false
    ProcessLog("Wave 40 has been reached")
    oldMouseMode := A_CoordModeMouse
    CoordMode "Mouse", "Client"
    settingsOpened := false
    targetImg := IsSet(ShowUpgradeUIOnLeftImg) ? ShowUpgradeUIOnLeftImg : "Images\ShowUpgradeUIOnLeft_Text.png"
    try {
        FixClick(26, 570) ; open settings
        settingsOpened := true
        Sleep(700)

        ; The panel reopens wherever it was last scrolled, so reset to the top
        ; before stepping down. FixMove is required: Roblox ignores wheel input
        ; until it has processed a fresh mouse-move at that position.
        FixMove(400, 300)
        Sleep(150)
        loop 10 {
            SendInput("{WheelUp}")
            Sleep(110)
        }
        Sleep(1200)
        WinActivate(rblxID)
        Sleep(200)

        ; "Return to Lobby" sits two rows below "Show Upgrade UI on left", so
        ; locate that row and offset to its button. The row also has to sit high
        ; enough for the button underneath to still be inside the panel.
        foundX := 0
        foundY := 0
        ready := false
        loop 16 {
            if ImageSearch(&foundX, &foundY, 200, 150, 620, 460, "*60 " targetImg) {
                if (foundY <= 290) {
                    probeX := foundX
                    probeY := foundY
                    Sleep(650)
                    if (ImageSearch(&foundX, &foundY, 200, 150, 620, 460, "*60 " targetImg)
                        && foundX = probeX && foundY = probeY && foundY <= 290) {
                        ready := true
                        break
                    }
                }
            }
            FixMove(400, 300)
            SendInput("{WheelDown}")
            Sleep(320)
        }

        if !ready {
            ProcessLog("Could not find 'Show Upgrade UI on left' in Settings")
            return false
        }

        ; Measured on the live panel: the toggle centre is foundY + 27 and the
        ; Return to Lobby button sits another 109px below that.
        lobbyX := foundX + 287
        lobbyY := foundY + 136
        WinActivate(rblxID)
        Sleep(150)
        FixClick(lobbyX, lobbyY)
        Sleep(1800)
        settingsOpened := false
        ProcessLog("Clicked Return to Lobby")
        handled := true
        return CheckLobby()
    } finally {
        if (settingsOpened) {
            FixClick(581, 157) ; close settings
            Sleep(250)
        }
        CoordMode "Mouse", oldMouseMode
    }
    return false
}

PortalSearch() { ; try to search portal in items bags
    DemonsPlaceColor := 0xFF60FF
    ShibuyaColor := 0x86FEFF
    ProcessLog("Searching for Portal...")
    Sleep(500)
    FixClick(40, 310) ;click Items
    Sleep(1500)
    FixClick(446, 225) ;click Portals Page
    Sleep(1500)

    ;scroll down to find portal
    MouseMove(442, 415, 10)
    if (PortalDropdown.Text = "Shibuya District") {
        while !((FindText(&x, &y, 171, 237, 634, 485, 0, 0, ShibuyaPortal)) && (PixelSearch(&foundX, &foundY, 171, 237,
            634, 485, ShibuyaColor, 0))) {
            Sleep(1500)
            loop {
                Send ("{WheelDown}")
                if (FindText(&x, &y, 171, 237, 634, 485, 0, 0, ShibuyaPortal)) && (PixelSearch(&foundX, &foundY, 171,
                    237, 634, 485, ShibuyaColor, 0)) {
                    break
                }
                Sleep(2000)
            }
        }
        FixClick(x, y)
        Sleep(1500)
    } else if (PortalDropdown.Text = "Demons Leader Place") {
        while !((FindText(&x, &y, 171, 237, 634, 485, 0, 0, DemonsPlacePortal)) && (PixelSearch(&x, &y, 171, 237, 634,
            485, DemonsPlaceColor, 0))) {
            Sleep(1500)
            loop {
                Send ("{WheelDown}")
                if (FindText(&x, &y, 171, 237, 634, 485, 0, 0, DemonsPlacePortal)) && (PixelSearch(&x, &y, 171, 237,
                    634, 485, DemonsPlaceColor, 0)) {
                    break
                }
                Sleep(2000)
            }
            Sleep(1500)
        }
        FixClick(x, y)
        Sleep(500)
    }
    Sleep(1500)
}

PortalMovement() {
    ProcessLog("Portal navigation: Items route (36, 297)")
    FixClick(36, 297)  ; Items
    Sleep(600)
    FixClick(533, 227) ; Portal tab
    Sleep(600)
    FixClick(486, 186) ; Search
    Sleep(600)
    FixClick(216, 287) ; First portal select
    Sleep(600)
    FixClick(253, 353) ; Use/Open portal
    Sleep(600)
    FixClick(400, 465) ; Start
    Sleep(1000)
    ProcessLog("Opened a Portal, joining in...")
}

FoundMapType() { ; just use for infinite daily quest mode
    global TextColor := 0xFCCF00

    if (FindText(&X1, &Y1, 214, 191, 587, 512, 0, 0, SandInf)) {
        return 5
    } else if (FindText(&X1, &Y1, 214, 191, 587, 512, 0, 0, FiendInf)) {
        return 7
    } else if (FindText(&X1, &Y1, 214, 191, 587, 512, 0, 0, AntKingdomInf)) {
        return 9
    } else if (FindText(&X1, &Y1, 214, 191, 587, 512, 0, 0, MagicTownInf)) {
        return 10
    } else if (FindText(&X1, &Y1, 214, 191, 587, 512, 0, 0, PuppetInf)) {
        return 17
    } else if (FindText(&X1, &Y1, 214, 191, 587, 512, 0, 0, DungeonThroneInf)) {
        return 20
    } else if (FindText(&X1, &Y1, 214, 191, 587, 512, 0, 0, ShibuyaInf)) {
        return 23
    } else {
        return 0 ; Không tìm thấy map
    }
}

EnterNavMode(steps) {
    SendInput("{LShift down}\{LShift up}") ; enable nav key
    loop steps {
        SendInput("{Down}")
        Sleep (500)
    }
    Sleep(500)
    SendInput("{Enter}")
    Sleep(500)
    SendInput("{LShift down}\{LShift up}") ; disable nav key
}

InfQuestMovement() {
    FixClick(640, 70) ; close player board
    Sleep(500)
    FixClick(770, 280) ; open quest
    Sleep(500)
    FixClick(453, 157) ; choose inf quest
    Sleep(500)
    if (FindText(&x, &y, 216, 190, 587, 516, 0, 0, ClaimText)) { ; claim reward
        loop 5 {
            FixClick(x, y - 30)
            Sleep(500)
        }
    }
    Sleep(1000)
    mapSteps := 0
    loop i := 1 {
        found := FoundMapType()
        if (found > 0) {
            mapSteps := found
        }
        Sleep(200)
        i++
    }

    if (mapSteps > 0) {
        FixClick(600, 130) ;close quest
        ProcessLog("Found map, moving to Daily Inf Quest (A4103ms)")
        MapWalk("a", 4103)
        Sleep(500)
        EnterNavMode(mapSteps)
    } else {
        ProcessLog("No map detected, moving to Farm")
        return FarmMode()
    }
    Sleep(500)
}

RaidMovement() {
    FixClick(765, 475) ; Click Area
    Sleep(300)
    FixClick(495, 410)
    Sleep(500)
    ProcessLog("Raid navigation: A4123ms -> W1863ms")
    MapWalk("a", 4123)
    Sleep(150)
    MapWalk("w", 1863)
    Sleep(500)
}

InfCastleMovement() {
    FixClick(765, 475) ;click Area
    Sleep (300)
    FixClick(370, 330)
    Sleep (500)
    SendInput ("{w down}")
    Sleep (500)
    SendInput ("{w up}")
    Sleep (500)
    SendInput ("{a down}")
    sleep (4000)
    SendInput ("{a up}")
    Sleep (500)
}

; Roblox keeps showing "Don't Miss Out!" event toasts in the top-right corner.
; Their red close button sits at x≈767 and the toast cards cover the first rows
; of the Select World list, so they must be cleared before picking a map.
DismissPromoPopups(maxPopups := 4) {
    CoordMode "Pixel", "Client"

    oldMouseMode := A_CoordModeMouse

    CoordMode "Mouse", "Client"

    loop maxPopups {
        ; A real close button is a filled red disc about 20px across, so the
        ; pixel 8px right and 8px down must be red as well. That rejects the
        ; isolated red pixels inside the world-card thumbnails, which used to
        ; make the macro select the wrong world.
        yStart := 55
        clicked := false

        loop 12 {
            if !PixelSearch(&px, &py, 758, yStart, 778, 320, 0xE00000, 40)

                break

            c := PixelGetColor(px + 8, py + 8, "RGB")
            r := (c >> 16) & 0xFF
            g := (c >> 8) & 0xFF
            b := c & 0xFF

            if (r > 180 && g < 60 && b < 60) {
                FixClick(px + 8, py + 8)
                Sleep(400)
                clicked := true
                break
            }
            yStart := py + 2
        }

        if !clicked
            break
    }
    CoordMode "Mouse", oldMouseMode
}

StartStory() {
    global mode, StoryDropdown, MapDropdown
    name := mode = "Infinite" ? MapDropdown.Text : StoryDropdown.Text
    return SelectWorldMap(name,"main")
}

StartLegend(map, actName) {
    return SelectWorldMap(map,"legend") && SelectWorldAct(actName,"legend")
}

StartRaid(map, RaidActDropdown) {
    ClosePlayerLeaderBoard()
    navKeys := GetNavKeys()
    for key in navKeys {
        SendInput("{" key "}")
    }
    Sleep(500)
    downArrows := GetRaidDownArrows(map) ; Map selection down arrows
    loop downArrows {
        SendInput("{Down}")
        Sleep(200)
    }
    SendInput("{Enter}") ; Select Raid
    loop 4 {
        SendInput("{Up}") ; Makes sure it selects act
        Sleep(200)
    }
    SendInput("{Left}") ; Go to act selection
    Sleep(500)
    actArrows := GetRaidActDownArrows(RaidActDropdown) ; Act selection down arrows
    loop actArrows {
        SendInput("{Down}")
        Sleep(200)
    }
    SendInput("{Enter}") ; Select Act
    Sleep(300)
    for key in navKeys {
        SendInput("{" key "}")
    }
}

; Click the requested act tab in the map detail panel. The panel only lists the
; acts that exist for the selected world and labels the infinite one "Infinite"
; while the dropdown says "Infinity".
SelectStoryAct(actName) {
    return SelectWorldAct(actName,"main")
}

PlayHere() {
    FixClick(400, 440)  ; 1. Select Act / Infinity
    Sleep(400)
    FixClick(330, 330)  ; 2. Click Play here
    Sleep(400)
    FixClick(400, 460)  ; 3. Click Start
    Sleep(400)
    FixClick(336, 463)  ; 4. Direct Start fallback
    Sleep(400)
}

FindMatch() {
    startTime := A_TickCount

    Loop {
        if (A_TickCount - startTime > 50000) {
            ProcessLog("Matchmaking timeout (50s); returning to main loop")
            FixClick(400, 520)
            return false
        }

        FixClick(400, 435)  ; Play Here or Find Match
        Sleep(300)
        FixClick(460, 330)  ; Click Find Match
        Sleep(300)

        ; Try captcha (CaptchaDetect handles focus, ^a clear, digit entry, Submit (300, 385) and confirmation)
        if (!CaptchaDetect(252, 292, 300, 50, 400, 335)) {
            ProcessLog("Could not find captcha, retrying...")
            FixClick(585, 190)  ; Click close
            Sleep(1000)
            continue
        }
        ProcessLog("FindMatch: captcha confirmed; waiting for match...")
        return true
    }
}

GetLegendDownArrows(map) {
    switch map {
        case "Magic Hills": return 1
        case "Space Center": return 3
        case "Fabled Kingdom": return 4
        case "Virtual Dungeon": return 6
        case "Dungeon Throne": return 7
        case "Rain Village": return 8
    }
}

GetLegendActDownArrows(LegendActDropdown) {
    switch LegendActDropdown {
        case "Act 1": return 1
        case "Act 2": return 2
        case "Act 3": return 3
    }
}

GetRaidDownArrows(map) {
    switch map {
        case "Sacred Planet": return 2
        case "Strange Town": return 3
        case "Ruined City": return 4
    }
}

GetRaidActDownArrows(RaidActDropdown) {
    switch RaidActDropdown {
        case "Act 1": return 1
        case "Act 2": return 2
        case "Act 3": return 3
        case "Act 4": return 4
        case "Act 5": return 5
    }
}

Zoom() {
    global rblxID

    ; Keep the camera in third person. The old routine zoomed all the way in,
    ; clicked the game view (rotating the camera), then tried to reverse it.
    ; That could leave Roblox stuck in first person during long runs.
    if WinExist(rblxID)
        WinActivate(rblxID)
    oldMouseMode := A_CoordModeMouse
    CoordMode "Mouse", "Client"
    FixMove(400, 300)
    loop 20 {
        SendEvent("{WheelDown}")
        Sleep(50)
    }
    CoordMode "Mouse", oldMouseMode
}

TpSpawn() {
    global rblxID

    if WinExist(rblxID)
        WinActivate(rblxID)
    oldMouseMode := A_CoordModeMouse
    oldPixelMode := A_CoordModePixel
    CoordMode "Mouse", "Client"
    CoordMode "Pixel", "Client"
    try {
        FixClick(26, 570) ; open Roblox settings
        Sleep(450)

        ; The panel reopens at its last scroll position, so scan what is already
        ; on screen before nudging the list. Resetting to the top every time cost
        ; about twenty seconds and was never needed.
        ; The panel reopens wherever it was left, so reset to the top with a few
        ; cheap wheel-ups first; then the downward search always starts from the
        ; same place instead of depending on the previous run's scroll position.
        FixMove(400, 300)
        loop 18 {
            SendInput("{WheelUp}")
            Sleep(25)
        }

        Sleep(200)

        ; The Gameplay section now has Disable Auto-Open Upgrade UI.
        ; Keep its value and locate the teleport row by its current label.
        WinGetClientPos(&cx, &cy,,, rblxID)
        try {
            settings := OCR.FromRect(cx + 230, cy + 190, 260, 250, "en-US", 2)
            row := settings.FindString("Teleport back to Spawn")
            if IsObject(row) {
                rowY := Round(190 + row.y + row.h / 2 + 5)
                if (rowY >= 190 && rowY <= 430 && ArrowNear(524, rowY)) {
                    FixClick(524, rowY)
                    ProcessLog("Clicked Teleport back to Spawn")
                    Sleep(500)
                } else
                    ProcessLog("Could not verify the Teleport back to Spawn button")
            }
        } catch {
            ProcessLog("Could not read the Teleport back to Spawn row")
        }

        FixClick(581, 148) ; close settings

        Sleep(250)
    } finally {
        CoordMode "Mouse", oldMouseMode
        CoordMode "Pixel", oldPixelMode
    }
    PlacementCamera()
}

IsControlPixel(x, y) {
    c := PixelGetColor(x, y, "RGB")
    r := (c >> 16) & 0xFF
    g := (c >> 8) & 0xFF
    b := c & 0xFF

    ; The arrow buttons are #3C3C3C (60,60,60) and the panel rows #1A1A1A, so
    ; the window has to start below 60 or every button is rejected.
    return (Abs(r - g) < 22 && Abs(g - b) < 22 && r >= 45 && r <= 130)
}

ArrowNear(x, y) {
    ; The row pitch measured on the live panel is ~53px, but the button circle
    ; centre drifts a few pixels with the row text height, so probe around it.

    return (IsControlPixel(x, y) || IsControlPixel(x, y - 4) || IsControlPixel(x, y + 4) || IsControlPixel(x, y - 8) || IsControlPixel(x, y + 8))
}

; Roblox paints the chat button as a solid white speech bubble while the log is
; open and as an outlined bubble while it is closed. Sampling the bubble's
; interior separates the two states, which matters because the button is a
; toggle: clicking it while the log is closed opens it and the game then eats
; movement keys as chat input.
IsChatOpen() {
    static probes := [[130, 30], [132, 32], [134, 34], [136, 36], [140, 36], [142, 34], [138, 29]]

    oldPixelMode := A_CoordModePixel
    CoordMode "Pixel", "Client"
    try {
        bright := 0
        for p in probes {
            c := PixelGetColor(p[1], p[2], "RGB")
            r := (c >> 16) & 0xFF
            g := (c >> 8) & 0xFF
            b := c & 0xFF
            if (r + g + b > 600)
                bright++
        }
        return bright >= 5
    } finally {
        CoordMode "Pixel", oldPixelMode
    }
}

CloseChat() {
    ; Only ever close an open chat. The old code clicked the toggle whenever the
    ; icon template matched, which reopened an already closed log.
    if !IsChatOpen()
        return

    oldMouseMode := A_CoordModeMouse
    CoordMode "Mouse", "Client"
    try {
        FixClick(139, 33)
        Sleep(600)

        ; A single retry, and only while the log is still open. Extra clicks
        ; would just flip the toggle back to open.
        if IsChatOpen()
            FixClick(139, 33)
    } finally {
        CoordMode "Mouse", oldMouseMode
    }

    Sleep(400)

    if IsChatOpen()
        ProcessLog("Could not close chat")
    else
        ProcessLog("Chat closed")
}

DetectMap(timeoutMs := 120000) {
    global mode, rblxID, SummerMapInterrupted, MatchMaking
    isSummer := mode="Summer Event"
    if isSummer
        SummerMapInterrupted:=false

    ProcessLog("Moving into the map...")

    startTime := A_TickCount

    loop {
        RefreshClientTarget()
        if isSummer {
            if !WinActive(rblxID) {
                SummerMapInterrupted:=true
                ProcessLog("Summer loading cover interrupted: Roblox focus unavailable")
                return "no map found"
            }
            if SmartPreviewInterrupted(true) {
                SummerMapInterrupted:=true
                ProcessLog("Summer loading cover interrupted: card/input unavailable")
                return "no map found"
            }
            if FindVoteStart(&vx,&vy) {
                ProcessLog("Summer Event: Vote Start confirmed; skipping missing cover and continuing to vote setup")
                return "no map found"
            }
            scene:=SummerReadUI()
            if CapysResultScreenVisible() || RegExMatch(scene,"i)\bdefeat\b|\bvictory\b|disconnected|choose\s+a\s+card|return\s+to\s+lobby") {
                SummerMapInterrupted:=true
                ProcessLog("Summer loading cover interrupted: result/card/disconnect")
                return "no map found"
            }
        }

        ; Periodic lobby detection (respect initial matchmaking queue grace of 15s)
        lobbyGrace := (IsSet(MatchMaking) && MatchMaking.Value) ? 15000 : 3000
        if (A_TickCount - startTime >= lobbyGrace) {
            if (WinActive(rblxID) && FindText(&X, &Y, 746, 514, 789, 530, 0, 0, AreaText)) {
                ProcessLog("DetectMap: returned to lobby - returning to main loop")
                return "lobby"
            }
        }

        if (A_TickCount - startTime > timeoutMs) {
            if (FindText(&X, &Y, 746, 514, 789, 530, 0, 0, AreaText)) {
                ProcessLog("DetectMap timeout in lobby - returning to main loop")
                return "lobby"
            }
            ProcessLog("Map cover recognition timed out - continuing without cover movement")
            return "no map found"
        }

        ; Check for vote screen
        if !isSummer && (FindVoteStart(&X,&Y) || RegularMatchHudVisible()) {
            ProcessLog("Loading cover unknown; match HUD/Vote Start confirmed, continuing without map movement")

            return "no map found"
        }
        if !isSummer && CapysResultScreenVisible() {
            ProcessLog("Loading interrupted by result screen; leaving cover recognition")
            return "no map found"
        }

        try {
            WinGetClientPos(&cx,&cy,&cw,&ch,rblxID)
            if cw<=0 || ch<=0
                throw Error("Empty client geometry")
        } catch {
            if isSummer
                SummerMapInterrupted:=true
            ProcessLog("Map cover client geometry unavailable; stopping recognition")
            return "no map found"
        }

        mapPatterns := Map(

            "Planet Greenie", Greenie,
            "Ant Kingdom", Ant,
            "Magic Town", MagicTown,
            "Magic Hill", MagicHills,
            "Navy Bay", Navy,
            "Snowy Town", SnowyTown,
            "Snowy Kingdom", SnowyKingdom,
            "Dungeon Throne", DungeonThrone,
            "Rain Village", RainVillage,
            "Fiend City", Fiend,
            "Spirit World", Spirit,
            "Haunted Academy", Academy,
            "Space Center", SpaceCenter,
            "Mountain Temple", Mount,
            "Cursed Festival", Cursed,
            "Nightmare Train", Nightmare,
            "Air Craft", AirCraft,
            "Hellish City", Hellish,
            "Shibuya District", Shibuya,
            "Misty Village", MistyVillage
        )
        for mapName, pattern in mapPatterns {
            found := false
            if (InStr(pattern, ".png") || FileExist(pattern) || FileExist(A_ScriptDir "\" pattern)) {
                imgPath := FileExist(pattern) ? pattern : (A_ScriptDir "\" pattern)
                CoordMode "Pixel", "Client"
                try {
                    if ImageSearch(&X, &Y, 0, 0, 816, 638, "*60 " imgPath)
                        found := true
                }
            } else {
                ; Loading title band measured at client800x599; allow long full names.
                if (ok := FindText(&X, &Y, cx+Round(cw*10/800), cy+Round(ch*58/599), cx+cw-1, cy+Round(ch*128/599), 0, 0, pattern))
                    found := true
            }

            if (found) {
                ProcessLog("Map found: " mapName)
                return mapName
            }
        }
        Sleep 1000
        Reconnect(&reconnected)
        if reconnected
            return "reconnected"
    }
}

HandleMapMovement(MapName) {
    ; All modes, including Summer, use the route for the recognized map.
    ProcessLog("Moving to: " MapName)
    switch MapName {
        case "Sacred Planet":
            return MoveForSacredPlanet()
        case "Planet Greenie":
            return MoveForGreenie()
        case "Snowy Town":
            return MoveForSnowyTown()
        case "Snowy Kingdom":
            return MoveForSnowyKingdom()
        case "Dungeon Throne":
            return MoveForDungeonThrone()
        case "Rain Village":
            return MoveForRainVillage()
        case "Ant Kingdom":
            return MoveForAntKingdom()
        case "Magic Town":
            return MoveForMagicTown()
        case "Magic Hill", "Magic Hills":
            return MoveForMagicHill()
        case "Misty Village", "Misty Infinite", "Misty Tower":
            return MoveForMistyVillage()
        case "Navy Bay":
            return MoveForNavyBay()
        case "Fiend City":
            return MoveForFiendCity()
        case "Spirit World":
            return MoveForSpiritWorld()
        case "Haunted Academy":
            return MoveForHauntedAcademy()
        case "Space Center":
            return MoveForSpaceCenter()
        case "Mountain Temple":
            return MoveForMountainTemple()
        case "Cursed Festival":
            return MoveForCursedFestival()
        case "Nightmare Train":
            return MoveForNightmareTrain()
        case "Air Craft":
            return MoveForAirCraft()
        case "Hellish City":
            return MoveForHellish()
        case "Shibuya District":
            return MoveForShibuya()
        case "Sand Village":
            return MoveForSandVillage()
        case "Otherworldly Plane":
            return MoveForOtherworldlyPlane()
        case "Future City":
            return MoveForFutureCity()
        case "Strange Town":
            return MoveForStrangeTown()
        case "Sky Island":
            return MoveForSkyIsland()
        case "Sky Aircraft":
            return MoveForSkyAircraft()
        case "Walled City":
            return MoveForWalledCity()
        case "Haunted Mansion":
            return MoveForHauntedMansion()
        case "Alien Spaceship":
            return MoveForAlienSpaceship()
        case "Ruined City":
            return MoveForRuinedCity()
        case "Adventure Town":
            return MoveForAdventureTown()
        default:
            ProcessLog("No movement route for " MapName "; continuing normal placement at current position")
    }

    return true
}

MoveForSacredPlanet() {
    try {
        SummerResetSpawn()
    } catch as err {
        ProcessLog("Sacred Planet spawn reset skipped: " err.Message)
        return false
    }
    if !MapWalk("w", 4000)
        return false
    if !MapWalk("a", 2000)
        return false
    ProcessLog("Sacred Planet movement complete: teleport spawn -> W4000ms -> A2000ms; keys released")
    return true
}

MoveForGreenie() {
    if !MapWalk("aw", 2200)
        return false
    return true
}

MoveForSnowyTown() {
    ProcessLog("Snowy Town movement: D2820ms -> W1500ms")
    if !MapWalk("d", 2820)
        return false
    Sleep(200)
    if !MapWalk("w", 1500)
        return false
    ProcessLog("Snowy Town movement complete; keys released")
    return true
}

MoveForRainVillage() {
    ProcessLog("Rain Village movement: A520ms -> S405ms -> A1790ms -> S380ms -> A655ms")
    if !MapWalk("a", 520)
        return false
    Sleep(150)
    if !MapWalk("s", 405)
        return false
    Sleep(150)
    if !MapWalk("a", 1790)
        return false
    Sleep(150)
    if !MapWalk("s", 380)
        return false
    Sleep(150)
    if !MapWalk("a", 655)
        return false
    ProcessLog("Rain Village movement complete; keys released")
    return true
}

MoveForDungeonThrone() {
    ProcessLog("Dungeon Throne movement: D6000ms")
    if !MapWalk("d", 6000)
        return false
    ProcessLog("Dungeon Throne movement complete; all movement keys released")
    return true
}

MoveForSnowyKingdom() {
    ProcessLog("Snowy Kingdom movement: W3500ms -> D2000ms -> W1950ms -> A350ms")
    if !MapWalk("w", 3500)
        return false
    Sleep(150)
    if !MapWalk("d", 640)
        return false
    Sleep(150)
    if !MapWalk("d", 1360)
        return false
    Sleep(150)
    if !MapWalk("w", 1950)
        return false
    Sleep(150)
    if !MapWalk("a", 350)
        return false
    ProcessLog("Snowy Kingdom movement complete; keys released")
    return true
}

MoveForNavyBay() {
    if !MapWalk("aw", 1700)
        return false
    return true
}

MoveForFiendCity() {
    ProcessLog("Fiend City movement: S300ms -> A4075ms -> S2600ms -> D1140ms")
    if !MapWalk("s", 300)
        return false
    Sleep(200)
    if !MapWalk("a", 4075)
        return false
    Sleep(200)
    if !MapWalk("s", 2600)
        return false
    Sleep(200)
    if !MapWalk("d", 1140)
        return false
    ProcessLog("Fiend City movement complete; keys released")
    return true
}

MoveForSpiritWorld() {
    ProcessLog("Spirit World movement: W1150ms -> D970ms -> W1525ms -> D3780ms -> W1670ms")
    if !MapWalk("w", 1150)
        return false
    Sleep(200)
    if !MapWalk("d", 970)
        return false
    Sleep(200)
    if !MapWalk("w", 1525)
        return false
    Sleep(200)
    if !MapWalk("d", 3780)
        return false
    Sleep(200)
    if !MapWalk("w", 1670)
        return false
    ProcessLog("Spirit World movement complete; keys released")
    return true
}

MoveForAntKingdom() {
    ProcessLog("Ant Kingdom movement: A+S5000ms")
    if !MapWalk("as", 5000)
        return false
    ProcessLog("Ant Kingdom movement: A+S released; wait500ms")
    Sleep(500)
    ProcessLog("Ant Kingdom movement: A+W6000ms")
    if !MapWalk("aw", 6000)
        return false
    ProcessLog("Ant Kingdom movement: A+W released; wait500ms")
    Sleep(500)
    ProcessLog("Ant Kingdom movement complete; all movement keys released")
    return true
}

MoveForMagicTown() {
    ProcessLog("Magic Town movement: D2640ms -> S1160ms -> D3750ms")
    if !MapWalk("d", 2640)
        return false
    Sleep(200)
    if !MapWalk("s", 1160)
        return false
    Sleep(200)
    if !MapWalk("d", 3750)
        return false
    ProcessLog("Magic Town movement complete; keys released")
    return true
}

MoveForMagicHill() {
    if !MapWalk("w", 200)
        return false
    Sleep(500)
    if !MapWalk("wd", 2000)
        return false
    Sleep(500)
    if !MapWalk("w", 9500)
        return false
    Sleep(600)
    return true
}

MoveForHauntedAcademy() {
    ProcessLog("Haunted Academy movement: D4860ms")
    if !MapWalk("d", 4860)
        return false
    ProcessLog("Haunted Academy movement complete; keys released")
    return true
}

MoveForSpaceCenter() {
    ProcessLog("Space Center movement: W550ms -> A3185ms -> S3080ms")
    if !MapWalk("w", 550)
        return false
    Sleep(200)
    if !MapWalk("a", 3185)
        return false
    Sleep(200)
    if !MapWalk("s", 3080)
        return false
    ProcessLog("Space Center movement complete; keys released")
    return true
}

MoveForMountainTemple() {
    ProcessLog("Mountain Temple movement: S780ms -> A1580ms")
    if !MapWalk("s", 780)
        return false
    Sleep(200)
    if !MapWalk("a", 1580)
        return false
    ProcessLog("Mountain Temple movement complete; keys released")
    return true
}

MoveForCursedFestival() {
    if !MapWalk("a", 1800)
        return false
    return true
}

MoveForNightmareTrain() {
    if !MapWalk("a", 1800)
        return false
    return true
}

MoveForAirCraft() {
    if !MapWalk("w", 800)
        return false
    return true
}

MoveForHellish() {
    if !MapMovementReady()
        return false
    FixClick(600, 300, "Right")
    Sleep(7000)
    return true
}

MoveForShibuya() {
    if FindText(&x, &y, 220, 190, 320, 250, 0.15, 0.15, ShibuyaAngle) {
        if !MapWalk("a", 600)
            return false
        Sleep(500)
        return MapWalk("aw", 1500)
    }
    return MapWalk("d", 2000)
}

MoveForMistyVillage() {
    ProcessLog("Misty Village: spawn position confirmed (no map walk needed)")
    return true
}

MoveForSandVillage() {
    ProcessLog("Sand Village movement")
    if !MapWalk("s", 550)
        return false
    Sleep(150)
    if !MapWalk("d", 2520)
        return false
    Sleep(150)
    if !MapWalk("s", 540)
        return false
    Sleep(150)
    if !MapWalk("d", 340)
        return false
    Sleep(150)
    if !MapWalk("s", 1950)
        return false
    Sleep(150)
    if !MapWalk("a", 1040)
        return false
    Sleep(150)
    if !MapWalk("s", 250)
        return false
    Sleep(150)
    if !MapWalk("a", 1260)
        return false
    Sleep(150)
    if !MapWalk("s", 1950)
        return false
    ProcessLog("Sand Village movement complete; keys released")
    return true
}

MoveForOtherworldlyPlane() {
    ProcessLog("Otherworldly Plane movement")
    if !MapWalk("s", 2150)
        return false
    Sleep(150)
    if !MapWalk("a", 3000)
        return false
    Sleep(150)
    if !MapWalk("s", 4100)
        return false
    Sleep(150)
    if !MapWalk("a", 680)
        return false
    Sleep(150)
    if !MapWalk("s", 370)
        return false
    Sleep(150)
    if !MapWalk("a", 725)
        return false
    Sleep(150)
    if !MapWalk("s", 3700)
        return false
    ProcessLog("Otherworldly Plane movement complete; keys released")
    return true
}

MoveForFutureCity() {
    ProcessLog("Future City movement: W3280ms -> D240ms -> W1490ms")
    if !MapWalk("w", 3280)
        return false
    Sleep(150)
    if !MapWalk("d", 240)
        return false
    Sleep(150)
    if !MapWalk("w", 1490)
        return false
    ProcessLog("Future City movement complete; keys released")
    return true
}

MoveForStrangeTown() {
    ProcessLog("Strange Town movement: D1660ms -> S540ms")
    if !MapWalk("d", 1660)
        return false
    Sleep(150)
    if !MapWalk("s", 540)
        return false
    ProcessLog("Strange Town movement complete; keys released")
    return true
}

MoveForSkyIsland() {
    ProcessLog("Sky Island movement: W7320ms -> A9580ms")
    if !MapWalk("w", 7320)
        return false
    Sleep(150)
    if !MapWalk("a", 9580)
        return false
    ProcessLog("Sky Island movement complete; keys released")
    return true
}

MoveForSkyAircraft() {
    ProcessLog("Sky Aircraft movement: S966ms")
    if !MapWalk("s", 966)
        return false
    ProcessLog("Sky Aircraft movement complete; keys released")
    return true
}

MoveForWalledCity() {
    ProcessLog("Walled City movement: A1130ms -> S540ms")
    if !MapWalk("a", 1130)
        return false
    Sleep(150)
    if !MapWalk("s", 540)
        return false
    ProcessLog("Walled City movement complete; keys released")
    return true
}

MoveForHauntedMansion() {
    ProcessLog("Haunted Mansion movement")
    if !MapWalk("w", 320)
        return false
    Sleep(150)
    if !MapWalk("a", 1600)
        return false
    Sleep(150)
    if !MapWalk("s", 400)
        return false
    Sleep(150)
    if !MapWalk("a", 240)
        return false
    Sleep(150)
    if !MapWalk("s", 1800)
        return false
    Sleep(150)
    if !MapWalk("d", 865)
        return false
    Sleep(150)
    if !MapWalk("s", 805)
        return false
    Sleep(150)
    if !MapWalk("d", 560)
        return false
    ProcessLog("Haunted Mansion movement complete; keys released")
    return true
}

MoveForAlienSpaceship() {
    ProcessLog("Alien Spaceship movement: A560ms -> W1350ms")
    if !MapWalk("a", 560)
        return false
    Sleep(150)
    if !MapWalk("w", 1350)
        return false
    ProcessLog("Alien Spaceship movement complete; keys released")
    return true
}

MoveForRuinedCity() {
    ProcessLog("Ruined City movement")
    if !MapWalk("wd", 830)
        return false
    Sleep(150)
    if !MapWalk("d", 3300)
        return false
    Sleep(150)
    if !MapWalk("w", 255)
        return false
    Sleep(150)
    if !MapWalk("d", 360)
        return false
    ProcessLog("Ruined City movement complete; keys released")
    return true
}

MoveForAdventureTown() {
    ProcessLog("Adventure Town movement")
    if !MapWalk("wd", 1420)
        return false
    Sleep(150)
    if !MapWalk("w", 1960)
        return false
    Sleep(150)
    if !MapWalk("d", 2535)
        return false
    Sleep(150)
    if !MapWalk("w", 690)
        return false
    Sleep(150)
    if !MapWalk("a", 600)
        return false
    ProcessLog("Adventure Town movement complete; keys released")
    return true
}

ResolveSelectedMap() {
    global mode, StoryDropdown, LegendDropDown, RaidDropdown, MapDropdown, PortalDropdown
    try {
        if (IsSet(mode) && (mode = "Misty Village" || mode = "Misty Infinite"))
            return "Misty Village"
        if (IsSet(mode) && (mode = "Farm" || mode = "Infinity Castle" || mode = "Infinity Mansion" || mode = "Summer Event" || mode = "Cursed Womb" || mode = "Artifacts" || mode = "Dungeon" || mode = "Daily Infinite Quest"))
            return mode
        if (IsSet(mode) && mode = "Story" && IsSet(StoryDropdown) && StoryDropdown.Text != "")
            return StoryDropdown.Text
        if (IsSet(mode) && mode = "Infinite" && IsSet(MapDropdown) && MapDropdown.Text != "")
            return MapDropdown.Text
        if (IsSet(mode) && mode = "Legend" && IsSet(LegendDropDown) && LegendDropDown.Text != "")
            return WorldCardEntry(LegendDropDown.Text,"legend")["map"]
        if (IsSet(mode) && mode = "Raid" && IsSet(RaidDropdown) && RaidDropdown.Text != "")
            return RaidDropdown.Text
        if (IsSet(mode) && mode = "Portal" && IsSet(PortalDropdown) && PortalDropdown.Text != "")
            return PortalDropdown.Text
        if (IsSet(StoryDropdown) && StoryDropdown.Visible && StoryDropdown.Text != "")
            return StoryDropdown.Text
        if (IsSet(LegendDropDown) && LegendDropDown.Visible && LegendDropDown.Text != "")
            return WorldCardEntry(LegendDropDown.Text,"legend")["map"]
        if (IsSet(RaidDropdown) && RaidDropdown.Visible && RaidDropdown.Text != "")
            return RaidDropdown.Text
        if (IsSet(MapDropdown) && MapDropdown.Text != "")
            return MapDropdown.Text
    }
    return ""
}

RestartStage(knownMap := "") {
    global mode, SummerMapName, SummerMapInterrupted
    global MansionMapName
    global successfulCoordinates, BossRoomCompleted, CARD_ACTION_BUSY, CARD_INPUT_BLOCKED

    ; Reset per-match global state
    successfulCoordinates := []
    ResetSmartPlacementState()
    BossRoomCompleted := false
    ClearCardOffer()
    CARD_ACTION_BUSY := false
    CARD_INPUT_BLOCKED := false

    fallbackMap := (knownMap != "") ? knownMap : ResolveSelectedMap()
    currentMap := mode="Summer Event" ? DetectMap(65000) : (knownMap != "" ? knownMap : DetectMap())
    if (currentMap = "lobby" || currentMap = "reconnected")
        return currentMap

    if (currentMap = "no map found" || currentMap = "không tìm thấy map") {
        if (fallbackMap != "" && fallbackMap != "no map found" && fallbackMap != "không tìm thấy map") {
            currentMap := fallbackMap
            ProcessLog("Map cover recognition unavailable; using selected map from GUI: " currentMap)
        } else {
            ProcessLog("Map data unavailable: running setup and normal placement at spawn")
        }
    }

    if mode = "Infinity Mansion"
        MansionMapName := currentMap="no map found" || currentMap="không tìm thấy map" ? "" : currentMap
    if mode="Summer Event" && SummerMapInterrupted
        return false

    status := CheckLoaded()
    if (status = "lobby" || status = "reconnected")
        return status
    if status = "result"
        return MonitorEndScreen()

    if mode="Summer Event" {
        coverMap:=ParseSummerMapName(currentMap)
        CloseLeaderboard()
        Sleep(200)
        CloseChat()
        Sleep(200)
        started := StartedGame()
        if (started = "lobby" || started = "reconnected")
            return started
        if !started
            return false
        PlacementCamera()
        ; The health-bar map title is only visible after Vote Start.
        SummerMapName:=DetectSummerMap(5000)
        if SummerMapInterrupted
            return false
        if SummerMapName="" && coverMap!="" {
            SummerMapName:=coverMap
            ProcessLog("Summer Event: post-start title unreadable; using current loading cover: " coverMap)
        } else if SummerMapName!="" && coverMap!="" && SummerMapName!=coverMap {
            ProcessLog("Summer Event: in-map title overrides loading cover: " SummerMapName)
        }
        currentMap:=SummerMapName!="" ? SummerMapName : "Summer Event"
    }

    matchId := BeginCardMatch(currentMap)
    try {
        if mode != "Summer Event" {
            CloseLeaderboard()
            Sleep(200)
            CloseChat()
            Sleep(200)
            if (currentMap != "không tìm thấy map" && currentMap != "no map found") {
                if !HandleMapMovement(currentMap)
                    return false
            }
            started := StartedGame()
            if (started = "lobby" || started = "reconnected")
                return started
            if !started
                return false
            PlacementCamera()
        } else {
            if !HandleMapMovement(currentMap) || !MapMovementReady()
                return false
        }

        placement := PlacingUnits()
        if (placement = "replay" || placement = "lobby" || placement = "reconnected" || placement = "handled")
            return placement
        if !placement && mode = "Summer Event"
            ProcessLog("Summer Event: placement stopped; continuing to monitor cards and match results")
        return MonitorStage()
    } finally {
        EndCardMatch("stage-exit", matchId)
    }
}

JoinUrl(link) {
    link := Trim(link)
    if (link = "")
        return "roblox://placeID=8304191830"
    if RegExMatch(link, "i)[?&]privateServerLinkCode=([a-z0-9_-]+)(?:&|$)", &code)
        return "roblox://experiences/start?placeId=8304191830&linkCode=" code[1]
    if RegExMatch(link, "i)[?&]code=([a-z0-9_-]+)(?:&|$)", &code)
        return "roblox://experiences/start?placeId=8304191830&linkCode=" code[1]
    if InStr(link, "roblox://")
        return link
    return "roblox://placeID=8304191830"
}

IsDisconnected() {
    global rblxID, Disconnect
    ; 1. FindText Disconnect template
    if FindText(&X, &Y, 330, 218, 474, 247, 0, 0, Disconnect)
        return true

    ; 2. OCR check dialog header (245, 170, 310, 65)
    try {
        targetWin := WinExist(rblxID)
        if !targetWin
            targetWin := WinExist("Roblox")
        if targetWin {
            WinGetClientPos(&cx, &cy, &cw, &ch, targetWin)
            if (cw > 0 && ch > 0) {
                sx := cw / 800, sy := ch / 600
                txt := OCR.FromRect(cx + Round(245 * sx), cy + Round(170 * sy), Round(310 * sx), Round(65 * sy), "en-US", 2).Text
                if RegExMatch(txt, "i)disconnected|join\s*error|connection\s*failed|teleport\s*failed")
                    return true
            }
        }
    }

    ; 3. Check if Roblox window / process terminated
    if !WinExist(rblxID) && !WinExist("Roblox") && !ProcessExist("RobloxPlayerBeta.exe")
        return true

    return false
}

RelaunchRobloxToLobby() {
    global rblxID, AreaText
    EndCardMatch("relaunch-lobby")
    psLink := FileExist("Settings\PrivateServer.txt") ? FileRead("Settings\PrivateServer.txt", "UTF-8") : ""
    targetUrl := JoinUrl(psLink)
    ProcessLog("Launching Roblox to lobby URL: " targetUrl)

    try ProcessClose("RobloxPlayerBeta.exe")
    closeDeadline := A_TickCount + 5000
    while ProcessExist("RobloxPlayerBeta.exe") && (A_TickCount < closeDeadline) {
        try ProcessClose("RobloxPlayerBeta.exe")
        Sleep(300)
    }
    Sleep(1500)

    Run(targetUrl)

    waitStart := A_TickCount
    newRblxHwnd := 0
    while (A_TickCount - waitStart < 120000) {
        Sleep(1000)
        targetWin := WinExist("ahk_exe RobloxPlayerBeta.exe")
        if !targetWin
            targetWin := WinExist("Roblox")
        if targetWin {
            newRblxHwnd := RefreshClientTarget(targetWin)
            if newRblxHwnd {
                try WinActivate(rblxID)
                Sleep(500)
                forceRobloxSize()
                moveRobloxWindow()
                ProcessLog("Roblox window recovered; waiting for lobby...")
                break
            }
        }
    }

    if !newRblxHwnd {
        ProcessLog("Recovery error: Roblox window failed to launch after 120s")
        return false
    }

    lobbyWait := A_TickCount
    while (A_TickCount - lobbyWait < 180000) {
        Sleep(2000)
        RefreshClientTarget()
        if IsDisconnected() {
            ProcessLog("Encountered connection error while loading lobby")
            return false
        }
        if WinActive(rblxID) && FindText(&X, &Y, 746, 514, 789, 530, 0, 0, AreaText) {
            ProcessLog("Successfully loaded into lobby; ready for next run")
            Sleep(2000)
            return true
        }
        if RegExMatch(SummerReadUI(), "i)\barea\b|\bsummon\b|\bevolve\b|\bquests\b") {
            ProcessLog("Successfully loaded into lobby (OCR confirmed); ready for next run")
            Sleep(2000)
            return true
        }
    }

    ProcessLog("Lobby wait timed out after 180s")
    return false
}

Reconnect(&handled := false) {
    handled := false

    if (!IsDisconnected())
        return false

    ProcessLog("Disconnected - reconnecting...")
    loop 2 {
        if RelaunchRobloxToLobby() {
            handled := true
            return "reconnected"
        }
        Sleep(2000)
    }
    ProcessLog("Reconnect failed after retries; returning to main loop")
    return false
}

RecoverToLobby() {
    ProcessLog("Timeout/stuck state detected - executing RecoverToLobby()...")
    if RelaunchRobloxToLobby()
        return "lobby"
    return false
}

PlaceUnit(x, y, slot := 1, &abilityDone := false) {
    global rblxID, mode, AutoAbilityBox
    abilityDone := false
    static nextServiceAt := 0

    if (A_TickCount >= nextServiceAt) {
        if (IsSet(mode) && mode = "Summer Event")
            ServiceSummerCards(true)
        if !UnitActionAllowed()
            return "interrupted"
        nextServiceAt := A_TickCount + 700
    } else if !WinActive(rblxID) {
        return "interrupted"
    }

    oldMouseMode := A_CoordModeMouse
    CoordMode "Mouse", "Client"
    try {
        if IsUnitPanelOpenFast() {
            SendEvent("q")
            Sleep(35)
            CloseUnitPanel()
        }
        SendEvent("{" slot "}")
        Sleep(70)
        FixClick(x, y)
        confirmed := UnitPlaced(&abilityDone)
        if (confirmed = false)
            SendEvent("q")
        return confirmed
    } finally {
        CoordMode "Mouse", oldMouseMode
    }
}

MaxUpgrade(&current := -1, panelKnown := false) {
    global MaxText, MaxText2
    if !panelKnown
        Sleep(80)
    current := ReadUnitUpgradeLevel(panelKnown)
    if (current = 999 || current = 21)
        return true

    ; Capys fast button/label check: (160, 368, 100, 24) "max" & (145, 270, 125, 65) "maxupgrade"
    maxBtnTxt := CapysOcrRect(160, 368, 100, 24, 4, true)
    if RegExMatch(maxBtnTxt, "i)^\s*max\s*$")
        return true
    if (current < 0) {
        maxUpgradeTxt := StrLower(RegExReplace(CapysOcrRect(145, 270, 125, 65, 3, true), "[^A-Za-z]", ""))
        if InStr(maxUpgradeTxt, "maxupgrade")
            return true
        static unavailable := Map()
        for image in ["Images\MaxTag.png", "Images\MaxButton.png"] {
            try {
                if FileExist(image) && ImageSearch(&mX, &mY, 110, 249, 309, 442, "*50 " image)
                    return true
            } catch {
                if !unavailable.Has(image) {
                    ProcessLog("Max marker unavailable: " image "; continuing with text checks")
                    unavailable[image] := true
                }
            }
        }
        try return !!((IsSet(MaxText) && FindText(&X, &Y, 0, 150, 600, 500, 0.15, 0.15, MaxText))
            || (IsSet(MaxText2) && FindText(&X, &Y, 0, 150, 600, 500, 0.15, 0.15, MaxText2)))
    }
    return false
}

UnitPlaced(&abilityDone := false) {
    global rblxID, mode, AutoAbilityBox
    abilityDone := false
    interrupted := false
    Sleep(100)

    loop 4 {
        if !WinActive(rblxID)
            return "uncertain"

        if IsUnitPanelOpenFast(&pKind, &kx, &ky) {
            if (IsSet(mode) && InStr(mode, "Misty") && DismissDefensePanel()) {
                SendEvent("q")
                return false
            }
            ProcessLog("Unit placement confirmed (" pKind " panel)")
            if (!IsSet(mode) || mode != "Summer Event" || !ServiceSummerCards()) {
                if AutoAbilityBox.Value
                    CheckAbility()
                abilityDone := true
            }
            CloseUnitPanel()
            return true
        }
        Sleep(80)
    }

    if CheckPlacementLimit() {
        ProcessLog("Placement limit reached (unique/max limit)")
        SendEvent("q")
        return "limit"
    }
    if FindSmartPlacementPanel() {
        ProcessLog("Unit placement confirmed (smart panel)")
        if AutoAbilityBox.Value
            CheckAbility()
        abilityDone := true
        CloseUnitPanel()
        return true
    }
    if (CapysResultScreenVisible())
        return "ended"
    if (IsSet(mode) && mode = "Summer Event" && ServiceSummerCards())
        interrupted := true
    return interrupted || !UnitActionAllowed() ? "uncertain" : false
}

RecheckSummerPlacement(x, y, originalWindow) {
    global rblxID
    if SmartPreviewInterrupted(true) || !UnitActionAllowed()
        return "uncertain"
    try WinGetClientPos(&cx, &cy, &cw, &ch, rblxID)
    catch
        return "uncertain"
    if cx != originalWindow.x || cy != originalWindow.y || cw != originalWindow.w || ch != originalWindow.h
        return "uncertain"
    SendEvent("q")
    if !CloseUnitPanel() || SmartPreviewInterrupted(true) || !UnitActionAllowed()
        return "uncertain"
    try WinGetClientPos(&nx, &ny, &nw, &nh, rblxID)
    catch
        return "uncertain"
    if nx != cx || ny != cy || nw != cw || nh != ch
        return "uncertain"
    ; Select the existing unit at the original point with no slot key pressed.
    ProcessLog("Smart: rechecking the last placement after the Summer card")
    deadline := A_TickCount + 1000
    FixClick(x, y)
    confirmed := WaitForSmartPlacement(deadline)
    return confirmed = "card-interrupted" ? "uncertain" : confirmed
}

RecheckSmartPlacement(point, slot, geometry) {
    global rblxID
    if SmartPreviewInterrupted(true) || !UnitActionAllowed()
        return "uncertain"
    if SmartPlacementGeometry() != geometry || WinExist(rblxID) != point.window
        return "uncertain"

    oldMouseMode := A_CoordModeMouse
    CoordMode "Mouse", "Client"
    try {
        ; Clear the ghost before opening a panel at the original point.
        SendEvent("q")
        if !CloseUnitPanel() || SmartPreviewInterrupted(true) || !UnitActionAllowed()
            return "uncertain"
        if SmartPlacementGeometry() != geometry || WinExist(rblxID) != point.window
            return "uncertain"
        FixClick(point.x, point.y)
        confirmed := WaitForSmartPlacement(A_TickCount + 1000, 0, geometry, point.window)
        if SmartPlacementGeometry() != geometry || WinExist(rblxID) != point.window || !UnitActionAllowed()
            return "uncertain"
        if confirmed = true && point.count = "" {
            CheckAbility()
            CloseUnitPanel()
            return true
        }
        if confirmed = "uncertain" || confirmed = "card-interrupted" || point.count = ""
            return "uncertain"

        ; A panel can belong to a nearby unit. Check the selected slot when a baseline exists.
        if confirmed && !CloseUnitPanel()
            return "uncertain"
        if !SmartPressSlotKey(slot)
            return "uncertain"
        try {
            count := SmartReadSelectedCount(slot)
            if count = "" || SmartReadSelectedCount(slot) != count
                return "uncertain"
            if SmartPlacementGeometry() != geometry || WinExist(rblxID) != point.window || !UnitActionAllowed()
                return "uncertain"
        } finally {
            if !SmartPreviewInterrupted(true) && UnitActionAllowed()
                SendEvent("q")
        }
        if count = point.count
            return false
        if count = point.count + 1 {
            if SmartPlacementGeometry() != geometry || WinExist(rblxID) != point.window
                || SmartPreviewInterrupted(true) || !UnitActionAllowed()
                return true
            FixClick(point.x, point.y)
            if WaitForSmartPlacement(A_TickCount + 1000, 0, geometry, point.window) = true && UnitActionAllowed() {
                CheckAbility()
                CloseUnitPanel()
            }
            return true
        }
        return "uncertain"
    } finally {
        CoordMode "Mouse", oldMouseMode
    }
}

FastPixelIsRed(hdc, x, y) {
    c := DllCall("gdi32\GetPixel", "Ptr", hdc, "Int", x, "Int", y, "UInt")
    return c != 0xFFFFFFFF && (c & 255) > 160 && ((c >> 8) & 255) < 90 && ((c >> 16) & 255) < 100
}

FastPixelIsWhite(hdc, x, y, minVal := 170) {
    c := DllCall("gdi32\GetPixel", "Ptr", hdc, "Int", x, "Int", y, "UInt")
    return c != 0xFFFFFFFF && Min(c & 255, (c >> 8) & 255, (c >> 16) & 255) > minVal
}

IsUnitPanelOpenFast(&panelKind := "", &closeX := 0, &closeY := 0) {
    panelKind := "", closeX := 0, closeY := 0
    if !CapysGetClientBox(&cx, &cy, &cw, &ch, &targetWin) || !WinActive("ahk_id " targetWin)
        return false
    sx := cw / 800, sy := ch / 599
    hdc := DllCall("user32\GetDC", "Ptr", 0, "Ptr")
    if !hdc
        return false
    try {
        ; Exclude Shop/End overlays covering top-right
        if FastPixelIsRed(hdc, cx + Round(670 * sx), cy + Round(135 * sy))
            && FastPixelIsWhite(hdc, cx + Round(670 * sx), cy + Round(147 * sy))
            return false

        ; Compact Panel: (265, 222) red & (277, 228) white
        if FastPixelIsRed(hdc, cx + Round(265 * sx), cy + Round(222 * sy))
            && FastPixelIsWhite(hdc, cx + Round(277 * sx), cy + Round(228 * sy)) {
            panelKind := "compact"
            closeX := 277, closeY := 228
            return true
        }

        ; Legacy Panel: [[317, 188], [329, 176], [339, 188]] red & (329, 188) white
        for pt in [[317, 188], [329, 176], [339, 188]] {
            if !FastPixelIsRed(hdc, cx + Round(pt[1] * sx), cy + Round(pt[2] * sy))
                return false
        }
        if FastPixelIsWhite(hdc, cx + Round(329 * sx), cy + Round(188 * sy), 180) {
            panelKind := "legacy"
            closeX := 329, closeY := 188
            return true
        }
    } finally {
        DllCall("user32\ReleaseDC", "Ptr", 0, "Ptr", hdc)
    }
    return false
}

FindUnitPanel(&panelX := 0, &panelY := 0) {
    global rblxID, UnitPanelUsesNewUI, mode
    UnitPanelUsesNewUI := false
    if !CapysGetClientBox(&cx, &cy, &cw, &ch, &targetWin) || !WinActive("ahk_id " targetWin)
        return false
    if IsUnitPanelOpenFast(&kind, &kx, &ky) {
        if (IsSet(mode) && InStr(mode, "Misty") && IsDefensePanelOpen())
            return false
        UnitPanelUsesNewUI := (kind = "compact")
        panelX := Round(160 * cw / 800), panelY := Round(375 * ch / 599)
        return true
    }
    if FindSmartPlacementPanel() {
        UnitPanelUsesNewUI := true
        panelX := Round(160*cw/800), panelY := Round(375*ch/599)
        return true
    }
    ; Plain green/cyan blocks also occur in map scenery (observed: Navy Bay
    ; water at310,93). Require the actual upgrade header and panel controls.
    return FindUpdatedUnitPanel(&panelX, &panelY)
}

FindUpdatedUnitPanel(&panelX := 0, &panelY := 0) {
    global rblxID, UnitPanelUsesNewUI
    if !WinActive(rblxID)
        return false
    WinGetClientPos(&cx, &cy, &cw, &ch, rblxID)
    sx := cw / 800, sy := ch / 599
    try {
        text := OCR.FromRect(cx, cy + Round(160*sy), Round(305*sx), Round(285*sy), "en-US", 2).Text
        WinGetClientPos(&nx,&ny,&nw,&nh,rblxID)
        if !WinActive(rblxID) || nx!=cx || ny!=cy || nw!=cw || nh!=ch
            return false
        if RegExMatch(text, "i)ancient\s*defen[cs]e|\bdestroy\b")
            return false
        hasControls := !!RegExMatch(text, "i)\bf[i1l]r[s5][t7]\b|\bs[e3][l1i]{2}\b")
        hasUpgrade := !!RegExMatch(text, "i)\b(?:upgrade|upg)\b")
        hasHeader := ParseUnitUpgradeLevel(text) >= 0
        ; The grey, unaffordable Upgrade button still has its header and controls.
        if ((hasUpgrade || hasHeader) && hasControls) {
            UnitPanelUsesNewUI := true
            panelX := Round(160*sx), panelY := Round(375*sy)
            return true
        }
    }
    return false
}

CloseUnitPanel(force := false, fastPanel := false) {
    global mode
    if !CapysGetClientBox(&cx, &cy, &cw, &ch, &targetWin) || !WinActive("ahk_id " targetWin)
        return false

    isOpen := IsUnitPanelOpenFast(&kind, &kx, &ky)
    if (!isOpen) {
        if (force && IsSet(mode) && InStr(mode, "Misty") && IsDefensePanelOpen()) {
            DismissDefensePanel()
            return !IsUnitPanelOpenFast()
        }
        if !force
            return true
    }

    oldMouseMode := A_CoordModeMouse
    CoordMode "Mouse", "Screen"
    try {
        loop 3 {
            if !IsUnitPanelOpenFast(&kind, &kx, &ky) {
                if (!force || A_Index > 1)
                    return true
                kx := 638, ky := 549
            }
            if !CapysGetClientBox(&cx, &cy, &cw, &ch, &targetWin) || !WinActive("ahk_id " targetWin)
                return false
            sx := cw / 800, sy := ch / 599
            FixClick(cx + Round(kx * sx), cy + Round(ky * sy))
            Sleep(60)
            if !IsUnitPanelOpenFast()
                return true
        }
    } finally {
        CoordMode "Mouse", oldMouseMode
    }
    return !IsUnitPanelOpenFast() && WinActive("ahk_id " targetWin)
}

CheckAbility() {
    global AutoAbilityBox, rblxID

    ; Only check ability if checkbox is checked
    ; The unit panel sits on the left (Show Upgrade UI on left), so the old
    ; fixed band 342,253-401,281 was to the right of the real toggle. FindText
    ; never matched and a live Summer run never logged "Auto-ability is on".
    ; Search the whole panel band, use the real toggle crop, and confirm the ON
    ; state before reporting success.

    if !AutoAbilityBox.Value
        return false

    if !WinActive(rblxID)
        return false

    static offImg := "GameModeImages\SummerQuantum\vision\auto-ability-off.png"
    static onImg := "GameModeImages\SummerQuantum\vision\auto-ability-on.png"
    static lastMissing := 0

    WinGetClientPos(,, &cw, &ch, rblxID)
    if (cw <= 0 || ch <= 0)
        return false

    sx := cw / 800, sy := ch / 599
    x1 := Round(250 * sx), y1 := Round(238 * sy), x2 := Round(440 * sx), y2 := Round(302 * sy)

    oldMouseMode := A_CoordModeMouse, oldPixelMode := A_CoordModePixel
    CoordMode "Mouse", "Client"
    CoordMode "Pixel", "Client"

    try {
        ; Never toggle a switch that is already on.
        if FileExist(onImg) && ImageSearch(&onX, &onY, x1, y1, x2, y2, "*40 " onImg)
            return true

        toggle := 0
        if FileExist(offImg) && ImageSearch(&fx, &fy, x1, y1, x2, y2, "*40 " offImg)
            toggle := { x: fx, y: fy, w: 48, h: 18, mode: "image" }
        else if FindText(&fx, &fy, x1, y1, x2, y2, 0, 0, AutoOff)
            toggle := { x: fx, y: fy, w: 18, h: 24, mode: "findtext" }

        if !IsObject(toggle) {
            if (A_TickCount - lastMissing > 30000) {
                lastMissing := A_TickCount
                ProcessLog("Auto Ability: toggle not found in the unit panel; left unchanged")
                ; Leave readable evidence instead of guessing a click point.
                try {
                    WinGetClientPos(&cx, &cy,,, rblxID)
                    band := OCR.FromRect(cx + x1, cy + y1, x2 - x1, y2 - y1, "en-US", 3).Text
                    if Trim(band) != ""
                        ProcessLog("Auto Ability: panel text was " StrReplace(Trim(band), "`n", " | "))
                }
            }
            return false
        }

        ; The crop contains the switch, so its centre is the target. The old
        ; FindText bitmap is the label, which used to be clicked 20px above.
        clickX := toggle.mode = "image" ? Round(toggle.x + toggle.w / 2) : toggle.x
        clickY := toggle.mode = "image" ? Round(toggle.y + toggle.h / 2) : toggle.y - 20
        FixClick(clickX, clickY)
        Sleep(400)

        if FileExist(onImg) && ImageSearch(&onX, &onY, x1, y1, x2, y2, "*40 " onImg) {
            ProcessLog("Auto-ability is on")
            return true
        }

        ProcessLog("Auto Ability: clicked the toggle but ON was not confirmed")
        return false
    } finally {
        CoordMode "Mouse", oldMouseMode
        CoordMode "Pixel", oldPixelMode
    }
}

; ==============================================================================
; Capys OCR Detection Suite (Vote Start, Wave, Result, Reward, End Choice)
; ==============================================================================
RefreshClientTarget(preferHwnd := 0) {
    global rblxID
    hwnd := preferHwnd ? WinExist("ahk_id " preferHwnd) : 0
    if !hwnd && IsSet(rblxID) && rblxID != ""
        hwnd := WinExist(rblxID)
    if !hwnd
        hwnd := WinExist("ahk_exe RobloxPlayerBeta.exe")
    if !hwnd
        hwnd := WinExist("Roblox")
    if hwnd {
        newId := "ahk_id " hwnd
        if (!IsSet(rblxID) || rblxID != newId) {
            rblxID := newId
            ProcessLog("Refreshed Roblox client target: " rblxID)
        }
        return hwnd
    }
    return 0
}

CapysGetClientBox(&cx := 0, &cy := 0, &cw := 0, &ch := 0, &targetWin := 0) {
    hwnd := RefreshClientTarget()
    targetWin := hwnd
    if !targetWin
        return false
    try {
        WinGetClientPos(&cx, &cy, &cw, &ch, "ahk_id " targetWin)
        return (cw >= 400 && ch >= 300)
    }
    return false
}

CapysOcrRect(rx, ry, rw, rh, scale := 2, tryContrast := true) {
    if !CapysGetClientBox(&cx, &cy, &cw, &ch)
        return ""
    sx := cw / 800, sy := ch / 599
    sxX := cx + Round(rx * sx)
    sxY := cy + Round(ry * sy)
    sxW := Max(8, Round(rw * sx))
    sxH := Max(8, Round(rh * sy))
    text := ""
    try text := Trim(OCR.FromRect(sxX, sxY, sxW, sxH, "en-US", scale).Text)
    if (text = "" && tryContrast) {
        try text := Trim(ReadHighContrastText(sxX, sxY, sxW, sxH, Min(Max(scale, 2), 4), 0, false))
    }
    return text
}

CapysNormalize(text) {
    return StrReplace(StrLower(RegExReplace(text, "[^a-zA-Z0-9]", "")), "repeat", "replay")
}

CapysReadVote(&x, &y, &boardVisible := false) {
    boardVisible := false
    if !CapysGetClientBox(&cx, &cy, &cw, &ch)
        return false
    text := CapysOcrRect(290, 25, 230, 125, 2, true)
    if (text = "")
        return false
    norm := CapysNormalize(text)
    titleVisible := !!InStr(norm, "votestart")
    boardVisible := titleVisible || (RegExMatch(text, "i)\byes\b") && RegExMatch(text, "i)\bno\b"))
    if titleVisible && (InStr(norm, "yes") || InStr(norm, "startsin") || RegExMatch(text, "\d+\s*/\s*\d+")) {
        sx := cw / 800, sy := ch / 599
        x := cx + Round(353 * sx)
        y := cy + Round(104 * sy)
        return true
    }
    return false
}

CapysReadWave() {
    text := CapysOcrRect(140, 60, 220, 65, 3, true)
    if RegExMatch(text, "i)\bWave\s*:?\s*([1-9]\d{0,3})\b", &m)
        return Integer(m[1])
    return -1
}

CapysReadResult(&nextVisible := false) {
    text := CapysOcrRect(125, 150, 390, 275, 2, true)
    nextVisible := !!RegExMatch(text, "im)^\h*next\h*$")
    if (text = "")
        return ""
    norm := CapysNormalize(text)
    if InStr(norm, "victory") && (InStr(norm, "next") || InStr(norm, "xpprogress") || InStr(norm, "rewards") || InStr(norm, "stageclear"))
        return "victory"
    if InStr(norm, "defeat") || InStr(norm, "gameover")
        return "defeat"
    return ""
}

CapysReadReward() {
    for crop in [[200, 420, 400, 100, 2], [200, 445, 400, 45, 3]] {
        norm := CapysNormalize(CapysOcrRect(crop[1], crop[2], crop[3], crop[4], crop[5], true))
        if RegExMatch(norm, "(?:c[l1i][i1l]ck|tap)any(?:w|vv)here(?:t[o0])?c[o0]nt[i1l]nue")
            return true
    }
    return false
}

CapysReadChoice(confirmButtons := true) {
    norm := CapysNormalize(CapysOcrRect(130, 80, 545, 110, 2, true))
    if (norm = "")
        return 0
    res := Map("kind", "none", "hasNextLevel", 0, "hasNextRoom", 0, "hasNextFloor", 0, "hasNextPortal", 0, "hasRetry", 0, "replayX", 0, "nextLevelX", 0, "lobbyX", 0, "ownerWait", 0)
    if InStr(norm, "picknextportal") && InStr(norm, "returntolobby") {
        res["kind"] := "choice", res["hasNextPortal"] := 1, res["replayX"] := 488
    } else if RegExMatch(norm, "nextf[l1i]oor") && InStr(norm, "returntolobby") {
        res["kind"] := "choice", res["hasNextFloor"] := 1, res["nextLevelX"] := 488, res["lobbyX"] := 312
    } else if InStr(norm, "nextroom") && InStr(norm, "returntolobby") {
        res["kind"] := "choice", res["hasNextRoom"] := 1, res["nextLevelX"] := 488, res["lobbyX"] := 312
    } else if InStr(norm, "replay") && (InStr(norm, "nextlevel") || InStr(norm, "returntolobby")) {
        res["kind"] := "choice"
        res["hasNextLevel"] := InStr(norm, "nextlevel") ? 1 : 0
        res["replayX"] := res["hasNextLevel"] ? 400 : 488
        res["nextLevelX"] := res["hasNextLevel"] ? 576 : 0
        res["lobbyX"] := res["hasNextLevel"] ? 224 : 312
    } else if InStr(norm, "retry") && InStr(norm, "returntolobby") {
        res["kind"] := "choice", res["hasRetry"] := 1, res["replayX"] := 488, res["lobbyX"] := 312
    } else if InStr(norm, "returntolobby") {
        res["kind"] := "choice", res["lobbyX"] := 400
    } else {
        return 0
    }
    res["ownerWait"] := InStr(norm, "waitingforowner") ? 1 : 0
    if !confirmButtons
        return res

    ; Xac minh toa do chinh xac cac nut tai hang y=99..143 (Capys ConfirmReplayButton)
    for bx in [224, 312, 400, 488, 576] {
        btnText := CapysNormalize(CapysOcrRect(bx - 77, 99, 154, 44, 3, true))
        if (btnText = "")
            continue
        if InStr(btnText, "returntolobby") || InStr(btnText, "return")
            res["lobbyX"] := bx
        else if RegExMatch(btnText, "replay|retry")
            res["replayX"] := bx
        else if RegExMatch(btnText, "nextlevel|nextf[l1i]oor|nextroom|picknextportal")
            res["nextLevelX"] := bx
    }
    return res
}

CapysResultScreenVisible() {
    if CapysReadResult(&nextVisible) != ""
        return true
    ; A covered result title can still leave both summary controls visible.
    if nextVisible && InStr(CapysNormalize(CapysOcrRect(520, 105, 250, 90, 2, true)), "xpprogress")
        return true
    return CapysReadReward() || IsObject(CapysReadChoice(false))
}

ParseUnitUpgradeLevel(text) {
    if (text = "")
        return -1

    clean := StrUpper(Trim(text))

    ; 1. Nhan dien MAX (UPG [MAX], UPG MAX, (MAX), MAX, vv.)
    if RegExMatch(clean, "i)\bMAX\b|\(\s*MAX\s*\)|\[\s*MAX\s*\]")
        return 999

    ; 2. Nhan dien UPG [N] hoac Upgrade [N] hoac UPG (N) hoac Upgrade (N)
    ; Co sua loi OCR ky tu so: O/o -> 0, I/l/i -> 1
    if RegExMatch(clean, "i)\b(?:UPGRADE|UPG)\s*[\[(]?\s*([0-9OIL]+)\s*[\])]?", &m) {
        val := m[1]
        val := StrReplace(val, "O", "0")
        val := StrReplace(val, "I", "1")
        val := StrReplace(val, "L", "1")
        if IsInteger(val) {
            num := Integer(val)
            return (num >= 0 && num <= 20) ? num : -1
        }
    }

    ; 3. Nhan dien UPG N hoac Upgrade N (khong co ngoac)
    if RegExMatch(clean, "i)\b(?:UPGRADE|UPG)\s+([0-9OIL]+)\b", &m) {
        val := m[1]
        val := StrReplace(val, "O", "0")
        val := StrReplace(val, "I", "1")
        val := StrReplace(val, "L", "1")
        if IsInteger(val) {
            num := Integer(val)
            return (num >= 0 && num <= 20) ? num : -1
        }
    }

    ; 4. Dang rut gon o header rieng biet: [N] hoac (N) hoac N
    if RegExMatch(clean, "^[\[(]?\s*([0-9OIL]+)\s*[\])]?$", &m) {
        val := m[1]
        val := StrReplace(val, "O", "0")
        val := StrReplace(val, "I", "1")
        val := StrReplace(val, "L", "1")
        if IsInteger(val) {
            num := Integer(val)
            return (num >= 0 && num <= 20) ? num : -1
        }
    }

    return -1
}

ReadUnitUpgradeLevel(panelKnown := false) {
    global rblxID, UnitPanelUsesNewUI
    if !panelKnown && !FindUnitPanel(&panelX, &panelY)
        return -1
    if !CapysGetClientBox(&cx, &cy, &cw, &ch)
        return -1
    sx := cw / 800, sy := ch / 599
    if panelKnown || (IsSet(UnitPanelUsesNewUI) && UnitPanelUsesNewUI) {
        ; 1. Fast primary crop (145, 233, 62, 20) scale 2 (~40-80ms)
        try {
            txt := OCR.FromRect(cx + Round(145*sx), cy + Round(233*sy), Max(8, Round(62*sx)), Max(8, Round(20*sy)), "en-US", 2).Text
            lvl := ParseUnitUpgradeLevel(txt)
            if (lvl >= 0)
                return lvl
        }
        ; 2. Capys gold/orange mask (r>130 && g>85 && b<150 && r>b*1.4) at (145, 235, 50, 15) scale 3
        try {
            lvl := ParseUnitUpgradeLevel(ReadHighContrastText(cx + Round(145*sx), cy + Round(235*sy), Max(8, Round(50*sx)), Max(8, Round(15*sy)), 3, 0, false, false, true))
            if (lvl >= 0)
                return lvl
        }
        ; 3. Fallback wider crop (140, 230, 120, 28) scale 4 only if both failed
        try {
            txt := OCR.FromRect(cx + Round(140*sx), cy + Round(230*sy), Max(8, Round(120*sx)), Max(8, Round(28*sy)), "en-US", 4).Text
            lvl := ParseUnitUpgradeLevel(txt)
            if (lvl >= 0)
                return lvl
        }
        return -1
    }
    ; Use the detected panel, not experience levels or upgrade prices elsewhere.
    left := Max(0, panelX - 220), top := Max(0, panelY - 260)
    right := Min(cw, panelX + 250), bottom := Min(ch, panelY + 60)
    try {
        text := OCR.FromRect(cx + left, cy + top, right - left, bottom - top, "en-US", 2).Text
        return ParseUnitUpgradeLevel(text)
    } catch {
        return -1
    }
}

PressUnitUpgrade() {
    if !UnitActionAllowed(true)
        return false
    SendEvent("{r down}")
    Sleep(80)
    SendEvent("{r up}")
    return true
}

ApplyUnitUpgradeLimit(limit, slot, current) {
    if (limit = "MAX" || limit = "" || limit = "0" || limit = "OFF")
        return PressUnitUpgrade()
    numericLimit := Integer(limit)
    if current < 0 {
        ProcessLog("Slot " slot ": could not read Upgrade [n]; skipping unverified upgrade")
        return false
    }
    if current >= numericLimit
        return "limit"
    if !PressUnitUpgrade()
        return false
    Sleep(200)
    if !UnitActionAllowed()
        return false
    confirmed := ReadUnitUpgradeLevel(true)
    if confirmed <= current {
        ProcessLog("Slot " slot ": upgrade increment not confirmed; stopping this upgrade pass")
        return false
    }
    return confirmed >= numericLimit ? "limit" : true
}

UpgradeUnit(x, y, slot := 0, &panelClear := false) {
    global rblxID, PriorityUpgrade
    window := WinActive(rblxID)
    if !window || !UnitActionAllowed() {
        panelClear := false
        return false
    }
    oldMouseMode := A_CoordModeMouse
    CoordMode "Mouse", "Client"
    result := false, selected := false, fastPanel := false
    try {
        if !panelClear {
            SendEvent("q")
            if !UnitActionAllowed() || !CloseUnitPanel()
                return false
        }
        if !UnitActionAllowed(true) || WinActive(rblxID) != window {
            panelClear := false
            return false
        }

        selected := true, panelClear := false
        FixClick(x, y)
        settleUntil := A_TickCount + 500
        loop 3 {
            Sleep(200)
            if !UnitActionAllowed()
                return false
            if FindSmartPlacementPanel() {
                fastPanel := true
                break
            }
        }
        if !fastPanel && !FindUpdatedUnitPanel() {
            ProcessLog("Upgrade panel not found at " x "," y "; waiting for another pass without offset clicks")
            return false
        }

        ; Preserve the earliest MAX read without adding a second delay after a late panel.
        remaining := settleUntil - A_TickCount
        if remaining > 0
            Sleep(remaining)
        if !UnitActionAllowed()
            return false
        if MaxUpgrade(&current, true) {
            result := "max"
        } else {
            limit := GetUnitUpgradeLimit(slot)
            result := limit <= 0 ? PressUnitUpgrade() : ApplyUnitUpgradeLimit(limit, slot, current)
        }
        if (PriorityUpgrade.Value || (result != "max" && result != "limit"))
            && UnitActionAllowed(true) && WinActive(rblxID) = window
            CheckAbility()
    } finally {
        try {
            ; Finish the outside click before the caller checks results and cards.
            if selected && WinActive(rblxID) = window
                panelClear := CloseUnitPanel(true, fastPanel)
        } finally {
            CoordMode "Mouse", oldMouseMode
        }
    }
    return panelClear ? result : false
}

CheckLobby() {
    waitStart := A_TickCount
    loop {
        Sleep 1000
        RefreshClientTarget()
        if (FindText(&X, &Y, 746, 514, 789, 530, 0, 0, AreaText)) {
            break
        }
        Reconnect(&reconnected)
        if reconnected
            return "reconnected"
        if (A_TickCount - waitStart >= 60000) {
            ProcessLog("CheckLobby timed out after 60s; recovering to lobby...")
            return RecoverToLobby()
        }
    }
    EndCardMatch("lobby")
    ProcessLog("Returned to lobby; returning to main loop")
    return "lobby"
}

FindVoteStart(&x, &y, &boardVisible := false) {
    global rblxID, VoteStart, SummerVoteStart, MansionVoteStart, mode
    boardVisible := false
    if !CapysGetClientBox(&cx, &cy, &cw, &ch, &targetWin)
        return false
    active := !!WinActive("ahk_id " targetWin)
    ; FindText uses screen coordinates, independent of CoordMode Pixel.
    if (mode = "Summer Event") {
        sx := cw / 800, sy := ch / 599
        if active && FindText(&x, &y, cx + Round(300*sx), cy + Round(30*sy), cx + Round(505*sx), cy + Round(85*sy), 0, 0, SummerVoteStart, 1, 0, 0, 20, 10, 1, sx, sy) {
            ; Title center -> center of Yes, measured on the supplied screenshot.
            x -= Round(47*sx)
            y += Round(51*sy)
            boardVisible := true
            return true
        }
        return CapysReadVote(&x, &y, &boardVisible)
    }
    if (mode = "Infinity Mansion") {
        sx := cw / 800, sy := ch / 599
        if active && FindText(&x, &y, cx + Round(300*sx), cy + Round(30*sy), cx + Round(505*sx), cy + Round(85*sy), 0, 0, MansionVoteStart, 1, 0, 0, 20, 10, 1, sx, sy) {
            ; Title -> Yes measured on the Mansion vote screen, not its room queue.
            x -= Round(47*sx)
            y += Round(51*sy)
            boardVisible := true
            return true
        }
        return CapysReadVote(&x, &y, &boardVisible)
    }
    if CapysReadVote(&x, &y, &boardVisible)
        return true
    if !active
        return false
    return FindText(&x, &y, cx + 333, cy + 61, cx + 465, cy + 101, 0, 0, VoteStart)
}

SummerMatchStarted() {
    global rblxID, mode
    if (mode != "Summer Event" || !WinActive(rblxID))
        return false
    try {
        WinGetClientPos(&cx, &cy, &cw, &ch, rblxID)
        sx := cw / 800, sy := ch / 599
        oldPixelMode := A_CoordModePixel
        CoordMode "Pixel", "Screen"
        try {
            ; Measured in all 16 SumnmerCards screenshots: health-bar fill and border.
            if !PixelSearch(&px, &py, cx + Round(150*sx), cy + Round(54*sy), cx + Round(650*sx), cy + Round(72*sy), 0x00FF00, 0)
                return false
            if !PixelSearch(&px, &py, cx + Round(150*sx), cy + Round(54*sy), cx + Round(650*sx), cy + Round(72*sy), 0x158200, 0)
                return false
        } finally {
            CoordMode "Pixel", oldPixelMode
        }
        if CardScreenVisible()
            return true
        wave := OCR.FromRect(cx + Round(145*sx), cy + Round(68*sy), Round(160*sx), Round(35*sy), "en-US", 2).Text
        return !!RegExMatch(wave, "i)\bwave\s*([1-9]\d*)\b")
    }
    return false
}

RegularMatchHudVisible() {
    global rblxID, mode
    if mode="Summer Event" || !CapysGetClientBox(&cx, &cy, &cw, &ch, &targetWin)
        return false
    try {
        if CapysReadWave() >= 1 && !CapysResultScreenVisible()
            return true
        if !WinActive("ahk_id " targetWin)
            return false
        oldPixelMode := A_CoordModePixel
        CoordMode "Pixel","Screen"
        try {
            if !PixelSearch(&x,&y,cx+Round(cw*150/800),cy+Round(ch*54/599),
                cx+Round(cw*650/800),cy+Round(ch*72/599),0x00FF00,30)
                return false
        } finally {
            CoordMode "Pixel",oldPixelMode
        }
        cash := OCR.FromRect(cx+Round(cw*300/800),cy+Round(ch*480/599),
            Round(cw*210/800),Round(ch*32/599),"en-US",2).Text
        if !RegExMatch(cash,"i)^\s*\d[\d,.\s]*[kmb]?\s*[¥y%]?\s*$")
            return false
        WinGetClientPos(&nx,&ny,&nw,&nh,targetWin)
        return nx=cx && ny=cy && nw=cw && nh=ch && !CapysResultScreenVisible()
    }
    return false
}

CheckLoaded() {
    global mode, MatchMaking
    summer := mode = "Summer Event"
    loadStart := A_TickCount
    deadline := A_TickCount + 15000
    ProcessLog("Waiting for match to load / Vote Start...")

    loop {
        Sleep(1000)

        RefreshClientTarget()
        CapysGetClientBox(&cx, &cy, &cw, &ch, &targetWin)

        ; 1. Phát hiện Vote Start chuẩn Capys OCR (hoạt động cả khi cửa sổ macro đang focus)
        if FindVoteStart(&X, &Y) {
            if targetWin && !WinActive("ahk_id " targetWin)
                try WinActivate("ahk_id " targetWin)
            ProcessLog(summer ? "Match loaded: Summer Vote Start confirmed" : "Match loaded: Vote Start detected")
            return "loaded"
        }

        if CapysResultScreenVisible()
            return "result"

        if SummerMatchStarted() {
            ProcessLog("Summer Event: active match HUD detected; match loaded")
            return "loaded"
        }
        if !summer && (CapysReadWave() >= 1 || RegularMatchHudVisible()) {
            if targetWin && !WinActive("ahk_id " targetWin)
                try WinActivate("ahk_id " targetWin)
            ProcessLog("Match loaded: Wave / HUD confirmed")
            return "loaded"
        }

        ; 2. Kiểm tra bị đá về sảnh (chờ tối thiểu 15s khi MatchMaking bật để tránh nhận nhầm lúc đang đếm Teleport)
        lobbyGrace := (IsSet(MatchMaking) && MatchMaking.Value) ? 15000 : 3000
        if (A_TickCount - loadStart >= lobbyGrace) {
            if targetWin && WinActive("ahk_id " targetWin) && FindText(&X, &Y, 746, 514, 789, 530, 0, 0, AreaText) {
                ProcessLog("Lobby detected (match aborted or failed to teleport) - returning to main loop")
                Sleep(1000)
                return "lobby"
            }
        }

        if (A_TickCount - loadStart >= 120000) {
            ProcessLog("CheckLoaded timed out after 120s; recovering to lobby...")
            RecoverToLobby()
            return "lobby"
        }

        if (A_TickCount >= deadline) {
            ProcessLog("Still waiting for match load / Vote Start...")
            deadline := A_TickCount + 15000
        }

        Reconnect(&reconnected)
        if reconnected
            return "lobby"
    }
}

StartedGame() {
    global mode, MatchMaking, SummerMinimumPlayers, stageStartTime
    summer := mode = "Summer Event"
    lowCount := 0, lowReads := 0
    unknownLogged := false, waitingLogged := false
    loopStart := A_TickCount
    ProcessLog("Waiting for teleport and Vote Start...")

    loop {
        if A_Index > 1
            Sleep(800)
        RefreshClientTarget()
        Reconnect(&reconnected)
        if reconnected
            return "reconnected"
        if CapysResultScreenVisible() {
            ProcessLog("Vote Start interrupted by result screen; stopping placement setup")
            return false
        }
        if (A_TickCount - loopStart >= 60000) {
            ProcessLog("Vote Start timed out after 60s without starting match; returning for recovery")
            return false
        }
        if (!waitingLogged && A_TickCount - loopStart >= 30000) {
            ProcessLog("Vote Start: still waiting for a fresh vote board or active match HUD (30s)...")
            waitingLogged := true
        }

        if !CapysGetClientBox(&cx, &cy, &cw, &ch, &targetWin)
            continue
        if !FindVoteStart(&x, &y, &boardVisible) {
            if !boardVisible && WinActive("ahk_id " targetWin)
                && (summer ? SummerMatchStarted() : (CapysReadWave() >= 1 || RegularMatchHudVisible())) {
                ProcessLog("Active match confirmed without pending Vote Start")
                break
            }
            continue
        }
        if !WinActive("ahk_id " targetWin) {
            try WinActivate("ahk_id " targetWin)
            continue
        }

        if (mode = "Summer Event" && MatchMaking.Value) {
            players := ReadSummerVotePlayers()
            if !players {
                if !unknownLogged
                    ProcessLog("Summer Event: player count unreadable; waiting without voting")
                unknownLogged := true
                lowCount := 0, lowReads := 0
                continue
            }
            if (players > 0 && players < SummerMinimumPlayers) {
                lowReads := players = lowCount ? lowReads + 1 : 1
                lowCount := players
                if (lowReads >= 2) {
                    ProcessLog("Summer Event: only " players " players; returning to lobby (minimum " SummerMinimumPlayers ")")
                    ReturnSummerLowPlayers()
                    return false
                }
                continue ; confirm once more before returning, without voting
            }
            lowCount := 0, lowReads := 0
        }

        if !ClickVoteStart(targetWin, cx, cy, cw, ch, x, y)
            continue
        ProcessLog("Vote Start detected; clicked YES")
        started := WaitForVoteStartDismissal(targetWin)
        if started != true
            return started
        break
    }

    ProcessLog("Match ready; proceeding to placement")
    stageStartTime := A_TickCount
    return true
}

ClickVoteStart(targetWin, cx, cy, cw, ch, x, y) {
    global mode
    if !CapysGetClientBox(&nx, &ny, &nw, &nh, &window) || window != targetWin
        || nx != cx || ny != cy || nw != cw || nh != ch || !WinActive("ahk_id " targetWin)
        return false
    if (mode != "Summer Event" && mode != "Infinity Mansion") {
        x := cx + Round(353 * cw / 800)
        y := cy + Round(104 * ch / 599)
    }
    oldMode := A_CoordModeMouse
    CoordMode "Mouse", "Screen"
    try FixClick(x, y)
    finally CoordMode "Mouse", oldMode
    return true
}

WaitForVoteStartDismissal(targetWin) {
    lastClick := A_TickCount
    deadline := lastClick + 60000
    absent := 0
    while A_TickCount < deadline {
        Sleep(300)
        Reconnect(&reconnected)
        if reconnected
            return "reconnected"
        if CapysResultScreenVisible()
            return false
        if !CapysGetClientBox(&cx, &cy, &cw, &ch, &window) || window != targetWin || !WinActive("ahk_id " targetWin) {
            absent := 0
            continue
        }
        canVote := FindVoteStart(&x, &y, &boardVisible)
        if !CapysGetClientBox(&nx, &ny, &nw, &nh, &window) || window != targetWin
            || nx != cx || ny != cy || nw != cw || nh != ch || !WinActive("ahk_id " targetWin) {
            absent := 0
            continue
        }
        if canVote || boardVisible {
            absent := 0
            if canVote && A_TickCount - lastClick >= 900 && ClickVoteStart(targetWin, cx, cy, cw, ch, x, y)
                lastClick := A_TickCount
            continue
        }
        ; Confirm disappearance on two fresh reads from the focused game window.
        if ++absent >= 2 {
            ProcessLog("Vote Start cleared")
            return true
        }
    }
    ProcessLog("Vote Start did not dismiss after 60s; aborting placement so macro can recover")
    return false
}

PlacementCamera() {
    global rblxID, aaMainUIHwnd
    if !CapysGetClientBox(&left, &top, &cw, &ch, &targetWin)
        return

    uiAlwaysOnTop := (IsSet(aaMainUIHwnd) && aaMainUIHwnd && WinExist("ahk_id " aaMainUIHwnd))
    if uiAlwaysOnTop
        WinSetAlwaysOnTop(false, "ahk_id " aaMainUIHwnd)

    try {
        try WinActivate("ahk_id " targetWin)
        Sleep(200)
        if !CapysGetClientBox(&left, &top, &cw, &ch, &targetWin) || !WinActive("ahk_id " targetWin)
            return
        sx := cw / 800, sy := ch / 599

        prevCrit := Critical(1)
        oldMouseMode := A_CoordModeMouse
        oldMouseDelay := A_MouseDelay
        CoordMode("Mouse", "Screen")
        SetMouseDelay(-1)
        try {
            MouseMove(left + Round(400 * sx), top + Round(330 * sy), 2)
            Sleep(100)
            ; 1. Zoom in cực đại về First-Person (20 lần 2 nấc = 40 nấc)
            Loop 20 {
                if !WinActive("ahk_id " targetWin)
                    break
                SendEvent("{WheelUp 2}")
                Sleep(15)
            }
            Sleep(150)
            ; 2. Đè chuột phải và kéo góc nhìn thẳng xuống sàn đấu (Tilt Top-Down)
            if WinActive("ahk_id " targetWin) {
                SendEvent("{RButton down}")
                Sleep(80)
                moved := 0
                Loop 28 {
                    if !CapysGetClientBox(&cx2, &cy2, &cw2, &ch2, &tw2) || !WinActive("ahk_id " tw2) {
                        ProcessLog("Camera adjustment interrupted: Roblox focus/client lost")
                        break
                    }
                    delta := 0
                    if (A_Index <= 16) {
                        destination := Round(1500 * (1 - Cos(A_Index * 3.141592653589793 / 16)) / 2)
                        delta := destination - moved
                        moved := destination
                    } else if (A_Index > 24) {
                        delta := 250
                    }
                    if (delta > 0)
                        DllCall("mouse_event", "UInt", 1, "Int", 0, "Int", delta, "UInt", 0, "UPtr", 0)
                    if (A_Index >= 5 && A_Index <= 24)
                        SendEvent("{WheelDown}")
                    Sleep(A_Index <= 16 || A_Index > 24 ? 15 : 18)
                }
            }
        } finally {
            SendEvent("{RButton up}")
            SetMouseDelay(oldMouseDelay)
            CoordMode("Mouse", oldMouseMode)
            Critical(prevCrit)
        }
        ProcessLog("Camera adjusted to top-down view")
    } finally {
        if (IsSet(aaMainUIHwnd) && aaMainUIHwnd && WinExist("ahk_id " aaMainUIHwnd))
            WinSetAlwaysOnTop(true, "ahk_id " aaMainUIHwnd)
    }
}

StartSelectedMode() {
    ; Do not click arbitrary points in the 3D viewport before navigating.
    ; Those clicks rotate or move the avatar and make the fixed lobby route
    ; unreliable, especially after restoring Roblox's camera zoom.
    if (ModeDropdown.Text = "Infinite") {
        return StoryMode()
    }
    else if (ModeDropdown.Text = "Infinity Mansion") {
        return InfinityMansionMode()
    }
    else if (ModeDropdown.Text = "Summer Event") {
        return SummerEventMode()
    }
    else if (ModeDropdown.Text = "Story") {
        return StoryMode()
    }
    else if (ModeDropdown.Text = "Legend") {
        return LegendMode()
    }
    else if (ModeDropdown.Text = "Raid") {
        return RaidMode()
    }
    else if (ModeDropdown.Text = "Infinity Castle") {
        return InfinityCastleMode()
    }
    else if (ModeDropdown.Text = "Dungeon") {
        return DungeonMode()
    }
    else if (ModeDropdown.Text = "Portal") {
        return PortalMode()
    }
    else if (ModeDropdown.Text = "Farm") {
        return FarmMode()
    }
    else if (ModeDropdown.Text = "Daily Infinite Quest") {
        return InfQuestMode()
    }
    else if (ModeDropdown.Text = "Misty Village") {
        return MistyVillageMode()
    }
    else if (ModeDropdown.Text = "Misty Infinite") {
        return MistyInfiniteMode()
    }
    else if (ModeDropdown.Text = "Artifacts") {
        return ArtifactsMode()
    }
    else if (ModeDropdown.Text = "Cursed Womb") {
        return CursedWombMode()
    }
    return false
}

FormatStageTime(ms) {
    seconds := Floor(ms / 1000)
    minutes := Floor(seconds / 60)
    hours := Floor(minutes / 60)
    minutes := Mod(minutes, 60)
    seconds := Mod(seconds, 60)
    return Format("{:02}:{:02}:{:02}", hours, minutes, seconds)
}

ValidateMode() {
    ; Without a Roblox window every later step fails silently while the
    ; macro keeps sleeping for minutes. Refuse to start instead of running
    ; blind - the log used to show a 60 s "cannot find window" wait followed
    ; by 8 minutes of nothing.
    if (!WinExist("ahk_exe RobloxPlayerBeta.exe") && !WinExist("Roblox")) {
        ProcessLog("Roblox is not running - open the game, then press start")

        return false
    }

    if (ModeDropdown.Text = "") {
        ProcessLog("Choose mode, my Nigga")
        return false
    }

    if (!confirmClicked) {
        ProcessLog("Vui lòng bấm 'Confirm' để xác nhận chế độ trước khi bấm F2!")
        return false
    }
    return true
}

GetNavKeys() {
    return StrSplit(FileExist("Settings\UINavigation.txt") ? FileRead("Settings\UINavigation.txt", "UTF-8") : "\,#,}",
    ",")
}

CheckEndAndRoute(&handled := false) {
    handled := false
    if CapysResultScreenVisible() {
        handled := true
        EndCardMatch("result-route")
        ProcessLog("Found end screen")
        if (mode = "Dungeon" && !MatchMaking.Value) {
            return MonitorDungeonEnd()
        } else {
            return MonitorEndScreen()
        }
    }
}

ClickUntilGone(x, y, searchX1, searchY1, searchX2, searchY2, textToFind, offsetX := 0, offsetY := 0, textToFind2 := "") {
    while (ok := FindText(&X, &Y, searchX1, searchY1, searchX2, searchY2, 0.15, 0.15, textToFind) ||
    textToFind2 && FindText(&X, &Y, searchX1, searchY1, searchX2, searchY2, 0.15, 0.15, textToFind2)) {
        if (offsetX != 0 || offsetY != 0) {
            FixClick(X + offsetX, Y + offsetY)
        } else {
            FixClick(x, y)
        }
        Sleep(1000)
    }
}

ClickOnce(x, y, searchX1, searchY1, searchX2, searchY2, textToFind, offsetX := 0, offsetY := 0, textToFind2 := "") {
    if (ok := FindText(&X, &Y, searchX1, searchY1, searchX2, searchY2, 0.15, 0.15, textToFind) ||
    textToFind2 && FindText(&X, &Y, searchX1, searchY1, searchX2, searchY2, 0.15, 0.15, textToFind2)) {
        if (offsetX != 0 || offsetY != 0) {
            FixClick(X + offsetX, Y + offsetY)
        } else {
            FixClick(x, y)
        }
    }
}

global macroRunning := false

StartMacro(*) {
    global macroRunning, rblxID
    global successfulCoordinates, BossRoomCompleted, CARD_ACTION_BUSY, CARD_INPUT_BLOCKED

    if macroRunning {
        ProcessLog("Macro is already running")
        return
    }
    macroRunning := true
    ProcessLog("F2: starting macro (24/7 continuous run loop)...")

    try {
        if (!ValidateMode()) {
            macroRunning := false
            return
        }

        firstRun := true
        nextStep := "auto"
        while macroRunning {
            try {
                ; Verify Roblox window exists
                if !WinExist(rblxID) && !WinExist("ahk_exe RobloxPlayerBeta.exe") && !WinExist("Roblox") {
                    ProcessLog("Roblox window not found; waiting for game...")
                    Sleep(3000)
                    continue
                }
                RefreshClientTarget()

                ; Reset per-match global state
                successfulCoordinates := []
                ResetSmartPlacementState()
                BossRoomCompleted := false
                ClearCardOffer()
                CARD_ACTION_BUSY := false
                CARD_INPUT_BLOCKED := false

                res := ""
                if (nextStep = "replay") {
                    ProcessLog("Seamless Replay / Next Stage: starting stage...")
                    res := RestartStage(ResolveSelectedMap())
                } else if (nextStep = "lobby" || nextStep = "reconnected") {
                    ProcessLog("Lobby ready; starting selected mode...")
                    res := StartSelectedMode()
                } else if (firstRun) {
                    firstRun := false
                    if CapysResultScreenVisible() {
                        ProcessLog("Starting into active result screen...")
                        res := MonitorEndScreen()
                    } else if (FindVoteStart(&vx, &vy) || RegularMatchHudVisible() || SummerMatchStarted()) {
                        ProcessLog("Starting into active match...")
                        res := RestartStage()
                    } else {
                        ProcessLog("Starting selected mode...")
                        res := StartSelectedMode()
                    }
                } else {
                    status := CheckLoaded()
                    if (status = "lobby" || status = "reconnected") {
                        ProcessLog("Returned to lobby; automatically starting next match...")
                        res := StartSelectedMode()
                    } else if (status = "result") {
                        ProcessLog("Result screen detected; processing end screen...")
                        res := MonitorEndScreen()
                    } else {
                        ProcessLog("Match loaded; running stage...")
                        res := RestartStage()
                    }
                }

                if (res = "replay" || res = "lobby" || res = "reconnected") {
                    nextStep := res
                } else {
                    nextStep := "auto"
                }
            } catch as innerErr {
                ProcessLog("Macro loop error: " . innerErr.Message . " @ line " . innerErr.Line)
                nextStep := "auto"
                Sleep(2000)
            }
            Sleep(1000)
        }
    } catch as err {
        ProcessLog("StartMacro ERROR: " . err.Message . " @ line " . err.Line)
    } finally {
        macroRunning := false
        ProcessLog("Macro stopped")
    }
}

; The settings toggle pill is green (#00F058) when on and dark red (#640000)
; when off. The knob covers whichever half is not the pill colour, so sample
; the left half where "on" always shows green.
UpgradeUIToggleGreen(x, y) {
    global rblxID

    ; "Client" pixel mode resolves against whichever window happens to be
    ; active, so a focus change silently reads the wrong window. Convert the
    ; client coordinate to screen space once and read there instead.
    oldMode := A_CoordModePixel
    CoordMode "Pixel", "Screen"
    green := 0
    if WinExist(rblxID) {
        WinGetClientPos(&cx, &cy, , , rblxID)
        loop 11 {
            c := PixelGetColor(cx + x - 25 + (A_Index - 1) * 5, cy + y, "RGB")
            r := (c >> 16) & 0xFF
            g := (c >> 8) & 0xFF
            b := c & 0xFF
            if (g > 180 && r < 60 && b < 140)
                green++
        }
    }
    CoordMode "Pixel", oldMode
    return green
}

IsUpgradeUIToggleOn(x, y) {
    return UpgradeUIToggleGreen(x, y) >= 3
}

EnsureUpgradeUIOnLeft(settingsAlreadyOpen := false) {
    global rblxID, aaMainUIHwnd, ShowUpgradeUIOnLeftImg

    if !WinExist(rblxID) {
        ProcessLog("Roblox window missing; cannot verify Show Upgrade UI on left")
        return false
    }

    if (IsSet(aaMainUIHwnd) && aaMainUIHwnd && WinExist("ahk_id " aaMainUIHwnd))
        WinSetAlwaysOnTop(false, "ahk_id " aaMainUIHwnd)
    WinActivate(rblxID)
    Sleep(200)
    oldMouseMode := A_CoordModeMouse
    oldPixelMode := A_CoordModePixel
    CoordMode "Mouse", "Client"
    CoordMode "Pixel", "Client"
    settingsOpened := false
    try {
        if (!settingsAlreadyOpen) {
            FixClick(26, 570) ; Mở bảng settings của Roblox
            settingsOpened := true
            Sleep(700)
        }

        ; The panel reopens at whatever position it was last scrolled to, so
        ; start from a known baseline instead of guessing a wheel count. Fewer
        ; events with longer gaps keep the input queue from backing up and
        ; delivering the wheel-ups later, after the search has started.

        FixMove(400, 300)

        Sleep(150)
        loop 10 {
            SendInput("{WheelUp}")
            Sleep(110)
        }
        Sleep(1200)

        ; Client-mode ImageSearch also resolves against the active window.
        WinActivate(rblxID)
        Sleep(200)
        targetImg := IsSet(ShowUpgradeUIOnLeftImg) ? ShowUpgradeUIOnLeftImg : "Images\ShowUpgradeUIOnLeft_Text.png"
        if !FileExist(targetImg) {
            ProcessLog("Missing image: " targetImg)
            return false
        }

        ; Walk down one notch at a time. Only accept a position that is still
        ; there a moment later: the list keeps gliding after the last wheel, so
        ; a single hit can point at a row that is about to slide away.
        foundX := 0
        foundY := 0
        found := false
        loop 16 {
            if ImageSearch(&foundX, &foundY, 200, 150, 620, 460, "*60 " targetImg) {
                probeX := foundX
                probeY := foundY
                Sleep(650)
                if (ImageSearch(&foundX, &foundY, 200, 150, 620, 460, "*60 " targetImg)
                    && foundX = probeX && foundY = probeY) {
                    found := true
                    break
                }
            }
            FixMove(400, 300)
            SendInput("{WheelDown}")
            Sleep(320)
        }

        if !found {
            ; This step only tunes the UI. Aborting the whole match because the
            ; settings list drifted would be far worse than a wrong layout.
            ProcessLog("Could not find 'Show Upgrade UI on left' - skipping this step")
            return true
        }

        ; Toggle sits to the right of the label block, 27px below its top edge.
        toggleX := foundX + 287
        toggleY := foundY + 27
        if IsUpgradeUIToggleOn(toggleX, toggleY) {
            ProcessLog("Show Upgrade UI on left is already enabled")
            return true
        }
        WinActivate(rblxID)
        Sleep(150)
        FixClick(toggleX, toggleY)

        ; The pill slides over a few hundred ms, so poll instead of judging the
        ; state once right after the click. Re-locate the row every time in case
        ; the list drifts while we wait.
        enabled := false
        loop 8 {
            Sleep(250)
            if ImageSearch(&foundX, &foundY, 200, 150, 620, 460, "*60 " targetImg) {
                toggleX := foundX + 287
                toggleY := foundY + 27
            }

            if IsUpgradeUIToggleOn(toggleX, toggleY) {
                enabled := true
                break
            }
        }

        if enabled {
            ProcessLog("Enabled Show Upgrade UI on left")
            return true
        }
        ProcessLog("Clicked Show Upgrade UI on left but could not verify it - skipping")
        return true
    } finally {
        if (settingsOpened) {
            FixClick(581, 157) ; Đóng bảng settings
            Sleep(250)
        }
        CoordMode "Mouse", oldMouseMode
        CoordMode "Pixel", oldPixelMode
        WinActivate(rblxID)

        ; Put the macro window back on top so its title bar is what the user
        ; sees above the game.
        if (IsSet(aaMainUIHwnd) && aaMainUIHwnd && WinExist("ahk_id " aaMainUIHwnd))
            WinSetAlwaysOnTop(true, "ahk_id " aaMainUIHwnd)
    }
}

TogglePause(*) {
    Pause -1
    if (A_IsPaused) {
        ProcessLog("Macro paused")
        Sleep(1000)
    } else {
        ProcessLog("Macro resumed")
        Sleep(1000)
    }
}

IsColorInRange(color, targetColor, tolerance := 50) {
    ; Extract RGB components
    r1 := (color >> 16) & 0xFF
    g1 := (color >> 8) & 0xFF
    b1 := color & 0xFF

    ; Extract target RGB components
    r2 := (targetColor >> 16) & 0xFF
    g2 := (targetColor >> 8) & 0xFF
    b2 := targetColor & 0xFF

    ; Check if within tolerance range
    return Abs(r1 - r2) <= tolerance
    && Abs(g1 - g2) <= tolerance
    && Abs(b1 - b2) <= tolerance
}

; Custom monitor for dungeon ending

MonitorDungeonEnd() {
    res := MonitorEndScreen(true)
    if (res != "replay")
        return res
    CheckDungeonSpecials()
    finishRes := CheckForFinishDungeon()
    if finishRes
        return finishRes
    return SelectDungeonRoute()
}

; Function to check for special dungeon elements after replay

CheckDungeonSpecials() {
    ProcessLog("Checking dungeon shop, shrine, and chest options")

    ; Give time for special elements to appear
    Sleep(2000)

    ; Check the area for shop, shrine, or chest
    loop 5 {
        ; Check for shop
        if (ok := FindText(&X, &Y, 140, 200, 375, 250, 0, 0, Shop)) {
            ProcessLog("Shop found")
            Sleep(1000)
            HandleShop()
            Sleep(1000)
            return true
        }

        ; Check for shrine
        if (ok := FindText(&X, &Y, 140, 200, 375, 250, 0, 0, Shrine)) {
            ProcessLog("Shrine found; declining")
            ClickUntilGone(0, 0, 490, 420, 605, 455, DenyShrine, 0, -30)
            Sleep(1000)
            return true
        }

        ; Check for Chest Opening
        if (ok := FindText(&X, &Y, 140, 200, 375, 250, 0, 0, ChestRoom)) {
            ProcessLog("Open Chest option found")
            HandleChestScreen()
            return true
        }
        Sleep(1000)  ; Wait and check again
    }
    ProcessLog("No shop, shrine, or Open Chest option found")
    return false
}

SelectDungeonRoute() {
    if (ok := FindText(&X, &Y, 140, 180, 480, 350, 0.20, 0.20, BossRoom) or (ok := FindText(&X, &Y, 140, 180, 480, 350,
        0.20, 0.20, BossRoom2))) {
        ProcessLog("Boss room found!")
        global BossRoomCompleted := true

        FixClick(X, Y - 30)
        Sleep(1000)
    }

    if (ok := FindText(&X, &Y, 200, 350, 600, 435, 0.20, 0.20, Chest)) {
        ProcessLog("Chest room found; clicking")
        FixClick(X, Y - 30)
        Sleep(1000)
    }
    else if (ok := FindText(&X, &Y, 200, 350, 600, 435, 0.20, 0.20, Hoard)) {
        ProcessLog("Hoard Room found; clicking")
        FixClick(X, Y - 30)
        Sleep(1000)
    }
    else {
        ; If no chest/hoard found, click default positions
        ProcessLog("No chest/hoard found; clicking the default position again")
        FixClick(400, 355)
        Sleep(500)
        FixClick(335, 355)
        Sleep(500)
    }

    ; Look for Enter button and click until gone
    if (ok := FindText(&X, &Y, 120, 425, 680, 500, 0.20, 0.20, Enter)) {
        ProcessLog("Enter button found; entering Dungeon")
        ClickUntilGone(0, 0, 120, 425, 680, 500, Enter, 0, -30)
        Sleep(2000)

        ; Start dungeon run
        ProcessLog("Starting dungeon")
        return "replay"
    }
    return false
}

HandleShop() {
    Sleep(1000)
    ProcessLog("Buying in shop")

    ; Give the shop time to fully load
    Sleep(1000)

    ; Buy item in slot 3 (bottom)
    FixClick(560, 335)
    Sleep(1000)

    ; Buy item in slot 2 (middle)
    FixClick(560, 280)
    Sleep(1000)

    ; Buy item in slot 1 (top)
    FixClick(560, 225)
    Sleep(1000)

    ; Click continue to close the shop
    ProcessLog("Close shop")
    ClickUntilGone(0, 0, 380, 385, 615, 490, DungeonContinue, -3, -35)
    Sleep(1000)
    return true
}

HandleChestScreen() {
    global BossRoomCompleted, SaveChestsForBoss

    ; Determine if we should open chests now
    shouldOpenChests := BossRoomCompleted || !SaveChestsForBoss
    if (shouldOpenChests) {
        ProcessLog("Opening available chests")

        ; Process first chest position - keep clicking until exhausted
        firstChestExhausted := false
        while (!firstChestExhausted) {
            ; Click first chest OPEN button
            ClickOnce(0, 0, 535, 265, 605, 315, OpenChest, -3, -35)
            Sleep(2000)

            ; Check if we're still on the chest screen
            if (!IsChestScreenVisible()) {
                ClaimChestReward()
            } else {
                firstChestExhausted := true
            }
        }

        ; Process second chest position - keep clicking until exhausted
        secondChestExhausted := false
        while (!secondChestExhausted) {
            ; Click second chest OPEN button
            ClickOnce(0, 0, 530, 330, 605, 375, OpenChest, -3, -35)
            Sleep(1000)

            ; Check if we're still on the chest screen
            if (!IsChestScreenVisible()) {
                ClaimChestReward()
            } else {
                secondChestExhausted := true
            }
        }
        ProcessLog("All chests opened")

        ; Reset the boss room flag if it was set
        if (BossRoomCompleted) {
            BossRoomCompleted := false
            ClickUntilGone(0, 0, 380, 385, 615, 490, DungeonContinue, -3, -35)
        }
    } else {
        ; Skip opening chests, just click continue
        ProcessLog("Saving chests for boss room - clicking continue")
        ClickUntilGone(0, 0, 380, 385, 615, 490, DungeonContinue, -3, -35)
    }
    Sleep(1000)
    Reconnect()
    return true
}

ClaimChestReward() {
    maxClicks := 30  ; Safety limit
    clicks := 0
    while (clicks < maxClicks) {
        ; Click to claim reward
        FixClick(560, 560)
        Sleep(500)

        ; Check if chest screen has returned
        if (IsChestScreenVisible()) {
            return true
        }
        clicks++
    }
    ProcessLog("All rewards collected")
    return false
}

IsChestScreenVisible() {
    return FindText(&X, &Y, 140, 200, 375, 250, 0, 0, ChestRoom)
}

CheckForFinishDungeon() {
    ; Check for the finish dungeon popup
    if (ok := FindText(&X, &Y, 240, 180, 565, 480, 0, 0, FinishDungeon) or (ok := FindText(&X, &Y, 310, 395, 495, 440,
        0.20, 0.20, EnterDungeon))) {

        ; Click the Finish button
        ClickUntilGone(0, 0, 240, 180, 565, 480, DungeonFinish, -3, -35)
        Sleep(1500)

        ; Click the X in the top right
        ClickUntilGone(0, 0, 640, 175, 700, 205, DungeonRedX, -3, -35)
        Sleep(1000)

        ; Return to lobby
        ProcessLog("Returning to lobby after completing Dungeon")
        ClickReturnToLobby()

        ; Check for lobby and restart
        return CheckLobby()
    }
    return false
}
