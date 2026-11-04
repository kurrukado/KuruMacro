#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\Lib\AHKv2-Gdip-master\Gdip_All.ahk
global macroStartTime := A_TickCount
global stageStartTime := A_TickCount
global completedMovements := Map()

LoadKeybindSettings()  ; Load saved keybinds
Hotkey(F1Key, (*) => moveRobloxWindow())
Hotkey(F2Key, (*) => StartMacro())
Hotkey(F3Key, (*) => Reload())
Hotkey(F4Key, (*) => TogglePause())
Hotkey(F5Key, (*) => Test())

Test() {
    ProcessLog("Looking for gems")
    x := 294
    y := 434
    w := 32
    h := 15
    loop 5 {
        result := OCR.FromRect(x, y, w, h, "FirstFromAvailableLanguages", {
            grayscale: true,
            scale: 1.0,
        })
    }
    newResult := Integer(result)
    ProcessLog("OCR Kết quả:`n" newResult.Text)
}


PlacingUnits() {
    global successfulCoordinates
    successfulCoordinates := []
    placedCounts := Map()

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
        ProcessLog("No units enabled - skipping to monitoring")
        return MonitorStage()
    }

    placementPoints := PlacementPatternDropdown.Text = "Circle" ? GenerateCirclePoints() :
        PlacementPatternDropdown.Text = "Grid" ? GenerateGridPoints() :
        GenerateRandomPoints()

    ; Go through each slot
    for slotNum in [1, 2, 3, 4, 5, 6] {
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
            ProcessLog("Placing Unit " slotNum " (0/" placements ")")

            ; Place all units for this slot
            while (placedCounts[slotNum] < placements) {
                for point in placementPoints {
                    ; Skip if this coordinate was already used successfully
                    alreadyUsed := false
                    for coord in successfulCoordinates {
                        if (coord.x = point.x && coord.y = point.y) {
                            alreadyUsed := true
                            break
                        }
                    }
                    if (alreadyUsed)
                        continue

                    if PlaceUnit(point.x, point.y, slotNum) {
                        successfulCoordinates.Push({ x: point.x, y: point.y, slot: slotNum })
                        placedCounts[slotNum] += 1
                        ProcessLog("Placed Unit " slotNum " (" placedCounts[slotNum] "/" placements ")")

                        CheckAbility()
                        FixClick(570, 580) ; Move Click
                        break
                    }

                    if CheckForXp()
                        return MonitorStage()
                    Reconnect()
                    CheckEndAndRoute()
                }
                Sleep(500)
            }
        }
    }

    ProcessLog("All units placed to requested amounts")
    UpgradeUnits()
}


UpgradeUnits() {
    global successfulCoordinates, PriorityUpgrade, priority1, priority2, priority3, priority4, priority5, priority6

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

    ProcessLog("Initiating Unit Upgrades...")

    if (PriorityUpgrade.Value) {
        ProcessLog("Using priority upgrade system")

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

                    ProcessLog("Starting upgrades for priority " priorityNum " (slot " slot ")")

                    ; Keep upgrading current slot until all its units are maxed
                    while true {
                        slotDone := true

                        for index, coord in successfulCoordinates {
                            if (coord.slot = slot) {
                                slotDone := false
                                UpgradeUnit(coord.x, coord.y)

                                if CheckForXp() {
                                    ProcessLog("Stage ended during upgrades, proceeding to results")
                                    successfulCoordinates := []
                                    MonitorStage()
                                    return
                                }

                                if MaxUpgrade() {
                                    upgradedCount[coord.slot]++
                                    ProcessLog("Max upgrade reached for Unit " coord.slot " (" upgradedCount[coord.slot] "/" totalUnits[coord.slot] ")")
                                    successfulCoordinates.RemoveAt(index)
                                    FixClick(325, 185) ;Close upg menu
                                    break
                                }

                                Sleep(200)
                                CheckAbility()
                                FixClick(570, 580) ; Move Click
                                Reconnect()
                                CheckEndAndRoute()
                            }
                        }

                        if (slotDone || successfulCoordinates.Length = 0) {
                            ProcessLog("Finished upgrades for priority " priorityNum)
                            break
                        }
                    }
                }
            }
        }

        ProcessLog("Priority upgrading completed")
        return MonitorStage()
    } else {
        ; Normal upgrade (no priority)
        while true {
            if (successfulCoordinates.Length == 0) {
                ProcessLog("All units maxed, proceeding to monitor stage")
                return MonitorStage()
            }

            for index, coord in successfulCoordinates {
                UpgradeUnit(coord.x, coord.y)

                if CheckForXp() {
                    ProcessLog("Stage ended during upgrades, proceeding to results")
                    successfulCoordinates := []
                    MonitorStage()
                    return
                }

                if MaxUpgrade() {
                    upgradedCount[coord.slot]++
                    ProcessLog("Max upgrade reached for Unit " coord.slot " (" upgradedCount[coord.slot] "/" totalUnits[coord.slot] ")")
                    successfulCoordinates.RemoveAt(index)
                    FixClick(325, 185) ;Close upg menu
                    continue
                }

                Sleep(200)
                CheckAbility()
                FixClick(570, 580) ; Move Click
                Reconnect()
                CheckEndAndRoute()
            }
        }
    }
}


