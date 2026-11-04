#Requires AutoHotkey v2.0

global macroStartTime := A_TickCount
global stageStartTime := A_TickCount
global contractPageCounter := 0
global contractSwitchPattern := 0
global BossRoomCompleted := false
global SaveChestsForBoss := true

;HotKeys
Hotkey(F1Key, (*) => moveRobloxWindow())
Hotkey(F2Key, (*) => StartMacro())
Hotkey(F3Key, (*) => Reload())
Hotkey(F4Key, (*) => TogglePause())

; ---------------------- Game Mode ----------------------------
StoryMode() {
    FixClick(640, 103) ; close leader board
    ProcessLog("Moving to: Story")
    StoryMovement()
    RestartStage()
}
ChallengeMode() {
    FixClick(640, 103)
    ProcessLog("Moving to: Challenge")
    ChallengeMovement()
    RestartStage()
}
RangerMode() {
    ProcessLog("Moving to Ranger mode")
    RangerMovement()
    RestartStage()
}
RaidMode() {
    ProcessLog("Moving to Raid mode")
    RaidMovement()
    RestartStage()
}
DungeonMode() {
    ProcessLog("Moving to Dungeon")
    DungeonMovement()
    RestartStage()
}
SummerMode() {
    ProcessLog("Moving to Summer Event")
    SummerMovement()
    RestartStage()
}
BossEventMode() {
    ProcessLog("Moving to Boss Event")
    BossEventMovement()
    RestartStage()
}
PortalMode() {
    ProcessLog("Moving to Portal")
    PortalMovement()
    RestartStage()
}
; -------------------------------------------------------------------------
; --------------------------------Movement---------------------------------
StoryMovement() {
    FixClick(30, 380) ; to play
    Sleep(800)
    FixClick(85, 270) ; create room
    Sleep(800)
    FixClick(260, 510) ; Story
    Sleep(800)
    StorySelect()
    Sleep(500)
    loop 3 {
        FixClick(475, 445) ; create
    }
    Sleep(800)
    loop 3 {
        FixClick(400, 500) ; confirm / start
    }
    Sleep(800)
}
ChallengeMovement() {
    FixClick(640, 103) ; close leader board
    Sleep(700)
    FixClick(30, 340) ; Area
    Sleep(700)
    FixClick(520, 260) ; Play room
    Sleep(1000)
    LookingForPlayRoom()
    Sleep(1000)
    SendInput("{a Down}")
    Sleep(3900)
    SendInput("{a Up}")
    Sleep(500)
    SendInput("{s Down}")
    Sleep(1000)
    SendInput("{s Up}")
    loop 3 {
        SendInput("e")
        Sleep(500)
    }
    FixClick(290, 305) ; Create Room
    Sleep(1000)
    FixClick(400, 500) ; play
    Sleep(700)
}
RangerMovement() {
    Sleep(800)
    FixClick(640, 103) ; close leader board
    Sleep(800)
    FixClick(30, 380) ; to play
    Sleep(800)
    FixClick(85, 270) ; create room
    Sleep(800)
    FixClick(400, 510) ; ranger
    Sleep(800)
    RangerMapSelect()
    Sleep(500)
    loop 3 {
        FixClick(475, 445) ; create
    }
    Sleep(800)
    loop 3 {
        FixClick(400, 500) ; confirm / start
    }
    Sleep(800)
}
SummerMovement() {
    FixClick(640, 103) ; close leader board
    Sleep(800)
    FixClick(770, 270) ; summer
    Sleep(800)
    FixClick(460, 400) ; play
    Sleep(800)
}
RaidMovement() {
    Sleep(800)
    FixClick(640, 103) ; close leader board
    Sleep(800)
    FixClick(30, 380) ; to play
    Sleep(800)
    FixClick(85, 270) ; create room
    Sleep(800)
    FixClick(540, 500) ; raid
    Sleep(800)
    RaidMapSelect()
    Sleep(500)
    loop 3 {
        FixClick(475, 445) ; create
    }
    Sleep(800)
    loop 3 {
        FixClick(400, 500) ; confirm / start
    }
    Sleep(800)
}
DungeonMovement() {
    Sleep(800)
    FixClick(640, 103) ; close leader board
    Sleep(800)
    FixClick(770, 410) ; choose Dungeon
    Sleep(500)
    if (DungeonDropdown.Text == "Easy") { ; choose difficult
        FixClick(250, 300)
    } else if (DungeonDropdown.Text == "Normal") {
        FixClick(280, 300)
    } else if (DungeonDropdown.Text == "Hell") {
        FixClick(310, 300)
    }
    Sleep(500)
    FixClick(270, 450) ; play
}
BossEventMovement() {
    Sleep(800)
    FixClick(640, 103) ; close leader board
    Sleep(500)
    FixClick(770, 220) ; open Boss Event
    Sleep(500)
    FixClick(440, 390) ; play
}
PortalMovement() {
    Sleep(800)
    FixClick(640, 103) ; close leader board
    Sleep(500)
    FixClick(70, 300) ; open inventiontory
    Sleep(500)
    PortalSearch()
    FixClick(160, 380) ; open portal
    Sleep(500)
    FixClick(120, 360) ; start portal
}
; ---------------------------------------------------------------------
; --------------------------------Story Select -----------------------
; ===== Story Maps Data =====
StoryMaps := Map(
    "Voocha Village",       [230, 270, 0, [230, 210]],
    "Green Planet",         [230, 270, 0, [230, 270]],
    "Demon Forest",         [230, 270, 0, [230, 330]],
    "Leaf Village",         [230, 270, 0, [230, 390]],
    "Z City",               [230, 270, 0, [235, 430]],
    "Ghoul City",           [230, 270, 0, [230, 180]],
    "Night Colosseum",      [230, 270, 3, [230, 420]],
    "Bizzare Race",         [230, 270, 3, [230, 180]],
    "Spirit Realm",         [230, 270, 3, [230, 230]],
    "The City",             [230, 270, 3, [240, 290]],
    "Virtual Sword",        [230, 270, 3, [220, 350]],
    "Ruined Future City",   [230, 270, 3, [230, 410]]
)

