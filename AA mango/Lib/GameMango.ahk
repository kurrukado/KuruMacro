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

PlacementPointUsed(points,point) {
    for used in points {
        if Abs(used.x-point.x)<2 && Abs(used.y-point.y)<2
            return true
    }
    return false
}

PlacementSlotOrder(smart) {
    if !smart
        return [1,2,3,4,5,6]
    slots := []
    for farmPass in [true,false] {
        for slot in [1,2,3,4,5,6] {
            if (GetUnitPlacementType(slot)="Farm")=farmPass
                slots.Push(slot)
        }
    }
    return slots
}

PlacingUnits() {

    global successfulCoordinates, UnitPlacements, SmartPlacementColor, mode, rblxID

    smart := PlacementPatternDropdown.Text = "Smart"
    if smart
        ResetSmartPlacementState()

    LoadUnitCoordsFromFile()

    successfulCoordinates := []

    placedCounts := Map()
    slotSearch := Map()
    placementGeometry := smart ? SmartPlacementGeometry() : ""

    requestedTotal := 0
    nextPlacementUpgrade := A_TickCount + 15000
    nextPlacementService := 0
    placementUpgradeCursor := 0

    anyEnabled := false

    for slotNum in [1, 2, 3, 4, 5, 6] {

        enabled := "enabled" slotNum

        enabled := %enabled%

        enabled := enabled.Value

        if (enabled) {

            anyEnabled := true

            break

        }

    }

    if (!anyEnabled) {

        ProcessLog("No Units Selected - Returning")

        return MonitorStage()

    }

    defaultPoints := smart ? [] : PlacementPatternDropdown.Text = "Circle" ? GenerateCirclePoints() :

        PlacementPatternDropdown.Text = "Grid" ? GenerateGridPoints() :

            GenerateRandomPoints()

    ; Farm first, then configured non-Farm slots in numerical order.
    slotOrder := PlacementSlotOrder(smart)

    while slotOrder.Length {
        slotNum := slotOrder.RemoveAt(1)

        enabled := "enabled" slotNum

        enabled := %enabled%

        enabled := enabled.Value

        ; Get number of placements wanted for this slot

        placements := "placement" slotNum

        placements := %placements%

        placements := Integer(placements.Text)

        ; Initialize count if not exists

        if !placedCounts.Has(slotNum)

            placedCounts[slotNum] := 0

        ; If enabled, place all units for this slot

        if (enabled && placements > 0) {

            firstVisit := !slotSearch.Has(slotNum)
            if firstVisit {
                requestedTotal += placements
                ProcessLog("Placing Unit: " slotNum " (0/" placements ")")
            }

            targetPoints := []
            failedPoints := []

            usingCustom := false

            if smart && !firstVisit {
                search := slotSearch[slotNum]
                targetPoints := search.points
                failedPoints := search.failed
            } else if (!smart && IsSet(UnitPlacements) && UnitPlacements.Has(slotNum) && UnitPlacements[slotNum].Length > 0) {

                usingCustom := true

                ProcessLog("Unit " slotNum ": Using CUSTOM positions from map")

                for pt in UnitPlacements[slotNum] {

                    targetPoints.Push({ x: pt[1], y: pt[2] })

                }

            } else {

                if smart {
                    targetPoints := GenerateSmartPoints(&placementScale, slotNum)
                    ProcessLog("Smart: slot " slotNum ", type=" GetUnitPlacementType(slotNum) ", search=random near player feet")
                } else {
                    ProcessLog("Unit " slotNum ": Using " PlacementPatternDropdown.Text " pattern")
                    targetPoints := defaultPoints
                }

            }

            ; Place all units for this slot

            loopSafety := 0
            searchBatches := 1

            stopThisSlot := false
            unreadableStreak := 0
            batchSkipped := []
            if smart {
                if firstVisit {
                    search := {points: targetPoints, failed: failedPoints, skipped: [], next: 1, batches: 1, unreadable: 0, nextLog: 0, hillVersion: SmartHillRegionVersion(slotNum)}
                    slotSearch[slotNum] := search
                }
                batchSkipped := search.skipped
                unreadableStreak := search.unreadable
                searchBatches := search.batches
            }
            failedAttempts := 0
            turnStarted := A_TickCount
            yieldSlot := false

            while (placedCounts[slotNum] < placements) {

                if smart && SmartHillRegionVersion(slotNum) != search.hillVersion {
                    targetPoints := GenerateSmartPoints(&placementScale, slotNum)
                    search.points := targetPoints, search.next := 1
                    search.hillVersion := SmartHillRegionVersion(slotNum)
                }

                if smart && targetPoints.Length = 0
                    break ; The client arena is unavailable; do not spin regenerating points.

                if smart {
                    if !WinActive(rblxID) {
                        Sleep(100)
                        yieldSlot := true
                        break
                    }
                    ServiceSummerCards()
                    if SmartPreviewInterrupted(true) {
                        Sleep(100)
                        yieldSlot := true
                        break
                    }
                    ; Even when every point is skipped, service the match and upgrades.
                    ; PlaceUnit retains its fresh pre-input result/card/focus checks.
                    if A_TickCount >= nextPlacementService {
                        if CheckForXp()
                            return MonitorStage()
                        Wave40Reached()
                        Reconnect()
                        CheckEndAndRoute()
                        nextPlacementService := A_TickCount + 1000
                    }
                    geometry := SmartPlacementGeometry()
                    if geometry = "" || geometry != placementGeometry {
                        ProcessLog("Smart: client geometry changed; ending placement before reusing screen coordinates")
                        successfulCoordinates := []
                        return false
                    }
                }

                loopSafety++

                if (usingCustom && loopSafety > 20) {

                    ProcessLog("Warning: Could not place all custom units for Slot " slotNum)

                    break

                }

                hadUntestedPoint := false

                for pointIndex, point in targetPoints {

                    if smart {
                        if pointIndex < search.next
                            continue
                        geometry := SmartPlacementGeometry()
                        if geometry = "" || geometry != placementGeometry {
                            ProcessLog("Smart: client geometry changed; ending placement before reusing screen coordinates")
                            successfulCoordinates := []
                            return false
                        }
                        if failedAttempts >= 4 || A_TickCount - turnStarted >= 6000 {
                            yieldSlot := true
                            break
                        }
                        search.next := pointIndex + 1
                    }

                    ; Skip if this coordinate was already used successfully

                    alreadyUsed := smart
                        ? SmartPlacementTooClose(successfulCoordinates, point, placementScale) || SmartRecentPoint(batchSkipped, point, placementScale)
                        : PlacementPointUsed(successfulCoordinates, point)

                    if (alreadyUsed)

                        continue

                    if (smart ? SmartRecentPoint(failedPoints, point, placementScale) : PlacementPointUsed(failedPoints, point))

                        continue

                    hadUntestedPoint := true

                    placementResult := smart ? PlaceUnit(point.x, point.y, slotNum, unreadableStreak > 0)
                        : PlaceUnit(point.x, point.y, slotNum)
                    if smart
                        failedAttempts++
                    if smart && placementResult="unreadable-point" {
                        unreadableStreak:=0
                        SmartRememberPoint(batchSkipped, point, true)
                        ProcessLog("Smart: slot " slotNum " ghost confirmed but point unreadable; trying another candidate")
                        continue
                    }
                    if smart && placementResult = "unreadable" {
                        search.next := pointIndex
                        unreadableStreak++
                        if unreadableStreak >= 3 {
                            ProcessLog("Smart: slot " slotNum " preview could not be verified after 3 selections; stopping slot without marking terrain invalid")
                            stopThisSlot := true
                        } else
                            ProcessLog("Smart: slot " slotNum " preview not confirmed; retrying the same point with the physical number key (" unreadableStreak "/2)")
                        break
                    }
                    unreadableStreak := 0
                    if (placementResult = "uncertain") {
                        ProcessLog("Placement interrupted after a click; leaving slot " slotNum " pending to avoid an unverified duplicate")
                        stopThisSlot := true
                        break
                    }
                    if (placementResult = "interrupted") {
                        if ((smart || mode = "Summer Event") && WinActive(rblxID) && ResultScreenReady())
                            return false ; RestartStage hands off to MonitorStage.
                        if smart {
                            search.next := pointIndex
                            yieldSlot := true
                        } else
                            batchSkipped := []
                        break ; reselect this slot after the Summer card offer closes
                    }
                    if (placementResult = true) {
                        if smart
                            SmartRecordPlacementOutcome(slotNum, true)

                        successfulCoordinates.Push({ x: point.x, y: point.y, slot: slotNum })

                        placedCounts[slotNum] += 1
                        nextPlacementUpgrade := A_TickCount + 15000
                        ProcessLog("Placed Unit: " slotNum " (" placedCounts[slotNum] "/" placements ")")

                        if smart {
                            failedAttempts := 0
                            turnStarted := A_TickCount
                        } else {
                            Sleep(500)
                            CloseUnitPanel()
                        }

                        break

                    }

                    ; Unconfirmed points cool down; only red previews reject terrain.
                    if smart {
                        SmartRememberPoint(placementResult = "blocked" ? failedPoints : batchSkipped, point, placementResult != "blocked")
                    } else
                        failedPoints.Push(point)
                    if placementResult != "blocked" {
                        ProcessLog("Placement not verified for unit " slotNum " at " point.x "," point.y "; trying another point")
                    }

                    if smart && SmartHillRegionVersion(slotNum) != search.hillVersion
                        break ; Newly scanned Hill regions take priority on the next turn.

                    if !smart {
                        Wave40Reached()
                        if CheckForXp()
                            return MonitorStage()
                        Reconnect()
                        CheckEndAndRoute()
                    }

                }

                if (stopThisSlot)

                    break

                if smart && yieldSlot
                    break

                if (!hadUntestedPoint) {
                    if smart {
                        searchBatches++
                        targetPoints := GenerateSmartPoints(&placementScale, slotNum)
                        search.points := targetPoints
                        search.next := 1
                        if A_TickCount >= search.nextLog {
                            ProcessLog("Smart: slot " slotNum " exhausted candidates; generating Random batch " searchBatches)
                            search.nextLog := A_TickCount + 5000
                        }
                        yieldSlot := true
                        ; Keep the slot pending until its configured Count is
                        ; reached: upgrades wait for every slot, and a finished
                        ; match or a geometry change is still detected above.
                        ; All candidates may be in cooldown, so poll slowly.
                        Sleep(targetPoints.Length > 0 ? 100 : 400)
                        break
                    }

                    ProcessLog("No valid placement points left for unit " slotNum " (" placedCounts[slotNum] "/" placements ")")

                    break

                }

                if (usingCustom && A_Index > 1 && placedCounts[slotNum] < placements) {

                    if (placedCounts[slotNum] >= targetPoints.Length) {

                        ProcessLog("Placed all available custom points for Unit " slotNum)

                        break

                    }

                }

                if !smart
                    Sleep(500)

            }

            if smart {
                search.batches := searchBatches
                search.unreadable := unreadableStreak
                if yieldSlot && !stopThisSlot && placedCounts[slotNum] < placements {
                    slotOrder.Push(slotNum)
                    if A_TickCount >= search.nextLog {
                        ProcessLog("Smart: slot " slotNum " yielding (" placedCounts[slotNum] "/" placements "); will retry after other pending slots")
                        search.nextLog := A_TickCount + 5000
                    }
                    continue
                }
            }
            if smart && placedCounts[slotNum]<placements {
                ProcessLog("Smart: slot " slotNum " incomplete (" placedCounts[slotNum] "/" placements "); continuing with other slots and confirmed units")
            }
        }

    }

    placedTotal := 0

    for slotNum, count in placedCounts

        placedTotal += count

    if (placedTotal < requestedTotal)

        ProcessLog("Placed " placedTotal "/" requestedTotal " units - remaining: " (requestedTotal - placedTotal) " units")

    else

        ProcessLog("Placed all " placedTotal "/" requestedTotal " units")

    if smart && placedTotal = 0
        return false
    if smart && SmartPlacementGeometry() != placementGeometry {
        successfulCoordinates := []
        ProcessLog("Smart: client geometry changed; skipping upgrades at stale coordinates")
        return false
    }
    UpgradeUnits()
    return true

}