InfiniteMode() {
    ProcessLog("Moving to: " ModeDropdown.Text)
    StoryMovement()
    Sleep(1000)
    FixClick(80, 280) ; create
    Sleep(1000)
    FixClick(150, 205) ; choose Namek inf
    Sleep(1000)
    FixClick(304, 329)
    loop 4 { ; scroll to bottom
        Send("{WheelDown}")
    }
    FixClick(307, 433) ; choose infinite mode
    Sleep(1000)
    FixClick(440, 480) ; choose start
    Sleep(1000)
    FixClick(90, 464) ; start here

    RestartStage()
}

; Click Return to Lobby button
ClickReturnLobby() {
    FixClick(143, 476)
}

; Click Replay button
ClickReplay() {
    Sleep(1000)
    FixClick(390, 475)

}

; Click Next Level button
ClickNextLevel() {
    DualClickUntilGone(
        [550, 435, 685, 480, LobbyText, -400, -35, LobbyText2], ; Next Level
        [352, 342, 453, 367, CancelButton, -4, -35, ""]         ; Cancel Button
    )
}

MonitorEndScreen() {
    global mode, ReturnLobbyBox

    ; RewardCount(335, 487, 65, 25)

    Loop {
        Sleep(3000)
        FixClick(600, 570)

        if (ok := FindText(&X, &Y, 135, 151, 201, 179, 0, 0, DefeatText) or FindText(&X, &Y, 136, 152, 222, 181, 0, 0, VictoryText)) {
            ProcessLog("Found Victory/Defeat Text - Current Mode: " mode)
            Sleep(2000)

            ; Now handle each mode
            if (mode = "Infinite") {
                ProcessLog("Handling Infinite end")
                ProcessLog("Replaying Infinite")
                ClickReplay()
                return RestartStage()
            } else {
                ProcessLog("Handling default case")
                ; Default to replay
                ProcessLog("Replaying")
                ClickReplay() ;Replay
                return RestartStage()
            }

        }

        Reconnect()
    }
}

