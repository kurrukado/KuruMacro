#Warn VarUnset, Off
#Warn All, Off

if (A_ScriptFullPath = A_LineFile) {
    mainScript := A_ScriptDir "\..\Main.ahk"
    if FileExist(mainScript) {
        Run('"' A_AhkPath '" "' mainScript '"')
        ExitApp()
    }
}

global settingsFile := ""
global confirmClicked := true

setupFilePath() {
    global settingsFile

    if !DirExist(A_ScriptDir "\Settings") {
        DirCreate(A_ScriptDir "\Settings")
    }

    settingsFile := A_ScriptDir "\Settings\Configuration.txt"
    return settingsFile
}

ChooseDropdownItemByText(dropDown, text) {
    if !IsObject(dropDown)
        return false
    text := Trim(text, " `t`r`n")
    try {
        dropDown.Choose(text)
        return dropDown.Text = text
    }
    return false
}

NormalizeUnitType(value) {
    switch StrLower(Trim(value, " `t`r`n")) {
        case "farm": return "Farm"
        case "ground": return "Ground"
        case "hill": return "Hill"
        case "hybrid": return "Hybrid"
    }
    throw ValueError("Type: select Farm, Ground, Hill or Hybrid")
}

GetUnitPlacementType(slot) {
    global UnitData
    if (slot < 1 || slot > UnitData.Length)
        return "Ground"
    try return NormalizeUnitType(UnitData[slot].Type.Text)
    return "Ground"
}

NormalizeUnitMaxLevel(value) {
    value := StrUpper(Trim(value, " `t`r`n"))
    ; Migrate the previous text-box defaults without enabling a cap.
    if (value = "OFF" || value = "MAX" || value = "" || value = "0")
        return "OFF"
    if RegExMatch(value, "^(?:[1-9]|1\d|20)$")
        return Integer(value) ""
    throw ValueError("Max Level: select OFF or a level from 1 to 20")
}

GetUnitUpgradeLimit(slot) {
    global UnitData
    if (slot < 1 || slot > UnitData.Length)
        return 0
    value := NormalizeUnitMaxLevel(UnitData[slot].MaxLevel.Text)
    return value = "OFF" ? 0 : Integer(value)
}

readInSettings() {
    global enabled1, enabled2, enabled3, enabled4, enabled5, enabled6
    global placement1, placement2, placement3, placement4, placement5, placement6
    global priority1, priority2, priority3, priority4, priority5, priority6, pos1, pos2, pos3, pos4, pos5, pos6
    global mode, UnitData, MatchMaking, ReturnLobbyBox, NextLevelBox, NextRoomBox, ReplayBox

    try {
        settingsFile := setupFilePath()
        if !FileExist(settingsFile) {
            return
        }

        content := FileRead(settingsFile)
    
        lines := StrSplit(content, "`n")

        for line in lines {
            if line = "" {
                continue
            }

            parts := StrSplit(line, "=")
            if RegExMatch(parts[1], "^UnitType([1-6])$", &typeSlot) {
                try UnitData[Integer(typeSlot[1])].Type.Choose(NormalizeUnitType(parts[2]))
                catch {
                    UnitData[Integer(typeSlot[1])].Type.Choose("Ground")
                    ProcessLog("Unit " typeSlot[1] ": invalid saved type; using Ground")
                }
                continue
            }
            if RegExMatch(parts[1], "^MaxLevel([1-6])$", &maxSlot) {
                try UnitData[Integer(maxSlot[1])].MaxLevel.Text := NormalizeUnitMaxLevel(parts[2])
                continue
            }
            switch parts[1] {
                case "Mode":
                    mode := parts[2]
                    try ChooseDropdownItemByText(ModeDropdown, mode)
                case "PlacementPattern":
                    try ChooseDropdownItemByText(PlacementPatternDropdown, Trim(parts[2], " `t`r`n"))
                case "Matchmaking":
                    try MatchMaking.Value := Trim(parts[2], " `t`r`n") = "1"
                case "ReturnToLobby":
                    try ReturnLobbyBox.Value := Trim(parts[2], " `t`r`n") = "1"
                case "NextLevel":
                    try NextLevelBox.Value := Trim(parts[2], " `t`r`n") = "1"
                case "NextRoom":
                    try NextRoomBox.Value := Trim(parts[2], " `t`r`n") = "1"
                case "Replay":
                    try ReplayBox.Value := Trim(parts[2], " `t`r`n") = "1"
                case "Map":
                    try ChooseDropdownItemByText(MapDropdown, parts[2])
                case "Enabled1": try enabled1.Value := parts[2]
                case "Enabled2": try enabled2.Value := parts[2]
                case "Enabled3": try enabled3.Value := parts[2]
                case "Enabled4": try enabled4.Value := parts[2]
                case "Enabled5": try enabled5.Value := parts[2]
                case "Enabled6": try enabled6.Value := parts[2]
                case "Placement1": try placement1.Text := parts[2]
                case "Placement2": try placement2.Text := parts[2]
                case "Placement3": try placement3.Text := parts[2]
                case "Placement4": try placement4.Text := parts[2]
                case "Placement5": try placement5.Text := parts[2]
                case "Placement6": try placement6.Text := parts[2]
                case "Priority1": try priority1.Text := parts[2]
                case "Priority2": try priority2.Text := parts[2]
                case "Priority3": try priority3.Text := parts[2]
                case "Priority4": try priority4.Text := parts[2]
                case "Priority5": try priority5.Text := parts[2]
                case "Priority6": try priority6.Text := parts[2]
                case "Pos1", "pos1": try pos1.Text := parts[2]
                case "Pos2", "pos2": try pos2.Text := parts[2]
                case "Pos3", "pos3": try pos3.Text := parts[2]
                case "Pos4", "pos4": try pos4.Text := parts[2]
                case "Pos5", "pos5": try pos5.Text := parts[2]
                case "Pos6", "pos6": try pos6.Text := parts[2]
            }
        }
        ProcessLog("Configuration settings are loaded")
    }
}

