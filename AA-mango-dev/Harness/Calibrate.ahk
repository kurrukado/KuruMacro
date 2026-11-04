#Requires AutoHotkey v2.0
#SingleInstance Force
; ================================================================
;  Calibrate.ahk - turn "I can see the icon" into exact numbers
;
;  Flow:
;    1. Captures the Roblox client area (exactly what FindText sees)
;    2. Shows it 1:1 in a borderless window
;    3. Drag a box around the button / icon you care about
;    4. Type a name -> saves Templates\<name>.png + Templates\templates.ini
;
;  Keys:  F9 = recapture    Esc = quit
;
;  Output per template (client coordinates, ready for FindText /
;  ImageSearch / PixelSearch):
;      x1, y1, x2, y2, w, h, client_w, client_h, png, created
; ================================================================

#Include "C:\Users\thoan\Downloads\AA-mango-dev\Harness\lib\Common.ahk"
#Include "C:\Users\thoan\Downloads\AA mango\AA mango\Lib\AHKv2-Gdip-master\Gdip_All.ahk"

EnsureDirs()

global gCal := ""
global picCal := ""
global pBmp := 0
global hbmCur := 0
global cw := 0, ch := 0
global cx0 := 0, cy0 := 0
global selDown := false
global sx := 0, sy := 0, ex := 0, ey := 0
global pToken := 0

; ---------------------------------------------------------------
Capture() {
    global pBmp, cw, ch, cx0, cy0

    info := RobloxInfo()
    if !info {
        MsgBox("Roblox window not found (ahk_exe RobloxPlayerBeta.exe).", "Calibrate", 0x30)
        return false
    }

    if (pBmp)
        Gdip_DisposeImage(pBmp)

    pBmp := Gdip_BitmapFromScreen(info.cx . "|" . info.cy . "|" . info.cw . "|" . info.ch)
    if (pBmp <= 0) {
        MsgBox("Screen capture failed.", "Calibrate", 0x30)
        return false
    }

    cw := info.cw
    ch := info.ch
    cx0 := info.cx
    cy0 := info.cy
    return true
}

ShowBitmap(pSrc) {
    global picCal, hbmCur

    if (hbmCur) {
        try DllCall("DeleteObject", "ptr", hbmCur)
        hbmCur := 0
    }
    hbmCur := Gdip_CreateHBITMAPFromBitmap(pSrc)
    picCal.Value := "HBITMAP:*" . hbmCur
}

ResetPreview() {
    global pBmp
    ShowBitmap(pBmp)
}

; ---------------------------------------------------------------
BuildGui() {
    global gCal, picCal, cw, ch, cx0, cy0

    gCal := Gui("-Caption +AlwaysOnTop -Resize +E0x08000000", "Calibrate")
    gCal.MarginX := 0
    gCal.MarginY := 0
    picCal := gCal.Add("Picture", "x0 y0 w" . cw . " h" . ch)
    gCal.Show("w" . cw . " h" . ch . " x" . cx0 . " y" . cy0)
    gCal.OnEvent("Close", (*) => Quit())
}

; ---------------------------------------------------------------
OnDown(wParam, lParam, msg, hwnd) {
    global gCal, picCal, selDown, sx, sy

    if (hwnd != gCal.Hwnd && hwnd != picCal.Hwnd)
        return
    selDown := true
    sx := lParam & 0xFFFF
    sy := (lParam >> 16) & 0xFFFF
}

OnUp(wParam, lParam, msg, hwnd) {
    global gCal, picCal, selDown, ex, ey

    if (!selDown)
        return
    selDown := false
    ex := lParam & 0xFFFF
    ey := (lParam >> 16) & 0xFFFF
    FinishSelection()
}