MonitorStage() {
    global Wins, loss, mode, GemsCount, totalGems
    lastClickTime := A_TickCount
    ProcessLog("Wating for end screen...")
    Loop {
        Sleep(1000)

        if (mode = "Infinite") {
            timeElapsed := A_TickCount - lastClickTime
            if (timeElapsed >= 1000) {  ; 5 minutes
                FixClick(613, 582) ; Move click
                lastClickTime := A_TickCount
            }
        }

        ; while (FindText(&x, &y,442, 282, 489, 304, 0, 0, Gold ) || FindText(&x, &y,442, 282, 489, 304, 0, 0, Gems)) {
        ;     Sleep(1000)
        ;     RewardCount(4293, 427, 332, 442)
        ;     Sleep(500)
        ;     FixClick(613, 582)
        ; }

        ; Check for XP screen
        if CheckForXp() {
            ProcessLog("Checking win/loss status")

            ; Calculate stage end time here, before checking win/loss
            stageEndTime := A_TickCount
            stageLength := FormatStageTime(stageEndTime - stageStartTime)

            if (ok := FindText(&X, &Y, 265, 240, 295, 260, 0, 0, UnitExit)) {
                ClickUntilGone(0, 0, 265, 240, 295, 260, UnitExit, -4, -35)
            }

            ; Check for Victory or Defeat
            if (ok := FindText(&X, &Y, 136, 152, 222, 181, 0, 0, VictoryText)) {
                ProcessLog("Victory detected - Stage Length: " stageLength)
                Wins += 1
                SendWebhookWithTime(true, stageLength)
                return MonitorEndScreen()
            } else if (ok := FindText(&X, &Y, 133, 148, 212, 182, 0, 0, DefeatText)) {
                ProcessLog("Defeat detected - Stage Length: " stageLength)
                loss += 1
                SendWebhookWithTime(false, stageLength)

                return MonitorEndScreen()

            }
        }
        Reconnect()
        CheckEndAndRoute()
    }
}

; RewardCount(x, y, w, h) {
;     global Gems, detectionCount := 0
;     local totalGems := 0
;     ProcessLog("Checking for Gems...")

;     Sleep(500) ; Chờ số gems hiển thị rõ

;     Loop 10 {
;         try {
;             result := OCR.FromRect(x, y, w, h, "FirstFromAvailableLanguages", {
;                 grayscale: true,
;                 scale: 3.0

;             })

;             if result {
;                 ProcessLog("OCR Text: " result.Text)
;                 number := StrSplit(result.Text, "`n")[1]  ; Lấy dòng đầu tiên
;                 number := StrReplace(number, "O", "0")     ; Fix lỗi OCR chữ O
;                 number := RegExReplace(number, "[^\d]")    ; Loại ký tự không phải số

;                 if (StrLen(number) >= 3 && StrLen(number) <= 7) {
;                     detectionCount++
;                     ProcessLog("Found " number " gems, total so far: " totalGems)
;                     if (detectionCount >= 1) {
;                         if !(number ~= "^\d+$") {
;                         ProcessLog("Skipped OCR result due to non-numeric content: " number)
;                         continue
;                     }
;                         ; Send exactly what we detected in the green text
;                         Sleep(300)

;                         for digit in StrSplit(number) {
;                             Gems := Integer(digit)
;                             Sleep(120)
;                         }
;                         Sleep(200)
;                     }
;                 }
;             }
;         }
;         Sleep(500)
;     }

;     if (Gems > 0) {
;         totalGems += Gems
;         ProcessLog("Total gems added this stage: " Gems " | Total overall: " totalGems)
;     } else {
;         ProcessLog("No gems detected.")
;     }
;     return totalGems
; }

StoryMovement() {
    FixClick(90, 290) ; Click Area
    sleep (1000)
    FixClick(120, 350) ; Click Story
    sleep (2000)
    SendInput ("{s down}")
    Sleep(4700)
    SendInput ("{s up}")
    Sleep(500)
    SendInput ("{a down}")
    Sleep(5000)
    SendInput ("{a up}")
    Sleep(500)
}

PlayHere() {
    FixClick(400, 480)  ; Click Start
    Sleep (500)
    FixClick(90, 500) ; Actually Starting
    Sleep (500)
    FixClick(80, 500) ; Actually Starting
    Sleep (500)
    FixClick(240, 500) ; Cancel Button
    Sleep (500)
    FixClick(90, 500) ; Actually Starting
    Sleep (500)
    FixClick(80, 500) ; Actually Starting
}

Zoom() {
    MouseMove(400, 300)
    Sleep 100

    ; Zoom in smoothly
    Loop 10 {
        Send "{WheelUp}"
        Sleep 50
    }

    ; Look down
    Click
    MouseMove(400, 400)  ; Move mouse down to angle camera down

    ; Zoom back out smoothly
    Loop 20 {
        Send "{WheelDown}"
        Sleep 50
    }

    ; Move mouse back to center
    MouseMove(400, 300)
}

