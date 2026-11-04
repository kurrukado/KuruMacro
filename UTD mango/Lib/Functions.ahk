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
    global pos1, pos2, pos3, pos4, pos5, pos6
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
                case "pos1" : pos1.Text := parts[2]
                case "pos2" : pos2.Text := parts[2]
                case "pos3" : pos3.Text := parts[2]
                case "pos4" : pos4.Text := parts[2]
                case "pos5" : pos5.Text := parts[2]
                case "pos6" : pos6.Text := parts[2]
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
        } else if (mode = "Winter") {
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

        content .= "`nPos1=" pos1.Text
        content .= "`nPos2=" pos2.Text
        content .= "`nPos3=" pos3.Text
        content .= "`nPos4=" pos4.Text
        content .= "`nPos5=" pos5.Text
        content .= "`nPos6=" pos6.Text
        
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
    UTDMainUI.Minimize()
 }
 
 Destroy(*){
    UTDMainUI.Destroy()
    ExitApp
 }
 ;Login Text
 setupOutputFile() {
     content := "`n==" UTDTitle "" version "==`n  Start Time: [" currentTime "]`n"
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
    ActDropdown.Visible := false
    MapDropdown.Visible := false
    DifficultDropdown.Visible := false
    
    ; Hide all dropdowns first

    ReturnLobbyBox.Visible := false
    
    if (selected = "Infinite") {
        ; change nothing, solo better than find matching
        mode := "Infinite"
        MapDropdown.Visible := true
        DifficultDropdown.Visible := true
    } else if (selected = "Challenge") {
        mode := "Challenge"
        ActDropdown.Visible := true
        MapDropdown.Visible := true
        DifficultDropdown.Visible := true
    } else if (selected == "Winter") {
        mode := "Winter"
    }
}

