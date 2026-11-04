global settingsFile := ""
global confirmClicked := false

setupFilePath() {
    global settingsFile

    if !DirExist(A_ScriptDir "\Settings") {
        DirCreate(A_ScriptDir "\Settings")
    }

    settingsFile := A_ScriptDir "\Settings\Configuration.txt"
    return settingsFile
}

; SaveUINavSettings(*) {
;     ProcessLog("Saving UI Navigation Key")

;     if FileExist("Settings\UINavigation.txt")
;         FileDelete("Settings\UINavigation.txt")

;     FileAppend(UINavBox.Value, "Settings\UINavigation.txt", "UTF-8")
; }

;Opens discord Link
OpenDiscordLink() {
    Run("")
}

;Minimizes the UI
minimizeUI(*) {
    arMainUI.Minimize()
}

Destroy(*) {
    arMainUI.Destroy()
    ExitApp
}
;Login Text
setupOutputFile() {
    content := "`n==" arTitle "" version "==`n  Start Time: [" currentTime "]`n"
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
    StoryDropdown.Visible := false
    StoryActDropdown.Visible := false
    RangerDropdown.Visible := false
    RangerActDropdown.Visible := false
    RaidDropdown.Visible := false
    RaidActDropdown.Visible := false
    DungeonDropdown.Visible := false
    PortalDropdown.Visible := false
    Difficult.Visible := false

    if (selected = "Story") {
        mode := "Story"
        StoryDropdown.Visible := true
        StoryActDropdown.Visible := true
        Difficult.Visible := true
    } else if (selected = "Challenge") {
        mode := "Challenge"
    } else if (selected = "Ranger") {
        mode := "Ranger"
        RangerDropdown.Visible := true
        RangerActDropdown.Visible := true
    } else if (selected = "Raid") {
        mode := "Raid"
        RaidDropdown.Visible := true
        RaidActDropdown.Visible := true
    } else if (selected = "Summer Event") {
        mode := "Summer"
    } else if (selected = "Dungeon") {
        mode := "Dungeon"
        DungeonDropdown.Visible := true
    } else if (selected = "Portal") {
        mode := "Portal"
        PortalDropdown.Visible := true
    }
}

OnConfirmClick(*) {
    selected := ModeDropdown.Text
    if (selected = "") {
        ProcessLog("Choose mode before you press confirm!")
        return
    } 
    if (selected == "Story" && (StoryDropdown.Text == "" || StoryActDropdown.Text == "")) {
        ProcessLog("Select your map/act before confirm!")
        return
    }
    if (selected == "Ranger" && (RangerDropdown.Text == "" || RangerActDropdown.Text == "")) {
        ProcessLog("Select your map/act before confirm!")
        return
    }
    if (selected == "Raid" && (RaidDropdown.Text == "" || RaidActDropdown.Text == "")) {
        ProcessLog("Select your map/act before confirm!")
        return
    }
    
    if (selected == "Story" && (Difficult.Text = "")) {
        Difficult.Text := "Normal"
    }

    if (selected == "Story") {
        ProcessLog("Selected " selected " - " StoryDropdown.Text " - " StoryActDropdown.Text " - " Difficult.Text)
    } else if (selected == "Ranger") {
        ProcessLog("Selected " selected " - " RangerDropdown.Text " - " RangerActDropdown.Text)
    } else if (selected == "Raid") {
        ProcessLog("Selected " selected " - " RaidDropdown.Text " - " RaidActDropdown.Text)
    } else if (selected == "Dungeon") {
        ProcessLog("Selected " selected " - " DungeonDropdown.Text)
    } else if (selected == "Portal") {
        ProcessLog("Selected " selected " - " PortalDropdown.Text)
    }
    ; Hide all controls if validation passes
    ModeDropdown.Visible := false
    StoryDropdown.Visible := false
    StoryActDropdown.Visible := false
    RangerDropdown.Visible := false
    RangerActDropdown.Visible := false
    RaidDropdown.Visible := false
    RaidActDropdown.Visible := false
    DungeonDropdown.Visible := false
    PortalDropdown.Visible := false
    Difficult.Visible := false
    ConfirmButton.Visible := false
    modeSelectionGroup.Visible := false
    Hotkeytext.Visible := true
    Hotkeytext2.Visible := true
    global confirmClicked := true
}

FixClick(x, y, LR := "Left") {
    CoordMode "Mouse", "Screen"
    CoordMode "Pixel", "Screen"
    MouseMove(x, y)
    MouseMove(1, 0, 30, "R")
    MouseClick(LR, -1, 0, , 10, , "R")
    Sleep(50)
}

SaveKeybindSettings(*) {
    ProcessLog("Saving Keybind Configuration")

    if FileExist("Settings\Keybinds.txt")
        FileDelete("Settings\Keybinds.txt")

    FileAppend(Format("F1={}`nF2={}`nF3={}`nF4={}", F1Box.Value, F2Box.Value, F3Box.Value, F4Box.Value), "Settings\Keybinds.txt", "UTF-8")

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
        Loop Parse, fileContent, "`n" {
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