RestartMatch() {
    Sleep(5000)
    ProcessLog("Restarting match")
    FixClick(25, 610) ;click settings
    Sleep (1000)
    FixClick(516, 315) ;click restart match
    Sleep (1000)
    FixClick(346, 348) ;click yes
    Sleep (1000)
    Sleep (2000)
    FixClick(403, 345) ; click cancel if not pass wave 1
    Sleep (1000)
    FixClick(573, 158) ;exit settings
}

TpSpawn() {
    FixClick(25, 610) ;click settings
    Sleep (500)
    FixClick(520, 245) ;click tp to spawn
    Sleep (500)
    FixClick(575, 160) ;exit settings
    Sleep (500)
}

CloseChat() {
    if (ok := FindText(&X, &Y, 123, 50, 156, 79, 0, 0, OpenChat)) {
        ProcessLog "Closing Chat"
        FixClick(140, 65) ;close chat
    }
}

BasicSetup() {
    Sleep(500)
    FixClick(566, 103) ; Closes Player leaderboard in game
    Sleep (300)
    CloseChat()
    Sleep (300)
    Zoom()
    Sleep (300)
}

DetectMap() {
    ProcessLog("Determining Map...")
    startTime := A_TickCount

    Loop {
        ; Check if we waited more than 3 minute for votestart
        if (A_TickCount - startTime > 180000) {
            if (ok := FindText(&X, &Y, 736, 399, 790, 452, 0, 0, ProfileText)) {
                ProcessLog("Found in lobby - restarting selected mode")
                return StartSelectedMode()
            }
            ProcessLog("Could not detect map after 3 minutes - force continuing")
            return "no map found"
        }

        ; Check for vote screen
        if (ok := FindText(&X, &Y, 322, 110, 483, 170, 0, 0, VoteStart) or PixelGetColor(300, 15) = 0x0F9C24 or PixelGetColor(300, 15) = 0x15DE33) {
            ProcessLog("Same Map or No Map Found")
            return "no map found"
        }

        mapPatterns := Map(
            "Planet Namek", PlanetNamek,
            "Sand Village", SandVillage,
            "Double Dungeon", DoubleDungeon,
            "Shibuya Station", ShibuyaStation,
            "Underground Church", UndergroundChurch,
            "Spirit Society", SpiritSociety,
            "Blood-Red Chamber", IgrisBoss,
            "Spider Forest", SpiderForest,
            "Track Of World", TrackOfWorld,
            "Shibuya Aftermath", ShibuyaAftermath,
            "Golden Castle", GoldenCastle,
            "Kuinshi Palace", KuinshiPalace
        )

        for mapName, pattern in mapPatterns {
            if (ok := FindText(&X, &Y, 10, 505, 335, 625, 0, 0, pattern)) {
                ProcessLog("Detected map: " mapName)
                return mapName
            }
        }

        Sleep 1000
        Reconnect()
    }
}

MoveForSandVillage() {
    SendInput ("{s down}")
    SendInput ("{d down}")
    Sleep (5000)
    SendInput ("{s up}")
    SendInput ("{d up}")
    Sleep (1000)
}

MoveForDoubleDungeon() {
    SendInput ("{w down}")
    Sleep (1400)
    SendInput ("{w up}")
    Sleep (1000)
}

MoveForSpiderForest() {
    SendInput ("{d down}")
    Sleep (800)
    SendInput ("{d up}")
    Sleep (1000)
    SendInput ("{s down}")
    Sleep (2300)
    SendInput ("{s up}")
    Sleep (1000)
}

MoveForGoldenCastle() {
    SendInput ("{a down}")
    Sleep (1200)
    SendInput ("{a up}")
    Sleep (1000)
}

MoveForBloodRedChamber() {
    SendInput ("{s down}")
    Sleep (4300)
    SendInput ("{s up}")
    Sleep (1000)
}

