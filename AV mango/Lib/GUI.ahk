#Requires AutoHotkey v2.0
#SingleInstance Force
#Include Image.ahk

; Basic Application Info
global aaTitle := "KuruMacro Anime Vanguard "
global version := "v1"
global rblxID := "ahk_exe RobloxPlayerBeta.exe"
global KurumiLogo := "Images\Kurumi.png"
;Coordinate and Positioning Variables
global targetWidth := 816
global targetHeight := 638
global offsetX := -5
global offsetY := 1
global WM_SIZING := 0x0214
global WM_SIZE := 0x0005
global centerX := 408
global centerY := 320
global successfulCoordinates := []
;State Variables
global enabledUnits := Map()  
global placementValues := Map()  
;Cards
global CardPriority1 := ""
global CardPriority2 := ""
global CardPriority3 := ""
global CardPriority4 := ""
global settingsPri1 := ""
global settingsPri2 := ""
global settingsPri3 := ""
global settingsPri4 := ""
global cardSettingsGUI := ""
;Hotkeys
global F1Key := "F1"
global F2Key := "F2"
global F3Key := "F3"
global F4Key := "F4"
global F5Key := "F5"
;Statistics Tracking
global totalGems := 0
global Wins := 0
global loss := 0
global mode := ""
global StartTime := A_TickCount
global currentTime := GetCurrentTime()
;Gui creation
global uiBorders := []
global uiBackgrounds := []
global uiTheme := []
global UnitData := []
global aaMainUI := Gui("+AlwaysOnTop -Caption")
global lastlog := ""
global aaMainUIHwnd := aaMainUI.Hwnd
;Theme colors
uiTheme.Push("0xb5b3b3")  ; Header color
uiTheme.Push("0x2C3041")  ; Background color
uiTheme.Push("0x807d7d")  ; Border color
uiTheme.Push("0x2C3041")  ; Accent color
uiTheme.Push("0x000000")  ; Trans color
uiTheme.Push("0x000000")  ; Textbox color
uiTheme.Push("0x54AD76")  ; HighLight
;Logs/Save settings
global settingsGuiOpen := false
global SettingsGUI := ""
global cardSettingsGuiOpen := false
global CardSettingsGUI := ""
global currentOutputFile := A_ScriptDir "\Logs\LogFile.txt"
global WebhookURLFile := "Settings\WebhookURL.txt"
global DiscordUserIDFile := "Settings\DiscordUSERID.txt"
global SendActivityLogsFile := "Settings\SendActivityLogs.txt"

if !DirExist(A_ScriptDir "\Logs") {
    DirCreate(A_ScriptDir "\Logs")
}
if !DirExist(A_ScriptDir "\Settings") {
    DirCreate(A_ScriptDir "\Settings")
}

setupOutputFile()
;------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------
aaMainUI.BackColor := uiTheme[2]
global Webhookdiverter := aaMainUI.Add("Edit", "x0 y0 w1 h1 +Hidden", "") ; diversion
uiBorders.Push(aaMainUI.Add("Text", "x0 y0 w1364 h1 +Background" uiTheme[3]))  ;Top line
uiBorders.Push(aaMainUI.Add("Text", "x0 y0 w1 h630 +Background" uiTheme[3]))   ;Left line
uiBorders.Push(aaMainUI.Add("Text", "x1363 y0 w1 h630 +Background" uiTheme[3])) ;Right line
uiBackgrounds.Push(aaMainUI.Add("Text", "x3 y3 w1360 h27 +Background" uiTheme[2])) ;Title Top
uiBorders.Push(aaMainUI.Add("Text", "x0 y30 w1363 h1 +Background" uiTheme[3])) ;Title bottom
uiBorders.Push(aaMainUI.Add("Text", "x802 y30 w1 h600 +Background" uiTheme[3])) ;Roblox Right
uiBorders.Push(aaMainUI.Add("Text", "x803 y433 w560 h1 +Background" uiTheme[3])) ;Process Top
uiBorders.Push(aaMainUI.Add("Text", "x803 y461 w560 h1 +Background" uiTheme[3])) ;Process bottom
uiBorders.Push(aaMainUI.Add("Text", "x0 y630 w1364 h1 +Background" uiTheme[3], "")) ;Roblox bottom