; ---------------------------------------------------------------
FinishSelection() {
    global pBmp, sx, sy, ex, ey, cw, ch

    x1 := Min(sx, ex)
    y1 := Min(sy, ey)
    w  := Abs(ex - sx)
    h  := Abs(ey - sy)

    if (w < 4 || h < 4) {
        ToolTip("Selection too small - drag a box")
        SetTimer(() => ToolTip(), -1400)
        return
    }

    ; clamp inside the client area
    x1 := Max(0, Min(x1, cw - 1))
    y1 := Max(0, Min(y1, ch - 1))
    w  := Min(w, cw - x1)
    h  := Min(h, ch - y1)

    ; show what was selected
    pPrev := Gdip_CloneBitmapArea(pBmp, 0, 0, cw, ch)
    G := Gdip_GraphicsFromImage(pPrev)
    pen := Gdip_CreatePen(0xFFFF0000, 2)
    Gdip_DrawRectangle(G, pen, x1, y1, w, h)
    Gdip_DeletePen(pen)
    Gdip_DeleteGraphics(G)
    ShowBitmap(pPrev)
    Gdip_DisposeImage(pPrev)

    defaultName := "tpl_" . FormatTime(A_Now, "HHmmss")
    ib := InputBox(
        "Selection: " . w . "x" . h . " at client (" . x1 . "," . y1 . ")`n"
        . "Client area: " . cw . "x" . ch . "`n`nTemplate name:",
        "Save template", "w440 h170", defaultName)

    if (ib.Result != "OK" || Trim(ib.Value) = "") {
        ResetPreview()
        return
    }

    name := Trim(ib.Value)
    png  := TEMPLATE_DIR . "\" . name . ".png"

    pCrop := CropBitmap(pBmp, x1, y1, w, h)
    Gdip_SaveBitmapToFile(pCrop, png, 100)
    Gdip_DisposeImage(pCrop)

    ini := TEMPLATE_DIR . "\templates.ini"
    IniWrite(x1,        ini, name, "x1")
    IniWrite(y1,        ini, name, "y1")
    IniWrite(x1 + w,    ini, name, "x2")
    IniWrite(y1 + h,    ini, name, "y2")
    IniWrite(w,         ini, name, "w")
    IniWrite(h,         ini, name, "h")
    IniWrite(cw,        ini, name, "client_w")
    IniWrite(ch,        ini, name, "client_h")
    IniWrite(png,       ini, name, "png")
    IniWrite(FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss"), ini, name, "created")

    FileAppend("SAVED " . name
        . " rect=(" . x1 . "," . y1 . ")-(" . (x1 + w) . "," . (y1 + h) . ")"
        . " size=" . w . "x" . h
        . " client=" . cw . "x" . ch . "`n",
        DEBUG_DIR . "\calibrate.log", "UTF-8")

    ToolTip("Saved " . name . "  (" . w . "x" . h . ")")
    SetTimer(() => ToolTip(), -1600)
    ResetPreview()
}

; ---------------------------------------------------------------
Recapture(*) {
    global pBmp, cw, ch
    if !Capture()
        return
    ResetPreview()
    ToolTip("Recaptured " . cw . "x" . ch)
    SetTimer(() => ToolTip(), -1400)
}

Quit(*) {
    global pBmp, pToken, hbmCur
    if (hbmCur)
        try DllCall("DeleteObject", "ptr", hbmCur)
    if (pBmp)
        Gdip_DisposeImage(pBmp)
    if (pToken)
        Gdip_Shutdown(pToken)
    ExitApp()
}

; ---------------------------------------------------------------
pToken := Gdip_Startup()
if !pToken {
    MsgBox("GDI+ failed to start.", "Calibrate", 0x10)
    ExitApp(1)
}

if !Capture()
    Quit()

BuildGui()
ShowBitmap(pBmp)

OnMessage(0x0201, OnDown)
OnMessage(0x0202, OnUp)
Hotkey("Escape", Quit)
Hotkey("F9", Recapture)

TrayTip("Calibrate - drag a box, F9 recapture, Esc quit")