SaveSettings(*) {
    global enabled1, enabled2, enabled3, enabled4, enabled5, enabled6
    global placement1, placement2, placement3, placement4, placement5, placement6
    global priority1, priority2, priority3, priority4, priority5, priority6, pos1, pos2, pos3, pos4, pos5, pos6
    global mode, UnitData, MatchMaking, ReturnLobbyBox, NextLevelBox, NextRoomBox, ReplayBox

    ; Validate all six values before replacing the existing configuration.
    unitTypes := []
    for slot, unit in UnitData {
        try unitTypes.Push(NormalizeUnitType(unit.Type.Text))
        catch as err {
            ProcessLog("Unit " slot ": " err.Message)
            unit.Type.Focus()
            return false
        }
    }
    maxLevels := []
    for slot, unit in UnitData {
        try maxLevels.Push(NormalizeUnitMaxLevel(unit.MaxLevel.Text))
        catch as err {
            ProcessLog("Unit " slot ": " err.Message)
            unit.MaxLevel.Focus()
            return false
        }
    }

    try {
        settingsFile := A_ScriptDir "\Settings\Configuration.txt"
        if FileExist(settingsFile) {
            FileDelete(settingsFile)
        }

        ; Save mode and map selection
        currMode := (IsSet(mode) && mode != "") ? mode : "Infinite"
        content := "Mode=" currMode "`n"
        if (currMode = "Story" && IsSet(StoryDropdown)) {
            content .= "Map=" StoryDropdown.Text
        } else if (currMode = "Portal" && IsSet(PortalDropdown)) {
            content .= "Map= " PortalDropdown.Text
        } else if (currMode = "Raid" && IsSet(RaidDropdown)) {
            content .= "Map=" RaidDropdown.Text
        } else if (IsSet(MapDropdown)) {
            content .= "Map=" MapDropdown.Text
        } else {
            content .= "Map=Planet Greenie"
        }

        content .= "`nPlacementPattern=" PlacementPatternDropdown.Text

        ; Save settings for each unit
        content .= "`n`nEnabled1=" (IsSet(enabled1) ? enabled1.Value : 1)
        content .= "`nEnabled2=" (IsSet(enabled2) ? enabled2.Value : 1)
        content .= "`nEnabled3=" (IsSet(enabled3) ? enabled3.Value : 1)
        content .= "`nEnabled4=" (IsSet(enabled4) ? enabled4.Value : 1)
        content .= "`nEnabled5=" (IsSet(enabled5) ? enabled5.Value : 0)
        content .= "`nEnabled6=" (IsSet(enabled6) ? enabled6.Value : 0)

        content .= "`n`nPlacement1=" (IsSet(placement1) ? placement1.Text : "1")
        content .= "`nPlacement2=" (IsSet(placement2) ? placement2.Text : "2")
        content .= "`nPlacement3=" (IsSet(placement3) ? placement3.Text : "3")
        content .= "`nPlacement4=" (IsSet(placement4) ? placement4.Text : "4")
        content .= "`nPlacement5=" (IsSet(placement5) ? placement5.Text : "5")
        content .= "`nPlacement6=" (IsSet(placement6) ? placement6.Text : "6")

        content .= "`nMatchmaking=" (IsSet(MatchMaking) ? MatchMaking.Value : 0)
        content .= "`nReturnToLobby=" (IsSet(ReturnLobbyBox) ? ReturnLobbyBox.Value : 0)
        content .= "`nNextLevel=" (IsSet(NextLevelBox) ? NextLevelBox.Value : 1)
        content .= "`nNextRoom=" (IsSet(NextRoomBox) ? NextRoomBox.Value : 1)
        content .= "`nReplay=" (IsSet(ReplayBox) ? ReplayBox.Value : 1)
        content .= "`nPriority1=" (IsSet(priority1) ? priority1.Text : "1")
        content .= "`nPriority2=" (IsSet(priority2) ? priority2.Text : "2")
        content .= "`nPriority3=" (IsSet(priority3) ? priority3.Text : "3")
        content .= "`nPriority4=" (IsSet(priority4) ? priority4.Text : "4")
        content .= "`nPriority5=" (IsSet(priority5) ? priority5.Text : "5")
        content .= "`nPriority6=" (IsSet(priority6) ? priority6.Text : "6")
        content .= "`nPos1=" (IsSet(pos1) ? pos1.Text : "Pos 1")
        content .= "`nPos2=" (IsSet(pos2) ? pos2.Text : "Pos 2")
        content .= "`nPos3=" (IsSet(pos3) ? pos3.Text : "Pos 3")
        content .= "`nPos4=" (IsSet(pos4) ? pos4.Text : "Pos 4")
        content .= "`nPos5=" (IsSet(pos5) ? pos5.Text : "Pos 5")
        content .= "`nPos6=" (IsSet(pos6) ? pos6.Text : "Pos 6")

        for index, value in maxLevels {
            UnitData[index].MaxLevel.Text := value
            content .= "`nMaxLevel" index "=" value
        }

        for index, value in unitTypes
            content .= "`nUnitType" index "=" value

        FileAppend(content, settingsFile)
        ProcessLog("Configuration setting are saved")
    }
}

