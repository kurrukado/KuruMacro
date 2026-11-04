#Requires AutoHotkey v2.0
#SingleInstance Force

; Basic Application Info
global arTitle := "Anime Rangers X - by KuruDev "
global version := "- update 2.5"
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
global nav := 0
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
global arMainUI := Gui("+AlwaysOnTop -Caption")
global lastlog := ""
global arMainUIHwnd := arMainUI.Hwnd
;Theme colors
uiTheme.Push("0xb5b3b3")  ; Header color
uiTheme.Push("0x3d3d3d")  ; Background color
uiTheme.Push("0x818080")  ; Border color
uiTheme.Push("0xC0C0C0")  ; Accent color
uiTheme.Push("0xF9F9F9")  ; Trans color
uiTheme.Push("0x000000")  ; Textbox color
uiTheme.Push("0x4d9e6c")  ; HighLight
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
arMainUI.BackColor := uiTheme[2]
global Webhookdiverter := arMainUI.Add("Edit", "x0 y0 w1 h1 +Hidden", "") ; diversion
uiBorders.Push(arMainUI.Add("Text", "x0 y0 w1464 h1 +Background" uiTheme[3]))  ;Top line
uiBorders.Push(arMainUI.Add("Text", "x0 y0 w1 h630 +Background" uiTheme[3]))   ;Left line
uiBorders.Push(arMainUI.Add("Text", "x1463 y0 w1 h630 +Background" uiTheme[3])) ;Right line
uiBackgrounds.Push(arMainUI.Add("Text", "x3 y3 w1460 h27 +Background" uiTheme[2])) ;Title Top
uiBorders.Push(arMainUI.Add("Text", "x0 y30 w1463 h1 +Background" uiTheme[3])) ;Title bottom
uiBorders.Push(arMainUI.Add("Text", "x802 y30 w1 h600 +Background" uiTheme[3])) ;Roblox Right
uiBorders.Push(arMainUI.Add("Text", "x803 y433 w660 h1 +Background" uiTheme[3])) ;Process Top
uiBorders.Push(arMainUI.Add("Text", "x803 y461 w660 h1 +Background" uiTheme[3])) ;Process bottom
uiBorders.Push(arMainUI.Add("Text", "x0 y630 w1464 h1 +Background" uiTheme[3], "")) ;Roblox bottom
uiBorders.Push(arMainUI.Add("Text", "x803 y110 w660 h1 +Background" uiTheme[3])) ;Dev message Top
uiBorders.Push(arMainUI.Add("Text", "x803 y180 w660 h1 +Background" uiTheme[3])) ;Dev message bottom

; private server link
arMainUI.Add("GroupBox", "x810 y300 w155 h125 c" uiTheme[1], "Keybinds") ; key changer
arMainUI.Add("Text", "x860 y325 c" uiTheme[1], "Position Roblox")
global F1Box := arMainUI.Add("Edit", "x820 y320 w30 h20 c" uiTheme[6], F1Key)
arMainUI.Add("Text", "x860 y345 c" uiTheme[1], "Start Macro")
global F2Box := arMainUI.Add("Edit", "x820 y340 w30 h20 c" uiTheme[6], F2Key)
arMainUI.Add("Text", "x860 y365 c" uiTheme[1], "Stop Macro")
global F3Box := arMainUI.Add("Edit", "x820 y360 w30 h20 c" uiTheme[6], F3Key)
arMainUI.Add("Text", "x860 y385 c" uiTheme[1], "Pause Macro")
global F4Box := arMainUI.Add("Edit", "x820 y380 w30 h20 c" uiTheme[6], F4Key)
keybindSaveBtn := arMainUI.Add("Button", "x820 y405 w50 h15", "Save")
keybindSaveBtn.OnEvent("Click", SaveKeybindSettings)

global MyLogo := arMainUI.Add("Picture", "x1315 y-1 w32 h32", KurumiLogo) ; dev logo
global robloxHolder := arMainUI.Add("Text", "x3 y33 w797 h597 +Background" uiTheme[5], "") ;Roblox window box
global Discord := arMainUI.Add("Picture", "x1355 y-4 w42 h42 +BackgroundTrans", Discord) ;Discord logo
Discord.OnEvent("Click", (*) => OpenDiscordLink()) ;Open discord
global exitButton := arMainUI.Add("Picture", "x1430 y1 w32 h32 +BackgroundTrans", Exitbutton) ;Exit image
exitButton.OnEvent("Click", (*) => Destroy()) ;Exit button
global minimizeButton := arMainUI.Add("Picture", "x1400 y3 w27 h27 +Background" uiTheme[2], Minimize) ;Minimize gui
minimizeButton.OnEvent("Click", (*) => minimizeUI()) ;Minimize gui

