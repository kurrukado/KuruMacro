#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\Lib\AHKv2-Gdip-master\Gdip_All.ahk
#Include %A_ScriptDir%\Lib\GameMovement.ahk
global macroStartTime := A_TickCount
global stageStartTime := A_TickCount
global CameraMoved := false

LoadKeybindSettings()  ; Load saved keybinds
Hotkey(F1Key, (*) => moveRobloxWindow())
Hotkey(F2Key, (*) => StartMacro())
Hotkey(F3Key, (*) => Reload())
Hotkey(F4Key, (*) => TogglePause())

SelectMap() {
    ; 1. Khai báo danh sách tọa độ
    mapCoords := [{ x: 233, y: 287 }, ; Vị trí 1: Ninja Forest
        { x: 233, y: 324 }, ; Vị trí 2: Marine Base
        { x: 233, y: 372 }  ; Vị trí 3: Hollowed Moon
    ]

    ; 2. Xác định vị trí (pos) dựa trên tên bản đồ
    pos := 0
    if (MapDropdown.Text == "Ninja Forest") {
        pos := 1
    } else if (MapDropdown.Text == "Marine Base") {
        pos := 2
    } else if (MapDropdown.Text == "Hollowed Moon") {
        pos := 3
    }

    ; 3. Kiểm tra nếu tìm thấy pos hợp lệ thì mới thực hiện Click
    if (pos > 0) {
        selectedX := mapCoords[pos].x
        selectedY := mapCoords[pos].y
        FixClick(selectedX, selectedY)
    }
}

ChooseDifficult() {
    loop {
        ProcessLog("Selecting Difficult")
        Sleep(500)
        if (DifficultDropdown.Text == "Easy") {
            if (FindText(&x, &y, 398, 314, 576, 346, 0.5, 0.5, Easy)) {
                FixClick(426, 328)
                break
            }
        } else if (DifficultDropdown.Text == "Hard") {
            if (FindText(&x, &y, 398, 314, 576, 346, 0.5, 0.5, Hard)) {
                FixClick(480, 328)
                break
            }
        } else if (DifficultDropdown.Text == "Nightmare") {
            if (FindText(&x, &y, 398, 314, 576, 346, 0.5, 0.5, Nightmare)) {
                FixClick(540, 328)
                break
            }
        }
    }

}

CreateMatch() {
    loop {
        ProcessLog("Creating match")
        Sleep(500)
        if (ImageSearch(&x, &y, 6, 338, 128, 375, "*50 " A_ScriptDir "\Images\CreateMatch.png")) {
            FixClick(x, y)
            break
        }
    }
}