LoadSettings() {
    global UnitData, mode
    try {
        settingsFile := A_ScriptDir "\Settings\Configuration.txt"
        if !FileExist(settingsFile) {
            return
        }

        content := FileRead(settingsFile)
        sections := StrSplit(content, "`n`n")

        for section in sections {
            if (InStr(section, "Index=")) {
                lines := StrSplit(section, "`n")
                index := ""

                for line in lines {
                    if line = "" {
                        continue
                    }

                    parts := StrSplit(line, "=")
                    if (parts[1] = "Index") {
                        index := parts[2]
                    } else if (index && UnitData.Has(Integer(index))) {
                        switch parts[1] {
                            case "Enabled": UnitData[index].Enabled.Value := parts[2]
                            case "Placement": UnitData[index].PlacementBox.Value := parts[2]
                        }
                    }
                }
            }
        }
        ProcessLog("Auto settings loaded successfully")
    }
}

SaveBannerSettings(*) {
    ProcessLog("Saving Banner Configuration")

    if FileExist("Settings\BannerUnit.txt")
        FileDelete("Settings\BannerUnit.txt")

    FileAppend(BannerUnitBox.Value, "Settings\BannerUnit.txt", "UTF-8")
}

SavePsSettings(*) {
    ProcessLog("Saving Private Server")

    if FileExist("Settings\PrivateServer.txt")
        FileDelete("Settings\PrivateServer.txt")

    FileAppend(PsLinkBox.Value, "Settings\PrivateServer.txt", "UTF-8")
}

SaveUINavSettings(*) {
    ProcessLog("Saving UI Navigation Key")

    if FileExist("Settings\UINavigation.txt")
        FileDelete("Settings\UINavigation.txt")

    FileAppend(UINavBox.Value, "Settings\UINavigation.txt", "UTF-8")
}

;Opens discord Link
OpenDiscordLink() {
    Run("https://discord.gg/xRYGPntnTT")
}

;Minimizes the UI
minimizeUI(*) {
    aaMainUI.Minimize()
}

Destroy(*) {
    aaMainUI.Destroy()
    ExitApp
}
;Login Text
setupOutputFile() {
    content := "`n==" aaTitle "" version "==`n  Start Time: [" currentTime "]`n"
    FileAppend(content, currentOutputFile)
}

;Gets the current time
getCurrentTime() {
    currentHour := A_Hour
    currentMinute := A_Min
    currentSecond := A_Sec

    return Format("{:d}h.{:02}m.{:02}s", currentHour, currentMinute, currentSecond)
}