; ===== Story Acts data =====
StoryActs := Map(
    "Act 1",  [0, [400, 220]],
    "Act 2",  [0, [400, 280]],
    "Act 3",  [0, [400, 330]],
    "Act 4",  [1, [400, 260]],
    "Act 5",  [1, [400, 320]],
    "Act 6",  [1, [400, 340]],
    "Act 7",  [2, [400, 290]],
    "Act 8",  [3, [400, 330]],
    "Act 9",  [3, [400, 260]],
    "Act 10", [3, [400, 320]]
)

; ===== Difficulty data =====
Difficulties := Map(
    "Normal",    [520, 290],
    "Hard",      [570, 290],
    "Nightmare", [620, 290]
)

; ===================== Function =====================
StorySelect() {
    global StoryMaps, StoryDropdown
    FixClick(230, 270) ; for sure
    ScrollUp4Times()

    mapName := StoryDropdown.Text
    if !StoryMaps.Has(mapName) {
        ProcessLog("Story map not found: " mapName)
        return
    }

    coords := StoryMaps[mapName]
    FixClick(coords[1], coords[2]) ; Ranger
    Sleep(500)
    if (coords[3] > 0)
        loop coords[3] {
            ScrollDown1Times()
        }
    FixClick(coords[4][1], coords[4][2]) ; click chọn map
    StoryActSelect()
}

StoryActSelect() {
    global StoryActs, StoryActDropdown
    Sleep(1000)
    actName := StoryActDropdown.Text
    if !StoryActs.Has(actName) {
        ProcessLog("Story act not found: " actName)
        return
    }

    scrollData := StoryActs[actName]
    if (scrollData[1] > 0) {
        FixClick(400, 270) ; for sure
        Sleep(500)
        loop scrollData[1]
            ScrollDown1Times()
    }
    FixClick(scrollData[2][1], scrollData[2][2])
    StorySelectDifficult()
}

