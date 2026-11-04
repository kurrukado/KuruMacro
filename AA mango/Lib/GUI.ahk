#Requires AutoHotkey v2.0
#SingleInstance Force

if (A_ScriptFullPath = A_LineFile) {
    mainScript := A_ScriptDir "\..\Main.ahk"
    if FileExist(mainScript) {
        Run('"' A_AhkPath '" "' mainScript '"')
        ExitApp()
    }
}

; Basic Application Info
global aaTitle := "KuruMacro Anime Adventures "
global version := "v3.0"
global rblxID := "ahk_exe RobloxPlayerBeta.exe"
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
;Hotkeys
global F1Key := "F1"
global F2Key := "F2"
global F3Key := "F3"
global F4Key := "F4"
;Statistics Tracking
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
uiTheme.Push("0xFF00FE")  ; Reserved viewport chroma key; never use text/black here.
uiTheme.Push("0x000000")  ; Textbox color
uiTheme.Push("0x54AD76")  ; HighLight
;Logs/Save settings
global settingsGuiOpen := false
global SettingsGUI := ""
global currentOutputFile := A_ScriptDir "\Logs\LogFile.txt"
global WebhookURLFile := "Settings\WebhookURL.txt"
global DiscordUserIDFile := "Settings\DiscordUSERID.txt"
global SendActivityLogsFile := "Settings\SendActivityLogs.txt"
;Create logs file if not exist
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

global MyLogo := aaMainUI.Add("Picture", "x1020 y-1 w32 h32", KurumiLogo)
global robloxHolder := aaMainUI.Add("Text", "x3 y33 w797 h597 +Background" uiTheme[5], "") ;Roblox window box
global Discord := aaMainUI.Add("Picture", "x1255 y-4 w42 h42 +BackgroundTrans", Discord) ;Discord logo
Discord.OnEvent("Click", (*) => OpenDiscordLink()) ;Open discord
global exitButton := aaMainUI.Add("Picture", "x1330 y1 w32 h32 +BackgroundTrans", Exitbutton) ;Exit image
exitButton.OnEvent("Click", (*) => Destroy()) ;Exit button
global minimizeButton := aaMainUI.Add("Picture", "x1300 y3 w27 h27 +Background" uiTheme[2], Minimize) ;Minimize gui
minimizeButton.OnEvent("Click", (*) => minimizeUI()) ;Minimize gui