PlaceUnitForAngle() {
    ; Try placing a unit using random points
    ProcessLog("Attempting to place a unit for angle fix")

    ; Generate random placement points
    placementPoints := GenerateRandomPoints()

    ; Track placement attempts
    placementAttempts := 0
    maxAttempts := 20

    ; Try to place unit with slot 1
    for point in placementPoints {
        SendInput("1")
        Sleep 50
        FixClick(point.x, point.y)
        Sleep 50
        SendInput("q")
        Sleep 300

        ; Increment attempt counter
        placementAttempts++

        ; Check if unit was placed
        if (CameraUnitPlaced()) {
            ProcessLog("Unit placed successfully for angle check")
            return true
        }

        ; Check if restart put us back in lobby or game ended
        if (CheckForXp() || FindText(&X, &Y, 736, 399, 790, 452, 0, 0, ProfileText)) {
            ProcessLog("Game ended or found lobby.")
            return false
        }

        ; Check if we've reached max attempts
        if (placementAttempts >= maxAttempts) {
            ProcessLog("Failed to place unit after " maxAttempts " attempts. tp spawn to retry.")
            TpSpawn()
            Sleep(3000)
            return PlaceUnitForAngle()  ; Recursive call to try again after restart
        }
    }
}

SpectatorAngleFix() {
    ; First Teleport to spawn
    TpSpawn()
    Sleep(1000)

    ; Enter spectator mode
    FixClick(229, 411)
    Sleep(800)

    ; look left to fix angle
    FixClick(327, 511)
    Sleep(800)

    ; Exit spectator mode
    FixClick(400, 575)
    Sleep(2000)
}

RestartStage() {
    global completedMovements
    currentMap := DetectMap()

    ; Reset movement completion if this is a new map
    if (!completedMovements.Has(currentMap)) {
        completedMovements := Map()  ; Clear all previous entries
        completedMovements[currentMap] := false  ; Set current map to false
    }

    ; Wait for loading
    CheckLoaded()

    ; Do initial setup and map-specific movement during vote timer
    BasicSetup()

    ; Wait for game to actually start to fix camera movement
    StartedGame()

    ; Fix camera angle
    ; FixMapCameraAngle(currentMap)

    ; Wait for game to actually start to start placing units
    StartedGame()

    ; Begin unit placement and management
    PlacingUnits()

    ; Monitor stage progress
    MonitorStage()
}

Reconnect() {
    ; Check for Disconnected Screen using FindText
    if (ok := FindText(&X, &Y, 330, 218, 474, 247, 0, 0, Disconnect)) {
        ProcessLog("Lost Connection! Attempting To Reconnect To Private Server...")

        psLink := FileExist("Settings\PrivateServer.txt") ? FileRead("Settings\PrivateServer.txt", "UTF-8") : ""

        ; Reconnect to Ps
        if FileExist("Settings\PrivateServer.txt") && (psLink := FileRead("Settings\PrivateServer.txt", "UTF-8")) {
            ProcessLog("Connecting to private server...")
            Run(psLink)
        } else {
            Run("roblox://placeID=16146832113")
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

            if (ok := FindText(&X, &Y, 736, 399, 790, 452, 0, 0, ProfileText)) {
                ProcessLog("Reconnected Successfully!")
                return StartSelectedMode()
            } else {
                Reconnect()
            }
        }
    }
}

PlaceUnit(x, y, slot := 1) {
    SendInput(slot)
    Sleep 50
    FixClick(x, y)
    Sleep 50
    SendInput("q")

    if UnitPlaced() {
        Sleep 15
        return true
    }
    return false
}

MaxUpgrade() {
    Sleep 500
    ; Check for max text
    if (ok := FindText(&X, &Y, 150, 250, 275, 412, 0.10, 0.10, MaxText) or (ok := FindText(&X, &Y, 150, 250, 275, 412, 0.10, 0.10, MaxText2))) {
        return true
    }
    return false
}

UnitPlaced() {
    Sleep 2000
    ; Check for upgrade text
    if (ok := FindText(&X, &Y, 140, 250, 280, 415, 0, 0, UpgradeText) or (ok := FindText(&X, &Y, 140, 250, 280, 415, 0, 0, UpgradeText2))) {
        ProcessLog("Unit Placed Successfully")
        FixClick(277, 220) ; close upg menu
        return true
    }
    return false
}