UpgradeWhilePlacing(&cursor) {
    global successfulCoordinates, PriorityUpgrade
    ; Keep explicit upgrade priorities and avoid spending on farms mid-placement.
    if PriorityUpgrade.Value
        return
    count := successfulCoordinates.Length
    loop count {
        cursor := Mod(cursor, count) + 1
        coord := successfulCoordinates[cursor]
        if GetUnitPlacementType(coord.slot) = "Farm"
            continue
        ProcessLog("Smart: placement search is taking time; trying one upgrade for confirmed slot " coord.slot)
        UpgradeUnit(coord.x, coord.y, coord.slot)
        return
    }
}

UpgradeUnits() {

    global successfulCoordinates, PriorityUpgrade, priority1, priority2, priority3, priority4, priority5, priority6, rblxID

    totalUnits := Map()

    upgradedCount := Map()

    ; Initialize counters

    for coord in successfulCoordinates {

        if (!totalUnits.Has(coord.slot)) {

            totalUnits[coord.slot] := 0

            upgradedCount[coord.slot] := 0

        }

        totalUnits[coord.slot]++

    }

    ProcessLog("Process to upgrading...")

    if (PriorityUpgrade.Value) {

        ProcessLog("Using priority system")

        ; Go through each priority level (1-6)

        for priorityNum in [1, 2, 3, 4, 5, 6] {

            ; Find which slot has this priority number

            for slot in [1, 2, 3, 4, 5, 6] {

                priority := "priority" slot

                priority := %priority%

                if (priority.Text = priorityNum) {

                    ; Skip if no units in this slot

                    hasUnitsInSlot := false

                    for coord in successfulCoordinates {

                        if (coord.slot = slot) {

                            hasUnitsInSlot := true

                            break

                        }

                    }

                    if (!hasUnitsInSlot) {

                        continue

                    }

                    ProcessLog("Priority upgrade for: " priorityNum " (slot " slot ")")

                    ; Keep upgrading current slot until all its units are maxed

                    while true {

                        slotDone := true

                        for index, coord in successfulCoordinates {

                            if (coord.slot = slot) {

                                slotDone := false

                                upgradeResult := UpgradeUnit(coord.x, coord.y, coord.slot)

                                if CheckForXp() {

                                    ProcessLog("Stage ended during upgrades, proceeding to results")

                                    successfulCoordinates := []

                                    MonitorStage()

                                    return

                                }

                                if (upgradeResult = false) {
                                    Sleep(200)
                                    if !ServiceSummerCards() && WinActive(rblxID) {
                                        Reconnect()
                                        CheckEndAndRoute()
                                    }
                                    continue ; no ability/world clicks when the upgrade was not confirmed
                                }

                                if (upgradeResult = "limit" || upgradeResult = "max") {

                                    upgradedCount[coord.slot]++

                                    ProcessLog((upgradeResult = "limit" ? "Max Level reached for: " : "Maxed out for: ") coord.slot " (" upgradedCount[coord.slot] "/" totalUnits[

                                        coord.slot] ")")

                                    successfulCoordinates.RemoveAt(index)


                                    break

                                }

                                Sleep(200)

                                if (ServiceSummerCards() || !UnitActionAllowed())
                                    continue

                                Reconnect()

                                CheckEndAndRoute()

                                Wave40Reached()

                            }

                        }

                        if (slotDone || successfulCoordinates.Length = 0) {

                            ProcessLog("Upgrade Priority maxed for: " priorityNum)

                            break

                        }

                    }

                }

            }

        }

        ProcessLog("Priority Upgrade successfully")

        return MonitorStage()

    } else {

        ; Normal upgrade (no priority)

        while true {

            if (successfulCoordinates.Length == 0) {

                ProcessLog("All units reached max or configured Max Level, waiting for end stage...")

                return MonitorStage()

            }

            for index, coord in successfulCoordinates {

                upgradeResult := UpgradeUnit(coord.x, coord.y, coord.slot)

                if CheckForXp() {

                    ProcessLog("Stage ended, replay...")

                    successfulCoordinates := []

                    MonitorStage()

                    return

                }

                if (upgradeResult = false) {
                    Sleep(200)
                    if !ServiceSummerCards() && WinActive(rblxID) {
                        Reconnect()
                        CheckEndAndRoute()
                    }
                    continue ; no ability/world clicks when the upgrade was not confirmed
                }

                if (upgradeResult = "limit" || upgradeResult = "max") {

                    upgradedCount[coord.slot]++

                    ProcessLog((upgradeResult = "limit" ? "Max Level reached for: " : "Maxed out for: ") coord.slot " (" upgradedCount[coord.slot] "/" totalUnits[coord.slot] ")"

                    )

                    successfulCoordinates.RemoveAt(index)
                    break ; Restart enumeration after removing the current unit.

                }

                Sleep(200)

                if (ServiceSummerCards() || !UnitActionAllowed())
                                    continue

                Reconnect()

                Wave40Reached()

                CheckEndAndRoute()

            }

        }

    }

}

IsModeCancelOpen(&outX := 0, &outY := 0) {

    global ModeCancel, Greenie, mode
    if (mode = "Infinite" || mode = "Story")
        return !!RegExMatch(SummerReadUI(), "i)select\s+world")

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
WaitForModeDialog(moveFn, modeName, maxAttempts := 10) {

    moveFn()

    attempts := 0

    while !IsModeCancelOpen(&x, &y) {

        if (attempts >= maxAttempts) {

            ProcessLog("Could not reach the " modeName " dialog after " maxAttempts " movement attempts; stopping safely")

            return false

        }

        attempts++

        ProcessLog("Retrying " modeName " route: " attempts "/" maxAttempts)

        moveFn()

    }

    return true

}

; Summer Event adapter (not tested end-to-end). UI input uses the same
; FixClick and Event movement as the existing macro. CAPTCHA in Function.ahk.
global SummerAwaitingMatch := false
global SummerMapName := ""
global SummerMapInterrupted := false
OnExit(ReleaseMapMovement)

IsInMatch() {
    global Yen, VoteStart
    try {
        ; 1. Bảng Vote Start xuất hiện đầu trận
        if (FindText(&vx, &vy, 333, 61, 465, 101, 0, 0, VoteStart) || PixelGetColor(320, 60) = 0x00EE00)
            return true
        ; 2. Biểu tượng Yên (¥) luôn hiển thị khi trận đấu đang diễn ra
        if FindText(&yx, &yy, 340, 515, 530, 565, 0, 0, Yen)
            return true
        ; 3. Kiểm tra OCR từ khóa trong trận (Wave, Path, Enemies Remaining, Weather)
        uiText := SummerReadUI(0, 300)
        if (uiText != "" && RegExMatch(uiText, "i)\b(wave|path\s*\d|enemies\s+remaining|weather)\b"))
            return true
    }
    return false
}

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
    if !RegExMatch(key,"^[wasd]{1,2}$") || (StrLen(key)=2 && (SubStr(key,1,1)=SubStr(key,2,1)
        || (InStr(key,"w") && InStr(key,"s")) || (InStr(key,"a") && InStr(key,"d"))))
        || ms<20 || ms>10000 || !MapMovementReady()
        return false
    WinGetClientPos(&cx,&cy,&cw,&ch,rblxID)
    oldDelay:=A_KeyDelay, oldDuration:=A_KeyDuration
    SetKeyDelay(-1,-1)
    deadline:=A_TickCount+ms, nextScene:=A_TickCount+500
    try {
        down:=""
        loop parse key
            down.="{" A_LoopField " down}"
        SendEvent(down)
        SetTimer(ReleaseMapMovement,-ms)
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
        SetTimer(ReleaseMapMovement,0)
        ReleaseMapMovement()
        SetKeyDelay(oldDelay,oldDuration)
    }
}

ReleaseMapMovement(*) {
    SendEvent("{w up}{a up}{s up}{d up}")
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
    scene:=ReadResultScreen(false)
    if !IsObject(scene) || Trim(scene.Text)="" {
        ProcessLog("Map movement stopped: scene unreadable")
        return false
    }
    if ResultScreenPhase(scene)!="" || RegExMatch(scene.Text,"i)\bdefeat\b|\bvictory\b|xp\s+progress|waiting\s+for\s+players|disconnected|choose\s+a\s+card|return\s+to\s+lobby") {
        ProcessLog("Map movement stopped: result/card/disconnect scene")
        return false
    }
    return true
}

; Compatibility for external callers. Map routes themselves use generic helpers.
SummerWalk(key, ms) => MapWalk(key, ms)
SummerMovementReady() => MapMovementReady()
SummerReleaseMovement(args*) => ReleaseMapMovement(args*)

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
        WinGetClientPos(&cx, &cy,,, win)
        if CaptchaDetect(232, 290, 581, 350, 400, 340, true) && WinActive(win)
            FixClick(300, 385)
        Sleep(500)
    }
    return SummerWaitForVerification()
}