OnModeChange(*) {
    global mode
    selected := ModeDropdown.Text

    ; Hide all dropdowns first
    MapDropdown.Visible := false
    StoryDropdown.Visible := false
    StoryActDropdown.Visible := false
    PortalDropDown.Visible := false
    LegendDropDown.Visible := false
    LegendActDropdown.Visible := false
    RaidDropdown.Visible := false
    RaidActDropdown.Visible := false
    InfinityCastleDropdown.Visible := false
    MatchMaking.Visible := false
    ReturnLobbyBox.Visible := false

    ;Chọn mode dựa trên đã chọn
    if (selected = "Story") {
        StoryDropdown.Visible := true
        StoryActDropdown.Visible := true
        mode := "Story"
    } else if (selected = "Portal") {
        PortalDropDown.Visible := true
        mode := "Portal"
    } else if (selected = "Farm") {
        mode := "Farm"
    } else if (selected = "Daily Infinite Quest") {
        mode := "Daily Infinite Quest"
        MatchMaking.Visible := true
        ReturnLobbyBox.Visible := true
    } else if (selected = "Legend") {
        LegendDropDown.Visible := true
        LegendActDropdown.Visible := true
        mode := "Legend"
        MatchMaking.Visible := true
        ReturnLobbyBox.Visible := true
    } else if (selected = "Raid") {
        RaidDropdown.Visible := true
        RaidActDropdown.Visible := true
        mode := "Raid"
        MatchMaking.Visible := true
        ReturnLobbyBox.Visible := true
    } else if (selected = "Infinity Mansion") {
        mode := "Infinity Mansion"
        MatchMaking.Visible := true
        ReturnLobbyBox.Visible := true
    } else if (selected = "Infinity Castle") {
        InfinityCastleDropdown.Visible := true
        mode := "Infinity Castle"
        MatchMaking.Visible := true
        ReturnLobbyBox.Visible := true
    } else if (selected = "Dungeon") {
        mode := "Dungeon"
        MatchMaking.Visible := true
        ReturnLobbyBox.Visible := true
    } else if (selected = "Summer Event") {
        mode := "Summer Event"
        try StartPaddleWorker()
        MatchMaking.Visible := true
        ReturnLobbyBox.Visible := true

    } else if (selected = "Infinite") {
        MapDropdown.Visible := true
        ReturnLobbyBox.Visible := true
        MatchMaking.Visible := true
        mode := "Infinite"
    }
    UpdateResultOptionsForMode(selected)
}

OnStoryChange(*) {
    if (StoryDropdown.Text != "") {
        StoryActDropdown.Visible := true
    } else {
        StoryActDropdown.Visible := false
    }
}

OnLegendChange(*) {
    if (LegendDropDown.Text != "") {
        LegendActDropdown.Visible := true
    } else {
        LegendActDropdown.Visible := false
    }
}

OnRaidChange(*) {
    if (RaidDropdown.Text != "") {
        RaidActDropdown.Visible := true
    } else {
        RaidActDropdown.Visible := false
    }
}

OnConfirmClick(*) {
    ConfirmModeSelection(true)
}