arMainUI.SetFont("Bold s16 c" uiTheme[1], "Verdana") ;Font
global windowTitle := arMainUI.Add("Text", "x10 y3 w1200 h29 +BackgroundTrans", arTitle "" . "" version) ;Title
arMainUI.Add("Text", "x805 y435 w658 h25 +Center +BackgroundTrans", "Process") ;Process header
arMainUI.SetFont("norm s11 c" uiTheme[1]) ;Font
global process1 := arMainUI.Add("Text", "x810 y470 w538 h18 +BackgroundTrans c" uiTheme[7], "➤ Made by KuruDev") ;Processes
global process2 := arMainUI.Add("Text", "xp yp+22 w538 h18 +BackgroundTrans", "")
global process3 := arMainUI.Add("Text", "xp yp+22 w538 h18 +BackgroundTrans", "")
global process4 := arMainUI.Add("Text", "xp yp+22 w538 h18 +BackgroundTrans", "")
global process5 := arMainUI.Add("Text", "xp yp+22 w538 h18 +BackgroundTrans", "")
global process6 := arMainUI.Add("Text", "xp yp+22 w538 h18 +BackgroundTrans", "")
global process7 := arMainUI.Add("Text", "xp yp+22 w538 h18 +BackgroundTrans", "")
WinSetTransColor(uiTheme[5], arMainUI) ;Roblox window box

arMainUI.SetFont("s12 Bold c" uiTheme[1])

arMainUI.SetFont("s9")
Hotkeytext := arMainUI.Add("Text", "x807 y35 w540 h30", "To change keybinds click top right settings, Below are default hotkey settings ")
Hotkeytext2 := arMainUI.Add("Text", "x807 y50 w540 h30", "F1: Resize ROBLOX || F2: Start Macro || F3: Exit Macro || F4: Pause/Continue Macro")
DevMessage := arMainUI.Add("Text", "x807 y115 w540 h30", "- Select your own upgrade priority before running")
DevMessage2 := arMainUI.Add("Text", "x807 y132 w540 h30", "- Leave a message if you have any idea")
; Webhook
arMainUI.Add("Text", "x805 y195 c" uiTheme[1], "Webhook URL")               ; Webhook Text
arMainUI.Add("Text", "x805 y220 c" uiTheme[1], "Discord ID (optional)")     ; Discord Id Text
arMainUI.Add("Text", "x805 y245 c" uiTheme[1], "PS Link (optional)")        ; PS link text

;--------------SETTINGS;--------------SETTINGS;--------------SETTINGS;--------------SETTINGS;--------------SETTINGS;--------------SETTINGS;--------------SETTINGS
;--------------MODE SELECT;--------------MODE SELECT;--------------MODE SELECT;--------------MODE SELECT;--------------MODE SELECT;--------------MODE SELECT
global modeSelectionGroup := arMainUI.Add("GroupBox", "x808 y38 w600 h45 Background" uiTheme[2], "Select mode")
arMainUI.SetFont("s10 c" uiTheme[6])
global ModeDropdown := arMainUI.Add("DropDownList", "x818 y53 w140 h180 Choose0 +Center", ["Story", "Challenge", "Ranger", "Raid", "Dungeon", "Summer Event", "Boss Event", "Portal"])
global StoryDropdown := arMainUI.Add("DropDownList", "x968 y53 w150 h180 Choose0 +Center", ["Voocha Village", "Green Planet", "Demon Forest", "Leaf Village", "Z City", "Ghoul City", "Night Colosseum", "Bizzare Race", "Spirit Realm", "The City", "Virtual Sword", "Ruined Future City"])
global StoryActDropdown := arMainUI.Add("DropDownList", "x1130 y53 w80 h180 Choose0 +Center", ["Act 1", "Act 2", "Act 3", "Act 4", "Act 5", "Act 6", "Act 7", "Act 8", "Act 9", "Act 10"])
global RangerDropdown := arMainUI.Add("DropDownList", "x968 y53 w150 h180 Choose0 +Center", ["Voocha Village", "Green Planet", "Demon Forest", "Leaf Village", "Z City", "Ghoul City", "Night Colosseum", "Spirit Realm", "The City", "Virtual Sword", "Ruined Future City"])
global RangerActDropdown := arMainUI.Add("DropDownList", "x1130 y53 w80 h180 Choose0 +Center", ["Act 1", "Act 2", "Act 3"])
global RaidDropdown := arMainUI.Add("DropDownList", "x968 y53 w150 h180 Choose0 +Center", ["Steel Blitz Rush", "The Graveyard"])
global RaidActDropdown := arMainUI.Add("DropDownList", "x1130 y53 w80 h180 Choose0 +Center", ["Act 1", "Act 2", "Act 3", "Act 4"])
global DungeonDropdown := arMainUI.Add("DropDownList", "x968 y53 w80 h180 Choose0 +Center", ["Easy", "Normal", "Hell"])
global PortalDropdown := arMainUI.Add("DropDownList", "x968 y53 w170 h180 Choose0 +Center", ["Colosseum & Ghoul","Ruined Future City"])