SummerEventMode() {
    global rblxID, MatchMaking, SummerAwaitingMatch, SummerMapName, mode
    mode := "Summer Event"
    ProcessLog("Summer Event: starting...")

    targetWin := WinExist(rblxID)
    if !targetWin
        targetWin := WinExist("Roblox")
    if !targetWin {
        ProcessLog("Summer Event: Roblox window not found!")
        return false
    }
    WinActivate("ahk_id " targetWin)
    Sleep(200)

    ; Kiểm tra bảng xác minh Captcha nếu có
    if SummerVerificationVisible() {
        SummerAwaitingMatch := true
        if !SummerWaitForVerification()
            return false
    }

    text := SummerReadUI()

    ; 3. Nếu đang ở sảnh chính (Lobby) và chưa mở bảng Matchmaking -> Dịch chuyển vào sảnh Event
    if (!SummerAwaitingMatch && !RegExMatch(text, "i)join\s+matchmaking")) {
        if (FindText(&ax, &ay, 746, 514, 789, 530, 0, 0, AreaText) || RegExMatch(text, "i)\bareas?\b")) {
            ProcessLog("Summer Event: in lobby, teleporting to the event area...")
            FixClick(85, 296) ; Play / Event teleport button
            Sleep(1500)
            if !SummerApproachQueue() {
                ProcessLog("Summer Event: Join Matchmaking dialog not found after walking")
            }
            text := SummerReadUI()
        }
    }

    ; 4. Nếu thấy bảng Join Matchmaking -> bấm nút Find Match hoặc Play Here
    if RegExMatch(text, "i)join\s+matchmaking") {
        ProcessLog("Summer Event: joining queue (MatchMaking=" . (MatchMaking.Value ? "ON" : "OFF") . ")...")
        FixClick(MatchMaking.Value ? 466 : 336, 324)
        SummerAwaitingMatch := true
        Sleep(500)
        if MatchMaking.Value {
            deadline := A_TickCount + 5000
            loop {
                if SummerVerificationVisible() {
                    if !SummerHandleVerification(targetWin, true) {
                        SummerAwaitingMatch := false
                        return false
                    }
                    break
                }
                if (A_TickCount >= deadline)
                    break
                Sleep(200)
            }
        }
    }

    ; 5. Vào chu trình chờ load trận
    SummerAwaitingMatch := false
    SummerMapName := "Summer Event"
    ProcessLog("Summer Event: waiting for the match to load...")
    return RestartStage("Summer Event")
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
        if ClassifyResultScreen(scene)!="" || RegExMatch(scene,"i)\bdefeat\b|\bvictory\b|xp\s+progress|waiting\s+for\s+players|disconnected|choose\s+a\s+card|return\s+to\s+lobby") {
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

FindSummerMapTemplate() {
    global rblxID, SummerMapPatterns
    patterns := Map("Planet Greenie", Greenie, "Ant Kingdom", Ant, "Magic Town", MagicTown
        , "Magic Hill", MagicHills, "Navy Bay", Navy, "Snowy Town", SnowyTown, "Snowy Kingdom", SnowyKingdom
        , "Dungeon Throne", DungeonThrone, "Rain Village", RainVillage
        , "Fiend City", Fiend, "Spirit World", Spirit, "Haunted Academy", Academy
        , "Space Center", SpaceCenter, "Mountain Temple", Mount, "Cursed Festival", Cursed
        , "Nightmare Train", Nightmare, "Air Craft", AirCraft, "Hellish City", Hellish
        , "Shibuya District", Shibuya)
    WinGetClientPos(&cx, &cy, &cw, &ch, rblxID)
    oldMode := A_CoordModePixel
    CoordMode "Pixel", "Client"
    try {
        for name, pattern in SummerMapPatterns {
            if FindText(&x, &y, cx, cy + 40, cx + cw - 1, cy + 220, 0.10, 0.10, pattern) {
                if (ParseSummerMapName(name) != "")
                    return name
                ; A recognized title does not grant an unmeasured map route.
                ProcessLog("Summer Event: recognized title " name "; no movement route available")
            }
        }
        for name, pattern in patterns {
            path := FileExist(pattern) ? pattern : A_ScriptDir "\" pattern
            if FileExist(path) {
                try {
                    if ImageSearch(&x, &y, 0, 40, cw - 1, Min(ch - 1, 220), "*60 " path)
                        return name
                }
            } else if FindText(&x, &y, cx, cy + 40, cx + cw - 1, cy + 220, 0.15, 0.15, pattern) {
                return name
            }
        }
    } finally {
        CoordMode "Pixel", oldMode
    }
    return ""
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
    SummerResetSpawn()
    PlacementCamera()
    if !MapWalk("a", 1200)
        return false
    Sleep(250)
    ProcessLog("Summer courtyard movement: spawn -> camera -> a 1200ms; beside enemy path")
    return true
}

global MansionMapName := ""

InfinityMansionMode() {
    if !InfinityMansionEnter()
        return false
    return RestartStage()
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
            ProcessLog("Infinity Mansion route: A7000ms")
            if !InfinityMansionWalk("a",7000)
                return false
            Sleep(500)
            ProcessLog("Infinity Mansion route: W600ms")
            if !InfinityMansionWalk("w",600)
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

    global StoryDropdown, StoryActDropdown

    ; Get current map and act

    currentStoryMap := StoryDropdown.Text

    currentStoryAct := StoryActDropdown.Text

    ; Execute the movement pattern

    ProcessLog("Moving to: " currentStoryMap)

    if !StoryMovement()
        return false

    ; Start stage

    movementAttempts := 0

    while !IsModeCancelOpen(&X, &Y) {

        if (movementAttempts >= 10) {

            ProcessLog("Could not reach the map-selection dialog after 10 movement attempts; stopping safely")

            return

        }

        movementAttempts++

        ProcessLog("Retrying map route: " movementAttempts "/10")

        if !StoryMovement()
            return false

    }

    ProcessLog("Starting: " currentStoryMap " - " currentStoryAct)

    if (!StartStory())

        return

    ; Pick the requested act in the map detail panel before confirming it.
    SelectStoryAct(currentStoryAct)

    ; Handle play mode selection

    if (StoryActDropdown.Text != "Infinity") {

        PlayHere()  ; Always PlayHere for normal story acts

    } else {

        if (MatchMaking.Value) {

            if (!FindMatch())

                return

        } else {

            PlayHere()

        }

    }

    RestartStage()

}

PortalMode() {

    global PortalDropdown

    ;get portal type

    currentPortalType := PortalDropdown.Text

    ; Execute the movement pattern

    while !IsModeCancelOpen(&X, &Y) {

        PortalMovement()

    }

    ProcessLog("Going to: - " currentPortalType)

    ; Handle play mode selection

    RestartStage()

}

FarmMode() {

    ProcessLog("Processing for Farm Mode")

    while !IsModeCancelOpen(&X, &Y) {

        FarmMovement()

    }

    ProcessLog("Going to Farm")

    PlayHere()

    RestartStage()

}

InfQuestMode() {

    ProcessLog("Processing for Daily Infinite Quest")

    while !IsModeCancelOpen(&X, &Y) {

        InfQuestMovement()

    }

    if (MatchMaking.Value) { ;find match or play alone

        if (!FindMatch())

            return

    } else {

        PlayHere()

    }

    ProcessLog("Entering Inf quest...")

    RestartStage()

}

LegendMode() {

    global LegendDropdown, LegendActDropdown

    ; Get current map and act

    currentLegendMap := LegendDropdown.Text

    currentLegendAct := LegendActDropdown.Text

    ; Execute the movement pattern

    ProcessLog("Moving to: " currentLegendMap)

    if !StoryMovement()
        return false

    ; Start stage

    while !IsModeCancelOpen(&X, &Y) {

        if !StoryMovement()
            return false

    }

    ProcessLog("Processing: " currentLegendMap " - " currentLegendAct)

    StartLegend(currentLegendMap, currentLegendAct)

    ; Handle play mode selection

    if (MatchMaking.Value) {

        if (!FindMatch())

            return

    } else {

        PlayHere()

    }

    RestartStage()

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

            return

    } else {

        PlayHere()

    }

    RestartStage()

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

            return

    } else {

        PlayHere()

        if (ok := IsModeCancelOpen(&X, &Y)) {

            ClickUntilGone(0, 0, 325, 520, 489, 587, ModeCancel, -10, -120)

        }

    }

    RestartStage()

}

DungeonMode() {

    ProcessLog("Entering Dungeon Mode")

    FixClick(85, 400)  ; Click Dungeon mode button

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

            return

        RestartStage()

    } else {

        ; Select dungeon route and enter

        SelectDungeonRoute()

    }

}

ClickReplay() {

    ClickUntilGone(0, 0, 80, 85, 739, 224, LobbyText, +120, -35, LobbyText2)

}

ClickNextLevel() {

    ClickUntilGone(0, 0, 80, 85, 739, 224, LobbyText, +260, -35, LobbyText2)

}

ClickReturnToLobby() {

    ClickUntilGone(0, 0, 80, 85, 739, 224, LobbyText, 0, -35, LobbyText2)

}

ChooseResultLabels(matchmaking := 0) {
    global mode, NextLevelBox, NextRoomBox, ReplayBox, ReturnLobbyBox
    if matchmaking || ReturnLobbyBox.Value
        return ["Return to lobby"]
    labels := []
    if !matchmaking {
        if mode = "Infinity Mansion" {
            if NextRoomBox.Value
                labels.Push("Next Room")
        } else if NextLevelBox.Value
            labels.Push("Next Level", "Next Room")
        if ReplayBox.Value
            labels.Push("Replay", "Retry")
    }
    labels.Push("Return to lobby")
    return labels
}

ClassifyResultScreen(text) {
    if RegExMatch(text, "i)choose\s+a\s+card|the\s+weather\s+shifts")
        return ""
    if (RegExMatch(text, "i)xp\s+progress") && RegExMatch(text, "i)total\s+time|waves\s+completed")
        && RegExMatch(text, "i)\bnext\b"))
        return "summary"
    if (RegExMatch(text, "i)return\s+to\s+lobby") && RegExMatch(text, "i)\b(replay|retry)\b|next\s+(level|room)|waiting\s+for\s+players"))
        return "choices"
    return ""
}

ReadResultScreen(strictSize := true, readButtons := false, scale := 2) {
    global rblxID
    if !WinActive(rblxID)
        return 0
    try {
        WinGetClientPos(&cx, &cy, &cw, &ch, rblxID)
        if cw<=0 || ch<=0 || (strictSize && (cw!=800 || ch!=599))
            return 0
        result := OCR.FromRect(cx, cy, cw, ch, "en-US", scale)
        result.clientW := cw, result.clientH := ch
        ; Ending paths may lose whole labels against green/yellow buttons.
        ; Keep their neutral-white ink in bounded layers; ordinary battle reads
        ; retain the original capture cost. All layers share the final guard.
        if readButtons && ResultScreenPhase(result)!="summary" {
            result.resultTextLayers := []
            for layerIndex, area in [[190,70,600,160],[120,430,560,140]] {
                ; Choices can show through a reward overlay. Only skip the
                ; lower prompt scan when summary/reward is already confirmed.
                if layerIndex=2 && ResultScreenPhase(result)="summary"
                    break
                left:=Round(area[1]*cw/800),top:=Round(area[2]*ch/599)
                width:=Min(cw-left,Round(area[3]*cw/800)),height:=Min(ch-top,Round(area[4]*ch/599))
                try {
                    layer:=ReadHighContrastResult(cx+left,cy+top,width,height,3,0,false,true)
                    for word in layer.Words {
                        word.x+=left,word.y+=top
                        word.BoundingRect:={x:word.x,y:word.y,w:word.w,h:word.h}
                    }
                    for line in layer.Lines {
                        line.resultLayer:=true
                        if line.HasOwnProp("BoundingRect")
                            line.DeleteProp("BoundingRect")
                    }
                    result.resultTextLayers.Push(layer)
                }
            }
        }
        WinGetClientPos(&nx, &ny, &nw, &nh, rblxID)
        if !WinActive(rblxID) || nx!=cx || ny!=cy || nw!=cw || nh!=ch
            return 0
        return result
    }
    return 0
}

ResultScreenReady() {
    ; Unit actions and the monitor poll this often. Read at native size first.
    result := ReadResultScreen(true, false, 1)
    if ResultScreenPhase(result) != ""
        return true
    if IsObject(result) && RegExMatch(result.Text,"i)\bxp\s*progr|\bvictory\b|\bdefeat\b|click.*continue")
        return ResultScreenPhase(ReadResultScreen(true, true)) != ""
    return false
}

ResultTextLines(result) {
    lines:=[]
    if !IsObject(result)
        return lines
    try {
        for line in result.Lines
            lines.Push(line)
        if result.HasProp("resultTextLayers") {
            for layer in result.resultTextLayers {
                for line in layer.Lines
                    lines.Push(line)
            }
        }
    }
    return lines
}

ResultText(result) {
    if !IsObject(result)
        return ""
    text:=result.Text
    if result.HasProp("resultTextLayers") {
        for layer in result.resultTextLayers
            text.=" " layer.Text
    }
    return text
}