ConfirmModeSelection(hideSelection := true) {
    if (ModeDropdown.Text = "") {
        ProcessLog("Select a mode before confirming")
        return
    }

    ; For Story mode, check if both Story and Act are selected
    if (ModeDropdown.Text = "Story") {
        if (StoryDropdown.Text = "" || StoryActDropdown.Text = "") {
            ProcessLog("Select Map and Act too")
            return
        }
        ProcessLog("Selected " StoryDropdown.Text " - " StoryActDropdown.Text)
        if (StoryActDropdown.Text = "Infinity") {
            MatchMaking.Visible := true
            ReturnLobbyBox.Visible := true
        } else {
            MatchMaking.Visible := false
            MatchMaking.Value := 0
            ReturnLobbyBox.Visible := false
            ; Định vị tọa độ riêng khi đánh Story thường (Act 1, 2, 3...)
        }


    }
    ; For Portal mode, check if both Portal and Type are selected
    else if (ModeDropdown.Text = "Portal") {
        if (PortalDropDown.Text = "") {
            ProcessLog("Pick up a Portal, Nigga")
            return
        }
        ProcessLog("Confirmed: " PortalDropDown.Text)
        MatchMaking.Visible := false
        MatchMaking.Value := 0
    }
    ;For Farm Mode
    else if (ModeDropdown.Text = "Farm") {
        ProcessLog("Selected mode: " ModeDropdown.Text)
        MatchMaking.Visible := false
        MatchMaking.Value := 0
    }
    ;for InfQuestMode
    else if (ModeDropdown.Text = "Daily Infinite Quest") {
        ProcessLog("Choosed: Inf Quest Mode")
        MatchMaking.Visible := true
        ReturnLobbyBox.Visible := true
    }
    ; For Legend mode, check if both Legend and Act are selected
    else if (ModeDropdown.Text = "Legend") {
        if (LegendDropDown.Text = "" || LegendActDropdown.Text = "") {
            ProcessLog("Please select both Legend Stage and Act before confirming")
            return
        }
        ProcessLog("Selected " LegendDropDown.Text " - " LegendActDropdown.Text)
        MatchMaking.Visible := true
        ReturnLobbyBox.Visible := true
    }
    ; For Raid mode, check if both Raid and RaidAct are selected
    else if (ModeDropdown.Text = "Raid") {
        if (RaidDropdown.Text = "" || RaidActDropdown.Text = "") {
            ProcessLog("Please select both Raid and Act before confirming")
            return
        }
        ProcessLog("Selected " RaidDropdown.Text " - " RaidActDropdown.Text)
        MatchMaking.Visible := true
        ReturnLobbyBox.Visible := true
    }
    ; For Infinity Castle, check if mode is selected
    else if (ModeDropdown.Text = "Infinity Castle") {
        if (InfinityCastleDropdown.Text = "") {
            ProcessLog("Please select an Infinity Castle difficulty before confirming")
            return
        }
        ProcessLog("Selected Infinity Castle - " InfinityCastleDropdown.Text)
        MatchMaking.Visible := true
        ReturnLobbyBox.Visible := true
    }
    else if (ModeDropdown.Text = "Infinity Mansion") {
        ProcessLog("Selected Infinity Mansion - random map, Play Here")
        MatchMaking.Value := 0
        MatchMaking.Visible := true
        ReturnLobbyBox.Visible := true
    }
    else if (ModeDropdown.Text = "Summer Event") {
        try StartPaddleWorker()
        ProcessLog("Selected Summer Event - result actions follow the GUI options; matchmaking returns to lobby")
        MatchMaking.Visible := true
        ReturnLobbyBox.Visible := true
    }
    else if (ModeDropdown.Text = "Dungeon") {
        ProcessLog("Selected Dungeon mode")
        MatchMaking.Visible := true
        ReturnLobbyBox.Visible := true
        SaveChestsBox.Visible := true  ; Show the save chests option for Dungeon mode
    }
    ; For Infinite Mode
    else if (ModeDropdown.Text = "Infinite") {
        if (MapDropdown.Text = "") {
            ProcessLog("Choose a map before confirm")
            return
        }
        ProcessLog("Selected Infinite - " MapDropdown.Text)
        ReturnLobbyBox.Visible := true
        MatchMaking.Visible := true
    }
    else {
        ProcessLog("Selected mode: " ModeDropdown.Text)
        MatchMaking.Visible := false
        MatchMaking.Value := 0
        ReturnLobbyBox.Visible := false
    }

    UpdateResultOptionsForMode(ModeDropdown.Text)
    ; Hide all controls if validation passes. Startup restores the saved mode and
    ; calls this with hideSelection=false so the mode selector stays usable;
    ; only a real Confirm click collapses the selector.
    if (hideSelection) {
        ModeDropdown.Visible := false
        MapDropdown.Visible := false
        StoryDropdown.Visible := false
        StoryActDropdown.Visible := false
        PortalDropDown.Visible := false
        LegendDropDown.Visible := false
        LegendActDropdown.Visible := false
        RaidDropdown.Visible := false
        RaidActDropdown.Visible := false
        InfinityCastleDropdown.Visible := false
        ConfirmButton.Visible := false
        modeSelectionGroup.Visible := false
        Hotkeytext.Visible := true
        Hotkeytext2.Visible := true
    }
    global confirmClicked := true
}

UpdateResultOptionsForMode(selectedMode) {
    global NextLevelBox, NextRoomBox, ReplayBox, ReturnLobbyBox, MatchMaking
    mansion := selectedMode = "Infinity Mansion"
    MatchMaking.Enabled := !mansion
    if mansion
        MatchMaking.Value := 0
    NextLevelBox.Visible:=!mansion
    NextRoomBox.Visible:=mansion
    ReplayBox.Visible:=true
    ReturnLobbyBox.Visible:=true
    repeatEnabled:=!MatchMaking.Value && !ReturnLobbyBox.Value
    NextLevelBox.Enabled:=repeatEnabled && !mansion
    NextRoomBox.Enabled:=repeatEnabled && mansion
    ReplayBox.Enabled:=repeatEnabled
}

FixClick(x, y, LR := "Left") {
    MouseMove(x, y)
    MouseMove(1, 0, , "R")
    MouseClick(LR, -1, 0, , , , "R")
    Sleep(50)
}

; Roblox only acts on wheel input once it has processed a fresh mouse-move at
; that position, so a bare SendInput("{WheelDown}") is silently dropped roughly
; half the time. This applies the same nudge FixClick does without clicking.
FixMove(x, y) {
    MouseMove(x, y)
    MouseMove(1, 0, , "R")
    MouseMove(-1, 0, , "R")
    Sleep(60)
}

