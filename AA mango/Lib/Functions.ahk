#Warn VarUnset, Off
#Warn All, Off

if (A_ScriptFullPath = A_LineFile) {
    mainScript := A_ScriptDir "\..\Main.ahk"
    if FileExist(mainScript) {
        Run('"' A_AhkPath '" "' mainScript '"')
        ExitApp()
    }
}

global confirmClicked := false

GetModeSettingsPath(modeName) {
    if (modeName = "")
        return A_ScriptDir "\Settings\Configuration.txt"
    safeMode := RegExReplace(modeName, '[\\/:*?"<>|]', "_")
    return A_ScriptDir "\Settings\Config_" . safeMode . ".txt"
}

setupFilePath() {
    if !DirExist(A_ScriptDir "\Settings")
        DirCreate(A_ScriptDir "\Settings")
    return GetModeSettingsPath("")
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
    if (value = "" || value = "0" || value = "OFF" || value = "MAX")
        return "MAX"
    if RegExMatch(value, "^(?:[1-9]|10)$")
        return Integer(value) ""
    return "MAX"
}

GetUnitUpgradeLimit(slot) {
    global UnitData
    if (slot < 1 || slot > UnitData.Length)
        return "MAX"
    return NormalizeUnitMaxLevel(UnitData[slot].MaxLevel.Text)
}

readInSettings(modeName := "") {
    global mode, ModeDropdown, UnitData, macroRunning, SaveChestsForBoss
    if IsSet(macroRunning) && macroRunning
        return false

    try {
        options := ReadSettingsValues(setupFilePath())
        if modeName = "" {
            if !ChooseDropdownItemByText(ModeDropdown, options.Get("Mode", "Infinite"))
                ModeDropdown.Choose(1)
            modeName := ModeDropdown.Text
        }
        mode := modeName
        if options.Get("Mode", modeName) != modeName {
            for key in ["Map", "Act", "Difficulty"]
                if options.Has(key)
                    options.Delete(key)
        }
        for key, value in ReadSettingsValues(GetModeSettingsPath(modeName))
            options[key] := value

        mapControl := ModeMapControl(modeName)
        if IsObject(mapControl) {
            mapName := options.Get("Map", modeName = "Infinite" ? WorldMapNames("main")[1] : "")
            if modeName = "Infinite" || modeName = "Story" || modeName = "Legend" {
                entry := WorldCardEntry(mapName, modeName = "Legend" ? "legend" : "main")
                mapName := IsObject(entry) ? entry["name"] : ""
            }
            if !ChooseDropdownItemByText(mapControl, mapName)
                mapControl.Choose(0)
        }
        if modeName = "Legend"
            OnLegendChange()
        actControl := ModeActControl(modeName)
        if IsObject(actControl) && !ChooseDropdownItemByText(actControl, options.Get("Act", ""))
            actControl.Choose(0)
        if modeName = "Infinity Castle" && !ChooseDropdownItemByText(InfinityCastleDropdown, options.Get("Difficulty", ""))
            InfinityCastleDropdown.Choose(0)

        ChooseDropdownItemByText(PlacementPatternDropdown, options.Get("PlacementPattern", "Capys"))
        MatchMaking.Value := options.Get("Matchmaking", "0") = "1"
        ReturnLobbyBox.Value := options.Get("ReturnToLobby", "0") = "1"
        NextLevelBox.Value := options.Get("NextLevel", "1") = "1"
        NextRoomBox.Value := options.Get("NextRoom", "1") = "1"
        ReplayBox.Value := options.Get("Replay", "1") = "1"
        AutoAbilityBox.Value := options.Get("AutoAbility", "1") = "1"
        PriorityUpgrade.Value := options.Get("PriorityUpgrade", "0") = "1"
        SaveChestsBox.Value := options.Get("SaveChestsForBoss", "1") = "1"
        SaveChestsForBoss := !!SaveChestsBox.Value
        for index, unit in UnitData {
            enabledName := "enabled" index
            countName := "placement" index
            priorityName := "priority" index
            %enabledName%.Value := options.Get("Enabled" index, "0") = "1"
            if !ChooseDropdownItemByText(%countName%, options.Get("Placement" index, "1"))
                %countName%.Choose(1)
            if !ChooseDropdownItemByText(%priorityName%, options.Get("Priority" index, index ""))
                %priorityName%.Choose(index)
            try unit.Type.Choose(NormalizeUnitType(options.Get("UnitType" index, "Ground")))
            catch
                unit.Type.Choose("Ground")
            ChooseDropdownItemByText(unit.MaxLevel, NormalizeUnitMaxLevel(options.Get("MaxLevel" index, "MAX")))
        }
        return true
    } catch {
        ProcessLog("Không đọc được cấu hình", true)
        return false
    }
}