FindResultButton(result, label, phase := "choices") {
    if !IsObject(result)
        return 0
    static patterns := Map("Next Room", "^nex[t7]r[o0][o0](?:m|rn)$",
        "Next Level", "^nex[t7]leve[l1i]$", "Replay", "^rep[l1i]ay$",
        "Retry", "^retry$", "Return to lobby", "^ret(?:urn|um)(?:to|w)?l[o0]bby$",
        "Next", "^nex[t7]$")
    if !patterns.Has(label)
        return 0
    sx := result.HasProp("clientW") ? result.clientW/800 : 1
    sy := result.HasProp("clientH") ? result.clientH/599 : 1
    band := phase="summary" ? [240*sx,350*sy,420*sx,450*sy] : [190*sx,70*sy,680*sx,180*sy]
    inBand := (r) => r.x+r.w/2>=band[1] && r.x+r.w/2<=band[3]
        && r.y+r.h/2>=band[2] && r.y+r.h/2<=band[4]
    try {
        rect := result.FindString(label)
        if IsObject(rect) && inBand(rect) {
            rect.source:="ocr"
            return rect
        }
    }
    ; Match bounded word groups, allowing spacing/punctuation and a few measured
    ; OCR confusions. Never guess a button from its color or a fixed click point.
    try {
        for line in ResultTextLines(result) {
            for first, word in line.Words {
                compact := "", left := word.x, top := word.y, right := word.x, bottom := word.y
                loop Min(4,line.Words.Length-first+1) {
                    part := line.Words[first+A_Index-1]
                    if part.x<band[1] || part.y<band[2] || part.x+part.w>band[3] || part.y+part.h>band[4]
                        break
                    compact .= RegExReplace(StrLower(part.Text),"[^a-z0-9]")
                    left:=Min(left,part.x),top:=Min(top,part.y)
                    right:=Max(right,part.x+part.w),bottom:=Max(bottom,part.y+part.h)
                    if RegExMatch(compact,patterns[label])
                        return {x:left,y:top,w:right-left,h:bottom-top,source:line.HasProp("resultLayer") ? "masked-ocr" : "ocr"}
                }
            }
        }
    }
    return 0
}

ResultScreenPhase(result) {
    if !IsObject(result)
        return ""
    text:=ResultText(result)
    ; A visible result button is sufficient even if OCR mangles its neighbour
    ; (observed: "Return Wlobby" beside a correctly read "Next Room").
    if RegExMatch(text, "i)choose\s+a\s+card|vote\s+start|the\s+weather\s+shifts")
        return ""
    ; A reward overlay can sit above already-visible end-of-match buttons.
    phase := ClassifyResultScreen(text)
    if ResultRewardPageVisible(result) || (phase="summary"
        && IsObject(FindResultButton(result,"Next","summary")))
        || ResultSummaryVisible(result)
        return "summary"
    for label in ["Return to lobby","Next Room","Next Level","Replay","Retry"] {
        if IsObject(FindResultButton(result,label))
            return "choices"
    }
    if phase!=""
        return phase
    return ""
}

ResultSummaryVisible(result) {
    if !IsObject(result) || !IsObject(FindResultButton(result,"Next","summary"))
        return false
    sx:=result.HasProp("clientW") ? result.clientW/800 : 1
    sy:=result.HasProp("clientH") ? result.clientH/599 : 1
    ; The unit panel can cover Victory/Total Time/Waves. The right XP title
    ; and the lower Next button remain visible in the observed stuck scene.
    try {
        for line in ResultTextLines(result) {
            if line.x<500*sx || line.x>790*sx || line.y<100*sy || line.y>230*sy
                continue
            if RegExMatch(RegExReplace(StrLower(line.Text),"[^a-z0-9]"),"^xppr[o0]gre[s5]{1,2}$")
                return true
        }
    }
    return false
}

ResultRewardPageVisible(result) {
    if !IsObject(result)
        return false
    if IsObject(FindResultRewardPrompt(result))
        return true
    sx:=result.HasProp("clientW") ? result.clientW/800 : 1
    sy:=result.HasProp("clientH") ? result.clientH/599 : 1
    try {
        for line in ResultTextLines(result) {
            if line.x<120*sx || line.x>680*sx || line.y<150*sy || line.y>450*sy
                continue
            if RegExMatch(line.Text,"i)^\s*(?:rewards?|loot|(?:items?\s+|you\s+)?received)\b")
                && !RegExMatch(line.Text,"i)boost|bonus|party|modif")
                return true
        }
    }
    return false
}

FindResultRewardPrompt(result) {
    if !IsObject(result)
        return 0
    sx:=result.HasProp("clientW") ? result.clientW/800 : 1
    sy:=result.HasProp("clientH") ? result.clientH/599 : 1
    try {
        for line in ResultTextLines(result) {
            if line.x<120*sx || line.x>680*sx || line.y<430*sy || line.y>570*sy
                continue
            text:=RegExReplace(StrLower(line.Text),"[^a-z0-9]")
            if RegExMatch(text,"^(?:cl[i1l]ck|tap)an[yv]w[h]?eretocontinue$")
                return {x:line.x,y:line.y,w:line.w,h:line.h}
        }
    }
    return 0
}

ClickResultButton(x,y) {
    global rblxID
    if !WinActive(rblxID)
        return false
    oldMouseMode:=A_CoordModeMouse
    CoordMode "Mouse","Client"
    try FixClick(x,y)
    finally CoordMode "Mouse",oldMouseMode
    return true
}

TryResultAction(&action := "") {
    global MatchMaking
    action := ""
    result := ReadResultScreen(true,true)
    if !IsObject(result)
        return false
    phase := ResultScreenPhase(result)
    if (phase = "")
        return false
    if (phase = "summary") {
        ; Victory/defeat: keep clicking one point every 0.7s until the
        ; Return to lobby / Replay choices replace the summary or reward page.
        sx := result.HasProp("clientW") ? result.clientW/800 : 1
        sy := result.HasProp("clientH") ? result.clientH/599 : 1
        anchor := FindResultRewardPrompt(result)
        x := IsObject(anchor) ? Round(anchor.x+anchor.w/2) : Round(330*sx)
        y := IsObject(anchor) ? Round(anchor.y+anchor.h/2) : Round(400*sy)
        if !ClickResultButton(x, y)
            return false
        ProcessLog("Result UI: summary/reward beat at " x "," y)
        action := "next"
        Sleep(700)
        return true
    }
    labels := ChooseResultLabels(MatchMaking.Value)
    chosenLabel := ""
    for label in labels {
        rect := FindResultButton(result,label,phase)
        if !IsObject(rect)
            continue
        chosenLabel := label
        break
    }
    if (chosenLabel = "")
        return false
    fresh := ReadResultScreen(true,true)
    if !IsObject(fresh) || ResultScreenPhase(fresh) != phase
        return false
    allowed:=false
    for label in ChooseResultLabels(MatchMaking.Value) {
        if label=chosenLabel
            allowed:=true
    }
    if !allowed
        return false
    rect := FindResultButton(fresh,chosenLabel,phase)
    if !IsObject(rect)
        return false
    x:=Round(rect.x+rect.w/2),y:=Round(rect.y+rect.h/2)
    if !ClickResultButton(x, y)
        return false
    action := chosenLabel = "Next Room" ? "next_room" : (chosenLabel = "Next Level" ? "next_level" : (chosenLabel = "Return to lobby" ? "lobby" : (chosenLabel = "Next" ? "next" : "replay")))
    ProcessLog("Result UI: " chosenLabel " at " x "," y " -> action=" action " (" (rect.HasProp("source") ? rect.source : "reward prompt") ", matchmaking=" MatchMaking.Value ")")
    Sleep(500)
    return true
}

ContinueAfterResult(action) {
    global mode, SummerAwaitingMatch, SummerMapName
    deadline := A_TickCount + 45000
    retries:=0,stableMenu:=0,nextRetry:=A_TickCount+3000
    while (A_TickCount < deadline) {
        result := ReadResultScreen(true,true)
        if IsObject(result) && Trim(ResultText(result))!="" {
            phase:=ResultScreenPhase(result)
            moving:=RegExMatch(ResultText(result),"i)te[li1]ep[o0]rting|connecting")
            if phase="" && !moving {
                if (action != "lobby" || RegExMatch(result.Text, "i)\bareas\b"))
                    break
            }
            if phase="choices" && !moving {
                stableMenu++
                if stableMenu>=3 && retries<2 && A_TickCount>=nextRetry {
                    ; A click can be ignored while reward UI is settling. Retry
                    ; only a freshly re-read choice, never during teleporting.
                    if TryResultAction(&retryAction) {
                        if retryAction!="next"
                            action:=retryAction
                        retries++
                        ProcessLog("Result UI: unchanged menu; verified retry " retries "/2")
                    }
                    stableMenu:=0,nextRetry:=A_TickCount+3000
                }
            } else {
                stableMenu:=0
            }
        } else {
            stableMenu:=0
        }
        Sleep(500)
    }
    if (A_TickCount >= deadline) {
        ProcessLog("Result UI: scene transition not confirmed; stopping without repeated clicks")
        return false
    }
    if (action = "lobby") {
        SummerAwaitingMatch := false
        SummerMapName := ""
        return StartSelectedMode()
    }
    if (mode = "Summer Event") {
        SummerMapName := "Summer Event"
        ProcessLog("Summer Event: continuing after " ((action="next_level" || action="next_room") ? "Next Level / Room" : "Replay") "; reading the new map")
        return RestartStage("Summer Event")
    }
    if mode = "Infinity Mansion" && action = "next_room"
        ProcessLog("Infinity Mansion: Next Room selected; detecting the new room's loading cover")
    return RestartStage()
}

MonitorEndScreen() {
    EndCardMatch("result-screen")
    deadline := A_TickCount + 45000
    while (A_TickCount < deadline) {
        if TryResultAction(&action) {
            if (action = "next")
                continue
            return ContinueAfterResult(action)
        }
        Sleep(500)
    }
    ProcessLog("Result UI: could not verify a safe button; inspect the UI")
    return false
}

MonitorStage() {


    global Wins, loss, mode, StoryActDropdown, CARD_ENABLED, lastResult

    lastClickTime := A_TickCount

    loop {

        Sleep(1000)

        ; Card picker (GAME layer) - chi chay khi da do toa do 3 the
        if CARD_ENABLED {
            WaitForCardChoice(mode)
        }

        if ((mode = "Story" && StoryActDropdown.Text = "Infinity") || (mode = "Farm") || (mode = "Daily Infinite Quest"

        )) {

            timeElapsed := A_TickCount - lastClickTime

            if (timeElapsed >= 300000) {  ; 5 minutes

                ProcessLog("Processing for Anti-AFK...")

                FixClick(560, 560) ; Move click

                ;mahogora ability checker

                FixClick(239, 400)

                FixClick(298, 400)

                FixClick(358, 400)

                if (FindText(&x, &y, 0, 0, A_ScreenWidth, A_ScreenHeight, 0, 0, Wave40Inf)) {

                    Wave40Reached()

                }

                lastClickTime := A_TickCount

            }

        }

        ; Check for XP screen

        if CheckForXp() {

            ProcessLog("Checking win/loss status...")
            ; A selected unit can cover the result title and totals. Close only
            ; its confirmed panel before reading the outcome / reward pages.
            if FindUnitPanel(&panelX,&panelY)
                CloseUnitPanel()

            ; Calculate stage end time here, before checking win/loss

            stageEndTime := A_TickCount

            stageLength := FormatStageTime(stageEndTime - stageStartTime)

            if (ok := FindText(&X, &Y, 300, 190, 360, 250, 0.20, 0.20, UnitExit)) {

                ClickUntilGone(0, 0, 300, 190, 360, 250, UnitExit, -4, -35)

            }

            ; Check for Victory or Defeat

            if (ok := FindText(&X, &Y, 150, 180, 350, 260, 0, 0, VictoryText) or (ok := FindText(&X, &Y, 150, 180, 350,

                260, 0, 0, VictoryText2))) { ;if win

                ProcessLog("Victory detected - Stage Length: " stageLength)

                Wins += 1

                SendWebhookWithTime(true, stageLength)

                if (mode = "Dungeon" && !MatchMaking.Value) {

                    return MonitorDungeonEnd()  ; New function for Dungeon endings

                } else {

                    return MonitorEndScreen()  ; Original behavior for other modes

                }

            } else if (ok := FindText(&X, &Y, 150, 180, 350, 260, 0, 0, DefeatText) or (ok := FindText(&X, &Y, 150, 180,

                350, 260, 0, 0, DefeatText2))) { ;if loss

                ProcessLog("Defeat detected - Stage Length: " stageLength)

                loss += 1

                SendWebhookWithTime(false, stageLength)

                if (mode = "Dungeon" && !MatchMaking.Value) {

                    return MonitorDungeonEnd()  ; New function for Dungeon endings

                } else {

                    return MonitorEndScreen()  ; Original behavior for other modes

                }

            }

            ; Recheck only after the first result/XP signal, since the panel
            ; cleanup above may have exposed a title or advanced the screen.
            if ResultScreenReady() {
                lastResult := "unknown"
                ProcessLog("Result title unreadable: verified result UI; outcome unknown")
                return MonitorEndScreen()
            }
        }

        Reconnect()

    }

}