aaMainUI.SetFont("Bold s16 c" uiTheme[1], "Verdana") ;Font
global windowTitle := aaMainUI.Add("Text", "x10 y3 w1200 h29 +BackgroundTrans", aaTitle "" . "" version) ;Title
aaMainUI.Add("Text", "x805 y435 w558 h25 +Center +BackgroundTrans", "Process") ;Process header
aaMainUI.SetFont("norm s11 c" uiTheme[1]) ;Font
global process1 := aaMainUI.Add("Text", "x810 y470 w538 h18 +BackgroundTrans c" uiTheme[7], "➤ Made by KuruMacro") ;Processes
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
    SettingsGUI.Add("Text", "x320 y83 c" uiTheme[1], "Discord ID (optional)")  ; Discord Id Text
    global DiscordUserIDBox := SettingsGUI.Add("Edit", "x320 y103 w260 h20 c" uiTheme[6])  ; Store Discord ID
    global SendActivityLogsBox := SettingsGUI.Add("Checkbox", "x320 y135 c" uiTheme[1], "Send Process")  ; Enable Activity

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

    ; Jev key stays masked and is only loaded when Settings is opened.
    SettingsGUI.Add("GroupBox", "x310 y175 w280 h100 c" uiTheme[1], "Jev (Typesafe)")
    SettingsGUI.Add("Text", "x320 y195 c" uiTheme[1], "API key")
    global JevKeyBox := SettingsGUI.Add("Edit", "x320 y215 w260 h20 Password c" uiTheme[6])
    global JevKeyStatus := SettingsGUI.Add("Text", "x320 y245 w135 h20 c" uiTheme[1], "")

    ; Private Server section
    SettingsGUI.Add("GroupBox", "x310 y280 w280 h100 c" uiTheme[1], "PS Link")  ; Box
    SettingsGUI.Add("Text", "x320 y300 c" uiTheme[1], "Private Server Link (optional)")  ; Ps text
    global PsLinkBox := SettingsGUI.Add("Edit", "x320 y320 w260 h20 c" uiTheme[6])  ;  ecit box

    SettingsGUI.Add("GroupBox", "x10 y10 w115 h70 c" uiTheme[1], "UI Navigation")
    SettingsGUI.Add("Text", "x20 y30 c" uiTheme[1], "Navigation Key")
    global UINavBox := SettingsGUI.Add("Edit", "x20 y50 w20 h20 c" uiTheme[6], "\")

    ; Save buttons
    webhookSaveBtn := SettingsGUI.Add("Button", "x460 y135 w120 h25", "Save Webhook")
    webhookSaveBtn.OnEvent("Click", (*) => SaveWebhookSettings())

    keybindSaveBtn := SettingsGUI.Add("Button", "x20 y220 w50 h20", "Save")
    keybindSaveBtn.OnEvent("Click", SaveKeybindSettings)

    jevSaveBtn := SettingsGUI.Add("Button", "x460 y240 w120 h25", "Save key")
    jevSaveBtn.OnEvent("Click", (*) => SaveJevSettings())

    PsSaveBtn := SettingsGUI.Add("Button", "x460 y345 w120 h25", "Save PsLink")
    PsSaveBtn.OnEvent("Click", (*) => SavePsSettings())

    UINavSaveBtn := SettingsGUI.Add("Button", "x50 y50 w60 h20", "Save")
    UINavSaveBtn.OnEvent("Click", (*) => SaveUINavSettings())

    ; Loadsettings
    if FileExist(WebhookURLFile)
        WebhookURLBox.Value := FileRead(WebhookURLFile, "UTF-8")
    if FileExist(DiscordUserIDFile)
        DiscordUserIDBox.Value := FileRead(DiscordUserIDFile, "UTF-8")
    if FileExist(SendActivityLogsFile)
        SendActivityLogsBox.Value := (FileRead(SendActivityLogsFile, "UTF-8") = "1")
    try JevKeyBox.Value := JevLoadKey()
    catch
        JevKeyStatus.Text := "Could not load key"
    if FileExist("Settings\PrivateServer.txt")
        PsLinkBox.Value := FileRead("Settings\PrivateServer.txt", "UTF-8")
    if FileExist("Settings\UINavigation.txt")
        UINavBox.Value := FileRead("Settings\UINavigation.txt", "UTF-8")

    ; Show the settings window
    WinGetPos(&ownerX, &ownerY, &ownerW, &ownerH, "ahk_id " aaMainUIHwnd)
    SettingsGUI.Show("x" (ownerX + Max(0, (ownerW - 600) // 2))
        . " y" (ownerY + Max(0, (ownerH - 430) // 2)) " w600 h400")
    Webhookdiverter.Focus()
}

SaveJevSettings(*) {
    global JevKeyBox, JevKeyStatus, JEV_KEY

    key := Trim(JevKeyBox.Value)
    keyPath := A_ScriptDir "\Settings\JevKey.txt"
    tempPath := keyPath "." DllCall("GetCurrentProcessId") ".tmp"
    try {
        ; Replace only after the entire new key has been written successfully.
        DirCreate(A_ScriptDir "\Settings")
        keyFile := FileOpen(tempPath, "w", "UTF-8-RAW")
        try keyFile.Write(key)
        finally keyFile.Close()
        FileMove(tempPath, keyPath, true)
        JEV_KEY := key
        JevKeyBox.Value := key
        JevKeyStatus.Text := key = "" ? "Key cleared" : "Key saved"
        return true
    } catch {
        try FileDelete(tempPath)
        ; Do not include exception text: it could contain credentials.
        JevKeyStatus.Text := "Could not save key"
        return false
    }
}

OpenGuide(*) {
    GuideGUI := Gui("+AlwaysOnTop")
    GuideGUI.SetFont("s10 bold", "Segoe UI")
    GuideGUI.Title := "Anime adventures settings"

    GuideGUI.BackColor := "0c000a"
    GuideGUI.MarginX := 20
    GuideGUI.MarginY := 20

    ; Add Guide content
    GuideGUI.SetFont("s16 bold", "Segoe UI")
    GuideGUI.Add("Text", "x0 w800 cWhite +Center", "1 - Chỉnh lại setting trong game như sau:")
    GuideGUI.Add("Picture", "x100 w600 h160 cWhite +Center", "Images\aasettings.png")
    GuideGUI.Add("Text", "x0 w800 cWhite +Center", "2 - Nhớ chỉnh Graphics về thành 1")
    GuideGUI.Add("Picture", "x50 w700   cWhite +Center", "Images\Clicktomove.png")
    GuideGUI.Add("Picture", "x50 w700   cWhite +Center", "Images\graphics1.png")
    GuideGUI.Add("Text", "x0 w800 cWhite +Center", "3 - Ko ưu tiên Hill units, ưu tiên Hybird")
    GuideGUI.Add("Text", "x0 w800 cWhite +Center", "4 - Vào lại game, đừng di chuyển camera và bấm F2 để bắt đầu")
    GuideGUI.Show("w800")
}

aaMainUI.SetFont("s12 Bold c" uiTheme[1])
global settingsBtn := aaMainUI.Add("Button", "x1160 y0 w90 h30", "Settings")
settingsBtn.OnEvent("Click", ShowSettingsGUI)
global guideBtn := aaMainUI.Add("Button", "x1060 y0 w90 h30", "Guide")
guideBtn.OnEvent("Click", OpenGuide)
placementSaveBtn := aaMainUI.Add("Button", "x807 y405 w80 h20", "Save")
placementSaveBtn.OnEvent("Click", SaveSettings)

aaMainUI.SetFont("s9")
global NextLevelBox := aaMainUI.Add("Checkbox", "x1135 y385 c0xb5b3b3 Checked", "Next Level")
global ReplayBox := aaMainUI.Add("Checkbox", "x980 y385 c0xb5b3b3 Checked", "Replay")
; Start in solo Play Here mode to avoid unattended matchmaking CAPTCHA prompts.
global MatchMaking := aaMainUI.Add("Checkbox", "x1035 y385 c0xb5b3b3", "Matchmaking")
global ReturnLobbyBox := aaMainUI.Add("Checkbox", "x900 y385 c0xb5b3b3", "Return To Lobby")
global AutoAbilityBox := aaMainUI.Add("CheckBox", "x900 y410 c0xb5b3b3 Checked", "Auto Ability")
global PriorityUpgrade := aaMainUI.Add("CheckBox", "x1005 y410 c0xb5b3b3", "Priority Upgrade")
global SaveChestsBox := aaMainUI.Add("CheckBox", "x900 y385 c0xb5b3b3 Checked", "Save Chests For Rukia")
global PlacementPatternDropdown := aaMainUI.Add("DropDownList", "x1250 y405 w100 h180 Choose1 +Center", ["Circle", "Random", "Grid"])
PlacementPatternText := aaMainUI.Add("Text", "x1250 y385 w105 h20", "Placement type")
placementSaveText := aaMainUI.Add("Text", "x807 y385 w80 h20", "Save Config")
Hotkeytext := aaMainUI.Add("Text", "x807 y35 w530 h30", "To change keybinds click top right settings, Below are default hotkey settings ")
Hotkeytext2 := aaMainUI.Add("Text", "x807 y50 w530 h30", "F1: Chỉnh lại cửa sổ Roblox || F2: Bắt đầu Macro || F3: Thoát Macro || F4: Dừng/Tiếp tục Macro")
;--------------SETTINGS;--------------SETTINGS;--------------SETTINGS;--------------SETTINGS;--------------SETTINGS;--------------SETTINGS;--------------SETTINGS
;--------------MODE SELECT;--------------MODE SELECT;--------------MODE SELECT;--------------MODE SELECT;--------------MODE SELECT;--------------MODE SELECT
global modeSelectionGroup := aaMainUI.Add("GroupBox", "x808 y38 w500 h45 Background" uiTheme[2], "Chọn chế độ")
aaMainUI.SetFont("s10 c" uiTheme[6])
global ModeDropdown := aaMainUI.Add("DropDownList", "x818 y53 w140 h220 Choose1 +Center", ["Infinite", "Story", "Portal", "Daily Infinite Quest", "Farm", "Legend", "Raid", "Infinity Castle", "Dungeon", "Summer Event"])
global MapDropdown := aaMainUI.Add("DropDownList", "x968 y53 w150 h180 Choose1 +Center", ["Planet Greenie", "Walled City", "Snowy Town", "Sand Village", "Navy Bay", "Fiend City", "Spirit World", "Ant Kingdom", "Magic Town", "Haunted Academy", "Magic Hills", "Space Center", "Alien Spaceship", "Fabled Kingdom", "Ruined City", "Puppet Island", "Virtual Dungeon", "Snowy Kingdom", "Dungeon Throne", "Mountain Temple", "Rain Village", "Shibuya District", "Ninja Forest", "Marine Base", "Hollowed Moon"])
global StoryDropdown := aaMainUI.Add("DropDownList", "x968 y53 w150 h180 Choose0 +Center", ["Planet Greenie", "Walled City", "Snowy Town", "Sand Village", "Navy Bay", "Fiend City", "Spirit World", "Ant Kingdom", "Magic Town", "Haunted Academy", "Magic Hills", "Space Center", "Alien Spaceship", "Fabled Kingdom", "Ruined City", "Puppet Island", "Virtual Dungeon", "Snowy Kingdom", "Dungeon Throne", "Mountain Temple", "Rain Village", "Shibuya District"])
global StoryActDropdown := aaMainUI.Add("DropDownList", "x1128 y53 w80 h180 Choose0 +Center", ["Act 1", "Act 2", "Act 3", "Act 4", "Act 5", "Act 6", "Infinity"])
global PortalDropdown := aaMainUI.Add("DropDownList", "x968 y53 w150 h180 Choose0 +Center", ["Shibuya District", "Demons Leader Place"])
global LegendDropDown := aaMainUI.Add("DropDownlist", "x968 y53 w150 h180 Choose0 +Center", ["Magic Hills", "Space Center", "Fabled Kingdom", "Virtual Dungeon", "Dungeon Throne", "Rain Village"])
global LegendActDropdown := aaMainUI.Add("DropDownList", "x1128 y53 w80 h180 Choose0 +Center", ["Act 1", "Act 2", "Act 3"])
global RaidDropdown := aaMainUI.Add("DropDownList", "x968 y53 w150 h180 Choose0 +Center", ["Sacred Planet", "Strange Town", "Ruined City"])
global RaidActDropdown := aaMainUI.Add("DropDownList", "x1128 y53 w80 h180 Choose0 +Center", ["Act 1", "Act 2", "Act 3", "Act 4", "Act 5"])
global InfinityCastleDropdown := aaMainUI.Add("DropDownList", "x968 y53 w80 h180 Choose0 +Center", ["Normal", "Hard"])
global ConfirmButton := aaMainUI.Add("Button", "x1218 y53 w80 h25", "Xác nhận")

MapDropdown.Visible := true
StoryDropdown.Visible := false
StoryActDropdown.Visible := false
PortalDropdown.Visible := false
LegendDropDown.Visible := false
LegendActDropdown.Visible := false
RaidDropdown.Visible := false
RaidActDropdown.Visible := false
InfinityCastleDropdown.Visible := false
MatchMaking.Visible := true
ReturnLobbyBox.Visible := false
Hotkeytext.Visible := false
Hotkeytext2.Visible := false
SaveChestsBox.Visible := false
ModeDropdown.OnEvent("Change", OnModeChange)
StoryDropdown.OnEvent("Change", OnStoryChange)
LegendDropDown.OnEvent("Change", OnLegendChange)
RaidDropdown.OnEvent("Change", OnRaidChange)
ConfirmButton.OnEvent("Click", OnConfirmClick)
SaveChestsBox.OnEvent("Click", ToggleSaveChestsForBoss)

; Tự động load tọa độ khi đổi Map / Mode
OnMapChange() {
    LoadUnitCoordsFromFile()
    UpdatePosButtons()
}

ModeDropdown.OnEvent("Change", (*) => OnMapChange())
MapDropdown.OnEvent("Change", (*) => OnMapChange())
StoryDropdown.OnEvent("Change", (*) => OnMapChange())
LegendDropDown.OnEvent("Change", (*) => OnMapChange())
RaidDropdown.OnEvent("Change", (*) => OnMapChange())
PortalDropdown.OnEvent("Change", (*) => OnMapChange())
;------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI
;------UNIT CONFIGURATION------UNIT CONFIGURATION------UNIT CONFIGURATION/------UNIT CONFIGURATION/------UNIT CONFIGURATION/------UNIT CONFIGURATION/

AddUnitCard(aaMainUI, index, x, y) {
    unit := {}

    unit.Background := aaMainUI.Add("Text", Format("x{} y{} w550 h45 +Background{}", x, y, uiTheme[4]))
    unit.BorderTop := aaMainUI.Add("Text", Format("x{} y{} w550 h2 +Background{}", x, y, uiTheme[3]))
    unit.BorderBottom := aaMainUI.Add("Text", Format("x{} y{} w552 h2 +Background{}", x, y + 45, uiTheme[3]))
    unit.BorderLeft := aaMainUI.Add("Text", Format("x{} y{} w2 h45 +Background{}", x, y, uiTheme[3]))
    unit.BorderRight := aaMainUI.Add("Text", Format("x{} y{} w2 h45 +Background{}", x + 550, y, uiTheme[3]))
    aaMainUI.SetFont("s11 Bold c" uiTheme[1])
    unit.Title := aaMainUI.Add("Text", Format("x{} y{} w60 h25 +BackgroundTrans", x + 30, y + 18), "Unit " index)

    aaMainUI.SetFont("s9 c" uiTheme[1])
    unit.PlacementText := aaMainUI.Add("Text", Format("x{} y{} w70 h20 +BackgroundTrans", x + 100, y + 2), "Placement")
    unit.PriorityText := aaMainUI.Add("Text", Format("x{} y{} w60 h20 BackgroundTrans hidden", x + 180, y + 2), "Priority")
    unit.LimitText := aaMainUI.Add("Text", Format("x{} y{} w72 h20 BackgroundTrans", x + 260, y + 2), "Max Level")
    maxLevels := ["OFF"]
    Loop 20
        maxLevels.Push(A_Index "")
    unit.MaxLevel := aaMainUI.Add("DropDownList", Format("x{} y{} w72 h260 Choose1", x + 260, y + 20), maxLevels)
    unit.PosText := aaMainUI.Add("Text", Format("x{} y{} w60 h20 +BackgroundTrans", x + 472, y + 2), "Position")

    UnitData.Push(unit)
    return unit
}

;Create Unit slot
y_start := 85
y_spacing := 50
Loop 6 {
    AddUnitCard(aaMainUI, A_Index, 808, y_start + ((A_Index - 1) * y_spacing))
}

global enabled1 := aaMainUI.Add("CheckBox", "x818 y105 w15 h15", "")
global enabled2 := aaMainUI.Add("CheckBox", "x818 y155 w15 h15", "")
global enabled3 := aaMainUI.Add("CheckBox", "x818 y205 w15 h15", "")
global enabled4 := aaMainUI.Add("CheckBox", "x818 y255 w15 h15", "")
global enabled5 := aaMainUI.Add("CheckBox", "x818 y305 w15 h15", "")
global enabled6 := aaMainUI.Add("CheckBox", "x818 y355 w15 h15", "")

aaMainUI.SetFont("s8 c" uiTheme[6])

; Placement dropdowns (x+100 = 908)
global placement1 := aaMainUI.Add("DropDownList", "x908 y105 w60 h180 Choose1 +Center", ["1", "2", "3", "4", "5", "6"])
global placement2 := aaMainUI.Add("DropDownList", "x908 y155 w60 h180 Choose1 +Center", ["1", "2", "3", "4", "5", "6"])
global placement3 := aaMainUI.Add("DropDownList", "x908 y205 w60 h180 Choose1 +Center", ["1", "2", "3", "4", "5", "6"])
global placement4 := aaMainUI.Add("DropDownList", "x908 y255 w60 h180 Choose1 +Center", ["1", "2", "3", "4", "5", "6"])
global placement5 := aaMainUI.Add("DropDownList", "x908 y305 w60 h180 Choose1 +Center", ["1", "2", "3", "4", "5", "6"])
global placement6 := aaMainUI.Add("DropDownList", "x908 y355 w60 h180 Choose1 +Center", ["1", "2", "3", "4", "5", "6"])

; Position Buttons (Chọn vị trí đặt Unit từ ảnh Map)
global pos1 := aaMainUI.Add("Button", "x1280 y100 w60 h20 Choose1 +Center", "Pos 1")
pos1.OnEvent("Click", (*) => LoadImage(1))

global pos2 := aaMainUI.Add("Button", "x1280 y150 w60 h20 Choose1 +Center", "Pos 2")
pos2.OnEvent("Click", (*) => LoadImage(2))

global pos3 := aaMainUI.Add("Button", "x1280 y200 w60 h20 Choose1 +Center", "Pos 3")
pos3.OnEvent("Click", (*) => LoadImage(3))

global pos4 := aaMainUI.Add("Button", "x1280 y250 w60 h20 Choose1 +Center", "Pos 4")
pos4.OnEvent("Click", (*) => LoadImage(4))

global pos5 := aaMainUI.Add("Button", "x1280 y300 w60 h20 Choose1 +Center", "Pos 5")
pos5.OnEvent("Click", (*) => LoadImage(5))

global pos6 := aaMainUI.Add("Button", "x1280 y350 w60 h20 Choose1 +Center", "Pos 6")
pos6.OnEvent("Click", (*) => LoadImage(6))

; Upgrade priority dropdowns
global Priority1 := aaMainUI.Add("DropDownList", "x990 y105 w60 h180 Choose1 +Center Hidden", ["1", "2", "3", "4", "5", "6"])
global Priority2 := aaMainUI.Add("DropDownList", "x990 y155 w60 h180 Choose2 +Center Hidden", ["1", "2", "3", "4", "5", "6"])
global Priority3 := aaMainUI.Add("DropDownList", "x990 y205 w60 h180 Choose3 +Center Hidden", ["1", "2", "3", "4", "5", "6"])
global Priority4 := aaMainUI.Add("DropDownList", "x990 y255 w60 h180 Choose4 +Center Hidden", ["1", "2", "3", "4", "5", "6"])
global Priority5 := aaMainUI.Add("DropDownList", "x990 y305 w60 h180 Choose5 +Center Hidden", ["1", "2", "3", "4", "5", "6"])
global Priority6 := aaMainUI.Add("DropDownList", "x990 y355 w60 h180 Choose6 +Center Hidden", ["1", "2", "3", "4", "5", "6"])

PriorityUpgrade.OnEvent("Click", TogglePriorityDropdowns)
readInSettings()
UpdatePosButtons()
; Rebuild the saved mode's control set without collapsing the mode selector.
; OnConfirmClick() used to hide every mode control here, so the selector was
; gone as soon as the macro started. Only a real Confirm click hides it now.
; OnModeChange() sets Summer matchmaking to 1, so keep the value loaded from
; Configuration.txt instead of overwriting the user's saved choice.
savedMatchmaking := MatchMaking.Value
try OnModeChange()
MatchMaking.Value := savedMatchmaking
try ConfirmModeSelection(false)
aaMainUI.Show("w1366 h633")
WinMove(0, 0, , , "ahk_id " aaMainUIHwnd)
forceRobloxSize()  ; Initial force size and position
;------UNIT CONFIGURATION ;------UNIT CONFIGURATION ;------UNIT CONFIGURATION ;------UNIT CONFIGURATION ;------UNIT CONFIGURATION ;------UNIT CONFIGURATION ;------UNIT CONFIGURATION
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
    ; Was Sleep(50): this runs on every state change, so 50 ms each time
    ; added up to minutes over a session. 1 ms still yields the thread.
    Sleep(1)
    ; Log reads can briefly hold this file open on Windows. Logging is
    ; best-effort: a sharing violation must never terminate the game macro.
    try FileAppend(current . " " . elapsedTime . "`n", currentOutputFile)
    catch as logError {
        ; The live UI above still records the latest process line.
    }

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

    ; A maximized Roblox window ignores WinMove: the game stays at full
    ; resolution while every coordinate in this macro assumes
    ; targetWidth x targetHeight. That mismatch silently breaks every
    ; FindText/PixelSearch and every FixClick, so restore first.
    try WinRestore(rblxID)

    WinGetPos(&X, &Y, &OutWidth, &OutHeight, rblxID)

    ; Exit fullscreen if needed
    if (OutWidth >= A_ScreenWidth && OutHeight >= A_ScreenHeight) {
        Send("{F11}")
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

    ; Only shout when it did not work: this is the one condition that makes
    ; the whole macro fail with no obvious cause in the log.
    if (OutWidth != targetWidth || OutHeight != targetHeight) {
        WinGetClientPos(&cx, &cy, &cw, &ch, rblxID)
        ProcessLog("WARN cannot resize Roblox: " . OutWidth . "x" . OutHeight
            . " (client " . cw . "x" . ch . "), expected "
            . targetWidth . "x" . targetHeight)
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
    WinMove(x + offsetX, y + offsetY, , , rblxID)
    WinActivate(rblxID)
}

forceRobloxSize() {
    global rblxID

    if !WinExist(rblxID) {
        checkCount := 0
        While !WinExist(rblxID) {
            Sleep(5000)
            if (checkCount >= 5) {
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

    ; One line at startup so the log always records what the macro is
    ; actually working with. Every hardcoded coordinate depends on this.
    WinGetClientPos(&cx, &cy, &cw, &ch, rblxID)
    ProcessLog("Roblox client area: " . cw . "x" . ch)

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

; try to re-size the roblox to match the macro
checkSizeTimer() {
    if (WinExist("ahk_exe RobloxPlayerBeta.exe")) {
        WinGetPos(&X, &Y, &OutWidth, &OutHeight, "ahk_exe RobloxPlayerBeta.exe")
        if (OutWidth != 816 || OutHeight != 638) {
            ProcessLog("Fixing Roblox window size")
            moveRobloxWindow()
        }
    }
}