PlacingUnits() {
    ; Khai báo biến toàn cục cần thiết
    global successfulCoordinates, UnitPlacements 
    
    ; Reset danh sách các điểm đã đặt thành công trong ván này
    successfulCoordinates := []
    placedCounts := Map()

    ; --- [QUAN TRỌNG] LOAD DỮ LIỆU TỪ FILE TXT LÊN ---
    LoadUnitCoordsFromFile()
    ; -------------------------------------------------

    ; Kiểm tra xem có Unit nào được bật không
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

    defaultPoints := PlacementPatternDropdown.Text = "Circle" ? GenerateCirclePoints() :
        PlacementPatternDropdown.Text = "Grid" ? GenerateGridPoints() :
        GenerateRandomPoints()

    ; --- BẮT ĐẦU VÒNG LẶP ĐẶT UNIT ---
    for slotNum in [1, 2, 3, 4, 5, 6] {
        enabled := "enabled" slotNum
        enabled := %enabled%
        enabled := enabled.Value

        ; Lấy số lượng muốn đặt
        placements := "placement" slotNum
        placements := %placements%
        placements := Integer(placements.Text)

        if !placedCounts.Has(slotNum)
            placedCounts[slotNum] := 0

        ; Chỉ chạy nếu Unit được bật và số lượng > 0
        if (enabled && placements > 0) {
            ProcessLog("Placing Unit " slotNum " (0/" placements ")")

            ; === LOGIC CHỌN VỊ TRÍ (MỚI) ===
            targetPoints := []
            usingCustom := false
            
            ; Kiểm tra: Nếu Unit này có dữ liệu tọa độ riêng (đã load từ file)
            if (IsSet(UnitPlacements) && UnitPlacements.Has(slotNum) && UnitPlacements[slotNum].Length > 0) {
                usingCustom := true
                ProcessLog("Unit " slotNum ": Using CUSTOM positions")
                
                ; Chuyển đổi định dạng [x,y] sang {x:..., y:...}
                for pt in UnitPlacements[slotNum] {
                    targetPoints.Push({x: pt[1], y: pt[2]})
                }
            } else {
                ; Nếu không cài đặt riêng, dùng danh sách mặc định (Random/Grid)
                ProcessLog("Unit " slotNum ": Using DEFAULT pattern")
                targetPoints := defaultPoints
            }
            ; =====================================

            ; Vòng lặp thực hiện đặt
            loopSafety := 0
            while (placedCounts[slotNum] < placements) {
                loopSafety++
                
                ; Nếu dùng Custom Point mà thử quá nhiều lần (20 vòng) thì dừng để tránh kẹt
                if (usingCustom && loopSafety > 20) {
                    ProcessLog("Warning: Could not place all custom units for Slot " slotNum)
                    break
                }

                ; Duyệt qua từng điểm trong danh sách mục tiêu
                for point in targetPoints {
                    
                    ; Kiểm tra trùng lặp với các Unit đã đặt thành công trước đó
                    alreadyUsed := false
                    for coord in successfulCoordinates {
                        ; So sánh khoảng cách nhỏ (sai số 2 pixel)
                        if (Abs(coord.x - point.x) < 2 && Abs(coord.y - point.y) < 2) {
                            alreadyUsed := true
                            break
                        }
                    }
                    if (alreadyUsed)
                        continue

                    ; Thử đặt Unit tại vị trí point.x, point.y
                    if PlaceUnit(point.x, point.y, slotNum) {
                        successfulCoordinates.Push({ x: point.x, y: point.y, slot: slotNum })
                        placedCounts[slotNum] += 1
                        ProcessLog("Placed Unit " slotNum " (" placedCounts[slotNum] "/" placements ")")

                        FixClick(570, 580) ; Click ra ngoài để bỏ chọn
                        
                        ; Nếu đặt được 1 con, thoát vòng for để kiểm tra lại số lượng (while loop)
                        break
                    }

                    ; Kiểm tra các sự kiện ngắt quãng
                    if CheckForXp() {
                        return MonitorStage()
                    }
                    Reconnect()
                    CheckEndAndRoute()
                }
                
                ; Logic thoát cho Custom Mode:
                ; Nếu đã duyệt hết danh sách Custom mà vẫn chưa đặt đủ (do bị chặn hoặc đặt hết điểm rồi)
                if (usingCustom && A_Index > 1 && placedCounts[slotNum] < placements) {
                    ; Nếu số lượng điểm bạn chấm ít hơn số lượng bạn muốn đặt -> Dừng lại
                    if (placedCounts[slotNum] >= targetPoints.Length) {
                        ProcessLog("Placed all available custom points for Unit " slotNum)
                        break
                    }
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
                FixClick(570, 580) ; Move Click
                Reconnect()
                CheckEndAndRoute()
            }
        }
    }
}


; Click Return to Lobby button
ClickReturnLobby() {
    FixClick(143, 476)
}

; Click Replay button
ClickReplay() {
    Sleep(1000)
    FixClick(347, 460)

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

        if (ImageSearch(&FoundX, &FoundY, 212, 213, 330, 275, "*70 " A_ScriptDir "\Images\InfiniteVictory.png")) or (ImageSearch(&FoundX, &FoundY, 213, 227, 324, 263, "*60 " A_ScriptDir "\Images\Defeat.png"))  or (ImageSearch(&FoundX, &FoundY, 213, 227, 324, 263, "*60 " A_ScriptDir "\Images\Victory.png")) {
            ProcessLog("Found Victory/Defeat Text - Current Mode: " mode)
            Sleep(2000)

            ; Now handle each mode
            if (mode == "Infinite") {
                ProcessLog("Handling Infinite end")
                ProcessLog("Replaying Infinite")
                ClickReplay()
                return RestartStage()
            } else if (mode == "Winter") {
                ProcessLog("Handling Winter end")
                ProcessLog("Replaying Winter")
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
    global Wins, loss, mode, GemsCount
    lastClickTime := A_TickCount
    ProcessLog("Wating for end screen...")
    Loop {
        Sleep(1000)

        if ((mode == "Infinite") || (mode == "Winter")) {
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
            if ((ImageSearch(&FoundX, &FoundY, 212, 213, 330, 275, "*70 " A_ScriptDir "\Images\InfiniteVictory.png")) or (ImageSearch(&FoundX, &FoundY, 213, 227, 324, 263, "*60 " A_ScriptDir "\Images\Victory.png"))) {
                ProcessLog("Victory detected - Stage Length: " stageLength)
                Wins += 1
                SendWebhookWithTime(true, stageLength)
                return MonitorEndScreen()
            } else if (ImageSearch(&FoundX, &FoundY, 213, 227, 324, 263, "*60 " A_ScriptDir "\Images\Defeat.png")) {
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
    ; --- QUAN TRỌNG: KHAI BÁO BIẾN TOÀN CỤC ---
    ; Phải có dòng này để hàm biết lấy dữ liệu từ bên ngoài vào
    global CameraMoved, MapDropdown 

    Sleep(500)
    FixClick(566, 103) ; Đóng bảng xếp hạng
    Sleep(300)
    CloseChat()
    Sleep(300)
    if (ModeDropdown.Text != "Winter") {
        Zoom()
    }
    Sleep(300)

    ; --- XỬ LÝ CAMERA ---
    ; Bây giờ nó đã hiểu CameraMoved là gì nên sẽ không báo lỗi nữa
    if (CameraMoved == false) {
        
        currentMap := MapDropdown.Text

        ; Nếu là Marine Base
        if (currentMap == "Marine Base") {
            Send("{D down}")  
            Sleep(1000)       
            Send("{D up}")    
            
            CameraMoved := true
        } else if (currentMap == "Hollowed Moon") {
            Send("{S down}")  
            Sleep(4000)       
            Send("{S up}")    
            
            CameraMoved := true
        } else if (ModeDropdown.Text == "Winter") {
            Send("{D down}")  
            Sleep(800)       
            Send("{D up}")
            Sleep(500)
            Send("{S down}")  
            Sleep(1000)       
            Send("{S up}")
            Sleep(500)
            loop 4 {
                Send("{WheelDown}")
            }
            CameraMoved := true
        }
        ; Nếu là các map khác (ví dụ)
        else if (currentMap = "Ninja Forest") {
             CameraMoved := true
        }
    }
}

DetectMap() {
    ProcessLog("Determining Map...")
    startTime := A_TickCount

    Loop {
        ; Check if we waited more than 3 minute for votestart
        if (A_TickCount - startTime > 180000) {
            ; if (ok := FindText(&X, &Y, 736, 399, 790, 452, 0, 0, ProfileText)) {
            ;     ProcessLog("Found in lobby - restarting selected mode")
            ;     return StartSelectedMode()
            ; }
            ProcessLog("Could not detect map after 3 minutes - force continuing")
            return "no map found"
        }

        ; Check for vote screen
        if (ok := FindText(&X, &Y, 334, 114, 399, 145, 0, 0, VoteStart) or (FindText(&X, &Y, 334, 114, 399, 145, 0, 0, VoteStart2)) or PixelSearch(&X, &Y, 334, 114, 399, 143, 0x3BABDC) or PixelSearch(&X, &Y, 334, 114, 399, 143, 0x358BD6)) {
            ProcessLog("Same Map or No Map Found")
            return "no map found"
        }

        mapPatterns := Map(
            "Ninja Forest", NinjaForest,
            "Marine Base", MarineBase,
            "Hollowed Moon", HollowedMoon
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
        ; if (CheckForXp() || FindText(&X, &Y, 736, 399, 790, 452, 0, 0, ProfileText)) {
        ;     ProcessLog("Game ended or found lobby.")
        ;     return false
        ; }

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
    DetectMap()

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

            ; if (ok := FindText(&X, &Y, 736, 399, 790, 452, 0, 0, ProfileText)) {
            ;     ProcessLog("Reconnected Successfully!")
            ;     return StartSelectedMode()
            ; } else {
            ;     Reconnect()
            ; }
        }
    }
}

PlaceUnit(x, y, slot := 1) {
    ProcessLog("Placing unit...")
    SendInput(slot)       ; Chọn slot unit
    Sleep(100)
    FixClick(x, y)        ; Click lần đầu để đặt
    Sleep(1500)
    lastClickTime := A_TickCount  ; Bắt đầu đếm giờ từ lúc click
    
    loop {
        ; 1. Kiểm tra xem Unit đã đặt chưa (Hàm này giờ chạy rất nhanh)
        if UnitPlaced() {
            ; Nếu UnitPlaced trả về true, nghĩa là đã đặt xong và đã đóng menu
            Sleep(500)      ; Đợi một chút cho ổn định
            CheckAbility()   ; Kiểm tra kỹ năng tiếp theo
            return true      ; Thoát và báo công thành công
        }

        ; 2. Tính thời gian đã trôi qua
        timeElapsed := A_TickCount - lastClickTime

        ; 3. Nếu quá 3 giây mà UnitPlaced vẫn chưa thấy gì -> Click lại
        if (timeElapsed >= 2000) {
            ProcessLog("Retry placing unit...") ; (Tùy chọn) Ghi log
            
            SendInput(slot)          ; Đảm bảo slot vẫn được chọn
            Sleep(150)
            FixClick(x, y)           ; Click đặt lại vào vị trí cũ
            
            lastClickTime := A_TickCount ; Reset lại đồng hồ đếm giờ
        }

        ; 4. Nghỉ ngắn 200ms giữa các lần kiểm tra để không lag máy
        Sleep(200) 
    }
}

MaxUpgrade() {
    Sleep(700)

    if (ImageSearch(&FoundX, &FoundY, 2, 211, 301, 511, "*60 " A_ScriptDir "\Images\maxUpgrade.png")) {
        return true ; Tìm thấy chữ "Max", không cần nâng cấp tiếp
    }

    return false ; Chưa thấy chữ "Max", có thể nâng cấp thêm
}

UnitPlaced() {
    if (ok := FindText(&X, &Y, 2, 211, 301, 511, 0, 0, UpgradeText) or PixelSearch(&x, &y, 57, 424, 79, 442, 0x53CC4B)) {
        ProcessLog("Unit Placed Successfully")
        
        ; Sau khi thấy Unit đã đặt thành công, thực hiện đóng menu
        FixClick(600, 580) ; Đóng menu upgrade
        Sleep(500)         ; Đợi menu đóng hẳn
        return true
    }
    
    return false
}

CameraUnitPlaced() {
    Sleep 2000
    ; Check for upgrade text
    if (ok := FindText(&X, &Y, 2, 211, 301, 511, 0, 0, UpgradeText) or PixelSearch(&x, &y, 57, 424, 79, 442, 0x53CC4B)) {
        return true
    }
    return false
}

CheckAbility() {
    global AutoAbilityBox  ; Reference your checkbox

    if (AutoAbilityBox.Value) {
        if (ok := FindText(&X, &Y, 265, 240, 354, 348, 0, 0, Ability)) {
            FixClick(x, y)  ; Turn ability on
            ProcessLog("Auto Ability Enabled")
        }
    }
}

CheckForXp() {
    ; Check for lobby text
    if ((ImageSearch(&FoundX, &FoundY, 212, 213, 330, 275, "*70 " A_ScriptDir "\Images\InfiniteVictory.png") or (ImageSearch(&FoundX, &FoundY, 213, 227, 324, 263, "*60 " A_ScriptDir "\Images\Defeat.png"))  or (ImageSearch(&FoundX, &FoundY, 213, 227, 324, 263, "*60 " A_ScriptDir "\Images\Victory.png"))) ){
        return true
    }
    return false
}

UpgradeUnit(x, y) {
    FixClick(x, y - 3)
    Sleep(200)
    SendInput("{E}")
    Sleep(200)
    SendInput("{E}")
    Sleep(200)
    SendInput("{E}")
    Sleep(200)
    CheckAbility()
}

; CheckLobby() {
;     loop {
;         Sleep 1000
;         if (ok := FindText(&X, &Y, 736, 399, 790, 452, 0, 0, ProfileText)) {
;             break
;         }
;         Reconnect()
;     }
;     Processlog("Returned to lobby, restarting selected mode")
;     return StartSelectedMode()
; }

CheckLoaded() {
    loop {
        Sleep(1000)

        ; Check for vote screen
        if (ok := FindText(&X, &Y, 334, 114, 399, 145, 0, 0, VoteStart) or PixelSearch(&X, &Y, 334, 114, 399, 143, 0x3BABDC) or PixelSearch(&X, &Y, 334, 114, 399, 143, 0x358BD6)) {
            ProcessLog("Successfully Loaded In")
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
        if (ok := FindText(&X, &Y, 334, 114, 399, 145, 0, 0, VoteStart) or PixelSearch(&X, &Y, 334, 114, 399, 143, 0x3BABDC) or PixelSearch(&X, &Y, 334, 114, 399, 143, 0x358BD6)) {
            Sleep(3000) ; wait for stage text disabled
            FixClick(440, 130)
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

    if (ModeDropdown.Text == "Infinite") {
        InfiniteMode()
    } else if (ModeDropdown.Text == "Winter") {
        WinterMode()
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