StoryMovement() {
    global rblxID, aaMainUIHwnd
    WinSetAlwaysOnTop(false, "ahk_id " aaMainUIHwnd)
    if !WinExist(rblxID)
        return false
    WinActivate(rblxID)
    Sleep(150)
    if !WinActive(rblxID)
        return false
    if RegExMatch(SummerReadUI(), "i)select\s+world")
        return true
    if !OpenRegularPlayArea()
        return false
    if RegExMatch(SummerReadUI(), "i)select\s+world")
        return true
    ProcessLog("Regular modes: holding W + D until Select World appears")
    release := (*) => SendEvent("{w up}{d up}")
    deadline := A_TickCount + 15000
    SetTimer(release, -15000)
    try {
        if !WinActive(rblxID)
            return false
        SendEvent("{w down}{d down}")
        while (A_TickCount < deadline && WinActive(rblxID)) {
            if RegExMatch(SummerReadUI(), "i)select\s+world") {
                if !WinActive(rblxID) || A_TickCount >= deadline
                    break
                ProcessLog("Regular modes: Select World confirmed; releasing W + D")
                return true
            }
            Sleep(150)
        }
        ProcessLog("Regular modes: navigation stopped without Select World (timeout or focus lost)")
        return false
    } catch as err {
        ProcessLog("Regular modes: navigation failed; " err.Message)
        return false
    } finally {
        SetTimer(release, 0)
        release()
    }
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

Wave40Reached() {

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

    PortalSearch()

    if (ok := FindText(&x2, &y2, 181, 362, 634, 475, 0, 0, Use_Portal)) {

        FixClick(x2, y2 - 40)

        Sleep(1000)

        FixClick(312, 350)

        Sleep(1000)

        FixClick(404, 482)

        Sleep(1000)

        ProcessLog("Opened a Portal, joining in...")

    }

    Sleep(1000)

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

        ProcessLog("Found map, attempt to quest")

        if !StoryMovement()
            return false

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

    SendInput ("{a down}")

    Sleep(400)

    SendInput ("{a up}")

    Sleep(500)

    SendInput ("{w down}")

    Sleep(5000)

    SendInput ("{w up}")

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

    ClosePlayerLeaderBoard()

    ; The Select World list always opens scrolled to the top, so Planet
    ; Greenie is the first card. The "Don't Miss Out!" promo toasts overlap
    ; that card, which is why the old ImageSearch never matched and the
    ; fallback click at (635, 220) landed on a toast instead of the list.
    DismissPromoPopups()

    CoordMode "Pixel", "Client"

    ProcessLog("Selecting Planet Greenie (first card in Select World)")

    oldMouseMode := A_CoordModeMouse

    CoordMode "Mouse", "Client"

    try {

        FixClick(690, 248)

    } finally {

        CoordMode "Mouse", oldMouseMode

    }

    Sleep(800)

    return true

}

StartLegend(map, LegendActDropdown) {

    ClosePlayerLeaderBoard()

    navKeys := GetNavKeys()

    for key in navKeys {

        SendInput("{" key "}")

    }

    Sleep(500)

    SendInput("{Down}")

    Sleep(500)

    SendInput("{Enter}") ; Opens Legend Stage

    downArrows := GetLegendDownArrows(map) ; Map selection down arrows

    loop downArrows {

        SendInput("{Down}")

        Sleep(200)

    }

    SendInput("{Enter}") ; Select LegendStage

    Sleep(500)

    loop 4 {

        SendInput("{Up}") ; Makes sure it selects act

        Sleep(200)

    }

    SendInput("{Left}") ; Go to act selection

    Sleep(1000)

    actArrows := GetLegendActDownArrows(LegendActDropdown) ; Act selection down arrows

    loop actArrows {

        SendInput("{Down}")

        Sleep(200)

    }

    SendInput("{Enter}") ; Select Act

    Sleep(500)

    for key in navKeys {

        SendInput("{" key "}")

    }

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

    static actY := Map(
        "Infinite", 239,
        "Act 1", 273,
        "Act 2", 307,
        "Act 3", 343,
        "Act 4", 377
    )

    if (actName = "Infinity")
        actName := "Infinite"

    if !actY.Has(actName)
        return false

    oldMouseMode := A_CoordModeMouse
    CoordMode "Mouse", "Client"
    try {
        FixClick(280, actY[actName])
    } finally {
        CoordMode "Mouse", oldMouseMode
    }
    Sleep(500)
    return true

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
            ProcessLog("Matchmaking timeout, restarting mode")
            FixClick(400, 520)
            return StartSelectedMode()
        }

        FixClick(400, 435)  ; Play Here or Find Match
        Sleep(300)
        FixClick(460, 330)  ; Click Find Match
        Sleep(300)

        ; Try captcha
        if (!CaptchaDetect(252, 292, 300, 50, 400, 335)) {
            ProcessLog("Could not find captcha, retrying...")
            FixClick(585, 190)  ; Click close
            Sleep(1000)
            continue
        }
        FixClick(300, 385)  ; Enter captcha
        return true
    }
}

GetStoryDownArrows(map) {

    switch map {

        case "Planet Greenie": return 2

        case "Walled City": return 3

        case "Snowy Town": return 4

        case "Sand Village": return 5

        case "Navy Bay": return 6

        case "Fiend City": return 7

        case "Spirit World": return 8

        case "Ant Kingdom": return 9

        case "Magic Town": return 10

        case "Haunted Academy": return 11

        case "Magic Hills": return 12

        case "Space Center": return 13

        case "Alien Spaceship": return 14

        case "Fabled Kingdom": return 15

        case "Ruined City": return 16

        case "Puppet Island": return 17

        case "Virtual Dungeon": return 18

        case "Snowy Kingdom": return 19

        case "Dungeon Throne": return 20

        case "Mountain Temple": return 21

        case "Rain Village": return 22

        case "Shibuya District": return 23

    }

}

GetStoryActDownArrows(StoryActDropdown) {

    switch StoryActDropdown {

        case "Infinity": return 1

        case "Act 1": return 2

        case "Act 2": return 3

        case "Act 3": return 4

        case "Act 4": return 5

        case "Act 5": return 6

        case "Act 6": return 7

    }

}

