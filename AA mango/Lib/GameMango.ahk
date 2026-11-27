#Requires AutoHotkey v2.0

global macroStartTime := A_TickCount
global stageStartTime := A_TickCount
global BossRoomCompleted := false
global ResultCounted := false
global TransitionCoverMap := ""
global DailyQuestMap := ""
global SaveChestsForBoss := IsSet(SaveChestsBox) ? !!SaveChestsBox.Value : true
global UpgradePauseEpoch := 0

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

PreparePlacementTerrain(entry) {
    if !entry.scanTerrain
        return true
    if A_TickCount < entry.scanAt
        return false
    points := SmartScanGreenPoints(entry.slot)
    entry.scanAt := A_TickCount + 2000
    if !IsObject(points)
        return false
    if !points.Length && entry.kind = "Hill" {
        if ++entry.emptyScans >= 3 {
            entry.exhausted := true
            ProcessLog("Slot " entry.slot ": no hill platform found in three confirmed previews")
        }
        return false
    }
    entry.emptyScans := 0
    entry.greenOnly := points.Length > 0
    entry.points := entry.greenOnly ? points : GenerateSmartPoints(&scale, entry.slot, "spiral")
    entry.nextIdx := 1
    entry.scanTerrain := !entry.points.Length
    return !entry.scanTerrain
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
        kind := GetUnitPlacementType(slot)
        custom := IsSet(UnitPlacements) && UnitPlacements.Has(slot) && UnitPlacements[slot].Length > 0
        scanTerrain := !custom && (kind = "Hill" || kind = "Hybrid")
        if custom {
            ProcessLog("Unit " slot ": using CUSTOM positions from map (" UnitPlacements[slot].Length " points)")
            for pt in UnitPlacements[slot]
                targetPoints.Push({x: pt[1], y: pt[2]})
        } else if !scanTerrain {
            targetPoints := GenerateSmartPoints(&scale,slot)
            if !targetPoints.Length {
                ProcessLog("Unit " slot ": placement geometry unavailable")
                return false
            }
            ProcessLog("Unit " slot ": " (kind = "Farm" ? "outside-in placement rings" : "center-out placement spiral"))
        }
        slots := kind = "Farm" ? farmSlots : otherSlots
        slots.Push({slot:slot, kind:kind, target:count, placed:0, points:targetPoints, nextIdx:1,
            limitHit:false, exhausted:false, scanTerrain:scanTerrain, greenOnly:false, scanAt:0, emptyScans:0})
    }

    pendingSlots := farmSlots.Length ? farmSlots : otherSlots
    if !pendingSlots.Length {
        ProcessLog("No Units Selected - Returning")
        return FormatHandledRoute(MonitorStage())
    }

    ProcessLog("Starting placement...")
    placedTotal := 0
    lastAfkTick := A_TickCount
    lastPlacementAt := A_TickCount
    nextCheckAt := 0

    loop {
        if (A_TickCount >= nextCheckAt) {
            if (CapysResultScreenVisible(1000)) {
                return FormatHandledRoute(HandleStageResult())
            }
            if mode = "Daily Infinite Quest" && (route := DailyInfiniteWaveRoute())
                return FormatHandledRoute(route)
            if (IsSet(mode) && mode = "Summer Event")
                ServiceSummerCards()
            Reconnect(&reconnected)
            if reconnected
                return "reconnected"
            nextCheckAt := A_TickCount + 700
        }

        if (A_TickCount - lastAfkTick >= 60000) {
            if UnitActionAllowed(true)
                FixClick(560, 560)
            lastAfkTick := A_TickCount
        }

        placedInPass := 0

        for entry in pendingSlots {
            if (entry.limitHit || entry.exhausted || entry.placed >= entry.target)
                continue
            if !PreparePlacementTerrain(entry)
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
                idx := entry.nextIdx
                entry.nextIdx := Mod(idx, ptsLen) + 1
                checkedAll++
                pt := entry.points[idx]

                ; Capys 24px minimum hitbox spacing to avoid clicking existing units
                if IsPointNearPlaced(pt.x, pt.y, 24)
                    continue

                anyFreeSpot := true
                abilityDone := false
                result := PlaceUnit(pt.x, pt.y, entry.slot, &abilityDone, entry.greenOnly)
                if (result = "ended") {
                    return FormatHandledRoute(HandleStageResult())
                }
                if (result = "limit") {
                    ProcessLog("Slot " entry.slot ": Placement limit reached (unique/max reached); finishing slot")
                    entry.limitHit := true
                    break
                }
                if (result = true) {
                    lastPlacementAt := A_TickCount
                    entry.placed++
                    placedTotal++
                    placedInPass++
                    successfulCoordinates.Push({x: pt.x, y: pt.y, slot: entry.slot, misses: 0, priorityDone: false, abilityDone: abilityDone})
                    ProcessLog("Placed Unit " entry.slot " (" entry.placed "/" entry.target ") at " pt.x "," pt.y)
                } else {
                    attemptsThisPass++
                }

                if (A_TickCount >= nextCheckAt) {
                    if (CapysResultScreenVisible(1000)) {
                        return FormatHandledRoute(HandleStageResult())
                    }
                    if mode = "Daily Infinite Quest" && (route := DailyInfiniteWaveRoute())
                        return FormatHandledRoute(route)
                    if (IsSet(mode) && mode = "Summer Event")
                        ServiceSummerCards()
                    Reconnect(&reconnected)
                    if reconnected
                        return "reconnected"
                    nextCheckAt := A_TickCount + 700
                }

                if entry.greenOnly && idx = ptsLen && entry.placed < entry.target {
                    if entry.kind = "Hybrid" {
                        entry.points := GenerateSmartPoints(&scale, entry.slot, "spiral")
                        entry.greenOnly := false
                        entry.scanTerrain := !entry.points.Length
                    } else
                        entry.scanTerrain := true
                    break
                }
                ; If lacking Yen / terrain failed 2 tries this pass, rotate to next slot instead of stalling
                if (attemptsThisPass >= 2)
                    break
            }

            if (!anyFreeSpot && entry.placed < entry.target && !entry.limitHit) {
                if entry.greenOnly && entry.kind = "Hybrid" {
                    entry.points := GenerateSmartPoints(&scale, entry.slot, "spiral")
                    entry.greenOnly := false, entry.nextIdx := 1
                    entry.scanTerrain := !entry.points.Length
                    continue
                }
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
            lastPlacementAt := A_TickCount
            continue
        }
        if A_TickCount - lastPlacementAt >= 120000 {
            ProcessLog("No new placement in 120s; moving on with " placedTotal " units placed")
            if pendingSlots == otherSlots || !otherSlots.Length
                break
            pendingSlots := otherSlots
            lastPlacementAt := A_TickCount
            continue
        }

        if !placedInPass
            Sleep(500)
    }

    ProcessLog("Placed total: " placedTotal "/" requestedTotal " units")
    return UpgradeUnits()
}

ProcessUpgradeUnitAt(idx, &anyUpgradedInPass, &routeOut) {
    global successfulCoordinates, mode, rblxID
    static nextCheckAt := 0
    routeOut := ""
    coord := successfulCoordinates[idx]
    if coord.HasOwnProp("retryAt") && A_TickCount < coord.retryAt
        return "next"

    if (A_TickCount >= nextCheckAt || !WinActive(rblxID)) {
        if (CapysResultScreenVisible(1000)) {
            successfulCoordinates := []
            routeOut := FormatHandledRoute(HandleStageResult())
            return "stop"
        }
        if (IsSet(mode) && mode = "Summer Event")
            ServiceSummerCards()
        if mode = "Daily Infinite Quest" && (route := DailyInfiniteWaveRoute()) {
            routeOut := FormatHandledRoute(route)
            return "stop"
        }
        Reconnect(&handled)
        if handled {
            routeOut := "reconnected"
            return "stop"
        }
        nextCheckAt := A_TickCount + 1000
    }

    res := UpgradeSingleUnit(coord.x, coord.y, coord.slot, coord)
    if (res = "ended" || CapysResultScreenVisible(1000)) {
        successfulCoordinates := []
        routeOut := FormatHandledRoute(HandleStageResult())
        return "stop"
    }
    if (IsSet(mode) && mode = "Summer Event")
        ServiceSummerCards()
    if (res = "max" || res = "limit") {
        reached := res = "max" ? "MAX" : "configured Max Level"
        ProcessLog("Unit slot " coord.slot " at " coord.x "," coord.y " reached " reached)
        successfulCoordinates.RemoveAt(idx)
        anyUpgradedInPass := true
        return "removed"
    }
    if (res = "no-panel" || res = "panel-blocked") {
        coord.misses := coord.HasOwnProp("misses") ? coord.misses + 1 : 1
        coord.retryAt := A_TickCount + 2000
        if (coord.misses = 1 || Mod(coord.misses, 5) = 0) {
            reason := res = "panel-blocked" ? "previous panel did not close" : "could not open its upgrade panel"
            ProcessLog("Unit slot " coord.slot " at " coord.x "," coord.y " " reason "; will retry")
        }
        return "next"
    }
    coord.misses := 0
    if (res = true)
        anyUpgradedInPass := true
    return "next"
}