CameraUnitPlaced() {
    Sleep 2000
    ; Check for upgrade text
    if (ok := FindText(&X, &Y, 140, 250, 280, 415, 0, 0, UpgradeText) or (ok := FindText(&X, &Y, 140, 250, 280, 415, 0, 0, UpgradeText2))) {
        return true
    }
    return false
}

CheckAbility() {
    global AutoAbilityBox  ; Reference your checkbox

    ; Only check ability if checkbox is checked
    if (AutoAbilityBox.Value) {
        if (ok := FindText(&X, &Y, 295, 240, 332, 264, 0, 0, AutoOff)) {
            FixClick(311, 223)  ; Turn ability on
            ProcessLog("Auto Ability Enabled")
        }
    }
}

CheckForXp() {
    ; Check for lobby text
    if (ok := FindText(&X, &Y, 380, 70, 530, 220, 0, 0, YellowSkull) or (ok := FindText(&X, &Y, 513, 167, 666, 198, 0, 0, XpText))) {
        return true
    }
    return false
}

UpgradeUnit(x, y) {
    FixClick(x, y - 3)
    Sleep(200)
    SendInput("{T}")
    Sleep(200)
    SendInput("{T}")
    Sleep(200)
    SendInput("{T}")
    Sleep(500)
}

CheckLobby() {
    loop {
        Sleep 1000
        if (ok := FindText(&X, &Y, 736, 399, 790, 452, 0, 0, ProfileText)) {
            break
        }
        Reconnect()
    }
    Processlog("Returned to lobby, restarting selected mode")
    return StartSelectedMode()
}

CheckLoaded() {
    loop {
        Sleep(1000)

        ; Check for vote screen
        if (ok := FindText(&X, &Y, 322, 110, 483, 170, 0, 0, VoteStart) or PixelGetColor(300, 15) = 0x0F9C24 or PixelGetColor(300, 15) = 0x15DE33) {
            ProcessLog("Successfully Loaded In")
            BasicSetup()
            Sleep(500)
            Sleep(1000)
            break
        }

        Reconnect()
    }
}

StartedGame() {
    loop {
        Sleep(1000)
        if (ok := FindText(&X, &Y, 322, 110, 483, 170, 0, 0, VoteStart)) {
            Sleep(3000) ; wait for stage text disabled
            FixClick(367, 157)
            continue  ; Keep waiting if vote screen is still there
        }

        ; If we don't see vote screen anymore the game has started
        ProcessLog("Game started")
        global stageStartTime := A_TickCount
        break
    }
}