StorySelectDifficult() {
    global Difficulties, Difficult
    Sleep(500)
    diffName := Difficult.Text
    if Difficulties.Has(diffName) {
        coords := Difficulties[diffName]
        FixClick(coords[1], coords[2])
    }
}

; ---------------------------------------------------------------------
; --------------------------------Ranger Select -----------------------
RangerMaps := Map(
    "Voocha Village",       [230, 270, 0,  [220, 200]],
    "Green Planet",         [230, 270, 0,  [230, 270]],
    "Demon Forest",         [230, 270, 0,  [230, 330]],
    "Leaf Village",         [230, 270, 0,  [230, 390]],
    "Z City",               [230, 270, 2,  [235, 180]],
    "Ghoul City",           [230, 270, 2,  [230, 220]],
    "Night Colosseum",      [230, 270, 3,  [230, 180]],
    "Spirit Realm",         [230, 270, 3,  [230, 230]],
    "The City",             [230, 270, 3,  [230, 300]],
    "Virtual Sword",        [230, 270, 3,  [230, 360]],
    "Ruined Future City",   [230, 270, 3,  [230, 410]]
)

RangerMapSelect() {
    global RangerMaps, RangerDropdown
    mapName := RangerDropdown.Text

    if !RangerMaps.Has(mapName) {
        ProcessLog("Map not found: " mapName)
        return
    }

    coords := RangerMaps[mapName]
    FixClick(coords[1], coords[2]) ; chọn map list
    Sleep(500)

    ; Scroll nếu cần
    scrollCount := coords[3]
    if (scrollCount > 0)
        loop scrollCount
            ScrollDown1Times()

    FixClick(coords[4][1], coords[4][2]) ; click map cụ thể
    RangerActSelect()
}

RangerActs := Map(
    "Act 1", [400, 215],
    "Act 2", [400, 280],
    "Act 3", [400, 330]
)

RangerActSelect() {
    global RangerActs, RangerActDropdown
    actName := RangerActDropdown.Text

    if RangerActs.Has(actName) {
        coords := RangerActs[actName]
        FixClick(coords[1], coords[2])
    }
}


; --------------------------------Raid Select -----------------------

RaidMaps := Map(
    "Steel Blitz Rush", [220, 200],
    "The Graveyard",    [230, 270]
)

RaidActs := Map(
    "Act 1", [400, 215],
    "Act 2", [400, 280],
    "Act 3", [400, 330],
    "Act 4", "scroll" ;
)

RaidMapSelect() {
    global RaidDropdown, RaidMaps
    mapName := RaidDropdown.Text
    if RaidMaps.Has(mapName) {
        coords := RaidMaps[mapName]
        FixClick(coords[1], coords[2])
        RaidActSelect()
    }
}

RaidActSelect() {
    global RaidActDropdown, RaidActs
    Sleep(500)
    actName := RaidActDropdown.Text

    if !RaidActs.Has(actName)
        return

    action := RaidActs[actName]
    if (action = "scroll") {
        FixClick(400, 215) ; for sure
        ScrollDown2Times()
        FixClick(400, 320)
    } else {
        FixClick(action[1], action[2])
    }
}