ReadSettingsValues(path) {
    values := Map()
    values.CaseSense := "Off"
    if FileExist(path) {
        for line in StrSplit(FileRead(path, "UTF-8"), "`n", "`r") {
            parts := StrSplit(line, "=", , 2)
            if parts.Length = 2
                values[Trim(parts[1])] := Trim(parts[2])
        }
    }
    return values
}

ModeMapControl(modeName) {
    switch modeName {
        case "Infinite": return MapDropdown
        case "Story": return StoryDropdown
        case "Legend": return LegendDropDown
        case "Raid": return RaidDropdown
        case "Portal": return PortalDropdown
    }
    return 0
}

ModeActControl(modeName) {
    switch modeName {
        case "Story": return StoryActDropdown
        case "Legend": return LegendActDropdown
        case "Raid": return RaidActDropdown
    }
    return 0
}

SaveSettings(*) {
    try {
        currMode := ModeDropdown.Text
        if currMode = ""
            return false
        mapControl := ModeMapControl(currMode)
        actControl := ModeActControl(currMode)
        content := "Mode=" currMode "`n"
        content .= "Map=" (IsObject(mapControl) ? mapControl.Text : GetCurrentMapName())
        if IsObject(actControl)
            content .= "`nAct=" actControl.Text
        if currMode = "Infinity Castle"
            content .= "`nDifficulty=" InfinityCastleDropdown.Text
        content .= "`nPlacementPattern=" PlacementPatternDropdown.Text
        content .= "`nMatchmaking=" MatchMaking.Value
        content .= "`nReturnToLobby=" ReturnLobbyBox.Value
        content .= "`nNextLevel=" NextLevelBox.Value
        content .= "`nNextRoom=" NextRoomBox.Value
        content .= "`nReplay=" ReplayBox.Value
        content .= "`nAutoAbility=" AutoAbilityBox.Value
        content .= "`nPriorityUpgrade=" PriorityUpgrade.Value
        content .= "`nSaveChestsForBoss=" SaveChestsBox.Value

        for index, unit in UnitData {
            enabledName := "enabled" index
            countName := "placement" index
            priorityName := "priority" index
            posName := "pos" index
            try unitType := NormalizeUnitType(unit.Type.Text)
            catch as err {
                ProcessLog("Unit " index ": " err.Message, true)
                unit.Type.Focus()
                return false
            }
            content .= "`n`nEnabled" index "=" %enabledName%.Value
            content .= "`nPlacement" index "=" %countName%.Text
            content .= "`nPriority" index "=" %priorityName%.Text
            content .= "`nPos" index "=" %posName%.Text
            content .= "`nMaxLevel" index "=" NormalizeUnitMaxLevel(unit.MaxLevel.Text)
            content .= "`nUnitType" index "=" unitType
        }

        settingsFile := setupFilePath()
        modeFile := GetModeSettingsPath(currMode)
        WriteSettingsFiles([[modeFile, content], [settingsFile, content]])
    } catch {
        ProcessLog("Không lưu được cấu hình", true)
        return false
    }
    ProcessLog("Cấu hình đã lưu cho: " currMode, true)
    return true
}