StartSelectedMode() {
    FixClick(640, 104) ; Closes Player leaderboard
    sleep (500)
    FixClick(667, 173) ; Close Update Logs
    sleep (500)
    FixClick(568, 231) ; Close Daily
    sleep (500)

    if (ModeDropdown.Text = "Infinite") {
        InfiniteMode()
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
    if (ModeDropdown.Text = "") {
        ProcessLog("Please select a gamemode before starting the macro!")
        return false
    }
    if (!confirmClicked) {
        ProcessLog("Please click the confirm button before starting the macro!")
        return false
    }
    return true
}

GetNavKeys() {
    return StrSplit(FileExist("Settings\UINavigation.txt") ? FileRead("Settings\UINavigation.txt", "UTF-8") : "\,#,}", ",")
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

    ; Generate 60 random points
    Loop 60 {
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
    squaresPerSide := 7  ; How many points per row/column (odd number recommended)

    ; Center point coordinates
    centerX := 408
    centerY := 320

    ; Calculate starting position for top-left point of the grid
    startX := centerX - ((squaresPerSide - 1) / 2 * gridSize)
    startY := centerY - ((squaresPerSide - 1) / 2 * gridSize)

    ; Generate grid points row by row
    Loop squaresPerSide {
        currentRow := A_Index
        y := startY + ((currentRow - 1) * gridSize)

        ; Generate each point in the current row
        Loop squaresPerSide {
            x := startX + ((A_Index - 1) * gridSize)
            points.Push({ x: x, y: y })
        }
    }

    return points
}

; circle coordinates
GenerateCirclePoints() {
    points := []

    ; Define each circle's radius
    radius1 := 45    ; First circle
    radius2 := 90    ; Second circle
    radius3 := 135   ; Third circle
    radius4 := 180   ; Fourth circle

    ; Angles for 8 evenly spaced points (in degrees)
    angles := [0, 45, 90, 135, 180, 225, 270, 315]

    ; First circle points
    for angle in angles {
        radians := angle * 3.14159 / 180
        x := centerX + radius1 * Cos(radians)
        y := centerY + radius1 * Sin(radians)
        points.Push({ x: Round(x), y: Round(y) })
    }

    ; second circle points
    for angle in angles {
        radians := angle * 3.14159 / 180
        x := centerX + radius2 * Cos(radians)
        y := centerY + radius2 * Sin(radians)
        points.Push({ x: Round(x), y: Round(y) })
    }

    ; third circle points
    for angle in angles {
        radians := angle * 3.14159 / 180
        x := centerX + radius3 * Cos(radians)
        y := centerY + radius3 * Sin(radians)
        points.Push({ x: Round(x), y: Round(y) })
    }

    ;  fourth circle points
    for angle in angles {
        radians := angle * 3.14159 / 180
        x := centerX + radius4 * Cos(radians)
        y := centerY + radius4 * Sin(radians)
        points.Push({ x: Round(x), y: Round(y) })
    }

    return points
}

CheckEndAndRoute() {
    if (ok := FindText(&X, &Y, 80, 85, 739, 224, 0, 0, LobbyText)) {
        ProcessLog("Found end screen")
        return MonitorEndScreen()
    }
    return false
}

ClickUntilGone(x, y, searchX1, searchY1, searchX2, searchY2, textToFind, offsetX := 0, offsetY := 0, textToFind2 := "") {
    while (ok := FindText(&X, &Y, searchX1, searchY1, searchX2, searchY2, 0, 0, textToFind) ||
        textToFind2 && FindText(&X, &Y, searchX1, searchY1, searchX2, searchY2, 0, 0, textToFind2)) {
        if (offsetX != 0 || offsetY != 0) {
            FixClick(X + offsetX, Y + offsetY)
        } else {
            FixClick(x, y)
        }
        Sleep(1000)
        Reconnect()
    }
}

DualClickUntilGone(pattern1, pattern2) {
    ; Keep going until neither pattern is found
    loop {
        pattern1Found := false
        pattern2Found := false

        ; Check if pattern 1 exists
        if (ok1 := FindText(&X, &Y, pattern1[1], pattern1[2], pattern1[3], pattern1[4], 0, 0, pattern1[5]) ||
            (pattern1[8] && FindText(&X, &Y, pattern1[1], pattern1[2], pattern1[3], pattern1[4], 0, 0, pattern1[8]))) {
            FixClick(X + pattern1[6], Y + pattern1[7])
            Sleep(1000)
            pattern1Found := true
        }

        ; Check if pattern 2 exists
        if (ok2 := FindText(&X, &Y, pattern2[1], pattern2[2], pattern2[3], pattern2[4], 0, 0, pattern2[5]) ||
            (pattern2[8] && FindText(&X, &Y, pattern2[1], pattern2[2], pattern2[3], pattern2[4], 0, 0, pattern2[8]))) {
            FixClick(X + pattern2[6], Y + pattern2[7])
            Sleep(1000)
            pattern2Found := true
        }

        ; If neither pattern was found, we're done
        if (!pattern1Found && !pattern2Found)
            break

        Reconnect()
    }

    return true
}

StartMacro(*) {
    if (!ValidateMode()) {
        return
    }
    StartSelectedMode()
}

TogglePause(*) {
    Pause -1
    if (A_IsPaused) {
        ProcessLog("Macro Paused")
        Sleep(1000)
    } else {
        ProcessLog("Macro Resumed")
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