CaptchaDetect(x, y, w, h, inputX, inputY, greenOnly := false) {
    detectionCount := 0
    ProcessLog("Checking for numbers...")
    Loop 10 {
        try {
            text := greenOnly ? ReadHighContrastText(x, y, w, h, 3, 0, true)
                : OCR.FromRect(x, y, w, h, "FirstFromAvailableLanguages", {
                grayscale: true,
                scale: 2.0
            }).Text

            if (text != "") {
                ; Get text before any linebreak
                number := StrSplit(text, "`n")[1]

                ; Clean to just get numbers
                number := RegExReplace(number, "[^\d]")

                if (StrLen(number) >= 5 && StrLen(number) <= 7) {
                    detectionCount++

                    if (detectionCount >= 1) {
                        ; Send exactly what we detected in the green text
                        FixClick(inputX, inputY)
                        Sleep(300)

                        ProcessLog("Verification code entered")
                        for digit in StrSplit(number) {
                            Send(digit)
                            Sleep(120)
                        }
                        Sleep(200)
                        return true
                    }
                }
            }
        }
        Sleep(200)
    }
    ProcessLog("Could not detect valid captcha")
    return false
}


TogglePriorityDropdowns(*) {
    LayoutUnitColumns()
}

SaveKeybindSettings(*) {
    ProcessLog("Saving Keybind Configuration")

    if FileExist("Settings\Keybinds.txt")
        FileDelete("Settings\Keybinds.txt")

    FileAppend(Format("F1={}`nF2={}`nF3={}`nF4={}", F1Box.Value, F2Box.Value, F3Box.Value, F4Box.Value),
    "Settings\Keybinds.txt", "UTF-8")

    ; Update globals
    global F1Key := F1Box.Value
    global F2Key := F2Box.Value
    global F3Key := F3Box.Value
    global F4Key := F4Box.Value

    ; Update hotkeys
    Hotkey(F1Key, (*) => moveRobloxWindow())
    Hotkey(F2Key, (*) => StartMacro())
    Hotkey(F3Key, (*) => Reload())
    Hotkey(F4Key, (*) => TogglePause())
}

LoadKeybindSettings() {
    if FileExist("Settings\Keybinds.txt") {
        fileContent := FileRead("Settings\Keybinds.txt", "UTF-8")
        loop parse, fileContent, "`n" {
            parts := StrSplit(A_LoopField, "=")
            if (parts[1] = "F1")
                global F1Key := parts[2]
            else if (parts[1] = "F2")
                global F2Key := parts[2]
            else if (parts[1] = "F3")
                global F3Key := parts[2]
            else if (parts[1] = "F4")
                global F4Key := parts[2]
        }
    }
}

ToggleSaveChestsForBoss(*) {
    global SaveChestsForBoss
    SaveChestsForBoss := !SaveChestsForBoss
    ProcessLog("Save chests for boss room: " (SaveChestsForBoss ? "Enabled" : "Disabled"))
}

; ==============================================================================
; BIẾN TOÀN CỤC & TÍNH NĂNG ĐẶT UNIT DỰA TRÊN ẢNH MAP
; ==============================================================================
global ImgSession := { GuiObj: "", Dots: [], UnitIndex: 0, MaxCount: 20, LastClickTime: 0 }

GetCurrentMapName() {
    global MapDropdown, StoryDropdown, LegendDropDown, RaidDropdown, PortalDropdown, ModeDropdown
    global SummerMapName, MansionMapName
    if (IsSet(ModeDropdown) && ModeDropdown.Text = "Infinity Mansion")
        return IsSet(MansionMapName) ? MansionMapName : ""
    if (IsSet(ModeDropdown) && ModeDropdown.Text = "Summer Event")
        return IsSet(SummerMapName) ? SummerMapName : ""
    if (IsSet(MapDropdown) && MapDropdown.Visible && MapDropdown.Text != "")
        return MapDropdown.Text
    if (IsSet(StoryDropdown) && StoryDropdown.Visible && StoryDropdown.Text != "")
        return StoryDropdown.Text
    if (IsSet(LegendDropDown) && LegendDropDown.Visible && LegendDropDown.Text != "")
        return LegendDropDown.Text
    if (IsSet(RaidDropdown) && RaidDropdown.Visible && RaidDropdown.Text != "")
        return RaidDropdown.Text
    if (IsSet(PortalDropdown) && PortalDropdown.Visible && PortalDropdown.Text != "")
        return PortalDropdown.Text
    if (IsSet(MapDropdown) && MapDropdown.Text != "")
        return MapDropdown.Text
    return "Planet Greenie"
}

GetCurrentModeName() {
    global ModeDropdown
    if (IsSet(ModeDropdown) && ModeDropdown.Text != "")
        return ModeDropdown.Text
    global StoryActDropdown
    if (IsSet(ModeDropdown) && ModeDropdown.Text = "Infinite")
        return "Infinite"
    if (IsSet(ModeDropdown) && ModeDropdown.Text = "Story" && IsSet(StoryActDropdown) && StoryActDropdown.Text =
    "Infinity")
        return "Infinite"
    return "Infinite"
}