UpgradeUnits() {
    global successfulCoordinates, PriorityUpgrade, mode

    if (!successfulCoordinates.Length) {
        ProcessLog("No placed units to upgrade; monitoring stage...")
        return FormatHandledRoute(MonitorStage())
    }

    ProcessLog("Starting unit upgrades...")

    lastPrioritySlot := 0
    while (successfulCoordinates.Length) {
        if (CapysResultScreenVisible(1000)) {
            ProcessLog("Stage ended during upgrade cycle; proceeding to results")
            successfulCoordinates := []
            return FormatHandledRoute(HandleStageResult())
        }

        if (IsSet(mode) && mode = "Summer Event")
            ServiceSummerCards()

        Reconnect(&handled)
        if handled
            return "reconnected"

        anyUpgradedInPass := false

        prioritySlot := PriorityUpgrade.Value ? NextUpgradePrioritySlot() : 0
        if prioritySlot && prioritySlot != lastPrioritySlot
            ProcessLog("Upgrade priority: slot " prioritySlot)
        lastPrioritySlot := prioritySlot

        i := 1
        while (i <= successfulCoordinates.Length) {
            if prioritySlot && successfulCoordinates[i].slot != prioritySlot {
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

        if (!anyUpgradedInPass) {
            Sleep(1000)
        }
    }

    ProcessLog("Upgrade targets confirmed for all placed units; monitoring stage...")
    return FormatHandledRoute(MonitorStage())
}

NextUpgradePrioritySlot() {
    global successfulCoordinates, priority1, priority2, priority3, priority4, priority5, priority6
    selected := 0
    best := 7
    for coord in successfulCoordinates {
        control := "priority" coord.slot
        rank := %control%.Text
        if !IsInteger(rank) || rank < 1 || rank > 6
            continue
        if rank < best || (rank = best && coord.slot < selected) {
            best := rank
            selected := coord.slot
        }
    }
    return selected
}

UpgradeSingleUnit(x, y, slot, coord := 0) {
    global rblxID, AutoAbilityBox, mode, UpgradePauseEpoch
    view := {window: WinActive(rblxID), geometry: SmartPlacementGeometry(), pauseEpoch: UpgradePauseEpoch}
    if !view.window || view.geometry = "" || !UpgradeViewStable(view)
        return false
    if CapysResultScreenVisible()
        return "ended"
    if !UnitActionAllowed()
        return CapysResultScreenVisible() ? "ended" : false

    oldMouseMode := A_CoordModeMouse
    CoordMode "Mouse", "Client"
    panelOpened := false, clickedUnit := false, ended := false
    try {
        ; Only cancel/close when a panel or ghost might actually be open.
        if IsUnitPanelOpenFast() || FindSmartPlacementPanel() {
            SendEvent("q")
            Sleep(35)
            if !UpgradeViewStable(view)
                return false
            if !CloseUpgradeSelection(view)
                return UpgradeViewStable(view) ? "panel-blocked" : false
            if !UpgradeViewStable(view)
                return false
        }

        FixClick(x, y)
        clickedUnit := true
        panelFrames := 0
        loop 4 {
            Sleep(70)
            if !UpgradeViewStable(view)
                return false
            if !IsUnitPanelOpenFast() && !FindSmartPlacementPanel() {
                panelFrames := 0
                continue
            }
            if ++panelFrames >= 2 {
                panelOpened := true
                break
            }
        }
        if (IsSet(mode) && InStr(mode, "Misty") && DismissDefensePanel())
            return "no-panel"
        if !panelOpened
            return "no-panel"

        ; Run Auto Ability ONCE per unit
        if !IsObject(coord) || !coord.HasOwnProp("abilityDone") || !coord.abilityDone {
            if AutoAbilityBox.Value
                CheckAbility()
            if IsObject(coord)
                coord.abilityDone := true
        }
        if !UpgradeViewStable(view)
            return false

        limit := GetUnitUpgradeLimit(slot)
        isMaxLimit := (limit = "MAX" || limit = "" || limit = "0" || limit = "OFF")
        targetLevel := isMaxLimit ? 999 : Integer(limit)

        beforeLevel := -1
        if MaxUpgrade(&beforeLevel)
            return "max"
        if !UpgradeViewStable(view)
            return false
        if (!isMaxLimit && beforeLevel < 0)
            return false
        if (!isMaxLimit && beforeLevel >= targetLevel)
            return "limit"

        ; Capys Batch Upgrade: keep panel open and press R up to 8 times per visit
        prevLvl := beforeLevel
        upgradedCount := 0
        staleCount := 0
        pressIdx := 0
        maxBatch := isMaxLimit ? 8 : Max(1, Min(8, targetLevel - Max(0, beforeLevel)))

        while (pressIdx < maxBatch) {
            if !UpgradeViewStable(view)
                return false
            if (!IsUnitPanelOpenFast() && !FindSmartPlacementPanel())
                break
            if !PressUnitUpgrade(view)
                return false

            Sleep(300)
            pressIdx++

            if CapysResultScreenVisible(1000) {
                ended := true
                return "ended"
            }
            if (IsSet(mode) && mode = "Summer Event")
                ServiceSummerCards()
            if !UpgradeViewStable(view)
                return false

            ; Read level on every press for numeric targets, or at 1, 2, 4, 6, 8 for MAX
            if (!isMaxLimit || pressIdx = 1 || Mod(pressIdx, 2) = 0 || pressIdx = maxBatch) {
                afterLevel := -1
                isMax := MaxUpgrade(&afterLevel)
                if !UpgradeViewStable(view)
                    return false
                if isMax
                    return "max"
                if (!isMaxLimit && afterLevel >= 0 && afterLevel >= targetLevel)
                    return "limit"

                if ((prevLvl >= 0 && afterLevel > prevLvl) || (prevLvl < 0 && afterLevel > 0)) {
                    upgradedCount++
                    prevLvl := afterLevel
                    staleCount := 0
                } else {
                    staleCount += (!isMaxLimit || pressIdx = 1) ? 1 : 2
                    if (staleCount >= 2)
                        break ; Insufficient Yen -> stop batch early
                }
            }
        }

        return upgradedCount > 0
    } finally {
        try {
            if clickedUnit && !ended && UpgradeViewStable(view)
                CloseUpgradeSelection(view, true)
        } finally {
            CoordMode "Mouse", oldMouseMode
        }
    }
}

UpgradeViewStable(view) {
    global rblxID, UpgradePauseEpoch
    return !SmartPreviewInterrupted() && WinActive(rblxID) = view.window
        && SmartPlacementGeometry() = view.geometry && UpgradePauseEpoch = view.pauseEpoch
}

CloseUpgradeSelection(view, clickOutside := false) {
    if !UpgradeViewStable(view)
        return false
    if !IsUnitPanelOpenFast() && !FindSmartPlacementPanel()
        return UpgradeViewStable(view)
    ; Close via red X in CloseUnitPanel() first; only click outside as fallback if panel stayed open
    if !CloseUnitPanel() && clickOutside {
        try {
            WinGetClientPos(,, &width, &height, "ahk_id " view.window)
            if UpgradeViewStable(view) {
                FixClick(Round(638 * width / 800), Round(549 * height / 599))
                Sleep(60)
            }
        }
    }
    return UpgradeViewStable(view) && !IsUnitPanelOpenFast() && !FindSmartPlacementPanel() && UpgradeViewStable(view)
}

ReadUpgradeVisitStatus(view, targetLevel, &level) {
    maxed := MaxUpgrade(&level)
    if !UpgradeViewStable(view)
        return "retry"
    ; MAX may retry R on the freshly confirmed panel without a numeric read.
    ; A numeric cap needs a readable level before R to avoid overshooting.
    if !maxed && level < 0 && targetLevel != 999
        return "retry"
    if !maxed && level < targetLevel
        return false
    ; Require the same completion result from a fresh panel read.
    Sleep(70)
    if !UpgradeViewStable(view)
        return "retry"
    stillMax := MaxUpgrade(&confirmedLevel)
    if !UpgradeViewStable(view) || maxed != stillMax || (!stillMax && confirmedLevel < targetLevel)
        return "retry"
    return stillMax ? "max" : "limit"
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
    if !MapWalk("w", 3050) || !MapWalk("wa", 1216)
        return false
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
    if !MapWalk("sd", 2530)
        return false
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
    if !MapWalk("w", 1500)
        return false
    Sleep(150)
    if !MapWalk("d", 500)
        return false
    Sleep(150)
    if !MapWalk("w", 1000)
        return false
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
    global MatchMaking
    view := LobbyEntryView()
    if !IsObject(view)
        return false
    for step in [["s",4851,516],["a",4346,959],["w",268,1491]] {
        if !WorldViewValid(view) || !MapWalk(step[1],step[2])
            return false
        Sleep(step[3])
    }
    if !WorldViewValid(view) || !MapMovementReady()
        return false
    SendEvent("{e}")

    if !LobbyEntryLabel(view, "^(artifact\s+stages?|artifacts?)$", [200,430,260,100], true, 26)
        || !LobbyEntryLabel(view, "^bloodstained\s+street$", [606,188,191,87], true)
        || !LobbyEntryLabel(view, "^select$", [330,406,140,65], true)
        return false
    if MatchMaking.Value {
        if !FindMatch(true)
            return false
    } else if !LobbyEntryLabel(view, "^play\s+here$", [255,294,157,91], true)
        || !LobbyEntryLabel(view, "^open$", [186,320,142,72], true)
        || !LobbyEntryLabel(view, "^start$", [298,425,208,83], true) {
        return false
    }
    return RestartStage()
}

CursedWombKeyPanelVisible() {
    return InStr(CapysNormalize(CapysOcrRect(155,142,485,120,3)),"cursedwombkey")
}

CursedWombMode() {
    view := LobbyEntryView()
    if !IsObject(view)
        return false
    title := CapysNormalize(CapysOcrRect(265,208,142,105,3))
    if InStr(title,"cursedwomb") && LobbyEntryLabel(view,"^select$",[272,334,124,31],true,1)
        return RestartStage()

    if !CursedWombKeyPanelVisible() || !WorldViewValid(view) {
        ProcessLog("Cursed Womb: key panel unavailable; no lobby path recording included")
        return false
    }
    if !WorldClick(view,219,289)
        return false
    loop 20 {
        Sleep(250)
        if !WorldViewValid(view)
            return false
        title := CapysNormalize(CapysOcrRect(265,208,142,105,3))
        if InStr(title,"cursedwomb") && LobbyEntryLabel(view,"^select$",[272,334,124,31],true,1)
            return RestartStage()
    }
    ProcessLog("Cursed Womb: Select was not confirmed")
    return false
}

DismissVillageShopPopup(view := 0) {
    if !IsObject(view)
        view := LobbyEntryView()
    if !IsObject(view)
        return false

    button := FindVillageShopLeaveButton(view)
    if !IsObject(button)
        button := FindVillageShopCloseButton(view)
    if !IsObject(button) || !WorldClick(view,button.x,button.y)
        return false

    ProcessLog("Village Shop: clicked " button.label)
    Sleep(500)
    return WorldViewValid(view)
}

FindVillageShopLeaveButton(view := 0) {
    if !IsObject(view)
        view := LobbyEntryView()
    if !IsObject(view)
        return false

    oldPixelMode := A_CoordModePixel
    CoordMode "Pixel","Screen"
    try {
        y := 240
        while y <= 470 && WorldViewValid(view) {
            rowMatch := true
            for point in [[270,true],[310,true],[360,true],[440,false],[500,false]] {
                rgb := PixelGetColor(view.x+Round(point[1]*view.sx),view.y+Round(y*view.sy))
                r := (rgb>>16)&255, g := (rgb>>8)&255, b := rgb&255
                if !(point[2] ? (g>130 && r<130 && b<80) : (r>150 && g<70 && b<70)) {
                    rowMatch := false
                    break
                }
            }
            if rowMatch {
                words := CapysNormalize(CapysOcrRect(235,Max(0,y-110),330,92,2,true))
                if InStr(words,"shop") && RegExMatch(words,"leave|offers|village") && WorldViewValid(view)
                    return {x:321,y:y,label:"Leave"}
            }
            y += 6
        }
    } finally CoordMode "Pixel",oldPixelMode
    return false
}

FindVillageShopCloseButton(view := 0) {
    if !IsObject(view)
        view := LobbyEntryView()
    if !WorldViewValid(view)
        return false

    oldPixelMode := A_CoordModePixel
    CoordMode "Pixel","Screen"
    try rgb := PixelGetColor(view.x+Round(582*view.sx),view.y+Round(211*view.sy))
    finally CoordMode "Pixel",oldPixelMode
    if ((rgb>>16)&255)<=170 || ((rgb>>8)&255)>=100 || (rgb&255)>=100
        return false
    header := CapysNormalize(CapysOcrRect(195,175,340,55,2,true))
    if (InStr(header,"villageshop") || (InStr(header,"village") && InStr(header,"shop")) || InStr(header,"ore"))
        && WorldViewValid(view)
        return {x:582,y:211,label:"Close"}
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
    return RestartStage()
}

InfinityMansionEnter() {
    global mode, MansionMapName
    mode := "Infinity Mansion"
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
    name := PortalDropdown.Text
    if !PortalMovement(name)
        return false
    return RestartStage(name)
}

FarmMode() {
    global mode
    mode := "Farm"
    map := WorldMapNames("main")[1]
    if !StoryMovement() || !SelectWorldMap(map,"main") || !SelectWorldAct("Infinity","main") || !WorldStartSolo()
        return false
    return RestartStage(map)
}

InfQuestMode() {
    global MatchMaking, DailyQuestMap, mode
    mode := "Daily Infinite Quest"
    quests := ReadDailyInfiniteQuests()
    if !IsObject(quests)
        return false
    name := NextInfiniteQuestMap(quests,DailyQuestMap)
    if name = "" {
        ProcessLog("Daily Infinite Quest: all 9 tasks completed and rewards claimed")
        return "complete"
    }

    ProcessLog("Daily Infinite Quest: entering " name " Infinite")
    if !StoryMovement() || !SelectWorldMap(name,"main") || !SelectWorldAct("Infinity","main")
        return false
    if !(MatchMaking.Value ? FindMatch() : WorldStartSolo())
        return false
    DailyQuestMap := name
    return RestartStage(name)
}

NextInfiniteQuestMap(quests, previous := "") {
    pendingMaps := []
    seen := Map()
    for quest in quests {
        if quest.status = "pending" && !seen.Has(quest.map) {
            seen[quest.map] := true
            pendingMaps.Push(quest.map)
        }
    }
    if !pendingMaps.Length
        return ""
    for index, mapName in pendingMaps {
        if mapName = previous
            return pendingMaps[Mod(index,pendingMaps.Length)+1]
    }
    return pendingMaps[1]
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
    global RaidDropdown, RaidActDropdown, MatchMaking
    map := RaidDropdown.Text, act := RaidActDropdown.Text
    if !GetRaidDownArrows(map) || !GetRaidActDownArrows(act)
        return false
    view := LobbyEntryView()
    if !IsObject(view) || !RaidMovement(view) || !StartRaid(map, act, view)
        return false
    if !(MatchMaking.Value ? FindMatch() : LobbyEntryStartSolo(view))
        return false
    return RestartStage(map)
}

InfinityCastleMode() {
    global InfinityCastleDropdown, MatchMaking
    difficulty := InfinityCastleDropdown.Text
    if difficulty != "Normal" && difficulty != "Hard"
        return false
    view := LobbyEntryView()
    if !IsObject(view) || !InfCastleMovement(view)
        return false
    label := difficulty = "Normal" ? "^(normal|easy)$" : "^hard$"
    if !LobbyEntryLabel(view, label, [330,343,220,63], true)
        return false
    if !(MatchMaking.Value ? FindMatch() : LobbyEntryStartSolo(view))
        return false
    return RestartStage("Infinity Castle")
}

DungeonMode() {
    global MatchMaking, BossRoomCompleted
    BossRoomCompleted := false
    view := LobbyEntryView()
    if !IsObject(view) || !WorldClick(view,35,404)
        return false
    if !LobbyEntryLabel(view,"^(enter|enter dungeon)$",[300,352,200,89],true)
        return false

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

MonitorEndScreen() {
    global LobbyText, LobbyText2, lastResult, ResultCounted
    EndCardMatch("result-screen")
    deadline := A_TickCount + 60000
    lastResult := ResultCounted ? lastResult : "unknown"
    waitingLogged := false
    reward := {beats:0,summaryNextConfirmed:false}

    while A_TickCount < deadline {
        Reconnect(&reconnected)
        if reconnected
            return "reconnected"

        if (window := RefreshClientTarget()) && !WinActive("ahk_id " window)
            try WinActivate("ahk_id " window)
        view := LobbyEntryView()
        if !IsObject(view) {
            Sleep(500)
            continue
        }

        DismissVillageShopPopup(view)
        if !WorldViewValid(view)
            continue
        if DismissResultUnitPanel(view)
            continue
        dungeon := HandleDungeonDeathScreen(view)
        if dungeon = "lobby"
            return dungeon
        if dungeon = "handled"
            continue
        rewardScreen := ReadResultRewardScreen(view)
        if !ResultCounted && rewardScreen.result != "" {
            RecordMatchResult(rewardScreen.result)
            rewardScreen := ReadResultRewardScreen(view)
        }
        if AdvanceResultReward(view,reward,rewardScreen)
            continue

        choice := CapysReadChoice(false)
        if IsObject(choice) {
            if choice["ownerWait"] {
                if !waitingLogged
                    ProcessLog("End screen: waiting for party owner")
                waitingLogged := true
            } else if reward.summaryNextConfirmed && reward.beats < 5 {
                ; Keep the reward cadence if the menu appears early. Every
                ; following beat rechecks for a reward without clicking the menu.
                reward.beats++
            } else if (route := RouteResultChoice(view,choice)) {
                return route
            }
        } else if !LobbyEntryPattern(view,LobbyText "|" LobbyText2,[80,85,739,224],&x,&y) && IsMacroLobbyVisible() {
            return "lobby"
        }
        Sleep(500)
    }

    ProcessLog("End screen: timeout; recovering to lobby")
    return RecoverToLobby()
}

DismissResultUnitPanel(view := 0) {
    global UnitExit
    if !IsObject(view)
        view := LobbyEntryView()
    if !WorldViewValid(view) || !LobbyEntryPattern(view,UnitExit,[300,190,360,250],&x,&y)
        return false
    if !WorldClick(view,x-4,y-35)
        return false
    Sleep(300)
    return true
}

HandleDungeonDeathScreen(view := 0) {
    global mode
    if mode != "Dungeon"
        return false
    if !IsObject(view)
        view := LobbyEntryView()
    if !ReadDungeonDeath(view)
        return false
    RecordMatchResult("defeat")
    if IsMacroLobbyVisible() {
        if WorldClick(view,400,383) && WaitForResultTransition("lobby")
            return "lobby"
    } else {
        WorldClick(view,670,147)
    }
    Sleep(500)
    return "handled"
}

ReadResultRewardScreen(view := 0) {
    global NextText
    if !IsObject(view)
        view := LobbyEntryView()
    if !WorldViewValid(view)
        return {kind:"",result:""}
    if CapysReadReward()
        return {kind:"reward",result:""}
    result := CapysReadResult(&nextVisible)
    hasNext := nextVisible || LobbyEntryPattern(view,NextText,[260,400,390,450],&x,&y)
    return {kind:hasNext ? "summary" : "",result:result}
}

AdvanceResultReward(view := 0, progress := 0, screen := 0) {
    if !IsObject(view)
        view := LobbyEntryView()
    if !WorldViewValid(view)
        return false
    if !IsObject(progress)
        progress := {beats:0,summaryNextConfirmed:false}
    if !IsObject(screen)
        screen := ReadResultRewardScreen(view)

    if screen.kind = "reward" {
        atSummary := progress.summaryNextConfirmed && progress.beats < 5
        if WorldClick(view,atSummary ? 319 : 400,atSummary ? 394 : 450)
            progress.beats++
        Sleep(500)
        return true
    }
    if screen.kind != "summary"
        return false

    if WorldClick(view,319,394) {
        progress.summaryNextConfirmed := true
        progress.beats++
    }
    Sleep(500)
    return true
}

RouteResultChoice(view := 0, choice := 0) {
    global mode
    if !IsObject(view)
        view := LobbyEntryView()
    if !WorldViewValid(view) || CapysReadReward()
        return false
    if !IsObject(choice)
        choice := CapysReadChoice(false)
    if !IsObject(choice) || choice["ownerWait"]
        return false

    oldWave := CapysReadWave()
    for route in ResultActionOrder() {
        if !TryConfirmedResultAction(view,choice,route)
            continue
        dungeonReplay := mode = "Dungeon" && route = "replay"
        transition := WaitForResultTransition(route,oldWave,dungeonReplay)
        if !transition {
            ProcessLog("End screen: no confirmed transition after " route)
            return false
        }
        if route = "dungeon" || transition = "dungeon"
            return ContinueDungeonAfterResult()
        return route = "lobby" ? "lobby" : "replay"
    }
    ProcessLog("End screen: choice buttons visible but no route action matched (lobbyX=" choice["lobbyX"] ", replayX=" choice["replayX"] ")")
    return false
}

ContinueDungeonAfterResult() {
    CheckDungeonSpecials()
    finish := CheckForFinishDungeon()
    return finish ? finish : SelectDungeonRoute()
}

RecordMatchResult(result) {
    global ResultCounted, Wins, loss, stageStartTime, lastResult
    if ResultCounted
        return
    ResultCounted := true
    win := result = "victory"
    lastResult := win ? "win" : "lose"
    if win
        Wins++
    else
        loss++
    duration := FormatStageTime(A_TickCount - stageStartTime)
    ProcessLog((win ? "Victory" : "Defeat") " detected (" duration ")")
    try SendWebhookWithTime(win, duration)
    catch
        ProcessLog("Match report could not be sent")
}

ResultActionOrder() {
    global mode, StoryActDropdown, ReturnLobbyBox, MatchMaking, ReplayBox, NextLevelBox, NextRoomBox, lastResult
    if mode = "Farm"
        return ["replay", "lobby"]
    if ReturnLobbyBox.Value || (ModeAllowsMatchmaking(mode) && MatchMaking.Value)
        || mode = "Portal" || mode = "Daily Infinite Quest" || mode = "Cursed Womb"
        return ["lobby"]
    if mode = "Dungeon" {
        if lastResult = "lose"
            return ["lobby"]
        return lastResult = "win" && ReplayBox.Value ? ["dungeon", "replay", "lobby"] : ["dungeon", "lobby"]
    }
    if (mode = "Story" && StoryActDropdown.Text = "Infinity")
        return ["lobby"]
    misty := mode = "Misty Village" || mode = "Misty Infinite"
    if misty && lastResult = "lose"
        return ["lobby"]

    actions := []
    if lastResult = "win" {
        if mode = "Infinity Mansion" && NextRoomBox.Value
            actions.Push("nextRoom")
        else if mode = "Story" && NextLevelBox.Value
            actions.Push("nextLevel")
        else if misty && NextLevelBox.Value
            actions.Push("nextFloor")
    }
    if ReplayBox.Value
        actions.Push("replay")
    actions.Push("lobby")
    return actions
}

TryConfirmedResultAction(view, choice, route) {
    buttonX := choice["nextLevelX"]
    switch route {
        case "lobby":
            if !choice["lobbyX"]
                return false
            buttonX := choice["lobbyX"]
            pattern := "^return\s+to\s+lobb"
        case "replay":
            if !choice["replayX"] || choice["hasNextPortal"]
                return false
            buttonX := choice["replayX"]
            pattern := "^(replay|repeat|retry)$"
        case "dungeon":
            if !choice["hasOpenDungeon"]
                return false
            buttonX := 488
            pattern := "^open\s+dungeon$"
        case "nextRoom":
            if !choice["hasNextRoom"]
                return false
            pattern := "^next\s+room$"
        case "nextFloor":
            if !choice["hasNextFloor"]
                return false
            pattern := "^next\s+fl[o0]{2}r$"
        case "nextLevel":
            if !choice["hasNextLevel"]
                return false
            pattern := "^next\s+level$"
        default:
            return false
    }
    candidates := []
    if buttonX > 0
        candidates.Push(buttonX)
    for x in [224,312,400,488,576] {
        if x != buttonX
            candidates.Push(x)
    }
    for x in candidates {
        if LobbyEntryLabel(view,pattern,[x-74,96,148,54],true,1)
            return true
    }
    if (route = "lobby" || route = "replay") {
        for x in candidates {
            if !WorldViewValid(view)
                return false
            norm := ""
            try norm := CapysNormalize(ReadHighContrastText(view.x+Round((x-74)*view.sx),view.y+Round(96*view.sy)
                ,Max(8,Round(148*view.sx)),Max(8,Round(54*view.sy)),3,0,false,true))
            if (route = "lobby" && (RegExMatch(norm,"returnt[o0]l[o0]bb") || (InStr(norm,"return") && CapysButtonPillKind(x) = "green")))
                || (route = "replay" && RegExMatch(norm,"replay|retry"))
                return WorldClick(view,x,121)
        }
    }
    return false
}

WaitForResultTransition(route, oldWave := -1, dungeonReplay := false) {
    global TransitionCoverMap
    TransitionCoverMap := ""
    deadline := A_TickCount + (route = "lobby" ? 60000 : 90000)
    menuDeadline := A_TickCount + 18000
    cleanReads := 0
    coverMap := ""
    lastView := 0
    while A_TickCount < deadline {
        Sleep(500)
        view := LobbyEntryView()
        if !WorldViewValid(lastView) {
            cleanReads := 0
            coverMap := ""
        }
        lastView := view
        if !WorldViewValid(view)
            continue
        if CapysResultScreenVisible() {
            cleanReads := 0
            coverMap := ""
            if A_TickCount >= menuDeadline
                return false
            continue
        }
        if route != "lobby" && route != "dungeon" && coverMap = ""
            coverMap := ReadMatchLoadingCover()
        if !WorldViewValid(view) {
            cleanReads := 0
            coverMap := ""
            continue
        }
        if ++cleanReads < 2
            continue
        if route = "lobby" {
            if IsMacroLobbyVisible() && WorldViewValid(view)
                return true
        } else if route = "dungeon" {
            if DungeonRouteVisible() && WorldViewValid(view)
                return true
        } else if !IsMacroLobbyVisible() && WorldViewValid(view) {
            if dungeonReplay && DungeonRouteVisible() && WorldViewValid(view)
                return "dungeon"
            if coverMap != "" && WorldViewValid(view) {
                TransitionCoverMap := coverMap
                return true
            }
            if FindVoteStart(&x, &y) && WorldViewValid(view)
                return true
            waveNow := CapysReadWave()
            if (oldWave > 1 ? (waveNow = 1) : (cleanReads >= 3 && (waveNow = 1 || RegularMatchHudVisible() || SummerMatchStarted())))
                && (RegularMatchHudVisible() || SummerMatchStarted()) && !CapysResultScreenVisible() && WorldViewValid(view)
                return true
        }
    }
    return false
}

ReadDungeonDeath(view) {
    if !WorldViewValid(view)
        return false
    title := CapysNormalize(CapysOcrRect(255,205,300,65,3))
    if !InStr(title,"youdied")
        return false
    label := CapysNormalize(CapysOcrRect(310,360,185,48,3))
    if !WorldViewValid(view) || !InStr(label,"continue")
        return false
    oldMode := A_CoordModePixel
    CoordMode "Pixel", "Screen"
    try {
        for x in [325,475] {
            color := PixelGetColor(view.x+Round(x*view.sx),view.y+Round(375*view.sy))
            green := (color>>8) & 255
            if green < 90 || green < ((color>>16)&255)+30 || green < (color&255)+30
                return false
        }
        return WorldViewValid(view)
    } finally CoordMode "Pixel", oldMode
}

DungeonRouteVisible() {
    global Enter, Shop, Shrine, ChestRoom, FinishDungeon
    view := LobbyEntryView()
    if !IsObject(view)
        return false
    return LobbyEntryPattern(view,Shop "|" Shrine "|" ChestRoom,[140,200,375,250],&x,&y)
        || LobbyEntryPattern(view,FinishDungeon,[240,180,565,480],&x,&y)
        || (LobbyEntryPattern(view,Enter,[120,425,680,500],&x,&y)
            && InStr(CapysNormalize(CapysOcrRect(180,185,440,185,2)),"dungeon"))
}

ProcessMatchResult() {
    return MonitorEndScreen()
}

MonitorStage() {
    global mode, StoryActDropdown

    lastClickTime := A_TickCount

    loop {
        Sleep(1000)

        if CapysResultScreenVisible()
            return HandleStageResult()
        Reconnect(&reconnected)
        if reconnected
            return "reconnected"
        if mode = "Summer Event"
            ServiceSummerCards()
        if mode = "Daily Infinite Quest" && (route := DailyInfiniteWaveRoute())
            return route

        if A_TickCount - lastClickTime >= 300000 && UnitActionAllowed(true) {
            view := LobbyEntryView()
            if IsObject(view) && WorldClick(view,638,549) {
                lastClickTime := A_TickCount
                ProcessLog("Match monitor: anti-idle click")
            }
            if (mode = "Story" && StoryActDropdown.Text = "Infinity") || mode = "Daily Infinite Quest" {
                for x in [239,298,358] {
                    if !UnitActionAllowed(true) || !IsObject(view) || !WorldClick(view,x,400)
                        break
                }
            }
        }
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

DailyInfiniteWaveRoute() {
    global DailyQuestMap, stageStartTime
    static tick := 0, match := -1, reads := 0, lastView := 0
    if match != stageStartTime {
        match := stageStartTime
        tick := 0
        reads := 0
        lastView := 0
    }
    if DailyQuestMap = "" || A_TickCount < tick
        return false
    tick := A_TickCount + 900
    if !WorldViewValid(lastView)
        reads := 0
    view := LobbyEntryView()
    lastView := view
    if !WorldViewValid(view) || CapysReadWave() < 40 || !WorldViewValid(view) {
        reads := 0
        return false
    }
    if ++reads < 2
        return false

    reads := 0
    if !UnitActionAllowed(true) || ReadInfiniteMatchMap() != DailyQuestMap || !WorldViewValid(view)
        return false

    ProcessLog("Daily Infinite Quest: Wave 40 reached on " DailyQuestMap)
    route := StartDailyLoseVote(view) ? FinishDailyLoseVote(view) : RecoverDailyLoseVote()
    tick := A_TickCount + 10000
    return route
}

FinishDailyLoseVote(view := 0) {
    if !IsObject(view)
        view := LobbyEntryView()
    deadline := A_TickCount + 30000
    voted := false
    allowVote := WorldViewValid(view)
    while A_TickCount < deadline {
        if !WorldViewValid(view) {
            allowVote := false
            view := LobbyEntryView()
        }
        if WorldViewValid(view) {
            if CapysResultScreenVisible()
                return FormatHandledRoute(HandleStageResult())
            if allowVote && !voted
                voted := ConfirmDailyLoseVote(view)
        }
        Sleep(350)
    }
    ProcessLog("Daily Infinite Quest: Vote to Lose did not finish the match")
    return RecoverDailyLoseVote()
}

ConfirmDailyLoseVote(view := 0) {
    if !IsObject(view)
        view := LobbyEntryView()
    if !IsDailyLoseVoteOpen(view) || CapysResultScreenVisible()
        return false
    if !LobbyEntryLabel(view,"^vote$",[329,304,70,35],true,1)
        return false
    ProcessLog("Daily Infinite Quest: confirmed Vote to Lose")
    return true
}

IsDailyLoseVoteOpen(view := 0) {
    if !IsObject(view)
        view := LobbyEntryView()
    return WorldViewValid(view) && RegExMatch(CapysOcrRect(330,259,145,49,3),"i)\bvote\s+to\s+lose\b")
        && WorldViewValid(view)
}

DismissDailyLoseVote(view := 0) {
    if !IsObject(view)
        view := LobbyEntryView()
    if !WorldViewValid(view)
        return false
    if IsDailyLoseVoteOpen(view) {
        if !LobbyEntryLabel(view,"^(?:cancel|no)$",[329,304,145,35],true,1)
            return false
        Sleep(350)
        if !WorldViewValid(view) || IsDailyLoseVoteOpen(view)
            return false
    }
    if IsMatchSettingsOpen(view) {
        if !CloseMatchSettings(view)
            return false
        Sleep(350)
    }
    loop 2 {
        if !WorldViewValid(view) || IsDailyLoseVoteOpen(view) || IsMatchSettingsOpen(view)
            return false
        if A_Index = 1
            Sleep(350)
    }
    return WorldViewValid(view)
}

RecoverDailyLoseVote() {
    view := LobbyEntryView()
    if WorldViewValid(view) {
        if CapysResultScreenVisible()
            return FormatHandledRoute(HandleStageResult())
        if IsMacroLobbyVisible()
            return "lobby"
        if DismissDailyLoseVote(view)
            return false
    }
    ProcessLog("Daily Infinite Quest: could not verify the vote and Settings closed; returning for recovery")
    return "handled"
}

ReadInfiniteMatchMap() {
    title := CapysOcrRect(160,12,493,45,3)
    if RegExMatch(title,"i)(.+?)\s+infinite\s+mode",&m)
        return ResolveInfiniteQuestMap(Trim(m[1]))
    return ""
}

StartDailyLoseVote(view := 0) {
    if !IsObject(view)
        view := LobbyEntryView()
    if !OpenMatchSettings(view) {
        ProcessLog("Daily Infinite Quest: Settings did not open")
        return false
    }
    if ClickVoteToLoseRow(view)
        return true
    CloseMatchSettings(view)
    return false
}

OpenMatchSettings(view := 0) {
    if !IsObject(view)
        view := LobbyEntryView()
    if !WorldViewValid(view)
        return false
    if IsMatchSettingsOpen(view)
        return true
    return WorldClick(view,26,570) && LobbyEntryLabel(view,"^settings$",[220,132,150,49])
}

IsMatchSettingsOpen(view := 0) {
    if !IsObject(view)
        view := LobbyEntryView()
    return WorldViewValid(view) && LobbyEntryLabel(view,"^settings$",[220,132,150,49],false,1)
}

CloseMatchSettings(view := 0) {
    if !IsObject(view)
        view := LobbyEntryView()
    return IsMatchSettingsOpen(view) && WorldClick(view,581,148)
}

ClickVoteToLoseRow(view := 0) {
    if !IsObject(view)
        view := LobbyEntryView()
    if !IsMatchSettingsOpen(view) || !ScrollMacroPanel(view,405,334,"up",12)
        return false
    loop 15 {
        if !IsMatchSettingsOpen(view) || CapysResultScreenVisible()
            return false
        rowY := FindVoteToLoseRow(view)
        if rowY && !CapysResultScreenVisible()
            return WorldClick(view,522,rowY)
        if !ScrollMacroPanel(view,405,334,"down",1)
            return false
    }
    ProcessLog("Daily Infinite Quest: Vote to Lose was not found in Settings")
    return false
}

FindVoteToLoseRow(view := 0) {
    if !IsObject(view)
        view := LobbyEntryView()
    if !IsMatchSettingsOpen(view)
        return false
    region := [226,188,260,253]
    lines := WorldReadRegion(view,region*)
    if !IsObject(lines)
        return false
    for line in lines.Lines {
        if CapysNormalize(line.Text) != "votetolose"
            continue
        y := region[2]+(line.y+line.h/2)/view.sy+6
        if y >= 202 && y <= 431 && WorldViewValid(view)
            return y
    }
    return false
}

LobbyEntryView() {
    if !CapysGetClientBox(&x,&y,&w,&h,&hwnd) || !WinActive("ahk_id " hwnd)
        return false
    return {window:hwnd, x:x, y:y, w:w, h:h, sx:w/800, sy:h/599}
}

LobbyEntryPattern(view, pattern, region, &x, &y) {
    if !WorldViewValid(view) || !FindText(&px,&py,view.x+Round(region[1]*view.sx),view.y+Round(region[2]*view.sy),
        view.x+Round(region[3]*view.sx),view.y+Round(region[4]*view.sy),0,0,pattern,1,0,0,20,10,1,view.sx,view.sy)
        return false
    x := (px-view.x)/view.sx, y := (py-view.y)/view.sy
    return WorldViewValid(view)
}

LobbyEntryLabel(view, pattern, region, click := false, attempts := 12) {
    loop attempts {
        if !WorldViewValid(view)
            return false
        ui := WorldReadRegion(view,region*)
        if IsObject(ui) {
            for line in ui.Lines {
                normLine := RegExReplace(StrLower(Trim(line.Text)), "\brepeat\b", "replay")
                if !RegExMatch(normLine, pattern)
                    continue
                if !click
                    return WorldViewValid(view)
                return WorldClick(view,region[1]+(line.x+line.w/2)/view.sx,
                    region[2]+(line.y+line.h/2)/view.sy)
            }
        }
        if A_Index < attempts
            Sleep(150)
    }
    if attempts > 1
        ProcessLog("Lobby entry: control unavailable (" pattern ")")
    return false
}

LobbyEntryStartSolo(view) {
    if !LobbyEntryLabel(view,"^(select|start)$",[332,406,135,57],true)
        || !LobbyEntryLabel(view,"^play here$",[252,293,159,93],true)
        || !LobbyEntryLabel(view,"^start$",[288,424,225,78],true)
        return false
    return true
}

PortalSearch(view?, name := "") {
    global PortalDropdown, ShibuyaPortal, DemonsPlacePortal
    if !IsSet(view)
        view := LobbyEntryView()
    if name = ""
        name := PortalDropdown.Text
    if !IsObject(view) || (name != "Shibuya District" && name != "Demons Leader Place")
        return false

    ProcessLog("Portal: searching inventory for " name)
    if !WorldClick(view,36,297)
        return false
    Sleep(600)
    if !WorldClick(view,533,227)
        return false
    Sleep(600)
    if !WorldClick(view,486,186)
        return false
    Sleep(600)
    if !WorldViewValid(view)
        return false
    SendEvent("^a")
    if !WorldViewValid(view)
        return false
    SendText(name = "Shibuya District" ? "Shibuya" : "Demon")
    pattern := name = "Shibuya District" ? ShibuyaPortal : DemonsPlacePortal
    loop 10 {
        Sleep(200)
        if !WorldViewValid(view)
            return false
        if LobbyEntryPattern(view, pattern, [171,237,634,485], &x, &y)
            return WorldClick(view,x,y)
    }
    ProcessLog("Portal: requested item icon unavailable: " name)
    return false
}

PortalMovement(name := "") {
    view := LobbyEntryView()
    if !IsObject(view) || !PortalSearch(view,name)
        return false
    ; Capys separates the item Use action from the Open confirmation and queue Start.
    if !LobbyEntryLabel(view, "^use$", [150,237,500,250], true)
        || !LobbyEntryLabel(view, "^open$", [186,320,142,72], true)
        || !LobbyEntryLabel(view, "^start$", [298,425,208,83], true)
        return false
    ProcessLog("Portal: selected item and started its queue")
    return true
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

ReadDailyInfiniteQuests() {
    view := LobbyEntryView()
    if !IsObject(view) || !DismissLobbyPopups(view) {
        ProcessLog("Daily Infinite Quest: lobby popup check interrupted")
        return false
    }
    if !OpenDailyQuestPanel(view) {
        ProcessLog("Daily Infinite Quest: Your Quests did not open")
        return false
    }
    quests := false
    try {
        if SelectInfiniteQuestTab(view)
            quests := CollectInfiniteQuestRewards(view)
        else
            ProcessLog("Daily Infinite Quest: Infinite tab could not be selected")
    } finally {
        panelClosed := CloseDailyQuestPanel(view)
    }
    if !panelClosed {
        ProcessLog("Daily Infinite Quest: Your Quests did not close")
        return false
    }
    return quests
}

CollectInfiniteQuestRewards(view := 0) {
    if !IsObject(view)
        view := LobbyEntryView()
    loop 10 {
        scan := ScanInfiniteQuestList(view)
        if !IsObject(scan)
            return false
        if !IsObject(scan.claimable) {
            for quest in scan.quests
                ProcessLog("Daily Infinite: " quest.map " Wave " quest.wave " is " quest.status)
            return scan.quests
        }
        if !ClaimVisibleInfiniteQuest(view,scan.claimable) {
            ProcessLog("Daily Infinite Quest: Claim button could not be confirmed")
            return false
        }
        Sleep(400)
    }
    ProcessLog("Daily Infinite Quest: claim did not settle")
    return false
}

DismissLobbyPopups(view := 0) {
    if !IsObject(view)
        view := LobbyEntryView()
    if !IsObject(view)
        return false
    DismissVillageShopPopup(view)
    return WorldClearLobbyNotices(view) && DismissPromoPopups(4,view)
}

OpenDailyQuestPanel(view := 0) {
    if !IsObject(view)
        view := LobbyEntryView()
    if !WorldViewValid(view)
        return false
    if IsDailyQuestPanelOpen(view)
        return true
    return LobbyEntryLabel(view,"^quests$",[731,230,69,62],true)
        && LobbyEntryLabel(view,"^your\s+quests$",[208,92,200,38])
}

IsDailyQuestPanelOpen(view := 0) {
    if !IsObject(view)
        view := LobbyEntryView()
    return WorldViewValid(view) && LobbyEntryLabel(view,"^your\s+quests$",[208,92,200,38],false,1)
}

SelectInfiniteQuestTab(view := 0) {
    if !IsObject(view)
        view := LobbyEntryView()
    return IsDailyQuestPanelOpen(view) && LobbyEntryLabel(view,"^infinite$",[399,132,92,39],true)
}

CloseDailyQuestPanel(view := 0) {
    if !IsObject(view)
        view := LobbyEntryView()
    if !WorldViewValid(view)
        return false
    if !IsDailyQuestPanelOpen(view)
        return WorldViewValid(view)
    if !WorldClick(view,592,99)
        return false
    Sleep(300)
    return WorldViewValid(view) && !IsDailyQuestPanelOpen(view)
}

ScanInfiniteQuestList(view := 0) {
    if !IsObject(view)
        view := LobbyEntryView()
    if !IsDailyQuestPanelOpen(view) || !ScrollMacroPanel(view,505,410,"up",16)
        return false
    quests := Map()
    order := []
    loop 18 {
        if !IsDailyQuestPanelOpen(view)
            return false
        for quest in ReadVisibleInfiniteTasks(view) {
            key := quest.map "|" quest.wave
            if !quests.Has(key)
                order.Push(key)
            quests[key] := quest
            if quest.status = "claimable"
                return {quests:[],claimable:quest}
        }
        if HasCompleteInfiniteQuestList(quests) {
            ordered := []
            for key in order
                ordered.Push(quests[key])
            return {quests:ordered,claimable:false}
        }
        if !ScrollMacroPanel(view,505,410,"down",1)
            return false
    }
    ProcessLog("Daily Infinite Quest: " quests.Count " distinct rows read; expected Waves 10, 20 and 40 on three maps")
    return false
}

HasCompleteInfiniteQuestList(quests) {
    if quests.Count != 9
        return false
    maps := Map()
    for key, quest in quests
        maps[quest.map] := true
    if maps.Count != 3
        return false
    for mapName in maps {
        for wave in [10,20,40] {
            if !quests.Has(mapName "|" wave)
                return false
        }
    }
    return true
}

ClaimVisibleInfiniteQuest(view := 0, task := 0) {
    if !IsObject(view)
        view := LobbyEntryView()
    if !IsDailyQuestPanelOpen(view)
        return false
    for current in ReadVisibleInfiniteTasks(view) {
        if current.status != "claimable"
            continue
        if IsObject(task) && (current.map != task.map || current.wave != task.wave)
            continue
        return WorldClick(view,505,current.buttonY)
    }
    return false
}

ReadVisibleInfiniteTasks(view := 0) {
    if !IsObject(view)
        view := LobbyEntryView()
    if !WorldViewValid(view)
        return []
    region := [220,193,214,290]
    left := WorldReadRegion(view,region*)
    rows := []
    if !IsObject(left)
        return rows
    seen := Map()
    for prompt in ReadInfiniteQuestRowPrompts(left.Lines,region[2],view.sy) {
        key := prompt.map "|" prompt.wave
        if prompt.conflict || seen.Has(key)
            continue
        y := prompt.y
        if y < 196 || y+75 > 484
            continue
        progress := CapysOcrRect(425,y-9,152,34,3)
        button := CapysOcrRect(439,y+41,135,31,3)
        if !WorldViewValid(view)
            continue
        status := ReadInfiniteQuestStatus(progress,button)
        if status = ""
            continue
        rows.Push({map:prompt.map,wave:prompt.wave,status:status,buttonY:y+58})
        seen[key] := true
    }
    return rows
}

ReadInfiniteQuestRowPrompts(lines, regionTop, scale) {
    prompts := []
    for index, line in lines {
        prompt := ReadInfiniteQuestPromptLine(lines,index,scale)
        if !IsObject(prompt)
            continue
        ; The measured description starts 25px below the title of the same card.
        prompt.y := regionTop+Round(line.y/scale)-(prompt.description ? 25 : 0)
        prompt.conflict := false
        matched := false
        for existing in prompts {
            if Abs(existing.y-prompt.y) > 10
                continue
            if existing.map != prompt.map || existing.wave != prompt.wave
                existing.conflict := true
            if !prompt.description
                existing.y := prompt.y
            matched := true
            break
        }
        if !matched
            prompts.Push(prompt)
    }
    return prompts
}

ReadInfiniteQuestPromptLine(lines, index, scale) {
    line := lines[index]
    text := Trim(line.Text)
    if !RegExMatch(text,"i)^(?:reach\s+)?wave")
        return false
    prompt := ParseInfiniteQuestPrompt(text)
    if IsObject(prompt)
        return prompt
    loop Min(2,lines.Length-index) {
        next := lines[index+A_Index]
        fragment := Trim(next.Text)
        if next.y <= line.y || (next.y-line.y)/scale > 30
            || RegExMatch(fragment,"i)^(?:reach\s+wave|wave\s*[\dilo|]+|reward\b|progress\b)")
            break
        text .= " " fragment
        prompt := ParseInfiniteQuestPrompt(text)
        if IsObject(prompt)
            return prompt
    }
    return false
}

ParseInfiniteQuestPrompt(text) {
    text := Trim(RegExReplace(text,"\s+"," "))
    text := Trim(RegExReplace(text,"i)\s*[\[(]?\s*infinite(?:\s+mode)?\s*[\])]?\s*$"))
    description := RegExMatch(text,"i)^reach\s+wave\s*([124il|][0o])\s+[il]n\s+(.+)$",&match)
    if !description && !RegExMatch(text,"i)^wave\s*([124il|][0o])(?:\s*[:;.\x{2013}\x{2014}-]\s*|\s+)(.+)$",&match)
        return false
    wave := Integer(RegExReplace(StrReplace(StrLower(match[1]),"o","0"),"[il|]","1"))
    mapName := ResolveInfiniteQuestMap(match[2])
    return mapName != "" ? {map:mapName,wave:wave,description:!!description} : false
}

ReadInfiniteQuestStatus(progress, button) {
    if !RegExMatch(progress,"i)\b([01])\s*/\s*1\b",&m)
        return ""
    button := CapysNormalize(button)
    if m[1] = "0"
        return button = "incomplete" ? "pending" : ""
    if RegExMatch(button,"^claim(?:reward)?$")
        return "claimable"
    return RegExMatch(button,"^(claimed|rewardclaimed|complete|completed)$") ? "done" : ""
}

ResolveInfiniteQuestMap(text) {
    entry := WorldCardEntry(text,"main")
    if IsObject(entry)
        return entry["map"]
    key := WorldTextKey(text)
    if StrLen(key) < 7
        return ""
    match := "", best := StrLen(key) <= 8 ? 2 : 3
    for world in WorldCatalog()["main"] {
        nameKey := WorldTextKey(world["name"])
        if Abs(StrLen(key)-StrLen(nameKey)) > best
            continue
        score := SummerQuantumDistance(key,nameKey)
        if score < best {
            match := world["map"]
            best := score
        } else if score = best
            match := ""
    }
    return match
}

ScrollMacroPanel(view, x, y, direction, ticks) {
    if !WorldViewValid(view)
        return false
    oldMode := A_CoordModeMouse
    CoordMode "Mouse","Screen"
    try {
        FixMove(view.x+Round(x*view.sx),view.y+Round(y*view.sy))
        Sleep(100)
        loop ticks {
            if !WorldViewValid(view)
                return false
            SendEvent(direction="up" ? "{WheelUp}" : "{WheelDown}")
            Sleep(45)
        }
        Sleep(200)
    } finally CoordMode "Mouse",oldMode
    return WorldViewValid(view)
}

RaidMovement(view?) {
    if !IsSet(view)
        view := LobbyEntryView()
    if !IsObject(view)
        return false
    cards := "i)(Sacred Planet|Strange Town|Ruined City)"
    if LobbyEntryLabel(view,cards,[612,205,185,251],false,1)
        return true
    if !WorldClick(view,765,475)
        return false
    Sleep(300)
    if !WorldClick(view,495,410)
        return false
    Sleep(500)
    ProcessLog("Raid navigation: A4123ms -> W1863ms")
    if !WorldViewValid(view) || !MapWalk("a",4123)
        return false
    Sleep(150)
    if !WorldViewValid(view) || !MapWalk("w",1863)
        return false
    return LobbyEntryLabel(view,cards,[612,205,185,251])
}

InfCastleMovement(view?) {
    if !IsSet(view)
        view := LobbyEntryView()
    if !IsObject(view)
        return false
    labels := "i)^(normal|easy|hard)$"
    if LobbyEntryLabel(view,labels,[330,343,220,63],false,1)
        return true
    if !WorldClick(view,765,475)
        return false
    Sleep(300)
    if !WorldClick(view,370,330)
        return false
    Sleep(500)
    if !WorldViewValid(view) || !MapWalk("w",500)
        return false
    Sleep(500)
    if !WorldViewValid(view) || !MapWalk("a",4000)
        return false
    return LobbyEntryLabel(view,labels,[330,343,220,63])
}

; Roblox keeps showing "Don't Miss Out!" event toasts in the top-right corner.
; Their red close button sits at x≈767 and the toast cards cover the first rows
; of the Select World list, so they must be cleared before picking a map.
DismissPromoPopups(maxPopups := 4, view := 0) {
    if !IsObject(view)
        view := LobbyEntryView()
    if !IsObject(view)
        return false
    loop maxPopups {
        button := FindPromoPopupCloseButton(view)
        if !IsObject(button)
            return WorldViewValid(view)
        if !WorldClick(view,button.x,button.y)
            return false
        Sleep(400)
    }
    return WorldViewValid(view)
}

FindPromoPopupCloseButton(view := 0) {
    if !IsObject(view)
        view := LobbyEntryView()
    if !WorldViewValid(view)
        return false

    oldPixelMode := A_CoordModePixel
    CoordMode "Pixel","Screen"
    try {
        yStart := view.y+Round(55*view.sy)
        dx := Round(8*view.sx), dy := Round(8*view.sy)
        loop 12 {
            if !WorldViewValid(view) || !PixelSearch(&px,&py,view.x+Round(758*view.sx),yStart,
                view.x+Round(778*view.sx),view.y+Round(320*view.sy),0xE00000,40)
                return false
            rgb := PixelGetColor(px+dx,py+dy)
            if ((rgb>>16)&255)>180 && ((rgb>>8)&255)<60 && (rgb&255)<60 && WorldViewValid(view)
                return {x:(px+dx-view.x)/view.sx,y:(py+dy-view.y)/view.sy}
            yStart := py+Max(1,Round(2*view.sy))
        }
    } finally CoordMode "Pixel",oldPixelMode
    return false
}

StartStory() {
    global mode, StoryDropdown, MapDropdown
    name := mode = "Infinite" ? MapDropdown.Text : StoryDropdown.Text
    return SelectWorldMap(name,"main")
}

StartLegend(map, actName) {
    return SelectWorldMap(map,"legend") && SelectWorldAct(actName,"legend")
}

StartRaid(map, act, view?) {
    if !IsSet(view)
        view := LobbyEntryView()
    if !IsObject(view) || !GetRaidDownArrows(map) || !GetRaidActDownArrows(act)
        return false
    ; The supported raid cards and all five act rows are visible without scrolling.
    if !LobbyEntryLabel(view,"i)" map,[612,205,185,251],true)
        || !LobbyEntryLabel(view,"i)" map,[219,161,366,53])
        return false
    number := GetRaidActDownArrows(act)
    return LobbyEntryLabel(view,"i)^(?:(?:raid\s*)?stage|act)\s*" number "(?!\d)",[242,216,121,191],true)
        && LobbyEntryLabel(view,"i)(?:stage|act)\s*" number "(?!\d)",[359,209,220,58])
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

FindMatch(selectAlreadyClicked := false) {
    view := LobbyEntryView()
    if !IsObject(view)
        return false
    findLabel := "^find\s+match$"
    findArea := [392,296,170,102]
    if !selectAlreadyClicked && !LobbyEntryLabel(view,findLabel,findArea,false,1) {
        if !LobbyEntryLabel(view,"^(select|start)$",[328,406,146,59],true)
            return false
    }
    if !LobbyEntryLabel(view,findLabel,findArea,true)
        return false

    deadline := A_TickCount + 50000
    triedCaptcha := false
    while A_TickCount < deadline && WorldViewValid(view) {
        Sleep(350)
        if !WorldViewValid(view)
            return false
        if SummerVerificationVisible() {
            if triedCaptcha
                continue
            triedCaptcha := true
            if CaptchaDetect(252, 292, 300, 50, 400, 335) {
                ProcessLog("Find Match: verification accepted")
                return true
            }
        } else if FindVoteStart(&vx,&vy) || ReadyMatchmakingQueue() {
            ProcessLog("Find Match: queue or Vote Start confirmed")
            return true
        }
    }
    ProcessLog("Find Match: queue was not confirmed within 50s")
    return false
}

ReadyMatchmakingQueue() {
    text := CapysOcrRect(195,130,410,330,2)
    return !!RegExMatch(text,"i)\b(?:finding\s+(?:a\s+)?match|matchmaking\s+in\s+progress|waiting\s+for\s+players|teleporting)\b")
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

        if CapysResultScreenVisible()
            return "no map found"

        ; Periodic lobby detection (respect initial matchmaking queue grace of 15s)
        lobbyGrace := (IsSet(MatchMaking) && ModeAllowsMatchmaking(mode) && MatchMaking.Value) ? 15000 : 3000
        if (A_TickCount - startTime >= lobbyGrace) {
            if IsMacroLobbyVisible() {
                ProcessLog("DetectMap: returned to lobby - returning to main loop")
                return "lobby"
            }
        }

        if (A_TickCount - startTime > timeoutMs) {
            if IsMacroLobbyVisible() {
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
        if (mapName := ReadMatchLoadingCover()) != "" {
            ProcessLog("Map found: " mapName)
            return mapName
        }
        Sleep(350)
        Reconnect(&reconnected)
        if reconnected
            return "reconnected"
    }
}

ReadMatchLoadingCover() {
    global Greenie, Ant, MagicTown, MagicHills, Navy, SnowyTown, SnowyKingdom, DungeonThrone, RainVillage
    global Fiend, Spirit, Academy, SpaceCenter, Mount, Cursed, Nightmare, AirCraft, Hellish, Shibuya, MistyVillage
    static patterns := Map("Planet Greenie",Greenie,"Ant Kingdom",Ant,"Magic Town",MagicTown,
        "Magic Hill",MagicHills,"Navy Bay",Navy,"Snowy Town",SnowyTown,"Snowy Kingdom",SnowyKingdom,
        "Dungeon Throne",DungeonThrone,"Rain Village",RainVillage,"Fiend City",Fiend,
        "Spirit World",Spirit,"Haunted Academy",Academy,"Space Center",SpaceCenter,
        "Mountain Temple",Mount,"Cursed Festival",Cursed,"Nightmare Train",Nightmare,
        "Air Craft",AirCraft,"Hellish City",Hellish,"Shibuya District",Shibuya,"Misty Village",MistyVillage)
    view := LobbyEntryView()
    if !IsObject(view)
        return ""
    for mapName, pattern in patterns {
        if InStr(pattern,".png") {
            oldMode := A_CoordModePixel
            CoordMode "Pixel","Screen"
            try {
                if ImageSearch(&x,&y,view.x,view.y,view.x+view.w-1,view.y+view.h-1,"*60 " A_ScriptDir "\" pattern)
                    return WorldViewValid(view) ? mapName : ""
            } catch {
                continue
            } finally CoordMode "Pixel",oldMode
        } else if LobbyEntryPattern(view,pattern,[10,58,799,128],&x,&y) {
            return mapName
        }
    }
    cover := CapysNormalize(CapysOcrRect(12,60,776,65,2,false))
    if !WorldViewValid(view)
        return ""
    switch cover {
        case "fabledkingdom": return "Fabled Kingdom"
        case "puppetisland": return "Puppet Island"
        case "virtualdungeon": return "Virtual Dungeon"
    }
    return ""
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
        case "Fabled Kingdom":
            return MoveForFabledKingdom()
        case "Ruined City":
            return MoveForRuinedCity()
        case "Adventure Town":
            return MoveForAdventureTown()
        default:
            ProcessLog("No movement route for " MapName "; continuing normal placement at current position")
    }

    return true
}

MoveForFabledKingdom() {
    ; Timings from the recorded Capys Fabled Kingdom route.
    Sleep(628)
    for step in [["s",529,267],["a",960,228],["s",156,184],["a",1392,176],
        ["s",3048,344],["d",280,112],["s",240,128],["d",1144,144],
        ["s",1273,151],["d",632,896]] {
        if !MapWalk(step[1],step[2])
            return false
        Sleep(step[3])
    }
    return MapMovementReady()
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
        if (IsSet(mode) && mode = "Farm")
            return WorldMapNames("main")[1]
        if (IsSet(mode) && InStr("|Infinity Castle|Infinity Mansion|Summer Event|Cursed Womb|Artifacts|Dungeon|Daily Infinite Quest|", "|" mode "|"))
            return ""
        if (IsSet(mode) && mode = "Story" && IsSet(StoryDropdown) && StoryDropdown.Text != "")
            return StoryDropdown.Text
        if (IsSet(mode) && mode = "Infinite" && IsSet(MapDropdown) && MapDropdown.Text != "")
            return MapDropdown.Text
        if (IsSet(mode) && mode = "Legend" && IsSet(LegendDropDown) && LegendDropDown.Text != "") {
            entry := WorldCardEntry(LegendDropDown.Text,"legend")
            return IsObject(entry) ? entry["map"] : ""
        }
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
    global MansionMapName, TransitionCoverMap, DailyQuestMap
    global successfulCoordinates, BossRoomCompleted, CARD_ACTION_BUSY, CARD_INPUT_BLOCKED
    global stageStartTime, ResultCounted, lastResult

    ; Reset per-match global state
    stageStartTime := A_TickCount
    ResultCounted := false
    lastResult := "unknown"
    successfulCoordinates := []
    ResetSmartPlacementState()
    if mode != "Dungeon"
        BossRoomCompleted := false
    ClearCardOffer()
    CARD_ACTION_BUSY := false
    CARD_INPUT_BLOCKED := false

    coverMap := TransitionCoverMap
    TransitionCoverMap := ""
    if mode = "Infinity Mansion" {
        MansionMapName := ""
        knownMap := coverMap
    } else if coverMap != "" {
        knownMap := coverMap
    }
    fallbackMap := (knownMap != "") ? knownMap : ResolveSelectedMap()
    if mode = "Summer Event" {
        SummerMapInterrupted := false
        currentMap := coverMap != "" ? coverMap : DetectMap(65000)
    } else {
        currentMap := knownMap != "" ? knownMap : DetectMap()
    }
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
        return CapysResultScreenVisible() ? HandleStageResult() : false

    status := CheckLoaded()
    if (status = "lobby" || status = "reconnected")
        return status
    if status = "result"
        return HandleStageResult()
    if status != "loaded"
        return false
    if mode = "Farm" {
        started := StartedGame()
        if started != true
            return started
        ProcessLog("Farm: waiting for defeat without placing units")
        return MonitorStage()
    }

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
            if mode = "Daily Infinite Quest" && DailyQuestMap = ""
                DailyQuestMap := ReadInfiniteMatchMap()
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
    view := LobbyEntryView()
    if IsObject(view) && LobbyEntryPattern(view,Disconnect,[330,218,474,247],&x,&y)
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
    global rblxID
    EndCardMatch("relaunch-lobby")
    psLink := FileExist("Settings\PrivateServer.txt") ? FileRead("Settings\PrivateServer.txt", "UTF-8") : ""
    targetUrl := JoinUrl(psLink)
    ProcessLog("Launching Roblox to lobby")

    try ProcessClose("RobloxPlayerBeta.exe")
    closeDeadline := A_TickCount + 5000
    while ProcessExist("RobloxPlayerBeta.exe") && (A_TickCount < closeDeadline) {
        try ProcessClose("RobloxPlayerBeta.exe")
        Sleep(300)
    }
    if ProcessExist("RobloxPlayerBeta.exe") {
        ProcessLog("Recovery: previous Roblox process did not exit")
        return false
    }
    Sleep(1500)

    try Run(targetUrl)
    catch {
        ProcessLog("Recovery: Windows could not launch Roblox")
        return false
    }

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
        if IsMacroLobbyVisible() {
            ProcessLog("Successfully loaded into lobby; ready for next run")
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

PlaceUnit(x, y, slot := 1, &abilityDone := false, greenOnly := false) {
    global rblxID, mode, UpgradePauseEpoch
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

    view := {window:WinActive(rblxID), geometry:SmartPlacementGeometry(), pauseEpoch:UpgradePauseEpoch}
    if !view.window || !view.geometry || !UpgradeViewStable(view) || !UnitActionAllowed()
        return "interrupted"
    oldMouseMode := A_CoordModeMouse
    CoordMode "Mouse", "Client"
    try {
        SendEvent("q")
        if (IsUnitPanelOpenFast() || FindSmartPlacementPanel()) {
            if !CloseUpgradeSelection(view) || !UpgradeViewStable(view)
                return "interrupted"
        }
        if greenOnly && !SmartCapturePreviewReference(x, y, slot, true)
            return "interrupted"
        if !SmartPressSlotKey(slot)
            return "interrupted"
        if greenOnly {
            FixMove(x, y)
            if SmartWaitPreviewReady(x, y, 1200, &details, true) != "ready" {
                if UpgradeViewStable(view) && UnitActionAllowed()
                    SendEvent("q")
                return false
            }
        }
        if !UpgradeViewStable(view) || !UnitActionAllowed(true)
            return "interrupted"
        FixClick(x, y)
        confirmed := UnitPlaced(&abilityDone, view)
        if (confirmed = false && UpgradeViewStable(view) && UnitActionAllowed())
            SendEvent("q")
        return confirmed
    } finally {
        CoordMode "Mouse", oldMouseMode
    }
}

MaxUpgrade(&current := -1) {
    global UnitPanelUsesNewUI
    current := -1
    if !CapysGetClientBox(&cx, &cy, &cw, &ch, &window) || !WinActive("ahk_id " window)
        return false
    if IsUnitPanelOpenFast(&kind)
        compact := (kind = "compact")
    else if FindUnitPanel()
        compact := UnitPanelUsesNewUI
    else
        return false

    level := ReadUnitUpgradeLevel(true, compact)
    maxed := (level = 999)
    if (!maxed && level < 0) {
        view := {x:cx, y:cy, sx:cw/800, sy:ch/599}
        if compact {
            maxed := FindUnitMaxImage(view, "MaxTag.png", [142, 231, 260, 259], 37, 16)
                || FindUnitMaxImage(view, "MaxButton.png", [152, 363, 270, 398], 37, 21)
                || StrLower(RegExReplace(CapysOcrRect(145, 270, 125, 65, 3), "[^A-Za-z]", "")) = "maxupgrade"
                || RegExMatch(CapysOcrRect(160, 368, 100, 24, 4), "i)^\s*max\s*$")
        } else {
            maxed := FindUnitMaxImage(view, "MaxButtonLegacy.png", [185, 340, 315, 395], 60, 35)
                || RegExMatch(CapysOcrRect(210, 350, 80, 35, 3), "i)^\s*max\s*$")
        }
    }

    try WinGetClientPos(&nx, &ny, &nw, &nh, "ahk_id " window)
    catch TargetError
        return false
    if !WinActive("ahk_id " window) || nx != cx || ny != cy || nw != cw || nh != ch
        return false
    current := maxed ? 999 : level
    return !!maxed
}

FindUnitMaxImage(view, filename, region, width, height) {
    static unavailable := Map()
    path := A_ScriptDir "\Images\" filename
    oldMode := A_CoordModePixel
    CoordMode "Pixel", "Screen"
    try {
        options := "*25 *w" Max(1, Round(width * view.sx)) " *h" Max(1, Round(height * view.sy)) " " path
        return ImageSearch(&x, &y, view.x + Round(region[1] * view.sx), view.y + Round(region[2] * view.sy)
            , view.x + Round(region[3] * view.sx), view.y + Round(region[4] * view.sy), options)
    } catch Error {
        if !unavailable.Has(filename) {
            ProcessLog("MAX image unavailable (" filename "). Using text checks.")
            unavailable[filename] := true
        }
        return false
    } finally {
        CoordMode "Pixel", oldMode
    }
}

UnitPlaced(&abilityDone := false, view := 0) {
    global rblxID, mode, AutoAbilityBox
    abilityDone := false
    confirmed := WaitForPlacedUnitPanel(view,&panelKind)
    if confirmed = "uncertain"
        return confirmed
    if confirmed {
        if IsSet(mode) && InStr(mode,"Misty") && DismissDefensePanel() {
            if WinActive(rblxID)
                SendEvent("q")
            return false
        }
        ProcessLog("Unit placement confirmed (" panelKind " panel)")
        if IsSet(mode) && mode = "Summer Event" && ServiceSummerCards()
            return true
        if (!IsObject(view) || UpgradeViewStable(view)) && UnitActionAllowed() {
            if AutoAbilityBox.Value
                CheckAbility()
            abilityDone := true
            if !IsObject(view) || UpgradeViewStable(view)
                CloseUnitPanel()
        }
        return true
    }

    if !UnitActionAllowed(true)
        return CapysResultScreenVisible(1000) ? "ended" : "uncertain"
    if IsObject(view) && !UpgradeViewStable(view)
        return "uncertain"
    if CheckPlacementLimit() {
        ProcessLog("Placement limit reached (unique/max limit)")
        if !IsObject(view) || UpgradeViewStable(view)
            SendEvent("q")
        return "limit"
    }
    if CapysResultScreenVisible(1000)
        return "ended"
    if (IsSet(mode) && mode = "Summer Event" && ServiceSummerCards()) || !UnitActionAllowed()
        return "uncertain"
    return false
}

WaitForPlacedUnitPanel(view, &panelKind) {
    global rblxID
    panelKind := ""
    previous := ""
    Sleep(100)
    loop 4 {
        if !WinActive(rblxID) || (IsObject(view) && !UpgradeViewStable(view))
            return "uncertain"
        panel := IsUnitPanelOpenFast(&kind)
        if !panel
            kind := FindSmartPlacementPanel() ? "smart" : ""
        if !WinActive(rblxID) || (IsObject(view) && !UpgradeViewStable(view))
            return "uncertain"
        if kind != "" && kind = previous {
            panelKind := kind
            return true
        }
        previous := kind
        if A_Index < 4
            Sleep(80)
    }
    return false
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
    smartOpen := !isOpen && FindSmartPlacementPanel()
    if (!isOpen && !smartOpen) {
        if (force && IsSet(mode) && InStr(mode, "Misty") && IsDefensePanelOpen()) {
            DismissDefensePanel()
            return !IsUnitPanelOpenFast() && !FindSmartPlacementPanel()
        }
        if !force
            return true
    }

    oldMouseMode := A_CoordModeMouse
    CoordMode "Mouse", "Screen"
    try {
        loop 3 {
            if IsUnitPanelOpenFast(&kind, &kx, &ky) {
                ; Use detected panel close button coordinates
            } else if FindSmartPlacementPanel() {
                kx := (A_Index = 1) ? 277 : 638
                ky := (A_Index = 1) ? 228 : 549
            } else {
                if (!force || A_Index > 1)
                    return true
                kx := 638, ky := 549
            }
            if !CapysGetClientBox(&cx, &cy, &cw, &ch, &targetWin) || !WinActive("ahk_id " targetWin)
                return false
            sx := cw / 800, sy := ch / 599
            FixClick(cx + Round(kx * sx), cy + Round(ky * sy))
            Sleep(60)
            if !IsUnitPanelOpenFast() && !FindSmartPlacementPanel()
                return true
        }
    } finally {
        CoordMode "Mouse", oldMouseMode
    }
    return !IsUnitPanelOpenFast() && !FindSmartPlacementPanel() && WinActive("ahk_id " targetWin)
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

CapysOcrRect(rx, ry, rw, rh, scale := 2, tryContrast := true, whiteOnly := false, goldOnly := false) {
    if !CapysGetClientBox(&cx, &cy, &cw, &ch)
        return ""
    sx := cw / 800, sy := ch / 599
    sxX := cx + Round(rx * sx)
    sxY := cy + Round(ry * sy)
    sxW := Max(8, Round(rw * sx))
    sxH := Max(8, Round(rh * sy))
    text := ""
    if (!whiteOnly && !goldOnly)
        try text := Trim(OCR.FromRect(sxX, sxY, sxW, sxH, "en-US", scale).Text)
    if (text = "" && tryContrast) {
        try text := Trim(ReadHighContrastText(sxX, sxY, sxW, sxH, Min(Max(scale, 2), 4), 0, false, whiteOnly, goldOnly))
    }
    return text
}

CapysNormalize(text) {
    return StrReplace(StrLower(RegExReplace(text, "[^a-zA-Z0-9]", "")), "repeat", "replay")
}

CapysReadVote(&x, &y, &boardVisible := false) {
    global mode
    boardVisible := false
    if (mode = "Summer Event" || mode = "Infinity Mansion")
        return false
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
    for crop in [[150,55,110,25],[140,60,220,65]] {
        text := CapysOcrRect(crop[1],crop[2],crop[3],crop[4],3,true)
        if RegExMatch(text,"i)\bWave\s*:?\s*([1-9]\d{0,3})\b",&m)
            return Integer(m[1])
    }
    return -1
}

CapysReadResult(&nextVisible := false) {
    text := CapysOcrRect(125, 150, 390, 275, 2, true)
    nextVisible := !!RegExMatch(text, "im)^\h*next\h*$")
    if !nextVisible && (RegExMatch(CapysNormalize(text),"victory|defeat|gameover|\bnext")
        || InStr(CapysNormalize(CapysOcrRect(520,105,250,90,2)),"xpprogress"))
        nextVisible := CapysNormalize(CapysOcrRect(267,370,114,62,3)) = "next"
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
    for crop in [[200, 420, 400, 100, 2, false], [200, 445, 400, 45, 3, true]] {
        norm := CapysNormalize(CapysOcrRect(crop[1], crop[2], crop[3], crop[4], crop[5], crop[6]))
        if RegExMatch(norm, "(?:c[l1i][i1l]ck|tap)any(?:w|vv)here(?:t[o0])?c[o0]nt[i1l]nue")
            return true
    }
    return false
}

CapysButtonPillKind(bx) {
    if !CapysGetClientBox(&cx, &cy, &cw, &ch)
        return ""
    sx := cw / 800, sy := ch / 599
    hdc := DllCall("user32\GetDC", "Ptr", 0, "Ptr")
    if !hdc
        return ""
    greenHits := 0, goldHits := 0
    try {
        for py in [133, 137] {
            syY := cy + Round(py * sy)
            for dx in [-45, -24, 0, 24, 45] {
                c := DllCall("gdi32\GetPixel", "Ptr", hdc, "Int", cx + Round((bx + dx) * sx), "Int", syY, "UInt")
                if (c = 0xFFFFFFFF)
                    continue
                r := c & 255, g := (c >> 8) & 255, b := (c >> 16) & 255
                if (g >= 135 && r <= 90 && b <= 65 && g - b >= 65)
                    greenHits++
                else if (r >= 185 && g >= 130 && b <= 65 && r - b >= 120)
                    goldHits++
            }
        }
    } finally {
        DllCall("user32\ReleaseDC", "Ptr", 0, "Ptr", hdc)
    }
    if greenHits >= 6
        return "green"
    if goldHits >= 6
        return "gold"
    return ""
}

CapysChoiceNormHas(norms, pattern) {
    for norm in norms {
        if (norm != "" && RegExMatch(norm, pattern))
            return true
    }
    return false
}

CapysReadChoice(confirmButtons := true) {
    norms := []
    raw2 := CapysNormalize(CapysOcrRect(130, 80, 545, 110, 2, false))
    if (raw2 != "")
        norms.Push(raw2)

    choicePat := "returnt[o0]l[o0]bb|picknextportal|opendungeon|nextf[l1i]oor|nextroom|nextlevel|replay|retry"
    if !CapysChoiceNormHas(norms, choicePat) {
        raw3 := CapysNormalize(CapysOcrRect(130, 90, 545, 95, 3, false))
        if (raw3 != "")
            norms.Push(raw3)
        if !CapysChoiceNormHas(norms, "returnt[o0]l[o0]bb") {
            white3 := CapysNormalize(CapysOcrRect(130, 90, 545, 95, 3, true, true))
            if (white3 != "")
                norms.Push(white3)
        }
    }

    hasLobby := CapysChoiceNormHas(norms, "returnt[o0]l[o0]bb")
    hasWaiting := CapysChoiceNormHas(norms, "waitingfor(?:players|owner)")
    hasAction := CapysChoiceNormHas(norms, "picknextportal|opendungeon|nextf[l1i]oor|nextroom|nextlevel|replay|retry")

    pillKinds := Map()
    hasAnyPill := false
    if (confirmButtons || !hasLobby || !hasAction) {
        for bx in [224, 312, 400, 488, 576] {
            pk := CapysButtonPillKind(bx)
            pillKinds[bx] := pk
            if (pk != "")
                hasAnyPill := true
        }
    }

    if (!norms.Length && !hasAnyPill)
        return 0

    btnLobbyX := 0, btnReplayX := 0, btnNextX := 0
    if (confirmButtons || hasLobby || hasWaiting || hasAction || hasAnyPill) {
        for bx in [224, 312, 400, 488, 576] {
            pk := pillKinds.Get(bx, "")
            if (!confirmButtons && !hasLobby && !hasWaiting && !hasAction && pk = "")
                continue
            btnText := CapysNormalize(CapysOcrRect(bx - 77, 96, 154, 52, 3, false))
            if (btnText = "" || (pk = "green" && !RegExMatch(btnText, "returnt[o0]l[o0]bb"))) {
                btnWhite := CapysNormalize(CapysOcrRect(bx - 77, 96, 154, 52, 3, true, true))
                if (btnWhite != "")
                    btnText := btnText != "" ? btnText " " btnWhite : btnWhite
            }
            if (btnText = "")
                continue
            norms.Push(btnText)
            if RegExMatch(btnText, "returnt[o0]l[o0]bb") || (pk = "green" && InStr(btnText, "return"))
                btnLobbyX := bx
            else if RegExMatch(btnText, "replay|retry")
                btnReplayX := bx
            else if RegExMatch(btnText, "nextlevel|nextf[l1i]oor|nextroom|picknextportal|opendungeon")
                btnNextX := bx
        }
    }

    hasLobby := CapysChoiceNormHas(norms, "returnt[o0]l[o0]bb") || btnLobbyX > 0
    hasNextPortal := CapysChoiceNormHas(norms, "picknextportal")
    hasOpenDungeon := CapysChoiceNormHas(norms, "opendungeon")
    hasNextFloor := CapysChoiceNormHas(norms, "nextf[l1i]oor")
    hasNextRoom := CapysChoiceNormHas(norms, "nextroom")
    hasNextLevel := CapysChoiceNormHas(norms, "nextlevel")
    hasReplay := CapysChoiceNormHas(norms, "replay")
    hasRetry := CapysChoiceNormHas(norms, "retry")
    hasWaitPlayers := CapysChoiceNormHas(norms, "waitingforplayers")
    choiceSignal := hasLobby || (hasWaitPlayers && (hasReplay || hasRetry || hasNextLevel || hasNextFloor || hasNextRoom || hasNextPortal || hasOpenDungeon)) || (hasAnyPill && (hasReplay || hasRetry || hasNextLevel || hasNextFloor || hasNextRoom || hasNextPortal || hasOpenDungeon))

    if !choiceSignal
        return 0

    res := Map("kind", "none", "hasNextLevel", 0, "hasNextRoom", 0, "hasNextFloor", 0, "hasNextPortal", 0, "hasOpenDungeon", 0, "hasRetry", 0, "replayX", 0, "nextLevelX", 0, "lobbyX", 0, "ownerWait", 0)
    if hasNextPortal {
        res["kind"] := "choice", res["hasNextPortal"] := 1, res["replayX"] := 488, res["lobbyX"] := 312
    } else if hasOpenDungeon {
        res["kind"] := "choice", res["hasOpenDungeon"] := 1, res["lobbyX"] := 312
    } else if hasNextFloor {
        res["kind"] := "choice", res["hasNextFloor"] := 1, res["nextLevelX"] := 488, res["lobbyX"] := 312
    } else if hasNextRoom {
        res["kind"] := "choice", res["hasNextRoom"] := 1, res["nextLevelX"] := 488, res["lobbyX"] := 312
    } else if hasReplay {
        res["kind"] := "choice"
        res["hasNextLevel"] := hasNextLevel ? 1 : 0
        res["replayX"] := res["hasNextLevel"] ? 400 : 488
        res["nextLevelX"] := res["hasNextLevel"] ? 576 : 0
        res["lobbyX"] := res["hasNextLevel"] ? 224 : 312
    } else if hasRetry {
        res["kind"] := "choice", res["hasRetry"] := 1, res["replayX"] := 488, res["lobbyX"] := 312
    } else if hasLobby {
        res["kind"] := "choice", res["lobbyX"] := 400
    } else {
        return 0
    }

    if hasNextLevel
        res["hasNextLevel"] := 1
    if btnLobbyX > 0
        res["lobbyX"] := btnLobbyX
    if btnReplayX > 0
        res["replayX"] := btnReplayX
    if btnNextX > 0
        res["nextLevelX"] := btnNextX
    res["ownerWait"] := CapysChoiceNormHas(norms, "waitingforowner") ? 1 : 0
    return res
}

CapysResultScreenVisible(cacheMs := 0) {
    global mode
    static lastAt := 0, lastWin := 0
    hwnd := RefreshClientTarget()
    if (cacheMs > 0 && hwnd && hwnd = lastWin && (A_TickCount - lastAt < cacheMs))
        return false

    res := false
    if mode = "Dungeon" && IsObject(view := LobbyEntryView()) && ReadDungeonDeath(view)
        res := true
    else if CapysReadResult(&nextVisible) != ""
        res := true
    else if nextVisible && InStr(CapysNormalize(CapysOcrRect(520, 105, 250, 90, 2, true)), "xpprogress")
        res := true
    else
        res := CapysReadReward() || IsObject(CapysReadChoice(false))

    if !res {
        lastAt := A_TickCount
        lastWin := hwnd
    } else {
        lastAt := 0
    }
    return res
}

ParseUnitUpgradeLevel(text) {
    if (text = "")
        return -1

    clean := StrUpper(Trim(text))

    ; 1. Nhan dien MAX (UPG [MAX], UPG MAX, (MAX), MAX, vv.)
    if RegExMatch(clean, "\b(?:UPGRADE|UPG)\b[\s.:\[(\-]*MAX\b|^[\[(]?\s*MAX\s*[\])]?$")
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

ReadUnitUpgradeLevel(panelKnown := false, compact := true) {
    global UnitPanelUsesNewUI
    if !panelKnown {
        if !FindUnitPanel()
            return -1
        compact := UnitPanelUsesNewUI
    }
    if !compact {
        header := CapysOcrRect(165, 190, 145, 40, 3)
        return RegExMatch(header, "i)\bMAX\b") ? 999 : ParseUnitUpgradeLevel(header)
    }

    ; Read the full header so MAX stays visible alongside UPG.
    header := CapysOcrRect(142, 232, 118, 23, 4, false)
    if RegExMatch(header, "i)\b(?:UPG|UPGRADE)\b[\s\S]*\bMAX\b")
        return 999
    level := ParseUnitUpgradeLevel(header)
    if level >= 0
        return level
    if !CapysGetClientBox(&cx, &cy, &cw, &ch)
        return -1
    sx := cw / 800, sy := ch / 599
    level := ParseUnitUpgradeLevel(CapysOcrRect(145, 233, 62, 20, 2, false))
    if level >= 0
        return level
    try return ParseUnitUpgradeLevel(ReadHighContrastText(cx + Round(145*sx), cy + Round(235*sy)
        , Max(8, Round(50*sx)), Max(8, Round(15*sy)), 3, 0, false, false, true))
    return -1
}

PressUnitUpgrade(view := 0) {
    global rblxID
    if !UnitActionAllowed(true) || !WinActive(rblxID) || (IsObject(view) && !UpgradeViewStable(view))
        return false
    ; Let SendEvent release the key even if the macro is paused after sending it.
    oldDelay := A_KeyDelay, oldDuration := A_KeyDuration
    SetKeyDelay(oldDelay, 80)
    try SendEvent("{r}")
    finally SetKeyDelay(oldDelay, oldDuration)
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
        if MaxUpgrade(&current) {
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

IsMacroLobbyVisible() {
    global AreaText
    view := LobbyEntryView()
    if !IsObject(view)
        return false
    if WorldImageFind("World_Areas.png",view,[738,448,798,510],44,16,&x,&y,90)
        || LobbyEntryPattern(view, AreaText, [738, 453, 799, 538], &x, &y)
        return true
    text := CapysOcrRect(738, 451, 62, 88, 3)
    return WorldViewValid(view) && RegExMatch(text,"im)^\h*areas\h*$")
}

CheckLobby() {
    waitStart := A_TickCount
    loop {
        Sleep 1000
        RefreshClientTarget()
        if IsMacroLobbyVisible() {
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
        return false
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
        return false
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
        if CapysReadWave() >= 1 && !CapysResultScreenVisible(1000)
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
        return nx=cx && ny=cy && nw=cw && nh=ch && !CapysResultScreenVisible(1000)
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
        if CapysResultScreenVisible()
            return "result"

        if FindVoteStart(&X, &Y) {
            if targetWin && !WinActive("ahk_id " targetWin)
                try WinActivate("ahk_id " targetWin)
            ProcessLog(summer ? "Match loaded: Summer Vote Start confirmed" : "Match loaded: Vote Start detected")
            return "loaded"
        }

        if SummerMatchStarted() {
            ProcessLog("Summer Event: active match HUD detected; match loaded")
            return "loaded"
        }
        if !summer && RegularMatchHudVisible() {
            if targetWin && !WinActive("ahk_id " targetWin)
                try WinActivate("ahk_id " targetWin)
            ProcessLog("Match loaded: Wave / HUD confirmed")
            return "loaded"
        }

        ; 2. Kiểm tra bị đá về sảnh (chờ tối thiểu 15s khi MatchMaking bật để tránh nhận nhầm lúc đang đếm Teleport)
        lobbyGrace := (IsSet(MatchMaking) && ModeAllowsMatchmaking(mode) && MatchMaking.Value) ? 15000 : 3000
        if (A_TickCount - loadStart >= lobbyGrace) {
            if IsMacroLobbyVisible() {
                ProcessLog("Lobby detected (match aborted or failed to teleport) - returning to main loop")
                Sleep(1000)
                return "lobby"
            }
        }

        if (A_TickCount - loadStart >= 120000) {
            ProcessLog("CheckLoaded timed out after 120s; recovering to lobby...")
            return RecoverToLobby()
        }

        if (A_TickCount >= deadline) {
            ProcessLog("Still waiting for match load / Vote Start...")
            deadline := A_TickCount + 15000
        }

        Reconnect(&reconnected)
        if reconnected
            return "reconnected"
    }
}

StartedGame() {
    global mode, MatchMaking, SummerMinimumPlayers, stageStartTime, ResultCounted, lastResult
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
        if (summer || mode = "Infinity Mansion") && !WinActive("ahk_id " targetWin) {
            try WinActivate("ahk_id " targetWin)
            continue
        }
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

    ProcessLog("Match ready")
    stageStartTime := A_TickCount
    ResultCounted := false
    lastResult := "unknown"
    return true
}

ClickVoteStart(targetWin, cx, cy, cw, ch, x, y) {
    global mode
    if !CapysGetClientBox(&nx, &ny, &nw, &nh, &window) || window != targetWin
        || nx != cx || ny != cy || nw != cw || nh != ch || !WinActive("ahk_id " targetWin)
        return false
    if (mode = "Summer Event" || mode = "Infinity Mansion") {
        if (x <= 0 || y <= 0)
            return false
    } else {
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
        ProcessLog("Select a mode before pressing F2")
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
        return HandleStageResult()
    }
}

ClickUntilGone(x, y, searchX1, searchY1, searchX2, searchY2, textToFind, offsetX := 0, offsetY := 0, textToFind2 := "") {
    view := LobbyEntryView()
    if !IsObject(view)
        return false
    pattern := textToFind2 = "" ? textToFind : textToFind "|" textToFind2
    loop 6 {
        if !WorldViewValid(view)
            return false
        if !LobbyEntryPattern(view, pattern, [searchX1,searchY1,searchX2,searchY2], &X, &Y)
            return WorldViewValid(view)
        if (offsetX != 0 || offsetY != 0) {
            clicked := WorldClick(view,X + offsetX,Y + offsetY)
        } else {
            clicked := WorldClick(view,x,y)
        }
        if !clicked
            return false
        Sleep(1000)
    }
    ProcessLog("A menu remained open after six confirmed clicks")
    return false
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
    global macroRunning, mode, ResultCounted, TransitionCoverMap, DailyQuestMap

    if macroRunning {
        ProcessLog("Macro is already running")
        return
    }
    macroRunning := true
    ProcessLog("F2: starting macro (24/7 continuous run loop)...")

    try {
        if !ValidateMode()
            return

        mode := ModeDropdown.Text
        nextStep := "auto"
        failures := 0
        ResultCounted := false
        TransitionCoverMap := ""
        DailyQuestMap := ""
        while macroRunning {
            try {
                if !(window := RefreshClientTarget()) {
                    res := RecoverToLobby()
                } else if nextStep = "replay" {
                    ProcessLog("Seamless Replay / Next Stage: starting stage...")
                    res := RestartStage(ResolveSelectedMap())
                } else {
                    if !WinActive("ahk_id " window)
                        try WinActivate("ahk_id " window)
                    if CapysResultScreenVisible()
                        status := "result"
                    else if IsMacroLobbyVisible() || (mode = "Cursed Womb" && CursedWombKeyPanelVisible())
                        status := "lobby"
                    else
                        status := CheckLoaded()
                    if (status = "lobby" || status = "reconnected") {
                        ProcessLog("Lobby ready; starting selected mode...")
                        res := StartSelectedMode()
                    } else if (status = "result") {
                        res := HandleStageResult()
                    } else if status = "loaded" {
                        res := RestartStage()
                    } else
                        res := false
                }
            } catch as innerErr {
                ProcessLog("Macro loop error (" Type(innerErr) ") at line " innerErr.Line)
                res := false
            }
            if res = "complete"
                break
            if (res = "replay" || res = "lobby" || res = "reconnected") {
                nextStep := res
                failures := 0
                Sleep(1000)
                continue
            }
            nextStep := "auto"
            failures := Min(failures + 1, 5)
            retryMs := Min(30000, 2000 * 2**(failures - 1))
            ProcessLog("Stage interrupted; checking recovery after " (retryMs // 1000) "s")
            Sleep(retryMs)
            if macroRunning {
                try {
                    if !IsMacroLobbyVisible() && !CapysResultScreenVisible()
                        nextStep := RecoverToLobby()
                }
                catch as recoveryErr
                    ProcessLog("Recovery error (" Type(recoveryErr) ") at line " recoveryErr.Line)
            }
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
    global UpgradePauseEpoch
    UpgradePauseEpoch++
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
    return MonitorEndScreen()
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
    global BossRoom, BossRoom2, Chest, Hoard, Enter, BossRoomCompleted
    view := LobbyEntryView()
    if !IsObject(view)
        return false
    deadline := A_TickCount + 8000
    while !DungeonRouteVisible() {
        if !WorldViewValid(view) || A_TickCount >= deadline
            return false
        Sleep(250)
    }
    if LobbyEntryPattern(view,BossRoom "|" BossRoom2,[140,180,480,350],&x,&y) {
        ProcessLog("Boss room found!")
        if !WorldClick(view,x,y-30)
            return false
        Sleep(1000)
        BossRoomCompleted := true
    } else if LobbyEntryPattern(view,Chest "|" Hoard,[200,350,600,435],&x,&y) {
        if !WorldClick(view,x,y-30)
            return false
        Sleep(1000)
    }
    if !LobbyEntryPattern(view,Enter,[120,425,680,500],&x,&y) || !WorldClick(view,x,y-30)
        return false
    if WaitForResultTransition("replay")
        return "replay"
    ProcessLog("Dungeon: room entry was not confirmed")
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
        loop 6 {
            ; Click first chest OPEN button
            ClickOnce(0, 0, 535, 265, 605, 315, OpenChest, -3, -35)
            Sleep(2000)

            ; Check if we're still on the chest screen
            if (!IsChestScreenVisible()) {
                if !ClaimChestReward()
                    return false
            } else {
                break
            }
        }

        ; Process second chest position - keep clicking until exhausted
        loop 6 {
            ; Click second chest OPEN button
            ClickOnce(0, 0, 530, 330, 605, 375, OpenChest, -3, -35)
            Sleep(1000)

            ; Check if we're still on the chest screen
            if (!IsChestScreenVisible()) {
                if !ClaimChestReward()
                    return false
            } else {
                break
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
        if !CapysReadReward() || !IsObject(view := LobbyEntryView())
            return false
        if !WorldClick(view,560,560)
            return false
        Sleep(500)

        ; Check if chest screen has returned
        if (IsChestScreenVisible()) {
            return true
        }
        clicks++
    }
    ProcessLog("Dungeon: chest reward remained open")
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