OnConfirmClick(*) {
    if (ModeDropdown.Text == "") {
        ProcessLog("Please select a gamemode before confirming")
        return
    }
    if (ModeDropdown.Text == "Infinite") {
        ProcessLog("Selected " ModeDropdown.Text " mode")
    } else if (ModeDropdown.Text == "Winter") {
        ProcessLog("Selected " ModeDropdown.Text " mode")
    }

    ; Hide all controls if validation passes
    ModeDropdown.Visible := false
    MapDropdown.Visible := false
    ActDropdown.Visible := false
    DifficultDropdown.Visible := false
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

; ==============================================================================
; BIẾN TOÀN CỤC
; ==============================================================================
Global ImgSession := {GuiObj: "", Dots: [], UnitIndex: 0, MaxCount: 0, LastClickTime: 0}

; ==============================================================================
; HÀM LOAD IMAGE & PICKER (TỰ ĐỘNG THEO MAP)
; ==============================================================================
LoadImage(unitIndex) { ; <--- Không cần truyền path ảnh nữa, tự tìm
    global uiBorders, uiBackgrounds, uiTheme, UnitData, lastlog
    global ImageUI, ImageUIHwnd
    global ImgSession, UnitPlacements
    
    ; Lấy thông tin từ Dropdown (Map và Mode)
    global MapDropdown, ModeDropdown
    currentMap := MapDropdown.Text
    currentMode := ModeDropdown.Text
    
    if (ModeDropdown.Text != "Winter") {
        if (currentMap == "") {
        MsgBox("Vui lòng chọn Map và Mode trước khi cài đặt!")
        return
        }
    }
    
    picName := ""
    
    if (currentMode == "Winter") {
        picName := "Winter" 
    } else {
        picName := currentMap
    }
    
    ; Tạo đường dẫn đầy đủ
    picPath := A_ScriptDir "\Images\" picName ".png"

    ; 1. Load dữ liệu tọa độ (Của riêng Map này)
    LoadUnitCoordsFromFile()

    ; 2. Khởi tạo Session
    if !IsSet(ImgSession)
        ImgSession := {GuiObj: "", Dots: [], UnitIndex: 0, MaxCount: 0, LastClickTime: 0}

    ; 3. Hủy GUI cũ
    try {
        if IsSet(ImageUI) && ImageUI
            ImageUI.Destroy()
    }

    ; 4. Tạo GUI
    ImageUI := Gui("+AlwaysOnTop -Caption +ToolWindow", "KuruImagePicker")
    ImageUIHwnd := ImageUI.Hwnd
    ImageUI.BackColor := "222222" 
    ImageUI.SetFont("s10 bold", "Segoe UI")

    ; 5. Load Ảnh
    try {
        ImageUI.Add("Picture", "x0 y30", picPath) 
    } catch {
        MsgBox("Lỗi: Không tìm thấy ảnh map tại:`n" picPath "`n`nHãy chắc chắn tên file ảnh trùng khớp tên trong Dropdown!")
        return
    }

    ; Tiêu đề hiển thị rõ đang cài cho Map nào
    ImageUI.Add("Text", "x0 y10 BackgroundTrans cRed Center", "MAP: " currentMap " (" currentMode ") - UNIT " unitIndex " | Chuột Trái: Chọn | Chuột Phải: Xóa | Enter: Lưu | Esc: Hủy")

    ImageUI.Show("x0 y0") 

    ImgSession.GuiObj := ImageUI
    ImgSession.Dots := []
    ImgSession.UnitIndex := unitIndex
    ImgSession.MaxCount := 20
    ImgSession.LastClickTime := 0

    ; 6. Vẽ lại các điểm cũ
    if (UnitPlacements.Has(unitIndex)) {
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

; --- CÁC HÀM XỬ LÝ CLICK ---

_ImgLeftClick(ThisHotkey) {
    global ImgSession 
    if (A_TickCount - ImgSession.LastClickTime < 150)
        return
    ImgSession.LastClickTime := A_TickCount
    CoordMode "Mouse", "Client"
    MouseGetPos &mx, &my
    if (ImgSession.Dots.Length >= ImgSession.MaxCount) {
        ToolTip "Đã đủ số lượng!"
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
    dot := ImgSession.GuiObj.Add("Text", "x" (x-radius) " y" (y-radius) " w" size " h" size " BackgroundRed cWhite Center 0x200", count)
    Sleep(20)
    try WinSetRegion("0-0 w" size " h" size " E", dot.Hwnd)
    DllCall("RedrawWindow", "Ptr", dot.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 7)
    ImgSession.Dots.Push({Ctrl: dot, X: x, Y: y})
}

; ------------------------------------------------------------------------------
; LƯU VÀ ĐỌC FILE (THÔNG MINH)
; ------------------------------------------------------------------------------

_ImgSave(ThisHotkey) {
    global ImgSession, UnitPlacements
    UnitPlacements[ImgSession.UnitIndex] := []
    for item in ImgSession.Dots {
        UnitPlacements[ImgSession.UnitIndex].Push([item.X, item.Y])
    }
    SaveUnitCoordsToFile()
    UpdatePosButtons()
    MsgBox("Đã lưu xong!", "KuruMacro", "T0.5")
    _ImgClose(ThisHotkey)
}

_ImgClose(ThisHotkey) {
    global ImageUI
    try ImageUI.Destroy()
    HotIfWinActive "ahk_id " ImageUIHwnd
        Hotkey "LButton", "Off"
        Hotkey "RButton", "Off"
        Hotkey "Enter", "Off"
        Hotkey "Esc", "Off"
    HotIf
}

; --- TẠO TÊN FILE DỰA TRÊN MAP VÀ MODE ---
GetSettingsFileName() {
    global MapDropdown, ModeDropdown
    mapName := MapDropdown.Text
    modeName := ModeDropdown.Text
    
    ; Nếu chưa chọn thì mặc định
    if (mapName == "")
        mapName := "UnknownMap"
    if (modeName == "")
        modeName := "Default"
        
    ; Tạo tên file: Settings\Ninja Forest_Infinite.txt
    return A_ScriptDir "\Settings\" mapName "_" modeName ".txt"
}

SaveUnitCoordsToFile() {
    global UnitPlacements
    if !DirExist(A_ScriptDir "\Settings")
        DirCreate(A_ScriptDir "\Settings")

    filePath := GetSettingsFileName() ; <--- Lấy tên file động
    fileContent := ""
    
    Loop 6 { 
        uIdx := A_Index
        line := uIdx "="
        if (UnitPlacements.Has(uIdx) && UnitPlacements[uIdx].Length > 0) {
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
    filePath := GetSettingsFileName() ; <--- Lấy tên file động
    
    if !IsSet(UnitPlacements)
        UnitPlacements := Map()
    Loop 6 
        UnitPlacements[A_Index] := []

    if !FileExist(filePath)
        return 

    try {
        content := FileRead(filePath, "UTF-8")
        Loop Parse, content, "`n", "`r" {
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
    Loop 6 {
        try {
            currBtn := % "pos" A_Index %
            if (UnitPlacements.Has(A_Index) && UnitPlacements[A_Index].Length > 0) {
                count := UnitPlacements[A_Index].Length
                currBtn.Text := "Set (" count ")"
            } else {
                currBtn.Text := "Pos " A_Index
            }
        }
    }
}