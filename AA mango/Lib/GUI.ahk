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
global version := "v4.2"
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
uiTheme.Push("0xE9EDF5")  ; Header color
uiTheme.Push("0x242937")  ; Background color
uiTheme.Push("0x41495C")  ; Border color
uiTheme.Push("0x2C3242")  ; Accent color
uiTheme.Push("0xFF00FE")  ; Reserved viewport chroma key; never use text/black here.
uiTheme.Push("0x000000")  ; Textbox color
uiTheme.Push("0x92EEAA")  ; HighLight
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
uiBorders.Push(aaMainUI.Add("Text", "x0 y0 w1628 h1 +Background" uiTheme[3]))  ;Top line
uiBorders.Push(aaMainUI.Add("Text", "x0 y0 w1 h977 +Background" uiTheme[3]))   ;Left line
uiBorders.Push(aaMainUI.Add("Text", "x1627 y0 w1 h977 +Background" uiTheme[3])) ;Right line
uiBackgrounds.Push(aaMainUI.Add("Text", "x3 y3 w1624 h27 +Background" uiTheme[2])) ;Title Top
uiBorders.Push(aaMainUI.Add("Text", "x0 y30 w1627 h1 +Background" uiTheme[3])) ;Title bottom
uiBorders.Push(aaMainUI.Add("Text", "x802 y30 w1 h600 +Background" uiTheme[3])) ;Roblox Right
uiBorders.Push(aaMainUI.Add("Text", "x1285 y30 w1 h947 +Background" uiTheme[3])) ;Process column
uiBorders.Push(aaMainUI.Add("Text", "x1287 y32 w340 h1 +Background" uiTheme[3])) ;Process Top
uiBorders.Push(aaMainUI.Add("Text", "x1287 y62 w340 h1 +Background" uiTheme[3])) ;Process bottom
uiBorders.Push(aaMainUI.Add("Text", "x0 y977 w1628 h1 +Background" uiTheme[3], "")) ;Roblox bottom

global MyLogo := aaMainUI.Add("Picture", "x1020 y-1 w32 h32", KurumiLogo)
global robloxHolder := aaMainUI.Add("Text", "x3 y33 w797 h597 +Background" uiTheme[5], "") ;Roblox window box
global Discord := aaMainUI.Add("Picture", "x1517 y-4 w42 h42 +BackgroundTrans", Discord) ;Discord logo
Discord.OnEvent("Click", (*) => OpenDiscordLink()) ;Open discord
global exitButton := aaMainUI.Add("Picture", "x1592 y1 w32 h32 +BackgroundTrans", Exitbutton) ;Exit image
exitButton.OnEvent("Click", (*) => Destroy()) ;Exit button
global minimizeButton := aaMainUI.Add("Picture", "x1562 y3 w27 h27 +Background" uiTheme[2], Minimize) ;Minimize gui
minimizeButton.OnEvent("Click", (*) => minimizeUI()) ;Minimize gui

aaMainUI.SetFont("Bold s15 c" uiTheme[1], "Segoe UI") ;Font
global windowTitle := aaMainUI.Add("Text", "x10 y3 w1200 h29 +BackgroundTrans", aaTitle version) ;Title
aaMainUI.Add("Text", "x1289 y34 w336 h25 +Center +BackgroundTrans", "Process") ;Process header
aaMainUI.SetFont("Bold s11 c" uiTheme[1]) ;Font
global ProcessRows := []
Loop 32 {
    color := A_Index = 1 ? uiTheme[7] : uiTheme[1]
    row := aaMainUI.Add("Text", "x1297 y74 w320 h28 Hidden +0x80 Background" uiTheme[2] " c" color,
        A_Index = 1 ? "➤ Made by KuruMacro" : "")
    row.SetFont("Bold s" (A_Index = 1 ? 12 : 10), "Segoe UI")
    ProcessRows.Push(row)
}
global ProcessTimeline := 0
try ProcessTimeline := KuruTimeline(aaMainUI, 1287, 64, 340, 565)
LoadRecentProcessHistory()
WinSetTransColor(uiTheme[5], aaMainUI) ;Roblox window box

