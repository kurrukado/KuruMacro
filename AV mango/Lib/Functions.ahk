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

readInSettings() {
    global enabled1, enabled2, enabled3, enabled4, enabled5, enabled6
    global placement1, placement2, placement3, placement4, placement5, placement6
    global priority1, priority2, priority3, priority4, priority5, priority6
    global mode

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
            switch parts[1] {
                case "Mode": mode := parts[2]
                case "Enabled1": enabled1.Value := parts[2]
                case "Enabled2": enabled2.Value := parts[2]
                case "Enabled3": enabled3.Value := parts[2]
                case "Enabled4": enabled4.Value := parts[2]
                case "Enabled5": enabled5.Value := parts[2]
                case "Enabled6": enabled6.Value := parts[2]
                case "Placement1": placement1.Text := parts[2]
                case "Placement2": placement2.Text := parts[2]
                case "Placement3": placement3.Text := parts[2]
                case "Placement4": placement4.Text := parts[2]
                case "Placement5": placement5.Text := parts[2]
                case "Placement6": placement6.Text := parts[2]
                case "Priority1": priority1.Text := parts[2]
                case "Priority2": priority2.Text := parts[2]
                case "Priority3": priority3.Text := parts[2]
                case "Priority4": priority4.Text := parts[2]
                case "Priority5": priority5.Text := parts[2]
                case "Priority6": priority6.Text := parts[2]
            }
        }
        ProcessLog("Configuration settings loaded successfully")
    }
}