WriteSettingsFiles(documents, encoding := "UTF-8-RAW") {
    previousCritical := A_IsCritical
    Critical("On")
    written := []
    try {
        for document in documents {
            path := document[1]
            previous := FileExist(path) ? FileRead(path, "RAW") : 0
            ReplaceSettingsFile(path, document[2], encoding)
            written.Push([path, previous])
        }
    } catch {
        while written.Length {
            document := written.Pop()
            if IsObject(document[2]) {
                try ReplaceSettingsFile(document[1], document[2])
            } else {
                try FileDelete(document[1])
            }
        }
        throw
    } finally {
        Critical(previousCritical)
    }
}

ReplaceSettingsFile(path, content, encoding := "UTF-8-RAW") {
    temp := path "." DllCall("GetCurrentProcessId", "UInt") ".tmp"
    try {
        if FileExist(temp)
            FileDelete(temp)
        FileAppend(content, temp, encoding)
        FileMove(temp, path, 1)
    } finally {
        if FileExist(temp)
            try FileDelete(temp)
    }
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
    global mode, confirmClicked, macroRunning
    if IsSet(macroRunning) && macroRunning {
        ChooseDropdownItemByText(ModeDropdown, mode)
        return
    }
    confirmClicked := false
    selected := ModeDropdown.Text
    mode := selected
    readInSettings(selected)
    RefreshModeOptions(selected)
    LayoutUnitColumns()
    OnMapChange()
}

RefreshModeOptions(selected) {
    for name in ["Infinite", "Story", "Portal", "Legend", "Raid"] {
        mapControl := ModeMapControl(name)
        mapControl.Visible := selected = name
        actControl := ModeActControl(name)
        if IsObject(actControl)
            actControl.Visible := selected = name && mapControl.Text != ""
    }
    InfinityCastleDropdown.Visible := selected = "Infinity Castle"
    SaveChestsBox.Visible := selected = "Dungeon"
    UpdateResultOptionsForMode(selected)
}

OnStoryChange(*) {
    StoryActDropdown.Visible := StoryDropdown.Text != ""
}

OnLegendChange(*) {
    entry := WorldCardEntry(LegendDropDown.Text,"legend")
    selectedAct := LegendActDropdown.Value
    LegendActDropdown.Delete()
    LegendActDropdown.Visible := IsObject(entry)
    if !IsObject(entry)
        return
    acts := []
    Loop entry["acts"]
        acts.Push("Act " A_Index)
    LegendActDropdown.Add(acts)
    if selectedAct <= acts.Length
        LegendActDropdown.Choose(selectedAct)
}

OnRaidChange(*) {
    RaidActDropdown.Visible := RaidDropdown.Text != ""
}

OnConfirmClick(*) {
    ConfirmModeSelection(true)
}

ConfirmModeSelection(hideSelection := true) {
    global confirmClicked, mode, macroRunning
    if IsSet(macroRunning) && macroRunning
        return false
    selected := ModeDropdown.Text
    mapControl := ModeMapControl(selected)
    actControl := ModeActControl(selected)
    if selected = "" || (IsObject(mapControl) && mapControl.Text = "") || (IsObject(actControl) && actControl.Text = "")
        || (selected = "Infinity Castle" && InfinityCastleDropdown.Text = "") {
        ProcessLog("Chọn đủ chế độ, bản đồ và stage trước khi xác nhận", true)
        return false
    }

    UpdateResultOptionsForMode(selected)
    if !hideSelection
        return true
    if !SaveSettings()
        return false
    mode := selected
    confirmClicked := true
    for control in [ModeDropdown, MapDropdown, StoryDropdown, StoryActDropdown, PortalDropdown, LegendDropDown,
        LegendActDropdown, RaidDropdown, RaidActDropdown, InfinityCastleDropdown, ConfirmButton, modeSelectionGroup] {
        control.Visible := false
    }
    Hotkeytext.Visible := true
    Hotkeytext2.Visible := true
    return true
}