global MyLogo := aaMainUI.Add("Picture", "x1100 y-1 w32 h32", KurumiLogo) ; dev logo
global robloxHolder := aaMainUI.Add("Text", "x3 y33 w797 h597 +Background" uiTheme[5], "") ;Roblox window box
Global Discord := aaMainUI.Add("Picture", "x1255 y-4 w42 h42 +BackgroundTrans", Discord) ;Discord logo
Discord.OnEvent("Click", (*) => OpenDiscordLink()) ;Open discord
global exitButton := aaMainUI.Add("Picture", "x1330 y1 w32 h32 +BackgroundTrans", Exitbutton) ;Exit image
exitButton.OnEvent("Click", (*) => Destroy()) ;Exit button
global minimizeButton := aaMainUI.Add("Picture", "x1300 y3 w27 h27 +Background" uiTheme[2], Minimize) ;Minimize gui
minimizeButton.OnEvent("Click", (*) => minimizeUI()) ;Minimize gui
aaMainUI.SetFont("Bold s16 c" uiTheme[1], "Verdana") ;Font
global windowTitle := aaMainUI.Add("Text", "x10 y3 w1200 h29 +BackgroundTrans", aaTitle "" . "" version) ;Title
aaMainUI.Add("Text", "x805 y435 w558 h25 +Center +BackgroundTrans", "Process") ;Process header
aaMainUI.SetFont("norm s11 c" uiTheme[1]) ;Font
global process1 := aaMainUI.Add("Text", "x810 y470 w538 h18 +BackgroundTrans c" uiTheme[7], "➤ Created by KuruMacro") ;Processes
global process2 := aaMainUI.Add("Text", "xp yp+22 w538 h18 +BackgroundTrans", "") 
global process3 := aaMainUI.Add("Text", "xp yp+22 w538 h18 +BackgroundTrans", "") 
global process4 := aaMainUI.Add("Text", "xp yp+22 w538 h18 +BackgroundTrans", "") 
global process5 := aaMainUI.Add("Text", "xp yp+22 w538 h18 +BackgroundTrans", "") 
global process6 := aaMainUI.Add("Text", "xp yp+22 w538 h18 +BackgroundTrans", "") 
global process7 := aaMainUI.Add("Text", "xp yp+22 w538 h18 +BackgroundTrans", "") 
WinSetTransColor(uiTheme[5], aaMainUI) ;Roblox window box