;--------------SETTINGS;--------------SETTINGS;--------------SETTINGS;--------------SETTINGS;--------------SETTINGS;--------------SETTINGS;--------------SETTINGS
global ConfigPopups := Map(), PrioritySlotLabels := [], PriorityPanelTitle := 0

OpenConfigPopup(kind, *) {
    global ConfigPopups, F1Box, F2Box, F3Box, F4Box
    if ConfigPopups.Has(kind) {
        KuruMotion.Open(ConfigPopups[kind])
        return
    }
    popup := Gui("+Owner" aaMainUIHwnd " -MinimizeBox", kind)
    popup.BackColor := uiTheme[2]
    popup.SetFont("Bold s10 c" uiTheme[1], "Segoe UI")
    popup.OnEvent("Close", ObjBindMethod(KuruMotion, "Close", popup))
    popup.OnEvent("Escape", ObjBindMethod(KuruMotion, "Close", popup))
    ConfigPopups[kind] := popup
    switch kind {
        case "Keybinds":
            for index, label in ["Position Roblox", "Start macro", "Reload / stop", "Pause / resume"] {
                y := 18 + (index - 1) * 38
                popup.Add("Text", "x18 y" y " w180 h24", label)
                keyName := "F" index "Key"
                boxName := "F" index "Box"
                %boxName% := popup.Add("Edit", "x210 y" y " w105 h24 c" uiTheme[6], %keyName%)
            }
            popup.Add("Button", "x210 y175 w105 h28", "Save").OnEvent("Click", SaveKeybindSettings)
            popup.SetFont("Bold s9 c" uiTheme[1])
            KuruButtons.Apply(popup)
            KuruMotion.Open(popup, "w340 h225")
        case "Discord":
            popup.Add("Text", "x18 y18", "Webhook URL")
            global WebhookURLBox := popup.Add("Edit", "x18 y45 w370 h24 Password c" uiTheme[6])
            popup.Add("Text", "x18 y85", "Discord ID (optional)")
            global DiscordUserIDBox := popup.Add("Edit", "x18 y112 w370 h24 c" uiTheme[6])
            global SendActivityLogsBox := popup.Add("Checkbox", "x18 y155", "Send Process")
            if FileExist(WebhookURLFile)
                WebhookURLBox.Value := FileRead(WebhookURLFile, "UTF-8")
            if FileExist(DiscordUserIDFile)
                DiscordUserIDBox.Value := FileRead(DiscordUserIDFile, "UTF-8")
            if FileExist(SendActivityLogsFile)
                SendActivityLogsBox.Value := Trim(FileRead(SendActivityLogsFile, "UTF-8")) = "1"
            popup.Add("Button", "x278 y150 w110 h28", "Save").OnEvent("Click", (*) => SaveWebhookSettings())
            KuruButtons.Apply(popup)
            KuruMotion.Open(popup, "w410 h200")
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
placementSaveBtn := aaMainUI.Add("Button", "x818 y515 w80 h24", "Save")
placementSaveBtn.OnEvent("Click", SaveSettings)

aaMainUI.SetFont("Bold s9")
global NextLevelBox := aaMainUI.Add("Checkbox", "x1225 y485 w125 h22 c0xb5b3b3 Checked", "Next Level")
global NextRoomBox := aaMainUI.Add("Checkbox", "x1225 y485 w125 h22 c0xb5b3b3 Checked Hidden", "Next Room")
global ReplayBox := aaMainUI.Add("Checkbox", "x980 y485 w100 h22 c0xb5b3b3 Checked", "Replay")
; Start in solo Play Here mode to avoid unattended matchmaking CAPTCHA prompts.
global MatchMaking := aaMainUI.Add("Checkbox", "x1090 y485 w130 h22 c0xb5b3b3", "Matchmaking")
global ReturnLobbyBox := aaMainUI.Add("Checkbox", "x818 y485 w150 h22 c0xb5b3b3", "Return To Lobby")
MatchMaking.OnEvent("Click", (*) => UpdateResultOptionsForMode(ModeDropdown.Text))
ReturnLobbyBox.OnEvent("Click", (*) => UpdateResultOptionsForMode(ModeDropdown.Text))
global AutoAbilityBox := aaMainUI.Add("CheckBox", "x920 y515 w120 h22 c0xb5b3b3 Checked", "Auto Ability")
global PriorityUpgrade := aaMainUI.Add("CheckBox", "x1045 y515 w145 h22 c0xb5b3b3", "Priority Upgrade")
global SaveChestsBox := aaMainUI.Add("CheckBox", "x818 y545 w280 h22 c0xb5b3b3 Checked", "Save Chests For Rukia")
global PlacementPatternDropdown := aaMainUI.Add("DropDownList", "x1200 y530 w140 h180 Choose1 +Center", ["Circle", "Random", "Grid", "Smart"])
PlacementPatternText := aaMainUI.Add("Text", "x1200 y510 w145 h20", "Placement type")
placementSaveText := aaMainUI.Add("Text", "x818 y470 w90 h16", "Save Config")
Hotkeytext := aaMainUI.Add("Text", "x807 y35 w530 h30", "Configure keybinds in the Settings panel below ")
Hotkeytext2 := aaMainUI.Add("Text", "x807 y50 w530 h30", "F1: Chỉnh lại cửa sổ Roblox || F2: Bắt đầu Macro || F3: Thoát Macro || F4: Dừng/Tiếp tục Macro")
;--------------SETTINGS;--------------SETTINGS;--------------SETTINGS;--------------SETTINGS;--------------SETTINGS;--------------SETTINGS;--------------SETTINGS
;--------------MODE SELECT;--------------MODE SELECT;--------------MODE SELECT;--------------MODE SELECT;--------------MODE SELECT;--------------MODE SELECT
global modeSelectionGroup := aaMainUI.Add("GroupBox", "x808 y38 w500 h45 Background" uiTheme[2], "Chọn chế độ")
aaMainUI.SetFont("Bold s10 c" uiTheme[6])
global ModeDropdown := aaMainUI.Add("DropDownList", "x818 y53 w140 h240 Choose1 +Center", ["Infinite", "Story", "Portal", "Daily Infinite Quest", "Farm", "Legend", "Raid", "Infinity Castle", "Dungeon", "Summer Event", "Infinity Mansion"])
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
    unit.Background := aaMainUI.Add("Text", Format("x{} y{} w470 h34 +0x04000000 +Background{}", x, y, uiTheme[4]))
    unit.BorderBottom := aaMainUI.Add("Text", Format("x{} y{} w470 h1 +Background{}", x, y + 34, uiTheme[3]))
    aaMainUI.SetFont("s11 Bold c" uiTheme[1])
    unit.Title := aaMainUI.Add("Text", Format("x{} y{} w60 h25 BackgroundTrans", x + 30, y + 6), "Unit " index)
    aaMainUI.SetFont("Bold s9  c" uiTheme[1])
    hidden := index = 1 ? "" : " Hidden"
    unit.PlacementText := aaMainUI.Add("Text", "x908 y89 w60 h20 BackgroundTrans" hidden, "Count")
    unit.PriorityText := aaMainUI.Add("Text", "x978 y89 w45 h20 BackgroundTrans Hidden", "Prio")
    unit.LimitText := aaMainUI.Add("Text", "x988 y89 w72 h20 BackgroundTrans" hidden, "Max Level")
    unit.TypeText := aaMainUI.Add("Text", "x1078 y89 w100 h20 BackgroundTrans" hidden, "Type")
    unit.PosText := aaMainUI.Add("Text", "x1200 y89 w60 h20 BackgroundTrans" hidden, "Position")
    maxLevels := ["OFF"]
    Loop 20
        maxLevels.Push(A_Index "")
    unit.MaxLevel := aaMainUI.Add("DropDownList", "x988 y" (y + 5) " w72 h260 Choose1", maxLevels)
    unit.Type := aaMainUI.Add("DropDownList", "x1078 y" (y + 5) " w100 h160 Choose2", ["Farm", "Ground", "Hill", "Hybrid"])
    UnitData.Push(unit)
    return unit
}

;Create Unit slot
y_start := 110
y_spacing := 36
Loop 6 {
    AddUnitCard(aaMainUI, A_Index, 808, y_start + ((A_Index - 1) * y_spacing))
}

global enabled1 := aaMainUI.Add("CheckBox", "x818 y118 w15 h15", "")
global enabled2 := aaMainUI.Add("CheckBox", "x818 y154 w15 h15", "")
global enabled3 := aaMainUI.Add("CheckBox", "x818 y190 w15 h15", "")
global enabled4 := aaMainUI.Add("CheckBox", "x818 y226 w15 h15", "")
global enabled5 := aaMainUI.Add("CheckBox", "x818 y262 w15 h15", "")
global enabled6 := aaMainUI.Add("CheckBox", "x818 y298 w15 h15", "")

aaMainUI.SetFont("Bold s10 c" uiTheme[6])

; Placement dropdowns (x+100 = 908)
global placement1 := aaMainUI.Add("DropDownList", "x908 y115 w60 h180 Choose1 +Center", ["1", "2", "3", "4", "5", "6"])
global placement2 := aaMainUI.Add("DropDownList", "x908 y151 w60 h180 Choose1 +Center", ["1", "2", "3", "4", "5", "6"])
global placement3 := aaMainUI.Add("DropDownList", "x908 y187 w60 h180 Choose1 +Center", ["1", "2", "3", "4", "5", "6"])
global placement4 := aaMainUI.Add("DropDownList", "x908 y223 w60 h180 Choose1 +Center", ["1", "2", "3", "4", "5", "6"])
global placement5 := aaMainUI.Add("DropDownList", "x908 y259 w60 h180 Choose1 +Center", ["1", "2", "3", "4", "5", "6"])
global placement6 := aaMainUI.Add("DropDownList", "x908 y295 w60 h180 Choose1 +Center", ["1", "2", "3", "4", "5", "6"])

; Position Buttons (Chọn vị trí đặt Unit từ ảnh Map)
global pos1 := aaMainUI.Add("Button", "x1200 y115 w60 h20 Choose1 +Center", "Pos 1")
pos1.OnEvent("Click", (*) => LoadImage(1))

global pos2 := aaMainUI.Add("Button", "x1200 y151 w60 h20 Choose1 +Center", "Pos 2")
pos2.OnEvent("Click", (*) => LoadImage(2))

global pos3 := aaMainUI.Add("Button", "x1200 y187 w60 h20 Choose1 +Center", "Pos 3")
pos3.OnEvent("Click", (*) => LoadImage(3))

global pos4 := aaMainUI.Add("Button", "x1200 y223 w60 h20 Choose1 +Center", "Pos 4")
pos4.OnEvent("Click", (*) => LoadImage(4))

global pos5 := aaMainUI.Add("Button", "x1200 y259 w60 h20 Choose1 +Center", "Pos 5")
pos5.OnEvent("Click", (*) => LoadImage(5))

global pos6 := aaMainUI.Add("Button", "x1200 y295 w60 h20 Choose1 +Center", "Pos 6")
pos6.OnEvent("Click", (*) => LoadImage(6))

; Upgrade priority dropdowns
global Priority1 := aaMainUI.Add("DropDownList", "x818 y548 w60 h180 Choose1 +Center Hidden", ["1", "2", "3", "4", "5", "6"])
global Priority2 := aaMainUI.Add("DropDownList", "x894 y548 w60 h180 Choose2 +Center Hidden", ["1", "2", "3", "4", "5", "6"])
global Priority3 := aaMainUI.Add("DropDownList", "x970 y548 w60 h180 Choose3 +Center Hidden", ["1", "2", "3", "4", "5", "6"])
global Priority4 := aaMainUI.Add("DropDownList", "x1046 y548 w60 h180 Choose4 +Center Hidden", ["1", "2", "3", "4", "5", "6"])
global Priority5 := aaMainUI.Add("DropDownList", "x1122 y548 w60 h180 Choose5 +Center Hidden", ["1", "2", "3", "4", "5", "6"])
global Priority6 := aaMainUI.Add("DropDownList", "x1198 y548 w60 h180 Choose6 +Center Hidden", ["1", "2", "3", "4", "5", "6"])

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
ApplyCompactLayout()
try KuruButtons.Apply(aaMainUI)
aaMainUI.Show("x0 y0 w1630 h633")
LayoutProcessHistory()
forceRobloxSize()  ; Initial force size and position

;------UNIT CONFIGURATION ;------UNIT CONFIGURATION ;------UNIT CONFIGURATION ;------UNIT CONFIGURATION ;------UNIT CONFIGURATION ;------UNIT CONFIGURATION ;------UNIT CONFIGURATION
;------FUNCTIONS;------FUNCTIONS;------FUNCTIONS;------FUNCTIONS;------FUNCTIONS;------FUNCTIONS;------FUNCTIONS;------FUNCTIONS;------FUNCTIONS;------FUNCTIONS;------FUNCTIONS

;Process text
ProcessLog(current) {
    global ProcessRows, currentOutputFile, lastlog
    Loop ProcessRows.Length {
        index := ProcessRows.Length - A_Index + 1
        ProcessRows[index].Value := index = 1 ? "➤ " current : StrReplace(ProcessRows[index - 1].Value, "➤ ", "")
    }

    LayoutProcessHistory(true)

    elapsedTime := getElapsedTime()
    ; Rendering is queued separately; logging must not insert scheduler sleeps.
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
    moveRobloxWindow() ; Includes sizing; do it once before measuring the final client.

    ; One line at startup so the log always records what the macro is
    ; actually working with. Every hardcoded coordinate depends on this.
    WinGetClientPos(&cx, &cy, &cw, &ch, rblxID)
    ProcessLog("Roblox client area: " . cw . "x" . ch)

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


ApplyCompactLayout() {
    global UnitData, PrioritySlotLabels, PriorityPanelTitle
    modeSelectionGroup.Move(,,470)
    ConfirmButton.Move(1198,,70)
    ConfirmButton.Text := "Confirm"
    for ctrl in [StoryActDropdown, LegendActDropdown, RaidActDropdown]
        ctrl.Move(1128,,60)
    ReturnLobbyBox.Move(818, 397, 150)
    ReplayBox.Move(970, 397, 80)
    MatchMaking.Move(1055, 397, 120)
    NextLevelBox.Move(1175, 397, 100)
    NextRoomBox.Move(1175, 397, 100)
    placementSaveText.Visible := false
    placementSaveBtn.Move(818, 353, 80, 28)
    AutoAbilityBox.Move(910, 357, 110)
    PriorityUpgrade.Move(1025, 357, 135)
    PlacementPatternText.Text := "Placing"
    PlacementPatternText.Move(1193, 336, 80)
    ResizePlacingDropdown()
    PlacementPatternDropdown.OnEvent("Change", ResizePlacingDropdown)
    SaveChestsBox.Move(818, 423, 280)
    aaMainUI.SetFont("Bold s10", "Segoe UI")
    for index, label in ["Keybinds", "Discord"]
        aaMainUI.Add("Button", "x" (818 + (index - 1)*156) " y454 w148 h28", label).OnEvent("Click", OpenConfigPopup.Bind(label))
    aaMainUI.SetFont("Bold s9  c" uiTheme[1], "Segoe UI")
    PriorityPanelTitle := aaMainUI.Add("Text", "x818 y500 w440 h20 Hidden", "Upgrade priority")
    Loop 6
        PrioritySlotLabels.Push(aaMainUI.Add("Text", "x" (818 + (A_Index - 1)*76) " y525 w60 h18 Hidden", "Unit " A_Index))
    LayoutUnitColumns()
    for border in uiBorders {
        border.GetPos(&x, &y, &w, &h)
        if (x = 0 && w = 1) || x = 1627
            border.Move(,,,630)
        else if x = 1285
            border.Move(,,,600)
        else if x = 0 && w > 1600 && h = 1 && y > 600
            border.Move(,630)
    }
}

LayoutUnitColumns() {
    active := !!PriorityUpgrade.Value
    columns := active ? [[904, 50], [962, 72], [1042, 94], [1144, 56]]
        : [[908, 60], [988, 72], [1078, 100], [1200, 60]]
    ; Move all siblings together, then repaint their old and new bounds once.
    visible := DllCall("IsWindowVisible", "Ptr", aaMainUI.Hwnd)
    if visible
        DllCall("SendMessageW", "Ptr", aaMainUI.Hwnd, "UInt", 0xB, "Ptr", 0, "Ptr", 0)
    try {
    for index, unit in UnitData {
        DllCall("SetWindowPos", "Ptr", unit.Background.Hwnd, "Ptr", 1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x13)
        countName := "placement" index, posName := "pos" index, priorityName := "priority" index
        controls := [%countName%, unit.MaxLevel, unit.Type, %posName%]
        headers := [unit.PlacementText, unit.LimitText, unit.TypeText, unit.PosText]
        for col, control in controls {
            control.Move(columns[col][1], 115 + (index - 1)*36, columns[col][2])
            ; Static row backgrounds otherwise precede and cover these siblings.
            DllCall("SetWindowPos", "Ptr", control.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x13)
            headers[col].Move(columns[col][1], 89, columns[col][2])
        }
        %priorityName%.Move(1208, 115 + (index - 1)*36, 60)
        DllCall("SetWindowPos", "Ptr", %priorityName%.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x13)
        %priorityName%.Visible := active
        unit.PriorityText.Text := "Priority"
        unit.PriorityText.Move(1208, 89, 60)
        unit.PriorityText.Visible := active && index = 1
    }
    for ctrl in PrioritySlotLabels
        ctrl.Visible := false
    if IsObject(PriorityPanelTitle)
        PriorityPanelTitle.Visible := false
    } finally {
        if visible {
            DllCall("SendMessageW", "Ptr", aaMainUI.Hwnd, "UInt", 0xB, "Ptr", 1, "Ptr", 0)
            DllCall("RedrawWindow", "Ptr", aaMainUI.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x185)
        }
    }
}


LoadRecentProcessHistory() {
    global ProcessRows, currentOutputFile
    try {
        file := FileOpen(currentOutputFile, "r", "UTF-8")
        if !IsObject(file)
            return
        try {
            offset := Max(0, file.Length - 32768)
            file.Pos := offset
            lines := StrSplit(file.Read(), "`n", "`r")
        } finally {
            file.Close()
        }
        row := 1
        Loop lines.Length {
            index := lines.Length - A_Index + 1
            if offset > 0 && index = 1
                break
            entry := Trim(lines[index])
            if entry = "" || RegExMatch(entry, "^(?:==|Start Time:)") || RegExMatch(entry, "i)^Smart:.*(?:press F6|calibration required|sampled preview)")
                continue
            ProcessRows[row].Value := (row = 1 ? "➤ " : "") entry
            row++
            if row > ProcessRows.Length
                break
        }
    } catch {
        ; History is optional; current-session logging remains available.
    }
}


MeasureGuiText(ctrl, text, width := 0) {
    scale := A_ScreenDPI / 96
    rect := Buffer(16, 0)
    NumPut("Int", Round(width * scale), rect, 8)
    dc := DllCall("GetDC", "Ptr", ctrl.Hwnd, "Ptr")
    if !dc
        throw Error("Could not measure GUI text")
    font := DllCall("SendMessageW", "Ptr", ctrl.Hwnd, "UInt", 0x31, "Ptr", 0, "Ptr", 0, "Ptr")
    previous := DllCall("SelectObject", "Ptr", dc, "Ptr", font, "Ptr")
    try {
        flags := width > 0 ? 0xC10 : 0xC20 ; calculate bounds, no prefix, wrap/single line
        DllCall("DrawTextW", "Ptr", dc, "Str", text, "Int", -1, "Ptr", rect, "UInt", flags)
        return {w: Ceil(NumGet(rect, 8, "Int") / scale), h: Ceil(NumGet(rect, 12, "Int") / scale)}
    } finally {
        DllCall("SelectObject", "Ptr", dc, "Ptr", previous)
        DllCall("ReleaseDC", "Ptr", ctrl.Hwnd, "Ptr", dc)
    }
}

LayoutProcessHistory(animate := false) {
    global ProcessTimeline
    if IsObject(ProcessTimeline) && !ProcessTimeline.failed {
        try {
            if ProcessTimeline.QueueRefresh(ProcessRows, animate) {
                if !ProcessTimeline.HasOwnProp("nativeHidden") {
                    for row in ProcessRows
                        row.Visible := false
                    ProcessTimeline.nativeHidden := true
                }
                return
            }
        } catch {
            ProcessTimeline.failed := true
            try ProcessTimeline.view.Visible := false
            try SetTimer(ProcessTimeline.tickCallback, 0)
        }
    }
    y := 74, overflow := false
    visible := DllCall("IsWindowVisible", "Ptr", aaMainUIHwnd)
    if visible
        DllCall("SendMessageW", "Ptr", aaMainUIHwnd, "UInt", 0xB, "Ptr", 0, "Ptr", 0)
    try {
        ; Hide old bounds first; opaque backgrounds plus one regional repaint
        ; prevent previous glyphs remaining behind a resized/moved log row.
        for row in ProcessRows
            row.Visible := false
        for index, row in ProcessRows {
            if overflow || row.Value = ""
                continue
            try height := Max(index = 1 ? 28 : 24, MeasureGuiText(row, row.Value, 312).h + 8)
            catch
                height := 621 - y
            if y + height > 621 {
                overflow := true
                if index != 1
                    continue
                height := 621 - y
            }
            row.Move(1297, y, 320, height)
            row.Visible := true
            y += height + 6
        }
    } finally {
        if visible {
            DllCall("SendMessageW", "Ptr", aaMainUIHwnd, "UInt", 0xB, "Ptr", 1, "Ptr", 0)
            scale := A_ScreenDPI / 96
            rect := Buffer(16, 0)
            NumPut("Int", Round(1287*scale), "Int", Round(63*scale), "Int", Round(1626*scale), "Int", Round(629*scale), rect)
            DllCall("RedrawWindow", "Ptr", aaMainUIHwnd, "Ptr", rect, "Ptr", 0, "UInt", 0x185)
        }
    }
}

ResizePlacingDropdown(*) {
    try width := Max(72, MeasureGuiText(PlacementPatternDropdown, PlacementPatternDropdown.Text).w + 30)
    catch
        width := 80
    width := Min(100, width)
    PlacementPatternDropdown.Move(1273 - width, 358, width)
    PlacementPatternText.Move(1273 - width, 336, width)
}