UpdateResultOptionsForMode(selectedMode) {
    global NextLevelBox, NextRoomBox, ReplayBox, ReturnLobbyBox, MatchMaking
    mansion := selectedMode = "Infinity Mansion"
    misty := selectedMode = "Misty Village" || selectedMode = "Misty Infinite"
    storyInfinity := selectedMode = "Story" && StoryActDropdown.Text = "Infinity"
    hasNextLevel := misty || (selectedMode = "Story" && !storyInfinity)
    fixedResult := selectedMode = "Farm" || selectedMode = "Portal" || selectedMode = "Daily Infinite Quest"
        || selectedMode = "Cursed Womb" || storyInfinity
    canMatchmake := ModeAllowsMatchmaking(selectedMode)
    canChooseLobby := !fixedResult && !(canMatchmake && MatchMaking.Value)
    canReplay := canChooseLobby && !ReturnLobbyBox.Value
    MatchMaking.Enabled := canMatchmake
    MatchMaking.Visible := canMatchmake
    ReturnLobbyBox.Enabled := canChooseLobby
    ReplayBox.Enabled := canReplay
    NextLevelBox.Text := misty ? "Next Floor" : "Next Level"
    NextLevelBox.Visible := hasNextLevel
    NextLevelBox.Enabled := canReplay && hasNextLevel
    NextRoomBox.Visible := mansion
    NextRoomBox.Enabled := canReplay && mansion
}

ModeAllowsMatchmaking(selectedMode) {
    switch selectedMode {
        case "Infinity Mansion", "Portal", "Farm", "Cursed Womb": return false
        case "Story": return StoryActDropdown.Text = "Infinity"
        default: return true
    }
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

                if (StrLen(number) >= 5 && StrLen(number) <= 9) {
                    detectionCount++

                    if (detectionCount >= 1) {
                        ; 1. Chuẩn bị ô nhập (Focus & Clear)
                        FixClick(inputX, inputY)
                        Sleep(250)
                        Send("^a{Backspace}")
                        Sleep(150)

                        ; 2. Gõ mã số (Send digits)
                        for digit in StrSplit(number) {
                            SendText(digit)
                            Sleep(80)
                        }
                        Sleep(250)
                        ProcessLog("Verification code entered")

                        ; 3. Bấm Submit tại (300, 385)
                        ProcessLog("Submitting verification code at (300, 385)...")
                        FixClick(300, 385)
                        Sleep(600)

                        ; 4. Kiểm tra kết quả sau khi bấm Submit
                        errCheck := ""
                        try errCheck := OCR.FromRect(100, 440, 600, 70, "FirstFromAvailableLanguages").Text
                        if (errCheck = "")
                            try errCheck := ReadHighContrastText(100, 440, 600, 70, 2, 0, false)

                        if InStr(StrLower(RegExReplace(errCheck, "[^A-Za-z]", "")), "incorrect") {
                            ProcessLog("Verification code incorrect; clearing and retrying...")
                            FixClick(inputX, inputY)
                            Sleep(200)
                            Send("^a{Backspace}")
                            Sleep(200)
                            continue
                        }

                        ProcessLog("Verification code confirmed successfully")
                        return true
                    }
                }
            }
        }
        Sleep(200)
    }

    ; 5. Fallback khi timeout/thất bại: đóng dialog tại (585, 190)
    try FixClick(585, 190)
    ProcessLog("Could not detect valid captcha")
    return false
}


TogglePriorityDropdowns(*) {
    LayoutUnitColumns()
}

LoadKeybindSettings() {
    try {
        values := ReadSettingsValues(A_ScriptDir "\Settings\Keybinds.txt")
        if values.Count
            ApplyKeybindSettings([values.Get("F1", "F1"), values.Get("F2", "F2"),
                values.Get("F3", "F3"), values.Get("F4", "F4")])
    } catch {
        ProcessLog("Không đọc được cấu hình phím tắt", true)
    }
    UpdateKeybindText()
}

SaveKeybindSettings(*) {
    keys := [Trim(F1Box.Value), Trim(F2Box.Value), Trim(F3Box.Value), Trim(F4Box.Value)]
    try {
        ApplyKeybindSettings(keys, true)
        UpdateKeybindText()
        ProcessLog("Đã lưu phím tắt", true)
    } catch {
        ProcessLog("Không lưu được phím tắt. Kiểm tra phím trống, trùng hoặc không hợp lệ.", true)
    }
}