;--------------SETTINGS;--------------SETTINGS;--------------SETTINGS;--------------SETTINGS;--------------SETTINGS;--------------SETTINGS;--------------SETTINGS
ShowSettingsGUI(*) {
    global settingsGuiOpen, SettingsGUI
    
    ; Check if settings window already exists
    if (SettingsGUI && WinExist("ahk_id " . SettingsGUI.Hwnd)) {
        WinActivate("ahk_id " . SettingsGUI.Hwnd)
        return
    }
    
    if (settingsGuiOpen) {
        return
    }
    
    settingsGuiOpen := true
    SettingsGUI := Gui("-MinimizeBox +Owner" aaMainUIHwnd)  
    SettingsGui.Title := "Settings"
    SettingsGUI.OnEvent("Close", OnSettingsGuiClose)
    SettingsGUI.BackColor := uiTheme[2]
    
    ; Window border
    SettingsGUI.Add("Text", "x0 y0 w1 h600 +Background" uiTheme[3])     ; Left
    SettingsGUI.Add("Text", "x599 y0 w1 h600 +Background" uiTheme[3])   ; Right
    SettingsGUI.Add("Text", "x0 y399 w600 h1 +Background" uiTheme[3])   ; Bottom
    
    ; Right side sections
    SettingsGUI.SetFont("s10", "Verdana")
    SettingsGUI.Add("GroupBox", "x310 y5 w280 h160 c" uiTheme[1], "Discord Webhook")  ; Box
    
    ; Webhook
    SettingsGUI.SetFont("s9", "Verdana")
    SettingsGUI.Add("Text", "x320 y30 c" uiTheme[1], "Webhook URL")     ; Webhook Text
    global WebhookURLBox := SettingsGUI.Add("Edit", "x320 y50 w260 h20 c" uiTheme[6])  ; Store webhook
    SettingsGUI.Add("Text", "x320 y73 c" uiTheme[1], "Discord ID (optional)")  ; Discord Id Text
    global DiscordUserIDBox := SettingsGUI.Add("Edit", "x320 y93 w260 h20 c" uiTheme[6])  ; Store Discord ID
    global SendActivityLogsBox := SettingsGUI.Add("Checkbox", "x320 y120 c" uiTheme[1], "Send Process")  ; Enable Activity

    ; HotKeys
    SettingsGUI.Add("GroupBox", "x10 y90 w160 h160 c" uiTheme[1], "Keybinds")
    SettingsGUI.Add("Text", "x20 y110 c" uiTheme[1], "Position Roblox:")
    global F1Box := SettingsGUI.Add("Edit", "x125 y110 w30 h20 c" uiTheme[6], F1Key)
    SettingsGUI.Add("Text", "x20 y140 c" uiTheme[1], "Start Macro:")
    global F2Box := SettingsGUI.Add("Edit", "x100 y140 w30 h20 c" uiTheme[6], F2Key)
    SettingsGUI.Add("Text", "x20 y170 c" uiTheme[1], "Stop Macro:")
    global F3Box := SettingsGUI.Add("Edit", "x100 y170 w30 h20 c" uiTheme[6], F3Key)
    SettingsGUI.Add("Text", "x20 y200 c" uiTheme[1], "Pause Macro:")
    global F4Box := SettingsGUI.Add("Edit", "x110 y200 w30 h20 c" uiTheme[6], F4Key)
    SettingsGUI.Add("Text", "x20 y230 c" uiTheme[1], "Test Macro:")
    global F5Box := SettingsGUI.Add("Edit", "x110 y230 w30 h20 c" uiTheme[6], F5Key)

    ; Banner section
    SettingsGUI.Add("GroupBox", "x310 y175 w280 h100 c" uiTheme[1], "Banner Checker")  ; Box
    SettingsGUI.Add("Text", "x320 y195 c" uiTheme[1], "Banner Unit Name (Adding later)")  ; Banner Text
    global BannerUnitBox := SettingsGUI.Add("Edit", "x320 y215 w260 h20 c" uiTheme[6])  ; Store banner
    testBannerBtn := SettingsGUI.Add("Button", "x320 y240 w120 h25", "Test Banner")
    testBannerBtn.OnEvent("Click", (*) => CheckBanner(BannerUnitBox.Value))

    ; Private Server section
    SettingsGUI.Add("GroupBox", "x310 y280 w280 h100 c" uiTheme[1], "PS Link")  ; box
    SettingsGUI.Add("Text", "x320 y300 c" uiTheme[1], "Private Server Link (optional)")  ; ps text
    global PsLinkBox := SettingsGUI.Add("Edit", "x320 y320 w260 h20 c" uiTheme[6])  ; edit box

    SettingsGUI.Add("GroupBox", "x10 y10 w115 h70 c" uiTheme[1], "UI Navigation")
    SettingsGUI.Add("Text", "x20 y30 c" uiTheme[1], "Navigation Key")
    global UINavBox := SettingsGUI.Add("Edit", "x20 y50 w20 h20 c" uiTheme[6], "\")

    ; Save buttons
    webhookSaveBtn := SettingsGUI.Add("Button", "x450 y125 w120 h25", "Save Webhook")
    webhookSaveBtn.OnEvent("Click", (*) => SaveWebhookSettings())

    keybindSaveBtn := SettingsGUI.Add("Button", "x20 y220 w50 h20", "Save")
    keybindSaveBtn.OnEvent("Click", SaveKeybindSettings)

    bannerSaveBtn := SettingsGUI.Add("Button", "x460 y240 w120 h25", "Save Banner")
    bannerSaveBtn.OnEvent("Click", (*) => SaveBannerSettings())

    PsSaveBtn := SettingsGUI.Add("Button", "x460 y345 w120 h25", "Save PsLink")
    PsSaveBtn.OnEvent("Click", (*) => SavePsSettings())

    UINavSaveBtn := SettingsGUI.Add("Button", "x50 y50 w60 h20", "Save")
    UINavSaveBtn.OnEvent("Click", (*) => SaveUINavSettings())
    

    ; Load settings
    if FileExist(WebhookURLFile)
        WebhookURLBox.Value := FileRead(WebhookURLFile, "UTF-8")
    if FileExist(DiscordUserIDFile)
        DiscordUserIDBox.Value := FileRead(DiscordUserIDFile, "UTF-8")
    if FileExist(SendActivityLogsFile)
        SendActivityLogsBox.Value := (FileRead(SendActivityLogsFile, "UTF-8") = "1")  
    if FileExist("Settings\BannerUnit.txt")
        BannerUnitBox.Value := FileRead("Settings\BannerUnit.txt", "UTF-8")
    if FileExist("Settings\PrivateServer.txt")
        PsLinkBox.Value := FileRead("Settings\PrivateServer.txt", "UTF-8")
    if FileExist("Settings\UINavigation.txt")
        UINavBox.Value := FileRead("Settings\UINavigation.txt", "UTF-8")

    ; Show the settings window
    SettingsGUI.Show("w600 h400")
    Webhookdiverter.Focus()
}
;--------------CARDS;--------------CARDS;--------------CARDS;--------------CARDS;--------------CARDS

ShowCardSettingsGUI(*) {
    global CardSettingsGUI, cardSettingsGuiOpen
    global settingsPri1, settingsPri2, settingsPri3, settingsPri4
    
    ; Check if settings window already exists
    if (CardSettingsGUI && WinExist("ahk_id " . CardSettingsGUI.Hwnd)) {
        WinActivate("ahk_id " . CardSettingsGUI.Hwnd)
        return
    }
    
    if (cardSettingsGuiOpen) {
        return
    }
    
    cardSettingsGuiOpen := true
    CardSettingsGUI := Gui("-MinimizeBox +Owner" aaMainUIHwnd)
    CardSettingsGUI.Title := "Legend Card Settings"
    CardSettingsGUI.OnEvent("Close", OnCardSettingsClose)
    CardSettingsGUI.BackColor := uiTheme[2]
    
    ; Add border styling
    CardSettingsGUI.Add("Text", "x0 y0 w1 h220 +Background" uiTheme[3])     ; Left
    CardSettingsGUI.Add("Text", "x389 y0 w1 h220 +Background" uiTheme[3])   ; Right
    CardSettingsGUI.Add("Text", "x0 y219 w390 h1 +Background" uiTheme[3])   ; Bottom
    
    ; Add title and explanation
    CardSettingsGUI.SetFont("s12 Bold c" uiTheme[1], "Verdana")
    CardSettingsGUI.Add("Text", "x20 y10 w350 c" uiTheme[1], "Legend Card Priority Settings")
    
    CardSettingsGUI.SetFont("s9 c" uiTheme[1], "Verdana")
    CardSettingsGUI.Add("Text", "x20 y40 w350 c" uiTheme[1], "Select starter cards in order of preference.")
    CardSettingsGUI.Add("Text", "x20 y60 w350 c" uiTheme[1], "Macro will pick the highest priority card available.")
    
    ; Card priority selections
    CardSettingsGUI.Add("GroupBox", "x20 y85 w330 h120 c" uiTheme[1], "Card Priority Order")
    
    ; Create dropdown lists 
    CardSettingsGUI.Add("Text", "x40 y110 w30 h20 c" uiTheme[1], "1st:")
    settingsPri1 := CardSettingsGUI.Add("DropDownList", "x70 y107 w100 h180", 
        ["Thrice", "Champion", "Revitalize", "Exploding", "Quake", "Immunity"])
    
    CardSettingsGUI.Add("Text", "x205 y110 w30 h20 c" uiTheme[1], "2nd:")
    settingsPri2 := CardSettingsGUI.Add("DropDownList", "x235 y107 w100 h180", 
        ["Thrice", "Champion", "Revitalize", "Exploding", "Quake", "Immunity"])
    
    CardSettingsGUI.Add("Text", "x40 y145 w30 h20 c" uiTheme[1], "3rd:")
    settingsPri3 := CardSettingsGUI.Add("DropDownList", "x70 y142 w100 h180", 
        ["Thrice", "Champion", "Revitalize", "Exploding", "Quake", "Immunity"])
    
    CardSettingsGUI.Add("Text", "x205 y145 w30 h20 c" uiTheme[1], "4th:")
    settingsPri4 := CardSettingsGUI.Add("DropDownList", "x235 y142 w100 h180", 
        ["Thrice", "Champion", "Revitalize", "Exploding", "Quake", "Immunity"])
    
    ; Load saved priorities from file
    savedPriorities := ["Thrice", "Champion", "Revitalize", "Exploding"]  ; Default values
    
    if FileExist("Settings\CardPriorities.txt") {
        fileContent := FileRead("Settings\CardPriorities.txt", "UTF-8")
        lines := StrSplit(fileContent, "`n")
        
        if (lines.Length >= 1 && lines[1] != "")
            savedPriorities[1] := lines[1]
        if (lines.Length >= 2 && lines[2] != "")
            savedPriorities[2] := lines[2]
        if (lines.Length >= 3 && lines[3] != "")
            savedPriorities[3] := lines[3]
        if (lines.Length >= 4 && lines[4] != "")
            savedPriorities[4] := lines[4]
    }
    
    ; Set the values in the dropdowns
    try {
        settingsPri1.Text := savedPriorities[1]
        settingsPri2.Text := savedPriorities[2]
        settingsPri3.Text := savedPriorities[3]
        settingsPri4.Text := savedPriorities[4]
    } catch {
        ProcessLog("Warning: Failed to set dropdown values from saved priorities")
        
        ; Fallback to Choose
        settingsPri1.Choose(GetIndexForValue(settingsPri1, savedPriorities[1]))
        settingsPri2.Choose(GetIndexForValue(settingsPri2, savedPriorities[2]))
        settingsPri3.Choose(GetIndexForValue(settingsPri3, savedPriorities[3]))
        settingsPri4.Choose(GetIndexForValue(settingsPri4, savedPriorities[4]))
    }
    
    ; Save button with dedicated function - smaller size
    SaveBtn := CardSettingsGUI.Add("Button", "x150 y175 w90 h25", "Save")
    SaveBtn.OnEvent("Click", SaveCardPriorities)
    
    ; Show the GUI - smaller size
    CardSettingsGUI.Show("w390 h240")
}

aaMainUI.SetFont("s10 c" uiTheme[1])
global CardSettingsBtn := aaMainUI.Add("Button", "x900 y385 w120 h20", "Starter cards")
CardSettingsBtn.OnEvent("Click", ShowCardSettingsGUI)

aaMainUI.SetFont("s12 Bold c" uiTheme[1])
global settingsBtn := aaMainUI.Add("Button", "x1160 y0 w90 h30", "Settings")
settingsBtn.OnEvent("Click", ShowSettingsGUI)

placementSaveBtn := aaMainUI.Add("Button", "x807 y405 w80 h20", "Save")
placementSaveBtn.OnEvent("Click", SaveSettings)
aaMainUI.SetFont("s9")
global NextLevelBox := aaMainUI.Add("Checkbox", "x900 y385 cffffff Checked" , "Next Level")
global ReturnLobbyBox := aaMainUI.Add("Checkbox", "x900 y385 cffffff Checked", "Return To Lobby")
global AutoAbilityBox := aaMainUI.Add("CheckBox", "x900 y410 cffffff Checked", "Auto Ability")
global PriorityUpgrade := aaMainUI.Add("CheckBox", "x1005 y410 cffffff", "Priority Upgrade")
global PlacementPatternDropdown := aaMainUI.Add("DropDownList", "x1250 y405 w100 h180 Choose1 +Center", ["Random", "Grid", "Circle"])
PlacementPatternText := aaMainUI.Add("Text", "x1250 y385 w105 h20", "Placement type")
placementSaveText := aaMainUI.Add("Text", "x807 y385 w80 h20", "Save Config")
Hotkeytext := aaMainUI.Add("Text", "x807 y35 w530 h30", "To change keybinds click top right settings, Below are default hotkey settings ")
Hotkeytext2 := aaMainUI.Add("Text", "x807 y50 w530 h30", "F1:Reposition roblox window|F2:Start Macro|F3:Stop Macro|F4:Pause Macro")
;--------------MODE SELECT;--------------MODE SELECT;--------------MODE SELECT;--------------MODE SELECT;--------------MODE SELECT;--------------MODE SELECT
global modeSelectionGroup := aaMainUI.Add("GroupBox", "x808 y38 w500 h45 Background" uiTheme[2], "Mode Select")
aaMainUI.SetFont("s10 c" uiTheme[6])
global ModeDropdown := aaMainUI.Add("DropDownList", "x818 y53 w140 h180 Choose0 +Center", ["Infinite"])
global ConfirmButton := aaMainUI.Add("Button", "x1218 y53 w80 h25", "Confirm")

ReturnLobbyBox.Visible := false
NextLevelBox.Visible := false
Hotkeytext.Visible := false
Hotkeytext2.Visible := false
CardSettingsBtn.Visible := false
ModeDropdown.OnEvent("Change", OnModeChange)
ConfirmButton.OnEvent("Click", OnConfirmClick)
;------UNIT CONFIGURATION------UNIT CONFIGURATION------UNIT CONFIGURATION/------UNIT CONFIGURATION/------UNIT CONFIGURATION/------UNIT CONFIGURATION/

AddUnitCard(aaMainUI, index, x, y) {
    unit := {}
 
    unit.Background := aaMainUI.Add("Text", Format("x{} y{} w550 h45 +Background{}", x, y, uiTheme[4]))
    unit.BorderTop := aaMainUI.Add("Text", Format("x{} y{} w550 h2 +Background{}", x, y, uiTheme[3]))
    unit.BorderBottom := aaMainUI.Add("Text", Format("x{} y{} w552 h2 +Background{}", x, y+45, uiTheme[3]))
    unit.BorderLeft := aaMainUI.Add("Text", Format("x{} y{} w2 h45 +Background{}", x, y, uiTheme[3]))
    unit.BorderRight := aaMainUI.Add("Text", Format("x{} y{} w2 h45 +Background{}", x+550, y, uiTheme[3]))
    aaMainUI.SetFont("s11 Bold c" uiTheme[1])
    unit.Title := aaMainUI.Add("Text", Format("x{} y{} w60 h25 +BackgroundTrans", x+30, y+18), "Unit " index)

    aaMainUI.SetFont("s9 c" uiTheme[1])
    unit.PlacementText := aaMainUI.Add("Text", Format("x{} y{} w70 h20 +BackgroundTrans", x+100, y+2), "Placement")
    unit.PriorityText := aaMainUI.Add("Text", Format("x{} y{} w60 h20 BackgroundTrans hidden", x+180, y+2), "Priority")
    
    UnitData.Push(unit)
    return unit
}

;Create Unit slot
y_start := 85
y_spacing := 50
Loop 6 {
    AddUnitCard(aaMainUI, A_Index, 808, y_start + ((A_Index-1)*y_spacing))
}

enabled1 := aaMainUI.Add("CheckBox", "x818 y105 w15 h15", "")
enabled2 := aaMainUI.Add("CheckBox", "x818 y155 w15 h15", "")
enabled3 := aaMainUI.Add("CheckBox", "x818 y205 w15 h15", "")
enabled4 := aaMainUI.Add("CheckBox", "x818 y255 w15 h15", "")
enabled5 := aaMainUI.Add("CheckBox", "x818 y305 w15 h15", "")
enabled6 := aaMainUI.Add("CheckBox", "x818 y355 w15 h15", "")

aaMainUI.SetFont("s8 c" uiTheme[6])
; Placement dropdowns
placement1 := aaMainUI.Add("DropDownList", "x908 y105 w60 h180 Choose1 +Center", ["1","2","3","4","5","6"])
placement2 := aaMainUI.Add("DropDownList", "x908 y155 w60 h180 Choose1 +Center", ["1","2","3","4","5","6"])
placement3 := aaMainUI.Add("DropDownList", "x908 y205 w60 h180 Choose1 +Center", ["1","2","3","4","5","6"])
placement4 := aaMainUI.Add("DropDownList", "x908 y255 w60 h180 Choose1 +Center", ["1","2","3","4","5","6"])
placement5 := aaMainUI.Add("DropDownList", "x908 y305 w60 h180 Choose1 +Center", ["1","2","3","4","5","6"])
placement6 := aaMainUI.Add("DropDownList", "x908 y355 w60 h180 Choose1 +Center", ["1","2","3","4","5","6"])

levelLimit1 := aaMainUI.Add("DropDownList", "x990 y105 w60 h180 Choose1 +Center Hidden", ["1", "2", "3", "4", "5", "6", "7", "8", "9", "Max"])
levelLimit2 := aaMainUI.Add("DropDownList", "x990 y155 w60 h180 Choose1 +Center Hidden", ["1", "2", "3", "4", "5", "6", "7", "8", "9", "Max"]) 
levelLimit3 := aaMainUI.Add("DropDownList", "x990 y205 w60 h180 Choose1 +Center Hidden", ["1", "2", "3", "4", "5", "6", "7", "8", "9", "Max"])
levelLimit4 := aaMainUI.Add("DropDownList", "x990 y255 w60 h180 Choose1 +Center Hidden", ["1", "2", "3", "4", "5", "6", "7", "8", "9", "Max"])
levelLimit5 := aaMainUI.Add("DropDownList", "x990 y305 w60 h180 Choose1 +Center Hidden", ["1", "2", "3", "4", "5", "6", "7", "8", "9", "Max"])
levelLimit6 := aaMainUI.Add("DropDownList", "x990 y355 w60 h180 Choose1 +Center Hidden", ["1", "2", "3", "4", "5", "6", "7", "8", "9", "Max"])

; Upgrade priority dropdowns
Priority1 := aaMainUI.Add("DropDownList", "X990 y105 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
Priority2 := aaMainUI.Add("DropDownList", "X990 y155 w60 h180 Choose2 +Center Hidden", ["1","2","3","4","5","6"])
Priority3 := aaMainUI.Add("DropDownList", "X990 y205 w60 h180 Choose3 +Center Hidden", ["1","2","3","4","5","6"])
Priority4 := aaMainUI.Add("DropDownList", "X990 y255 w60 h180 Choose4 +Center Hidden", ["1","2","3","4","5","6"])
Priority5 := aaMainUI.Add("DropDownList", "X990 y305 w60 h180 Choose5 +Center Hidden", ["1","2","3","4","5","6"])
Priority6 := aaMainUI.Add("DropDownList", "X990 y355 w60 h180 Choose6 +Center Hidden", ["1","2","3","4","5","6"])
PriorityUpgrade.OnEvent("Click", TogglePriorityDropdowns)

readInSettings()
aaMainUI.Show("w1366 h633")
WinMove(0, 0,,, "ahk_id " aaMainUIHwnd)
forceRobloxSize()  ; Initial force size and position
;------FUNCTIONS;------FUNCTIONS;------FUNCTIONS;------FUNCTIONS;------FUNCTIONS;------FUNCTIONS;------FUNCTIONS;------FUNCTIONS;------FUNCTIONS;------FUNCTIONS;------FUNCTIONS

;Process text
ProcessLog(current) { 
    global process1, process2, process3, process4, process5, process6, process7, currentOutputFile, lastlog

    ; Remove arrow from all lines first
    process7.Value := StrReplace(process6.Value, "➤ ", "")
    process6.Value := StrReplace(process5.Value, "➤ ", "")
    process5.Value := StrReplace(process4.Value, "➤ ", "")
    process4.Value := StrReplace(process3.Value, "➤ ", "")
    process3.Value := StrReplace(process2.Value, "➤ ", "")
    process2.Value := StrReplace(process1.Value, "➤ ", "")
    
    ; Add arrow only to newest process
    process1.Value := "➤ " . current
    
    elapsedTime := getElapsedTime()
    Sleep(50)
    FileAppend(current . " " . elapsedTime . "`n", currentOutputFile)

    ; Add webhook logging
    lastlog := current
    if FileExist("Settings\SendActivityLogs.txt") {
        SendActivityLogsStatus := FileRead("Settings\SendActivityLogs.txt", "UTF-8")
        if (SendActivityLogsStatus = "1") {
            WebhookLog()
        }
    }
}

;Timer
getElapsedTime() {
    global StartTime
    ElapsedTime := A_TickCount - StartTime
    Minutes := Mod(ElapsedTime // 60000, 60)  
    Seconds := Mod(ElapsedTime // 1000, 60)
    return Format("{:02}:{:02}", Minutes, Seconds)
}

;Basically the code to move roblox, below

sizeDown() {
    global rblxID
    
    if !WinExist(rblxID)
        return

    WinGetPos(&X, &Y, &OutWidth, &OutHeight, rblxID)
    
    ; Exit fullscreen if needed
    if (OutWidth >= A_ScreenWidth && OutHeight >= A_ScreenHeight) {
        Send "{F11}"
        Sleep(100)
    }

    ; Force the window size and retry if needed
    Loop 3 {
        WinMove(X, Y, targetWidth, targetHeight, rblxID)
        Sleep(100)
        WinGetPos(&X, &Y, &OutWidth, &OutHeight, rblxID)
        if (OutWidth == targetWidth && OutHeight == targetHeight)
            break
    }
}

moveRobloxWindow() {
    global aaMainUIHwnd, offsetX, offsetY, rblxID
    
    if !WinExist(rblxID) {
        ProcessLog("Waiting for Roblox window...")
        return
    }

    ; First ensure correct size
    sizeDown()
    
    ; Then move relative to main UI
    WinGetPos(&x, &y, &w, &h, aaMainUIHwnd)
    WinMove(x + offsetX, y + offsetY,,, rblxID)
    WinActivate(rblxID)
}

forceRobloxSize() {
    global rblxID
    
    if !WinExist(rblxID) {
        checkCount := 0
        While !WinExist(rblxID) {
            Sleep(5000)
            if(checkCount >= 5) {
                ProcessLog("Attempting to locate the Roblox window")
            } 
            checkCount += 1
            if (checkCount > 12) { ; Give up after 1 minute
                ProcessLog("Could not find Roblox window")
                return
            }
        }
        ProcessLog("Found Roblox window")
    }

    WinActivate(rblxID)
    sizeDown()
    moveRobloxWindow()
}
;Basically the code to move roblox, Above

OnSettingsGuiClose(*) {
    global settingsGuiOpen, SettingsGUI
    settingsGuiOpen := false
    if SettingsGUI {
        SettingsGUI.Destroy()
        SettingsGUI := ""  ; Clear the GUI reference
    }
}

; Function to handle the Close event for the card settings GUI
OnCardSettingsClose(*) {
    global cardSettingsGuiOpen, CardSettingsGUI
    
    cardSettingsGuiOpen := false
    if CardSettingsGUI {
        CardSettingsGUI.Destroy()
        CardSettingsGUI := ""
    }
}

checkSizeTimer() {
    if (WinExist("ahk_exe RobloxPlayerBeta.exe")) {
        WinGetPos(&X, &Y, &OutWidth, &OutHeight, "ahk_exe RobloxPlayerBeta.exe")
        if (OutWidth != 816 || OutHeight != 638) {
            ProcessLog("Fixing Roblox window size")
            moveRobloxWindow()
        }
    }
}