GetPortalDownType(PortalDropdown) {

    switch PortalDropdown {

        case "Shibuya": return 23

        case "Pupet": return 17

        case "Demons Place": return 15

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

FindUpgradeToggleRow() {

    ; "Show Upgrade UI on left" is the only row whose toggle is followed by two

    ; grey arrow buttons. Find the toggle with a single PixelSearch per pass

    ; instead of a GetPixel sweep (each read costs ~9ms), then confirm the two

    ; arrow buttons below it. Search downward first, then back upward, because

    ; the panel reopens at whatever scroll position it was left at.

    down := 0

    up := 0

    loop 22 {

        y := 150

        while (y <= 438) {

            hit := 0

            if PixelSearch(&tx, &ty, 512, y, 542, 438, 0x00F058, 14)

                hit := ty

            else if PixelSearch(&tx, &ty, 512, y, 542, 438, 0x640000, 20)

                hit := ty

            if (!hit)

                break

            if (ArrowNear(524, hit + 53) && ArrowNear(524, hit + 106))

                return hit

            y := hit + 6

        }

        if (down < 12) {

            down += 1

            FixMove(400, 300)

            SendInput("{WheelDown}")

            Sleep(60)

        } else if (up < 22) {

            up += 1

            FixMove(400, 300)

            SendInput("{WheelUp}")

            Sleep(60)

        } else

            break

    }

    return 0

}

ToggleIsOn(x, y) {

    c := PixelGetColor(x, y, "RGB")

    r := (c >> 16) & 0xFF

    g := (c >> 8) & 0xFF

    b := c & 0xFF

    ; Green when on, red when off. Neutral greys are other rows' controls.

    return ((g > 140 && r < 150 && b < 150) || (r > 150 && g < 130 && b < 130))

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

BasicSetup() {

    FixClick(565, 73) ; Close the in-match leaderboard

    Sleep 300

    CloseChat()

    Sleep 300

    Zoom()

    Sleep 300

    TpSpawn()

}

DetectMap(timeoutMs := 300000) {
    global mode, rblxID, SummerMapInterrupted
    isSummer := mode="Summer Event"
    if isSummer
        SummerMapInterrupted:=false

    ProcessLog("Moving into the map...")

    startTime := A_TickCount

    loop {
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
            if ClassifyResultScreen(scene)!="" || RegExMatch(scene,"i)\bdefeat\b|\bvictory\b|disconnected|choose\s+a\s+card|return\s+to\s+lobby") {
                SummerMapInterrupted:=true
                ProcessLog("Summer loading cover interrupted: result/card/disconnect")
                return "no map found"
            }
        }

        ; Check if we waited more than 5 minute for votestart

        if (A_TickCount - startTime > timeoutMs) {

            if (ok := FindText(&X, &Y, 746, 514, 789, 530, 0, 0, AreaText)) {

                ProcessLog("In lobby - restarting the selected mode")

                return isSummer ? "no map found" : StartSelectedMode()

            }

            ProcessLog("Map cover recognition timed out - continuing without cover movement")

            return "no map found"

        }

        ; Check for vote screen

        if !isSummer && (FindVoteStart(&X,&Y) || RegularMatchHudVisible()) {

            ProcessLog("Loading cover unknown; match HUD/Vote Start confirmed, continuing without map movement")

            return "no map found"

        }
        if !isSummer && ResultScreenReady() {
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

            "Shibuya District", Shibuya

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

        Reconnect()

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

        case "Magic Hill":

            return MoveForMagicHill()

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

        default:
            ProcessLog("No movement route for " MapName "; continuing normal placement at current position")

    }

    return true

}

MoveForSacredPlanet() {
    SummerResetSpawn()
    if !MapWalk("w",4000)
        return false
    if !MapWalk("a",2000)
        return false
    ProcessLog("Sacred Planet movement complete: teleport spawn -> W4000ms -> A2000ms; keys released")
    return true
}

MoveForGreenie() {
    if !MapWalk("aw",2200)
        return false
    return true
}

MoveForSnowyTown() {
    if !MapWalk("d",2000)
        return false
    Sleep(500)
    return true
}

MoveForRainVillage() {
    ProcessLog("Rain Village movement: A+S500ms")
    if !MapWalk("as",500)
        return false
    ProcessLog("Rain Village movement complete; all movement keys released")
    return true
}

MoveForDungeonThrone() {
    ProcessLog("Dungeon Throne movement: D6000ms")
    if !MapWalk("d",6000)
        return false
    ProcessLog("Dungeon Throne movement complete; all movement keys released")
    return true
}

MoveForSnowyKingdom() {
    ProcessLog("Snowy Kingdom movement: W+D6000ms")
    if !MapWalk("wd",6000)
        return false
    ProcessLog("Snowy Kingdom movement: W+D released; wait500ms")
    Sleep(500)
    ProcessLog("Snowy Kingdom movement: W+A1000ms")
    if !MapWalk("wa",1000)
        return false
    ProcessLog("Snowy Kingdom movement complete; all movement keys released")
    return true
}

MoveForNavyBay() {
    if !MapWalk("aw",1700)
        return false
    return true
}

MoveForFiendCity() {
    if !MapWalk("a",1700)
        return false
    Sleep(500)
    if !MapWalk("s",3100)
        return false
    Sleep(500)
    if !MapWalk("a",900)
        return false
    return true
}

MoveForSpiritWorld() {
    if !MapWalk("dw",7000)
        return false
    Sleep(500)
    if !MapMovementReady()
        return false
    FixClick(400,15,"Right")
    Sleep(4000)
    return true
}

MoveForAntKingdom() {
    ProcessLog("Ant Kingdom movement: A+S5000ms")
    if !MapWalk("as",5000)
        return false
    ProcessLog("Ant Kingdom movement: A+S released; wait500ms")
    Sleep(500)
    ProcessLog("Ant Kingdom movement: A+W6000ms")
    if !MapWalk("aw",6000)
        return false
    ProcessLog("Ant Kingdom movement: A+W released; wait500ms")
    Sleep(500)
    ProcessLog("Ant Kingdom movement complete; all movement keys released")
    return true
}

MoveForMagicTown() {
    if !MapWalk("d",2500)
        return false
    if !MapWalk("s",3000)
        return false
    if !MapWalk("sd",3000)
        return false
    return true
}

MoveForMagicHill() {
    if !MapWalk("w",200)
        return false
    Sleep(500)
    if !MapWalk("wd",2000)
        return false
    Sleep(500)
    if !MapWalk("w",9500)
        return false
    Sleep(600)
    return true
}

MoveForHauntedAcademy() {
    color := PixelGetColor(647,187)
    if FindText(&x,&y,620,200,750,375,0.15,0.15,AcademyAngle2) || IsColorInRange(color,0xFDF0B3)
        return MapWalk("s",3000)
    return MapWalk("d",3000)
}

MoveForSpaceCenter() {
    if !MapWalk("d",4000)
        return false
    Sleep(500)
    if !MapWalk("w",3000)
        return false
    Sleep(500)
    return true
}

MoveForMountainTemple() {
    ProcessLog("Mountain Temple movement: A+S1200ms")
    if !MapWalk("as",1200)
        return false
    ProcessLog("Mountain Temple movement: A+S released; wait500ms")
    Sleep(500)
    ProcessLog("Mountain Temple movement: A1200ms")
    if !MapWalk("a",1200)
        return false
    ProcessLog("Mountain Temple movement complete; all movement keys released")
    return true
}

MoveForCursedFestival() {
    if !MapWalk("a",1800)
        return false
    return true
}

MoveForNightmareTrain() {
    if !MapWalk("a",1800)
        return false
    return true
}

MoveForAirCraft() {
    if !MapWalk("w",800)
        return false
    return true
}

MoveForHellish() {
    if !MapMovementReady()
        return false
    FixClick(600,300,"Right")
    Sleep(7000)
    return true
}

MoveForShibuya() {
    if FindText(&x,&y,220,190,320,250,0.15,0.15,ShibuyaAngle) {
        if !MapWalk("a",600)
            return false
        Sleep(500)
        return MapWalk("aw",1500)
    }
    return MapWalk("d",2000)
}

RestartStage(knownMap := "") {
    global mode, PlacementPatternDropdown, SummerMapName, SummerMapInterrupted
    global MansionMapName
    currentMap := mode="Summer Event" ? DetectMap(65000) : (knownMap != "" ? knownMap : DetectMap())
    if mode = "Infinity Mansion"
        MansionMapName := currentMap="no map found" || currentMap="không tìm thấy map" ? "" : currentMap
    if mode="Summer Event" && SummerMapInterrupted
        return false
    status := CheckLoaded()
    if (status = "lobby")
        return StartSelectedMode()
    if status = "result"
        return MonitorEndScreen()
    if currentMap="no map found" || currentMap="không tìm thấy map"
        ProcessLog("Map data unavailable: running setup and normal placement at spawn")
    if mode="Summer Event" {
        coverMap:=ParseSummerMapName(currentMap)
        BasicSetup()
        if !StartedGame()
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
        if mode!="Summer Event" {
            BasicSetup()
            PlacementCamera()
        }
        if (mode = "Summer Event") {
            ; Disabled2026-11-08 by user: dynamic path finding retained for reference.
            ; positioned := PathNavigationPosition(currentMap)
            ; if positioned!="positioned"
            ;     return false
            if !HandleMapMovement(currentMap) || !MapMovementReady()
                return false
        } else if (currentMap != "không tìm thấy map" && currentMap != "no map found") {
            if !HandleMapMovement(currentMap)
                return false
        }
        if mode!="Summer Event" && !StartedGame()
            return false
        if !PlacingUnits() && mode = "Summer Event"
            ProcessLog("Summer Event: placement stopped; continuing to monitor cards and match results")
        MonitorStage()
    } finally {
        EndCardMatch("stage-exit", matchId)
    }
}

Reconnect() {

    ; Check for Disconnected Screen using FindText

    if (ok := FindText(&X, &Y, 330, 218, 474, 247, 0, 0, Disconnect)) {
        EndCardMatch("disconnected")

        ProcessLog("Disconnected - reconnecting to the private server...")

        psLink := FileExist("Settings\PrivateServer.txt") ? FileRead("Settings\PrivateServer.txt", "UTF-8") : ""

        ; Reconnect to Ps

        if FileExist("Settings\PrivateServer.txt") && (psLink := FileRead("Settings\PrivateServer.txt", "UTF-8")) {

            ProcessLog("Connecting to private server...")

            Run(psLink)

        } else {

            Run("roblox://placeID=8304191830")

        }

        Sleep(5000)

        loop {

            ProcessLog("Reconnecting to Roblox...")

            Sleep(15000)

            if WinExist(rblxID) {

                forceRobloxSize()

                moveRobloxWindow()

                Sleep(1000)

            }

            if (ok := FindText(&X, &Y, 746, 514, 789, 530, 0, 0, AreaText)) {

                ProcessLog("Reconnect success")

                return StartSelectedMode()

            } else {

                Reconnect()

            }

        }

    }

}

PlaceUnit(x, y, slot := 1, physicalKey := false) {
    global rblxID, mode, PlacementPatternDropdown, SmartPreviewReference
    smart := PlacementPatternDropdown.Text = "Smart"
    ServiceSummerCards(true)
    if !UnitActionAllowed()
        return "interrupted"
    oldMouseMode := A_CoordModeMouse
    CoordMode "Mouse", "Client"
    try {
        if smart
            SendEvent("q") ; Never toggle a stale ghost into a different slot.
        panelClosed := CloseUnitPanel()
        if smart && !panelClosed {
            ProcessLog("Smart: unit panel did not close; slot selection deferred")
            return "unreadable"
        }
        if smart && SmartPreviewInterrupted(true)
            return "interrupted"
        if smart {
            ; Move into the arena and let the previous cancel settle BEFORE selecting.
            FixMove(x, y)
            if !SmartCapturePreviewReference(x,y,slot) {
                ProcessLog("Smart: preview reference capture failed; selection deferred")
                return "unreadable"
            }
            if !SmartPressSlotKey(slot, physicalKey)
                return SmartPreviewInterrupted(true) || !UnitActionAllowed() ? "interrupted" : "unreadable"
            if GetUnitPlacementType(slot) = "Hill"
                SmartCollectHillRegions()
        } else {
            SendEvent("{" slot "}")
            Sleep(120)
        }
        if ServiceSummerCards(true)
            return "interrupted"
        if smart {
            if SmartPreviewInterrupted(true)
                return "interrupted"
            previewDetails := {reason: "unknown", green: 0, red: 0, colors: []}
            preview := SmartWaitPreviewReady(x, y, 1000, &previewDetails)
            if preview != "ready" {
                if preview = "blocked" || preview = "unreadable" {
                    if SmartPreviewInterrupted(true)
                        return "interrupted"
                    pointUnreadable:=preview="unreadable" && SmartPreviewPromptVisible(x,y)
                    if SmartPreviewInterrupted(true) || !UnitActionAllowed()
                        return "interrupted"
                    SendEvent("q")
                    center := previewDetails.colors.Length >= 3 ? previewDetails.colors[3] : "n/a"
                    ProcessLog("Smart: slot " slot " " (preview = "blocked" ? "red preview rejected" : "preview not verified")
                        " at " x "," y "; reason=" previewDetails.reason ", green=" previewDetails.green "/5, red=" previewDetails.red "/5, center=" center)
                    if pointUnreadable
                        return "unreadable-point"
                }
                return preview
            }
        }
        if !UnitActionAllowed()
            return "interrupted"
        if smart {
            if SmartPreviewInterrupted(true)
                return "interrupted"
            if previewDetails.reason!="blue-border" {
            sample := SmartReadPreviewSample(x, y)
            if sample = "interrupted" || SmartPreviewInterrupted(true)
                return "interrupted"
            if sample != "green" && sample != "blue" {
                pointUnreadable:=sample!="red" && SmartPreviewPromptVisible(x,y)
                if SmartPreviewInterrupted(true) || !UnitActionAllowed()
                    return "interrupted"
                SendEvent("q")
                ProcessLog("Smart: slot " slot " preview changed before click; skipping this point")
                return sample = "red" ? "blocked" : pointUnreadable ? "unreadable-point" : "unreadable"
            }
            }
        }
        recoveryWindow := 0
        if smart && mode = "Summer Event" {
            try WinGetClientPos(&cx, &cy, &cw, &ch, rblxID)
            catch
                return "interrupted"
            recoveryWindow := {x:cx, y:cy, w:cw, h:ch}
        }
        FixClick(x, y)
        if smart {
            ; 1.5 s per attempt: keep the 1 s settling delay the user asked for,
            ; then spend the remaining 0.5 s confirming the unit panel.
            ; Card/focus interruptions are checked throughout.
            settleUntil := A_TickCount + 1000
            confirmed := WaitForSmartPlacement(settleUntil + 500, settleUntil)
            if confirmed = "card-interrupted" {
                ServiceSummerCards(true)
                confirmed := RecheckSummerPlacement(x, y, recoveryWindow)
            }
            if confirmed = true {
                ProcessLog("Unit placement confirmed (UPG or close button visible)")
                if !ServiceSummerCards() && UnitActionAllowed() {
                    CheckAbility()
                    CloseUnitPanel()
                }
            } else if confirmed = false && !SmartPreviewInterrupted(true) {
                SendEvent("q")
            }
        } else {
            Sleep(350)
            confirmed := UnitPlaced()
            if confirmed = false
                SendEvent("q")
        }
        return confirmed
    } finally {
        if smart
            SmartPreviewReference:=0
        CoordMode "Mouse", oldMouseMode
    }
}

MaxUpgrade() {
    Sleep 300
    if (ReadUnitUpgradeLevel() = 21)
        return true
    ; Nhan dien chu (MAX) tren header hoac nut Max xanh ben trai
    static unavailable:=Map()
    for image in ["Images\MaxTag.png","Images\MaxButton.png"] {
        try {
            if FileExist(image) && ImageSearch(&mX,&mY,110, 249, 309, 442,"*50 " image)
                return true
        } catch {
            if !unavailable.Has(image) {
                ProcessLog("Max marker unavailable: " image "; continuing with text checks")
                unavailable[image]:=true
            }
        }
    }
    try return !!(FindText(&X,&Y,0,150,600,500,0.15,0.15,MaxText)
        || FindText(&X,&Y,0,150,600,500,0.15,0.15,MaxText2))
    return false
}

UnitPlaced() {
    global rblxID
    interrupted := false
    Sleep(350)
    loop 6 {
        if ServiceSummerCards() {
            interrupted := true
        }
        if !WinActive(rblxID)
            return "uncertain"
        if !UnitActionAllowed() {
            Sleep(150)
            continue
        }
        if FindUnitPanel(&panelX, &panelY) {
            ProcessLog("Unit placement confirmed (panel at " panelX "," panelY ")")
            if !ServiceSummerCards() {
                CheckAbility()
            }
            CloseUnitPanel()
            return true
        }
        Sleep(250)
    }
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

; The upgrade panel's "Upgrade" button is a solid green block, but the old
; FindText patterns were captured from an older UI and no longer match anything.
; Build a tiny solid-green BMP once and let ImageSearch find that block: a
; filled 20x12 area cannot be confused with the thin green range rings or the
; 8px wave bar.
EnsureSolidTemplate(name, rgb, w, h) {

    path := A_Temp "\" name

    if FileExist(path)

        return path

    r := (rgb >> 16) & 0xFF

    g := (rgb >> 8) & 0xFF

    b := rgb & 0xFF

    ; BMP rows are padded to a 4-byte boundary. Without this an 18px wide image
    ; (54 bytes per row) produces a file ImageSearch refuses to load.

    padBytes := Mod(4 - Mod(w * 3, 4), 4)

    stride := w * 3 + padBytes

    pixelBytes := stride * h

    buf := Buffer(54 + pixelBytes, 0)

    NumPut("UChar", 0x42, buf, 0)          ; "BM"

    NumPut("UChar", 0x4D, buf, 1)

    NumPut("UInt", 54 + pixelBytes, buf, 2)

    NumPut("UInt", 54, buf, 10)

    NumPut("UInt", 40, buf, 14)

    NumPut("Int", w, buf, 18)

    NumPut("Int", h, buf, 22)

    NumPut("UShort", 1, buf, 26)

    NumPut("UShort", 24, buf, 28)

    NumPut("UInt", pixelBytes, buf, 34)

    p := 54

    loop h {

        loop w {

            NumPut("UChar", b, buf, p)

            NumPut("UChar", g, buf, p + 1)

            NumPut("UChar", r, buf, p + 2)

            p += 3

        }

        p += padBytes

    }

    try {

        f := FileOpen(path, "w")

        f.RawWrite(buf, 54 + pixelBytes)

        f.Close()

    } catch {

        return ""

    }

    return path

}

; The upgrade panel has two always-coloured controls: the green "Upgrade" button,
; which greys out when you cannot afford the upgrade, and the cyan "First" button,
; which keeps its colour. Matching either detects the panel in both money states.
EnsureUnitPanelTemplate() {

    return [EnsureSolidTemplate("aa_unitpanel_green.bmp", 0x3CF500, 20, 12)

        , EnsureSolidTemplate("aa_unitpanel_cyan.bmp", 0x12C3FD, 18, 6)]

}

FindUnitPanel(&panelX := 0, &panelY := 0) {
    global rblxID, UnitPanelUsesNewUI, PlacementPatternDropdown
    UnitPanelUsesNewUI := false
    if !WinActive(rblxID)
        return false
    if (IsSet(PlacementPatternDropdown) && PlacementPatternDropdown.Text = "Smart") && FindSmartPlacementPanel() {
        UnitPanelUsesNewUI := true
        WinGetClientPos(,, &cw, &ch, rblxID)
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

CloseUnitPanel(force := false) {
    global rblxID
    if !WinActive(rblxID)
        return false
    if (!force && !FindUnitPanel(&panelX, &panelY))
        return true
    WinGetClientPos(,, &cw, &ch, rblxID)
    oldMouseMode := A_CoordModeMouse
    CoordMode "Mouse", "Client"
    try {
        ; Clear arena space to the right of the hotbar in the supplied screenshots.
        FixClick(Round(638 * cw / 800), Round(549 * ch / 599))
        Sleep(150)
    } finally {
        CoordMode "Mouse", oldMouseMode
    }
    return !FindUnitPanel(&panelX, &panelY)
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

CheckForXp() {


    if ResultScreenReady() {
        EndCardMatch("result-detected")
        return true
    }

    ; Check for lobby text

    if (ok := FindText(&X, &Y, 340, 369, 437, 402, 0, 0, XpText) or (ok := FindText(&X, &Y, 539, 155, 760, 189, 0, 0,

        XpText2))) {

        FixClick(325, 185)

        FixClick(560, 560)

        return true

    }

    return false

}

ParseUnitUpgradeLevel(text) {
    if RegExMatch(Trim(text), "i)^upg\s*\[\s*\d{1,2}\s*\]\s*\(\s*max\s*\)$")
        return 21
    pattern := "i)\b(?:upgrade|upg)\s*(?:\[\s*(\d{1,2}|MAX)\s*\]|\(\s*(\d{1,2}|MAX)\s*\))"
    pos := RegExMatch(text, pattern, &match)
    if !pos {
        ; The measured gold UPG [0] header is read as "upgo" by Windows OCR.
        ; Limit glyph correction to an entire isolated UPG header, never prices,
        ; experience, card descriptions, or arbitrary words in the full panel.
        if RegExMatch(Trim(text), "i)^upg\s*[\[(]?\s*(max|o|i|l|\d{1,2})\s*[\])]?\s*$", &short) {
            value := StrLower(short[1])
            if (value = "max")
                return 21
            value := value = "o" ? "0" : (value = "i" || value = "l" ? "1" : value)
            return Integer(value) <= 20 ? Integer(value) : -1
        }
        return -1
    }
    ; Never choose between conflicting OCR labels.
    if RegExMatch(text, pattern, , pos + match.Len)
        return -1
    value := match[1] != "" ? match[1] : match[2]
    if (StrUpper(value) = "MAX")
        return 21
    level := Integer(value)
    return level <= 20 ? level : -1
}

ReadUnitUpgradeLevel() {
    global rblxID, UnitPanelUsesNewUI
    if !FindUnitPanel(&panelX, &panelY)
        return -1
    WinGetClientPos(&cx, &cy, &cw, &ch, rblxID)
    if (IsSet(UnitPanelUsesNewUI) && UnitPanelUsesNewUI) {
        try return ParseUnitUpgradeLevel(ReadHighContrastText(cx + 143, cy + 234, 86, 22, 4))
        catch
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
    if (!UnitActionAllowed() || ServiceSummerCards(true))
        return false
    SendEvent("{r}")
    return true
}

ApplyUnitUpgradeLimit(limit, slot, readLevel := 0, pressUpgrade := 0) {
    if !readLevel
        readLevel := ReadUnitUpgradeLevel
    if !pressUpgrade
        pressUpgrade := PressUnitUpgrade
    if ServiceSummerCards()
        return false
    current := readLevel()
    if (current < 0) {
        ProcessLog("Slot " slot ": could not read Upgrade [n]; skipping unverified upgrade")
        return false
    }
    if (current >= limit)
        return "limit"
    if (pressUpgrade() = false)
        return false
    Sleep(200)
    if ServiceSummerCards()
        return false
    confirmed := readLevel()
    if (confirmed < 0 || confirmed <= current) {
        ProcessLog("Slot " slot ": upgrade increment not confirmed; stopping this upgrade pass")
        return false
    }
    return confirmed >= limit ? "limit" : true
}

UpgradeUnit(x, y, slot := 0) {
    global rblxID
    ServiceSummerCards(true)
    if !UnitActionAllowed()
        return false
    oldMouseMode := A_CoordModeMouse
    CoordMode "Mouse", "Client"
    result := false, closed := false
    try {
        SendEvent("q")
        ; Clear the previous panel before selecting a unit underneath its area.
        if !UnitActionAllowed() || !CloseUnitPanel()
            return false
        FixClick(x, y)
        opened := false
        loop 4 {
            Sleep(200)
            if ServiceSummerCards() {
                if !UnitActionAllowed() || !CloseUnitPanel()
                    return false
                FixClick(x, y)
                continue
            }
            if FindUnitPanel(&panelX, &panelY) {
                opened := true
                break
            }
        }
        if !opened {
            ProcessLog("Upgrade panel not found at " x "," y "; waiting for another pass without offset clicks")
            return false
        }
        if MaxUpgrade() {
            result := "max"
        } else {
            limit := GetUnitUpgradeLimit(slot)
            ; One R press per visit, including when a numerical cap is set.
            ; Ability is handled right after placement; upgrading keeps the
            ; card check above and does not toggle ability again.
            result := limit<=0 ? PressUnitUpgrade() : ApplyUnitUpgradeLimit(limit, slot)
        }
    } finally {
        try {
            if UnitActionAllowed()
                closed := CloseUnitPanel()
        } finally {
            CoordMode "Mouse", oldMouseMode
        }
    }
    return closed ? result : false
}

CheckLobby() {

    loop {

        Sleep 1000

        if (ok := FindText(&X, &Y, 746, 514, 789, 530, 0, 0, AreaText)) {

            break

        }

        Reconnect()

    }

    EndCardMatch("lobby")
    ProcessLog("Returned to lobby; restarting the selected mode")

    return StartSelectedMode()

}

FindVoteStart(&x, &y) {
    global rblxID, VoteStart, SummerVoteStart, MansionVoteStart, mode
    if !WinActive(rblxID)
        return false
    WinGetClientPos(&cx, &cy, &cw, &ch, rblxID)
    ; FindText uses screen coordinates, independent of CoordMode Pixel.
    if (mode = "Summer Event") {
        sx := cw / 800, sy := ch / 599
        if !FindText(&x, &y, cx + Round(300*sx), cy + Round(30*sy), cx + Round(505*sx), cy + Round(85*sy), 0, 0, SummerVoteStart, 1, 0, 0, 20, 10, 1, sx, sy)
            return false
        ; Title center -> center of Yes, measured on the supplied screenshot.
        x -= Round(47*sx)
        y += Round(51*sy)
        return true
    }
    if (mode = "Infinity Mansion") {
        sx := cw / 800, sy := ch / 599
        if !FindText(&x, &y, cx + Round(300*sx), cy + Round(30*sy), cx + Round(505*sx), cy + Round(85*sy), 0, 0, MansionVoteStart, 1, 0, 0, 20, 10, 1, sx, sy)
            return false
        ; Title -> Yes measured on the Mansion vote screen, not its room queue.
        x -= Round(47*sx)
        y += Round(51*sy)
        return true
    }
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
    if mode="Summer Event" || !WinActive(rblxID)
        return false
    try {
        WinGetClientPos(&cx,&cy,&cw,&ch,rblxID)
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
        WinGetClientPos(&nx,&ny,&nw,&nh,rblxID)
        return WinActive(rblxID) && nx=cx && ny=cy && nw=cw && nh=ch && !ResultScreenReady()
    }
    return false
}

CheckLoaded() {
    global mode
    summer := mode = "Summer Event"
    deadline := A_TickCount + 65000

    loop {

        Sleep(1000)

        ; The Summer vote title confirms the load without a full-client OCR read.
        if summer && FindVoteStart(&X, &Y) {
            ProcessLog("Match loaded: Summer Vote Start confirmed")
            return "loaded"
        }

        if ResultScreenReady()
            return "result"

        if SummerMatchStarted() {
            ProcessLog("Summer Event: active match HUD detected; match loaded")
            return "loaded"
        }
        if RegularMatchHudVisible() {
            ProcessLog("Regular match HUD confirmed; match loaded")
            return "loaded"
        }

        ; Check for vote screen
        if !summer && FindVoteStart(&X, &Y) {

            ProcessLog("Match loaded")

            Sleep(1000)

            return "loaded"

        }

        ; Check if player was returned to lobby (e.g. out of Raid tries, key/item missing, or party disbanded)
        if (ok := FindText(&X, &Y, 746, 514, 789, 530, 0, 0, AreaText)) {

            ProcessLog("Lobby detected (no Raid attempts/key or party disbanded) - restarting mode")

            Sleep(1000)

            return "lobby"

        }

        if summer && A_TickCount >= deadline {
            ProcessLog("Summer Event: still waiting for Vote Start or the match HUD; continuing detection")
            deadline := A_TickCount + 65000
        }

        Reconnect()

    }

}

StartedGame() {
    global mode, MatchMaking, SummerMinimumPlayers
    lowCount := 0, lowReads := 0
    if SummerMatchStarted() {
        ProcessLog("Summer Event: match already running; skipping Vote Start")
        global stageStartTime := A_TickCount
        return true
    }
    if !FindVoteStart(&X,&Y) && RegularMatchHudVisible() {
        ProcessLog("Regular match already running; proceeding to placement")
        stageStartTime := A_TickCount
        return true
    }
    ProcessLog("Waiting for teleport and Vote Start...")
    voted := false, unknownLogged := false
    waitStart := A_TickCount

    loop {
        Sleep(1000)

        if ResultScreenReady() {
            ProcessLog("Vote Start interrupted by result screen; stopping placement setup")
            return false
        }

        if SummerMatchStarted() {
            ProcessLog("Summer Event: active match HUD detected while waiting for Vote Start")
            break
        }

        if (A_TickCount - waitStart > 45000) {
            ProcessLog("Vote Start: still waiting for a fresh vote board or active match HUD")
            waitStart := A_TickCount
        }

        if FindVoteStart(&X, &Y) {
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
            oldMouseMode := A_CoordModeMouse
            CoordMode "Mouse", "Screen"
            try FixClick(X, Y)
            finally CoordMode "Mouse", oldMouseMode
            if !voted
                ProcessLog("Vote Start detected; clicked vote")
            voted := true
            continue
        }

        if !voted && RegularMatchHudVisible() {
            ProcessLog("Regular match HUD confirmed without pending Vote Start")
            break
        }

        if (voted) {
            Sleep(2500)
            break
        }

    }

    ProcessLog("Match ready; proceeding to placement")
    global stageStartTime := A_TickCount
    return true
}

PlacementCamera() {

    global rblxID, aaMainUIHwnd

    ; The vote screen ending often leaves the camera close to the avatar.

    ; Recreate the user's placement view: zoom into first person, pitch down,

    ; then zoom back out while keeping the camera pointed at the arena floor.

    if (IsSet(aaMainUIHwnd) && aaMainUIHwnd && WinExist("ahk_id " aaMainUIHwnd))

        WinSetAlwaysOnTop(false, "ahk_id " aaMainUIHwnd)

    if WinExist(rblxID)

        WinActivate(rblxID)

    Sleep(200)

    oldMouseMode := A_CoordModeMouse

    CoordMode "Mouse", "Client"

    try {

        FixMove(400, 300)

        loop 10 {
            SendEvent("{WheelUp}")
            Sleep(25)
        }

        Sleep(150)

        ; In first person, a right-button drag down looks toward the floor.

        MouseClickDrag("Right", 400, 300, 400, 470, 18)

        Sleep(150)

        loop 16 {
            SendEvent("{WheelDown}")
            Sleep(25)
        }

        Sleep(200)

    } finally {

        CoordMode "Mouse", oldMouseMode

        ; Leaving the macro window behind the game is what made the title bar
        ; read "Roblox" instead of the macro name.

        if (IsSet(aaMainUIHwnd) && aaMainUIHwnd && WinExist("ahk_id " aaMainUIHwnd))

            WinSetAlwaysOnTop(true, "ahk_id " aaMainUIHwnd)

    }

    ProcessLog("Camera adjusted for top-down unit placement")

}

StartSelectedMode() {

    ; Do not click arbitrary points in the 3D viewport before navigating.

    ; Those clicks rotate or move the avatar and make the fixed lobby route

    ; unreliable, especially after restoring Roblox's camera zoom.

    if (ModeDropdown.Text = "Infinite") {

        selectedMap := (IsSet(MapDropdown) && MapDropdown.Text != "") ? MapDropdown.Text : "Planet Greenie"

        StoryDropdown.Text := selectedMap

        StoryActDropdown.Text := "Infinity"

        StoryMode()

    }

    else if (ModeDropdown.Text = "Infinity Mansion") {
        InfinityMansionMode()
    }

    else if (ModeDropdown.Text = "Summer Event") {
        SummerEventMode()
    }

    else if (ModeDropdown.Text = "Story") {

        StoryMode()

    }

    else if (ModeDropdown.Text = "Legend") {

        LegendMode()

    }

    else if (ModeDropdown.Text = "Raid") {

        RaidMode()

    }

    else if (ModeDropdown.Text = "Infinity Castle") {

        InfinityCastleMode()

    }

    else if (ModeDropdown.Text = "Dungeon") {

        DungeonMode()

    }

    else if (ModeDropdown.Text = "Portal") {

        PortalMode()

    }

    else if (ModeDropdown.Text = "Farm") {

        FarmMode()

    }

    else if (ModeDropdown.Text = "Daily Infinite Quest") {

        InfQuestMode()

    }

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

        ProcessLog("Click on confirm, Nigga!")

        return false

    }

    return true

}

GetNavKeys() {

    return StrSplit(FileExist("Settings\UINavigation.txt") ? FileRead("Settings\UINavigation.txt", "UTF-8") : "\,#,}",

    ",")

}

GenerateRandomPoints() {

    points := []

    gridSize := 40  ; Minimum spacing between units

    ; Center point coordinates

    centerX := 408

    centerY := 320

    ; Define placement area boundaries (adjust these as needed)

    minX := centerX - 180  ; Left boundary

    maxX := centerX + 180  ; Right boundary

    minY := centerY - 140  ; Top boundary

    maxY := centerY + 140  ; Bottom boundary

    ; Generate 40 random points

    loop 40 {

        ; Generate random coordinates

        x := Random(minX, maxX)

        y := Random(minY, maxY)

        ; Check if point is too close to existing points

        tooClose := false

        for existingPoint in points {

            ; Calculate distance to existing point

            distance := Sqrt((x - existingPoint.x) ** 2 + (y - existingPoint.y) ** 2)

            if (distance < gridSize) {

                tooClose := true

                break

            }

        }

        ; If point is not too close to others, add it

        if (!tooClose)

            points.Push({ x: x, y: y })

    }

    ; Always add center point last (so it's used last)

    points.Push({ x: centerX, y: centerY })

    return points

}

GenerateGridPoints() {

    points := []

    gridSize := 40  ; Space between points

    squaresPerSide := 10  ; How many points per row/column (odd number recommended)

    ; Center point coordinates

    centerX := 408

    centerY := 320

    ; Calculate starting position for top-left point of the grid

    startX := centerX - ((squaresPerSide - 1) / 2 * gridSize)

    startY := centerY - ((squaresPerSide - 1) / 2 * gridSize)

    ; Generate grid points row by row

    loop squaresPerSide {

        currentRow := A_Index

        y := startY + ((currentRow - 1) * gridSize)

        ; Generate each point in the current row

        loop squaresPerSide {

            x := startX + ((A_Index - 1) * gridSize)

            points.Push({ x: x, y: y })

        }

    }

    return points

}

; circle coordinates

GenerateCirclePoints() {

    points := []

    ; A fixed set of 8 angles per ring is what left the growing holes: on the

    ; radius-180 ring neighbours were ~141 px apart while the radius-45 ring had

    ; only ~35 px. Keep the arc distance between neighbours constant instead, so

    ; a wider ring simply gets more points.

    ringGap := 45      ; distance between rings

    arcGap := 45       ; desired distance between neighbours on the same ring

    maxRadius := 180

    ring := 1

    radius := ringGap

    while (radius <= maxRadius) {

        count := Max(6, Round(2 * 3.14159 * radius / arcGap))

        ; Offset every other ring by half a step so the points interleave

        ; instead of lining up into radial spokes.

        phase := (Mod(ring, 2) = 0) ? 3.14159 / count : 0

        loop count {

            radians := phase + (A_Index - 1) * 2 * 3.14159 / count

            x := centerX + radius * Cos(radians)

            y := centerY + radius * Sin(radians)

            points.Push({ x: Round(x), y: Round(y) })

        }

        radius += ringGap

        ring++

    }

    ; Centre goes last: the avatar stands there, so it is the least reliable

    ; spot and should only be used once everything else failed.

    points.Push({ x: centerX, y: centerY })

    return points

}

CheckEndAndRoute() {


    if ((ok := FindText(&X, &Y, 140, 130, 662, 172, 0, 0, LobbyText)) || ResultScreenReady()) {
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

StartMacro(*) {
    ProcessLog("F2: starting macro...")
    try {
        if (!ValidateMode()) {
            return
        }
        StartSelectedMode()
        ProcessLog("Macro workflow returned; press F2 to start again (see preceding status)")
    } catch as err {
        ProcessLog("StartMacro ERROR: " . err.Message . " @ line " . err.Line)
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

    global mode, Wins, loss

    loop {

        Sleep(3000)

        FixClick(560, 560)  ; Move click

        ; Check for unit exit UI element

        if (ok := FindText(&X, &Y, 300, 190, 360, 250, 0.20, 0.20, UnitExit)) {

            ClickUntilGone(0, 0, 300, 190, 360, 250, UnitExit, -4, -35)

        }

        ; Dungeon keeps its own routing after the common result action.

        if TryResultAction(&action) {
            if action="next"
                continue
            if action!="replay"
                return ContinueAfterResult(action)

            ProcessLog("Dungeon complete; replaying")

            ; After clicking replay, check for shop/shrine/chest

            CheckDungeonSpecials()

            if (CheckForFinishDungeon()) {

                ProcessLog("Dungeon processing complete")

                return

            }

            ; Start a new dungeon run

            ProcessLog("Moving to next Dungeon")

            return SelectDungeonRoute()

        }

        Reconnect()

    }

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

        RestartStage()

    }

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