GetSettingsFileName() {
    mapName := GetCurrentMapName()
    modeName := GetCurrentModeName()

    if (mapName == "")
        mapName := "UnknownMap"
    if (modeName == "")
        modeName := "Default"

    safeMap := RegExReplace(mapName, '[\\/:*?"<>|]', "_")
    safeMode := RegExReplace(modeName, '[\\/:*?"<>|]', "_")
    return A_ScriptDir "\Settings\" safeMap "_" safeMode ".txt"
}

LoadImage(unitIndex) {
    global ImageUI, ImageUIHwnd, ImgSession, UnitPlacements

    currentMap := GetCurrentMapName()
    currentMode := GetCurrentModeName()

    if (currentMap == "" || currentMap == "UnknownMap") {
        MsgBox("Vui lòng chọn Map và Mode trước khi cài đặt vị trí Unit!", "Thông báo", "Icon!")
        return
    }

    picPath := A_ScriptDir "\GameModeImages\Placement\" currentMap ".png"

    if !FileExist(picPath) && FileExist(A_ScriptDir "\Images\" currentMap ".png")
        picPath := A_ScriptDir "\Images\" currentMap ".png"

    if !FileExist(picPath) {
        choice := MsgBox("Không tìm thấy file ảnh map tại:`n" picPath "`n`nBạn có muốn tự chọn file ảnh map từ máy tính không?",
            "Chưa có ảnh map", "YesNo Icon?")
        if (choice = "Yes") {
            selectedFile := FileSelect(1, A_ScriptDir "\GameModeImages\Placement", "Chọn ảnh map cho '" currentMap "'",
                "Images (*.png; *.jpg; *.bmp)")
            if (selectedFile != "") {
                picPath := selectedFile
            } else {
                return
            }
        } else {
            return
        }
    }

    LoadUnitCoordsFromFile()

    if !IsSet(ImgSession)
        ImgSession := { GuiObj: "", Dots: [], UnitIndex: 0, MaxCount: 20, LastClickTime: 0 }

    try {
        if IsSet(ImageUI) && ImageUI
            ImageUI.Destroy()
    }

    ImageUI := Gui("+AlwaysOnTop -Caption +ToolWindow", "AAImagePicker")
    ImageUIHwnd := ImageUI.Hwnd
    ImageUI.BackColor := "222222"
    ImageUI.SetFont("s10 bold", "Segoe UI")

    try {
        ImageUI.Add("Picture", "x0 y30", picPath)
    } catch as err {
        MsgBox("Lỗi load ảnh map:`n" err.Message "`nĐường dẫn: " picPath, "Lỗi", "Icon!")
        return
    }

    ImageUI.Add("Text", "x0 y8 BackgroundTrans cRed Center", "MAP: " currentMap " (" currentMode ") - UNIT " unitIndex " | Chuột Trái: Đặt điểm | Chuột Phải: Xóa điểm | Enter: Lưu | Esc: Thoát"
    )

    ImageUI.Show("x0 y0")

    ImgSession.GuiObj := ImageUI
    ImgSession.Dots := []
    ImgSession.UnitIndex := unitIndex
    ImgSession.MaxCount := 20
    ImgSession.LastClickTime := 0

    if (IsSet(UnitPlacements) && UnitPlacements.Has(unitIndex)) {
        for pt in UnitPlacements[unitIndex] {
            _ImgDrawDot(pt[1], pt[2])
        }
    }

    HotIfWinActive "ahk_id " ImageUIHwnd
    Hotkey "LButton", _ImgLeftClick, "On"
    Hotkey "RButton", _ImgRightClick, "On"
    Hotkey "Enter", _ImgSave, "On"
    Hotkey "Esc", _ImgClose, "On"
    HotIf
}

_ImgLeftClick(ThisHotkey) {
    global ImgSession
    if (A_TickCount - ImgSession.LastClickTime < 150)
        return
    ImgSession.LastClickTime := A_TickCount
    CoordMode "Mouse", "Client"
    MouseGetPos &mx, &my
    if (ImgSession.Dots.Length >= ImgSession.MaxCount) {
        ToolTip "Đã đủ số lượng điểm tối đa!"
        SetTimer () => ToolTip(), -1000
        return
    }
    _ImgDrawDot(mx, my)
}

_ImgRightClick(ThisHotkey) {
    global ImgSession, ImageUIHwnd
    if (A_TickCount - ImgSession.LastClickTime < 150)
        return
    ImgSession.LastClickTime := A_TickCount
    if (ImgSession.Dots.Length > 0) {
        lastItem := ImgSession.Dots.Pop()
        try {
            lastItem.Ctrl.Visible := false
            lastItem.Ctrl.Destroy()
        }
        DllCall("RedrawWindow", "Ptr", ImageUIHwnd, "Ptr", 0, "Ptr", 0, "UInt", 7)
    }
}

_ImgDrawDot(x, y) {
    global ImgSession
    count := ImgSession.Dots.Length + 1
    size := 26
    radius := size / 2
    dot := ImgSession.GuiObj.Add("Text", "x" (x - radius) " y" (y - radius) " w" size " h" size " BackgroundRed cWhite Center 0x200",
    count)
    Sleep(20)
    try WinSetRegion("0-0 w" size " h" size " E", dot.Hwnd)
    DllCall("RedrawWindow", "Ptr", dot.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 7)
    ImgSession.Dots.Push({ Ctrl: dot, X: x, Y: y })
}

_ImgSave(ThisHotkey) {
    global ImgSession, UnitPlacements
    if !IsSet(UnitPlacements) {
        UnitPlacements := Map()
        loop 6
            UnitPlacements[A_Index] := []
    }
    UnitPlacements[ImgSession.UnitIndex] := []
    for item in ImgSession.Dots {
        UnitPlacements[ImgSession.UnitIndex].Push([item.X, item.Y])
    }
    SaveUnitCoordsToFile()
    UpdatePosButtons()
    MsgBox("Đã lưu tọa độ Unit " ImgSession.UnitIndex " thành công!", "Thông báo", "T1")
    _ImgClose(ThisHotkey)
}

_ImgClose(ThisHotkey) {
    global ImageUI, ImageUIHwnd
    HotIfWinActive "ahk_id " ImageUIHwnd
    try Hotkey "LButton", "Off"
    try Hotkey "RButton", "Off"
    try Hotkey "Enter", "Off"
    try Hotkey "Esc", "Off"
    HotIf
    try {
        if IsSet(ImageUI) && ImageUI
            ImageUI.Destroy()
    }
}

SaveUnitCoordsToFile() {
    global UnitPlacements
    if !DirExist(A_ScriptDir "\Settings")
        DirCreate(A_ScriptDir "\Settings")

    filePath := GetSettingsFileName()
    fileContent := ""

    loop 6 {
        uIdx := A_Index
        line := uIdx "="
        if (IsSet(UnitPlacements) && UnitPlacements.Has(uIdx) && UnitPlacements[uIdx].Length > 0) {
            for i, pt in UnitPlacements[uIdx] {
                line .= pt[1] "," pt[2]
                if (i < UnitPlacements[uIdx].Length)
                    line .= "|"
            }
        }
        fileContent .= line "`n"
    }

    try {
        if FileExist(filePath)
            FileDelete(filePath)
        FileAppend(fileContent, filePath, "UTF-8")
    }
}

LoadUnitCoordsFromFile() {
    global UnitPlacements
    filePath := GetSettingsFileName()

    ; Summer rotates existing maps. Prefer an explicit Summer setup, otherwise
    ; read the old map's coordinates without copying or overwriting that file.
    if (!FileExist(filePath) && GetCurrentModeName() = "Summer Event") {
        mapName := GetCurrentMapName()
        if (mapName != "") {
            mapAliases := mapName = "Magic Hill" ? ["Magic Hill", "Magic Hills"] : [mapName]
            for oldMap in mapAliases {
                safeMap := RegExReplace(oldMap, '[\\/:*?"<>|]', "_")
                for oldMode in ["Infinite", "Story", "Legend"] {
                    candidate := A_ScriptDir "\Settings\" safeMap "_" oldMode ".txt"
                    if FileExist(candidate) {
                        filePath := candidate
                        break
                    }
                }
                if (filePath != GetSettingsFileName())
                    break
            }
        }
    }

    if !IsSet(UnitPlacements)
        UnitPlacements := Map()
    loop 6
        UnitPlacements[A_Index] := []

    if !FileExist(filePath)
        return

    try {
        content := FileRead(filePath, "UTF-8")
        loop parse, content, "`n", "`r" {
            if (A_LoopField == "")
                continue
            parts := StrSplit(A_LoopField, "=")
            if (parts.Length < 2)
                continue
            uIdx := Integer(parts[1])
            coordsStr := parts[2]
            if (coordsStr == "")
                continue

            points := StrSplit(coordsStr, "|")
            for ptStr in points {
                xy := StrSplit(ptStr, ",")
                if (xy.Length == 2)
                    UnitPlacements[uIdx].Push([Integer(xy[1]), Integer(xy[2])])
            }
        }
    }
}

UpdatePosButtons() {
    global UnitPlacements, pos1, pos2, pos3, pos4, pos5, pos6
    if !IsSet(UnitPlacements)
        return
    loop 6 {
        try {
            currBtn := %"pos" A_Index%
            if (UnitPlacements.Has(A_Index) && UnitPlacements[A_Index].Length > 0) {
                count := UnitPlacements[A_Index].Length
                currBtn.Text := "Set (" count ")"
            } else {
                currBtn.Text := "Pos " A_Index
            }
        }
    }
}