global Difficult := arMainUI.Add("DropDownList", "x1220 y53 w90 h180 Choose0 +Center", ["Normal", "Hard", "Nightmare"])
global ConfirmButton := arMainUI.Add("Button", "x1318 y53 w80 h25", "Confirm")
arMainUI.SetFont("s8")
global PsLinkBox := arMainUI.Add("Edit", "x950 y245 w120 h20 c" uiTheme[6])  ; private server link
global WebhookURLBox := arMainUI.Add("Edit", "x950 y195 w120 h20 c" uiTheme[6]) ; webhook url
global DiscordUserIDBox := arMainUI.Add("Edit", "x950 y220 w120 h20 c" uiTheme[6])  ; Discord ID
global SendActivityLogsBox := arMainUI.Add("Checkbox", "x1215 y198 c" uiTheme[1], "Send Process")  ; Enable send process
global SendWebhookStatus := arMainUI.Add("Checkbox", "x1215 y215 cffffff Checked" uiTheme[1], "Send Webhook")
global Speed := arMainUI.Add("DropDownList", "x1340 y195 w50 h50 c" uiTheme[1], ["2x", "3x"])
Speed.Text := "2x"
; Save buttons
webhookSaveBtn := arMainUI.Add("Button", "x1085 y195 w115 h20", "Save Webhook")
webhookSaveBtn.OnEvent("Click", (*) => SaveWebhookSettings())

if FileExist(WebhookURLFile)
    WebhookURLBox.Value := FileRead(WebhookURLFile, "UTF-8")
if FileExist(DiscordUserIDFile)
    DiscordUserIDBox.Value := FileRead(DiscordUserIDFile, "UTF-8")
if FileExist(SendActivityLogsFile)
    SendActivityLogsBox.Value := (FileRead(SendActivityLogsFile, "UTF-8") = "1")
if FileExist("Settings\PrivateServer.txt")
    PsLinkBox.Value := FileRead("Settings\PrivateServer.txt", "UTF-8")

Hotkeytext.Visible := false
Hotkeytext2.Visible := false
StoryDropdown.Visible := false
StoryActDropdown.Visible := false
RangerDropdown.Visible := false
RangerActDropdown.Visible := false
RaidDropdown.Visible := false
RaidActDropdown.Visible := false
DungeonDropdown.Visible := false
PortalDropdown.Visible := false
Difficult.Visible := false

ModeDropdown.OnEvent("Change", OnModeChange)
ConfirmButton.OnEvent("Click", OnConfirmClick)
;------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI
arMainUI.Show("w1466 h633")
WinMove(0, 0, , , "ahk_id " arMainUIHwnd)
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
    global arMainUIHwnd, offsetX, offsetY, rblxID

    if !WinExist(rblxID) {
        ProcessLog("Waiting for Roblox window...")
        return
    }

    ; First ensure correct size
    sizeDown()

    ; Then move relative to main UI
    WinGetPos(&x, &y, &w, &h, arMainUIHwnd)
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