ApplyKeybindSettings(keys, save := false) {
    global F1Key, F2Key, F3Key, F4Key
    static actions := [(*) => moveRobloxWindow(), (*) => StartMacro(), (*) => Reload(), (*) => TogglePause()]
    selected := Map()
    selected.CaseSense := "Off"
    oldKeys := [F1Key, F2Key, F3Key, F4Key]
    for key in keys {
        if key = "" || selected.Has(key)
            throw ValueError("Invalid or duplicate hotkey")
        selected[key] := true
    }

    previousCritical := A_IsCritical
    Critical("On")
    registered := []
    try {
        for index, key in keys {
            Hotkey(key, actions[index], "On")
            registered.Push(key)
        }
        if save
            ReplaceSettingsFile(A_ScriptDir "\Settings\Keybinds.txt",
                Format("F1={}`nF2={}`nF3={}`nF4={}", keys*), "UTF-8")
        for key in oldKeys
            if !selected.Has(key)
                try Hotkey(key, "Off")
        F1Key := keys[1], F2Key := keys[2], F3Key := keys[3], F4Key := keys[4]
    } catch {
        for key in registered
            try Hotkey(key, "Off")
        for index, key in oldKeys
            Hotkey(key, actions[index], "On")
        throw
    } finally {
        Critical(previousCritical)
    }
}

UpdateKeybindText() {
    Hotkeytext2.Text := F1Key ": Chỉnh cửa sổ || " F2Key ": Bắt đầu || " F3Key ": Thoát || " F4Key ": Dừng/Tiếp tục"
}

ToggleSaveChestsForBoss(*) {
    global SaveChestsForBoss
    SaveChestsForBoss := !!SaveChestsBox.Value
    ProcessLog("Save chests for boss room: " (SaveChestsForBoss ? "Enabled" : "Disabled"), true)
}

; ==============================================================================
; BIẾN TOÀN CỤC & TÍNH NĂNG ĐẶT UNIT DỰA TRÊN ẢNH MAP
; ==============================================================================
global ImgSession := { GuiObj: "", Dots: [], UnitIndex: 0, MaxCount: 20, LastClickTime: 0 }

GetCurrentMapName() {
    global SummerMapName, MansionMapName
    global DailyQuestMap
    selected := GetCurrentModeName()
    switch selected {
        case "Daily Infinite Quest":
            if IsSet(DailyQuestMap) && DailyQuestMap != ""
                return DailyQuestMap
        case "Farm": return WorldMapNames("main")[1]
        case "Infinity Mansion": return IsSet(MansionMapName) ? MansionMapName : ""
        case "Summer Event": return IsSet(SummerMapName) ? SummerMapName : ""
        case "Misty Village", "Misty Infinite": return "Misty Village"
        case "Artifacts", "Cursed Womb": return selected
    }
    mapControl := ModeMapControl(selected)
    if IsObject(mapControl)
        return mapControl.Text
    if (IsSet(MapDropdown) && MapDropdown.Text != "")
        return MapDropdown.Text
    return "Planet Greenie"
}

GetCurrentModeName() {
    global ModeDropdown
    if (IsSet(ModeDropdown) && ModeDropdown.Text != "")
        return ModeDropdown.Text
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

    if !FileExist(filePath) && GetCurrentModeName() = "Daily Infinite Quest" && IsSet(DailyQuestMap) && DailyQuestMap != "" {
        for sourceMode in ["Infinite","Story"] {
            candidate := A_ScriptDir "\Settings\" DailyQuestMap "_" sourceMode ".txt"
            if FileExist(candidate) {
                filePath := candidate
                break
            }
        }
    }

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

    ; Misty Infinite shares the same map and coordinates as Misty Village.
    if (!FileExist(filePath) && GetCurrentModeName() = "Misty Infinite") {
        candidate := A_ScriptDir "\Settings\Misty Village_Misty Village.txt"
        if FileExist(candidate)
            filePath := candidate
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