SaveSettings(*) {
    global enabled1, enabled2, enabled3, enabled4, enabled5, enabled6
    global placement1, placement2, placement3, placement4, placement5, placement6
    global priority1, priority2, priority3, priority4, priority5, priority6
    global mode

    try {
        settingsFile := A_ScriptDir "\Settings\Configuration.txt"
        if FileExist(settingsFile) {
            FileDelete(settingsFile)
        }

        ; Save mode and map selection
        if (mode = "Infinite") {
            content .= "Map=" ModeDropdown.Text
        }
        ; Save settings for each unit
        content .= "`n`nEnabled1=" enabled1.Value
        content .= "`nEnabled2=" enabled2.Value
        content .= "`nEnabled3=" enabled3.Value
        content .= "`nEnabled4=" enabled4.Value
        content .= "`nEnabled5=" enabled5.Value
        content .= "`nEnabled6=" enabled6.Value

        content .= "`n`nPlacement1=" placement1.Text
        content .= "`nPlacement2=" placement2.Text
        content .= "`nPlacement3=" placement3.Text
        content .= "`nPlacement4=" placement4.Text
        content .= "`nPlacement5=" placement5.Text
        content .= "`nPlacement6=" placement6.Text

        content .= "`nPriority1=" priority1.Text
        content .= "`nPriority2=" priority2.Text
        content .= "`nPriority3=" priority3.Text
        content .= "`nPriority4=" priority4.Text
        content .= "`nPriority5=" priority5.Text
        content .= "`nPriority6=" priority6.Text
        
        FileAppend(content, settingsFile)
        ProcessLog("Configuration settings saved successfully")
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

CheckBanner(unitName) {

    ; First check if Roblox window exists
    if !WinExist(rblxID) {
        ProcessLog("Roblox window not found - skipping banner check")
        return false
    }

    ; Get Roblox window position
    WinGetPos(&robloxX, &robloxY, &rblxW, &rblxH, rblxID)
    
    detectionCount := 0
    ProcessLog("Checking for: " unitName)

    ; Split unit name into individual words
    unitName := Trim(unitName)  ; Remove spaces
    unitWords := StrSplit(unitName, " ")

    Loop 5 {
        try {
            result := OCR.FromRect(robloxX + 280, robloxY + 293, 250, 55, "en",
                {   
                    grayscale: true,
                    scale: 2.0
                })
            
            ; Check if all words are found in the text
            allWordsFound := true
            for word in unitWords {
                if !InStr(result.Text, word) {
                    allWordsFound := false
                    break
                }
            }
            
            if (allWordsFound) {
                detectionCount++
                Sleep(100)
            }
        }
    }

    if (detectionCount >= 1) {
        ProcessLog("Found " unitName " in banner")
        try {
            BannerFound()
        }
        return true
    }

    ProcessLog("Did not find " unitName " in banner")
    return false
}

SaveBannerSettings(*) {
    ProcessLog("Saving Banner Unit Name")
    
    if FileExist("Settings\BannerUnit.txt")
        FileDelete("Settings\BannerUnit.txt")
    
    FileAppend(BannerUnitBox.Value, "Settings\BannerUnit.txt", "UTF-8")
}

SavePsSettings(*) {
    ProcessLog("Saving Private Server Link")
    
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
 minimizeUI(*){
    aaMainUI.Minimize()
 }
 
 Destroy(*){
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

    ReturnLobbyBox.Visible := false
    
    if (selected = "Infinite") {
        ; change nothing, solo better than find matching
        mode := "Infinite"
    }
}

OnConfirmClick(*) {
    if (ModeDropdown.Text = "") {
        ProcessLog("Please select a gamemode before confirming")
        return
    }
    if (ModeDropdown.Text = "Infinite") {
        ProcessLog("Selected " ModeDropdown.Text " mode")
    }

    ; Hide all controls if validation passes
    ModeDropdown.Visible := false
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
    MouseClick(LR, -1, 0, , , , "R")
    Sleep(50)
}
 
CaptchaDetect(x, y, w, h, inputX, inputY) {
    detectionCount := 0
    ProcessLog("Checking for numbers...")
    Loop 10 {
        try {
            result := OCR.FromRect(x, y, w, h, "FirstFromAvailableLanguages", 
                {   
                    grayscale: true,
                    scale: 2.0
                })
            
            if result {
                ; Get text before any linebreak
                number := StrSplit(result.Text, "`n")[1]
                
                ; Clean to just get numbers
                number := RegExReplace(number, "[^\d]")
                
                if (StrLen(number) >= 5 && StrLen(number) <= 7) {
                    detectionCount++
                    
                    if (detectionCount >= 2) {
                        ; Send exactly what we detected in the green text
                        FixClick(inputX, inputY)
                        Sleep(300)
                        
                        ProcessLog("Sending number: " number)
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
    global PriorityUpgrade, priority1, priority2, priority3, priority4, priority5, priority6
    shouldShow := PriorityUpgrade.Value

    priority1.Visible := shouldShow
    priority2.Visible := shouldShow
    priority3.Visible := shouldShow
    priority4.Visible := shouldShow
    priority5.Visible := shouldShow
    priority6.Visible := shouldShow

    for unit in UnitData {
        unit.PriorityText.Visible := shouldShow
    }
}

SaveKeybindSettings(*) {
    ProcessLog("Saving Keybind Configuration")
    
    if FileExist("Settings\Keybinds.txt")
        FileDelete("Settings\Keybinds.txt")
        
    FileAppend(Format("F1={}`nF2={}`nF3={}`nF4={}", F1Box.Value, F2Box.Value, F3Box.Value, F4Box.Value, F5Box.Value), "Settings\Keybinds.txt", "UTF-8")
    
    ; Update globals
    global F1Key := F1Box.Value
    global F2Key := F2Box.Value
    global F3Key := F3Box.Value
    global F4Key := F4Box.Value
    global F5Key := F5Box.Value
    
    ; Update hotkeys
    Hotkey(F1Key, (*) => moveRobloxWindow())
    Hotkey(F2Key, (*) => StartMacro())
    Hotkey(F3Key, (*) => Reload())
    Hotkey(F4Key, (*) => TogglePause())
    Hotkey(F5Key, (*) => Test())
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
            else if (parts[1] = "F5")
                global F5Key := parts[2]
        }
    }
}

; Dedicated save function for card priorities
SaveCardPriorities(*) {
    global settingsPri1, settingsPri2, settingsPri3, settingsPri4
    
    ProcessLog("Saving card priorities...")
    
    ; Save values directly to file
    if FileExist("Settings\CardPriorities.txt")
        FileDelete("Settings\CardPriorities.txt")
    
    ; Get values from settings GUI
    pri1Value := settingsPri1.Text
    pri2Value := settingsPri2.Text
    pri3Value := settingsPri3.Text
    pri4Value := settingsPri4.Text
    
    ; Write to file
    FileAppend(pri1Value . "`n" . 
              pri2Value . "`n" . 
              pri3Value . "`n" . 
              pri4Value, "Settings\CardPriorities.txt", "UTF-8")
    
    ProcessLog("Card priorities saved: " . pri1Value . ", " . 
              pri2Value . ", " . 
              pri3Value . ", " . 
              pri4Value)
    
    Processlog("Card priorities saved successfully!")
}

; Function to load card settings
LoadCardPriorities() {
    global CardPriority1, CardPriority2, CardPriority3, CardPriority4
    
    if FileExist("Settings\CardPriorities.txt") {
        fileContent := FileRead("Settings\CardPriorities.txt", "UTF-8")
        lines := StrSplit(fileContent, "`n")
        
        if (lines.Length >= 1 && lines[1] != "")
            CardPriority1.Text := lines[1]
        if (lines.Length >= 2 && lines[2] != "")
            CardPriority2.Text := lines[2]
        if (lines.Length >= 3 && lines[3] != "")
            CardPriority3.Text := lines[3]
        if (lines.Length >= 4 && lines[4] != "")
            CardPriority4.Text := lines[4]
        
        ProcessLog("Card priorities loaded from settings")
    }
}

; Helper function to get dropdown index for a value
GetIndexForValue(dropDown, value) {
    try {
        loop dropDown.Items.Length {
            if (dropDown.Items[A_Index] = value)
                return A_Index
        }
    } catch {
        ; If we can't get items, return 1
    }
    
    ; Default to 1 if not found
    return 1
}

; Helper function to select dropdown item by text
ChooseDropdownItemByText(dropDown, text) {
    items := dropDown.GetCount()
    Loop items {
        if (dropDown.GetText(A_Index) = text) {
            dropDown.Choose(A_Index)
            return true
        }
    }
    return false
}