; ---------------------------------------------------------------------
; ---------------------------Portal Search Functions-------------------
PortalSearch() {
    Sleep(500)
    Sleep(500)
    SendInput("{Left}")
    loop 5 {
        SendInput("w")
        Sleep(500)
    }
    Sleep(500)
    if (PortalDropdown.Text == "Ruined Future City") {
        while (!FindText(&x, &y, 237, 233, 568, 378, 0, 0, SaiyanPortal)) {
            Sleep(800)
            continue
        }
    } else if (PortalDropdown.Text == "Colosseum & Ghoul") {
        while (!FindText(&x, &y, 237, 233, 568, 378, 0, 0, NightColosseumAndGhoulCityPortal)) {
            Sleep(800)
            continue
        }
    }
    FixClick(x, y)
}
; ---------------------------------------------------------------------
; ---------------------------Auto Start/ Replay Functions--------------
CheckAutoVoteStartAndReplay() {
    FixClick(20, 600)
    Sleep(500)
    FixClick(540, 325)
    Sleep(500)
    MouseMove(390, 350)
    Sleep(500)
    ScrollDown1Times()
    if (FindText(&x, &y, 526, 296, 556, 327, 0, 0, AutoVoteStart)) {
        Sleep(500)
        FixClick(540, 310)
        ProcessLog("Auto Vote Start Turned ON")
    } else {
        ProcessLog("Auto Vote Start Already ON")
    }
    if (!FindText(&x, &y, 528, 338, 555, 365, 0, 0, AutoReplay)) {
        Sleep(500)
        FixClick(540, 350)
        ProcessLog("Auto Replay Turned ON")
    } else {
        ProcessLog("Auto Replay Already ON")
    }
    FixClick(550, 200)
}
; ---------------------------------------------------------------------
; ---------------------------GameMode Functions------------------------
StoryReplay() {
    FixClick(220, 425)
}
ChallReplay() {
    FixClick(270, 430)
}
RangerReplay() {
    FixClick(210, 430)
}
RaidReplay() {
    FixClick(220, 430)
}
DungeonNext() {
    FixClick(265, 430)
}
SummerReplay() {
    FixClick(275, 435)
}
BossEventReplay() {
    FixClick(275, 435)
}
LookingForPlayRoom() {
    loop {
        if !(FindText(&x, &y, 333, 107, 469, 339, 0, 0, PlayRoom)) {
            SendInput("{Right}")
        } else {
            ProcessLog("Found Play Room")
            break
        }
    }
}
ScrollDown1Times() {
    SendInput("{WheelDown}")
    Sleep(500)
}
ScrollDown2Times() {
    loop 2 {
        SendInput("{WheelDown}")
        Sleep(500)
    }
}
ScrollDown3Times() {
    loop 3 {
        SendInput("{WheelDown}")
        Sleep(500)
    }
}
ScrollUp4Times() {
    loop 4 {
        SendInput("{WheelUp}")
        Sleep(500)
    }
}
; -------------------------------------------------------------------------
; ---------------------------------Game Functions-------------------------
RestartStage() {
    currentMap := DetectMap()
    ; Wait for loading
    CheckLoaded()
    ; Wait for game to actually start
    StartedGame()
    ; Monitor stage progress
    MonitorStage()
}
MonitorEndScreen() {
    global mode, ReturnLobbyBox, MatchMaking
    global RangerReplayCount

    Loop {
        Sleep(3000)
        if (mode = "Story") {
            ProcessLog("Replay Story")
            StoryReplay()
            return MonitorStage()
        } else if (mode = "Challenge") {
            ProcessLog("Replaying challenge")
            ChallReplay()
            return MonitorStage()
        } else if (mode = "Ranger") {
            ProcessLog("Replaying Ranger end")
            RangerReplay()
            Sleep(5000)
            MonitorStage()
        } else if (mode = "Raid") {
            ProcessLog("Replaying on Raid end")
            RaidReplay()
            return MonitorStage()
        } else if (mode = "Dungeon") {
            ProcessLog("Play next Dungeon")
            DungeonNext()
            return MonitorStage()
        } else if (mode = "Summer") {
            ProcessLog("Replaying on Summer end")
            SummerReplay()
            return MonitorStage()
        } else if (mode = "Boss Event") {
            ProcessLog("Replaying Boss Event")
            BossEventReplay()
            return MonitorStage()
        } else if (mode = "Portal") {
            ProcessLog("Replaying Portal")
            BossEventReplay()
            return MonitorStage()
        }
    } else {
        ProcessLog("Restart after lose")
        return RestartStage()
    }
    Reconnect()
}

