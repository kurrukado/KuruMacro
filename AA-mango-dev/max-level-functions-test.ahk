NormalizeUnitMaxLevel(value) {
    value := StrUpper(Trim(value, " `t`r`n"))
    ; Migrate the previous text-box defaults without enabling a cap.
    if (value = "OFF" || value = "MAX" || value = "" || value = "0")
        return "OFF"
    if RegExMatch(value, "^(?:[1-9]|1\d|20)$")
        return Integer(value) ""
    throw ValueError("Max Level: chon OFF hoac muc tu 1 den 20")
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
    global mode, UnitData, MatchMaking

    try {
        settingsFile := setupFilePath()
        if !FileExist(settingsFile) {
            return
        }

        content := FileRead(settingsFile)
        if (RegExMatch(content, "m)^Mode=Summer Event\s*$") && !RegExMatch(content, "m)^Matchmaking="))
            MatchMaking.Value := 1
        lines := StrSplit(content, "`n")

        for line in lines {
            if line = "" {
                continue
            }

            parts := StrSplit(line, "=")
            if RegExMatch(parts[1], "^MaxLevel([1-6])$", &maxSlot) {
                try UnitData[Integer(maxSlot[1])].MaxLevel.Text := NormalizeUnitMaxLevel(parts[2])
                continue
            }
            switch parts[1] {
                case "Mode":
                    mode := parts[2]
                    try ChooseDropdownItemByText(ModeDropdown, mode)
                case "Matchmaking":
                    try MatchMaking.Value := Trim(parts[2], " `t`r`n") = "1"
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
    global mode, UnitData, MatchMaking

    ; Validate all six values before replacing the existing configuration.
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

        FileAppend(content, settingsFile)
        ProcessLog("Configuration setting are saved")
    }
}

setupFilePath() {
    global settingsFile

    if !DirExist(A_ScriptDir "\Settings") {
        DirCreate(A_ScriptDir "\Settings")
    }

    settingsFile := A_ScriptDir "\Settings\Configuration.txt"
    return settingsFile
}

ChooseDropdownItemByText(dropDown, text) {
    if !IsSet(dropDown) || !IsObject(dropDown)
        return false
    try {
        items := dropDown.GetCount()
        loop items {
            if (dropDown.GetText(A_Index) = text) {
                dropDown.Choose(A_Index)
                return true
            }
        }
    }
    return false
}