MonitorStage() {
    global UnitCollected := 0
    global TraitKeyCollected := 0
    global Wins
    global Loss
    lastClickTime := A_TickCount

    if (Speed.Text == "2x") { ; enable 2x speed
        FixClick(570, 60)
    } else {
        FixClick(590, 60)
    }

    while (FindText(&X, &Y, 476, 499, 548, 523, 0, 0, NotAutoPlay)) {
        FixClick(X, Y)
        Sleep(700)
    }
    ProcessLog("Auto Play is ON")
    ProcessLog("Waiting for end status...")

    Loop {
        Sleep(1000)

        timeElapsed := A_TickCount - lastClickTime
        if (timeElapsed >= 1000) {  ; 1 second
            FixClick(400, 180) ; Make sure click play for chall refresh
            lastClickTime := A_TickCount
        }

        if (FindText(&X, &Y, 3, 578, 56, 627, 0, 0, Settings)) {
            return CheckLobby()
        }

        ; Check for Victory
        if ((FindText(&X, &Y, 369, 207, 578, 283, 0, 0, VictoryText) || (FindText(&X, &Y, 369, 207, 578, 283, 0, 0, VictoryText2)))) {
            stageEndTime := A_TickCount
            stageLength := FormatStageTime(stageEndTime - stageStartTime)
            ProcessLog("Victory detected - Stage Length: " stageLength)
            Wins++
            return MonitorEndScreen()
        }
        ; check for loss
        if (FindText(&X, &Y, 369, 207, 578, 283, 0, 0, Defeat)) {
            stageEndTime := A_TickCount
            stageLength := FormatStageTime(stageEndTime - stageStartTime)
            ProcessLog("Loss detected - Stage Length: " stageLength)
            return MonitorEndScreen()
        }

        if ((Wins // 10) || Loss // 10) == 0 {
            SendWebhookWithTime(true, stageLength)
        }
        Reconnect()
    }
}

DetectMap() {
    ProcessLog("Getting in map...")
    startTime := A_TickCount

    Loop {
        ; Check if we waited more than 2 minute for votestart
        if (A_TickCount - startTime > 120000) {
            if ((FindText(&X, &Y, 0, 0, A_ScreenWidth, A_ScreenHeight, 0, 0, LobbyText)) || (FindText(&X, &Y, A_ScreenWidth, A_ScreenHeight, 0, 0, LobbyText2))) {
                ProcessLog("Lobby Found - Return selected mode")
                return StartSelectedMode()
            } else {
                ProcessLog("Cannot find map - Restart game mode selected")
                Sleep(1000)
                return StartSelectedMode()
            }
        }

        mapPatterns := Map(
            "Voocha Village", VoochaVillage,
            "Green Planet", GreenPlanet,
            "Demon Forest", DemonForest,
            "Leaf Village", LeafVillage,
            "Z City", ZCity,
            "Ghoul City", GhoulCity,
            "Night Colosseum", NightColosseum,
            "Spirit Realm", SpiritRealm,
            "Lobby", Lobby,
            "Summer Event", Summer,
        )

        for mapName, pattern in mapPatterns {
            if (ok := FindText(&X, &Y, 0, 0, A_ScreenWidth, A_ScreenHeight, 0, 0, pattern)) {
                ProcessLog("Found map: " mapName)
                return mapName
            }
        }

        ; Check for vote screen
        if (ok := FindText(&X, &Y, 349, 163, 455, 201, 0, 0, VoteStart) or PixelGetColor(320, 60) = 0x00FF00) {
            ProcessLog("Found vote game, start without searching for map")
            Sleep(1000)
            return
        }

        Sleep 1000
        Reconnect()
    }
}

Reconnect() {
    ; Check for Disconnected Screen using FindText
    if (ok := FindText(&X, &Y, 448, 394, 541, 444, 0, 0, Disconnect)) {
        ProcessLog("Lost connect, moving to private sever...")

        psLink := FileExist("Settings\PrivateServer.txt") ? FileRead("Settings\PrivateServer.txt", "UTF-8") : ""

        ; Reconnect to Ps
        if FileExist("Settings\PrivateServer.txt") && (psLink := FileRead("Settings\PrivateServer.txt", "UTF-8")) {
            ProcessLog("Connecting to private server...")
            Run(psLink)
        } else {
            Run("roblox://placeID=8304191830")
        }

        if (FindText(&x, &y, 185, 202, 642, 357, 0, 0, TeleportFailed)) {
            if FileExist("Settings\PrivateServer.txt") && (psLink := FileRead("Settings\PrivateServer.txt", "UTF-8")) {
                ProcessLog("Connecting to private server...")
                Run(psLink)
            } else {
                Run("roblox://placeID=8304191830")
            }
        } else {
            FixClick(43, 67)
            SendInput("{ldown}")
            Sleep(1000)
            SendInput("{Enter}")
            Sleep(7000)
            if (FindText(&x, &y, 185, 202, 642, 357, 0, 0, RobloxAppHomeScreen)) {
                ProcessLog("Found Roblox App Home Screen")
                MouseMove(170, 495)
                FixClick(150, 540)
                return CheckLobby()
            }
        }
        Sleep(5000)

        loop {
            ProcessLog("Reconnecting to Roblox...")
            FixClick(X, Y)
            Sleep(15000)

            if WinExist(rblxID) {
                forceRobloxSize()
                moveRobloxWindow()
                Sleep(1000)
            }

            if (ok := FindText(&X, &Y, 746, 514, 789, 530, 0, 0, Settings)) {
                ProcessLog("Reconnect success")
                return StartSelectedMode()
            } else {
                Reconnect()
            }
        }
    }
}

CheckLobby() {
    Sleep(500)
    while !(FindText(&x, &y, 7, 590, 37, 619, 0, 0, Settings)) {
        Sleep(500)
        continue
    }
    ProcessLog("Returned to Lobby, starting selected mode")
    return StartSelectedMode()
}

CheckLoaded() {
    loop {
        Sleep(1000)

        ; Check for vote screen
        if (ok := FindText(&X, &Y, 349, 163, 455, 201, 0, 0, VoteStart) or PixelGetColor(320, 60) = 0x00FF00) {
            ProcessLog("Game loaded")
            Sleep(1000)
            break
        }
        Reconnect()
    }
}

StartedGame() {
    loop {
        Sleep(1000)
        if (ok := FindText(&X, &Y, 349, 163, 455, 201, 0, 0, VoteStart) or PixelGetColor(320, 60) = 0x00FF00) {
            FixClick(x, y) ; click yes
            FixClick(x + 1, y + 1)
            FixClick(x - 2, y - 2)
            continue  ; Keep waiting if vote screen is still there
        }

        ; If we don't see vote screen anymore the game has started
        ProcessLog("Game Started")
        global stageStartTime := A_TickCount
        break
    }
}

StartSelectedMode() {
    FixClick(400, 450) ; close leaderboard
    ProcessLog("Start current mode: " ModeDropdown.Text)
    if (FindText(&x, &y, 123, 50, 160, 81, 0, 0, Chat)) {
        ProcessLog("Turning off chat button")
        FixClick(x, y)
    }
    CheckAutoVoteStartAndReplay()
    Sleep(500)
    if (mode = "Story") {
        StoryMode()
    } else if (mode = "Challenge") {
        ChallengeMode()
    } else if (mode = "Ranger") {
        RangerMode()
    } else if (mode = "Raid") {
        RaidMode()
    } else if (mode = "Dungeon") {
        DungeonMode()
    } else if (mode = "Summer") {
        SummerMode()
    } else if (mode = "Boss Event") {
        BossEventMode()
    } else if (mode = "Portal") {
        PortalMode()
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
        ProcessLog("Choose your game mode before confirm")
        return false
    }
    if (!confirmClicked) {
        ProcessLog("Click confirm")
        return false
    }
    return true
}

GetNavKeys() {
    return StrSplit(FileExist("Settings\UINavigation.txt") ? FileRead("Settings\UINavigation.txt", "UTF-8") : "\,#,}", ",")
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
        ProcessLog("Macro has stopped")
        Sleep(1000)
    } else {
        ProcessLog("Continue the Macro")
        Sleep(1000)
    }
}