#Requires AutoHotkey v2.0
; ================================================================
;  AA mango dev harness - shared helpers
;  Lives OUTSIDE the macro folder. The macro never loads this file.
; ================================================================

global DEV_ROOT     := "C:\Users\thoan\Downloads\AA-mango-dev"
global PROJ_ROOT    := "C:\Users\thoan\Downloads\AA mango\AA mango"
global DEBUG_DIR    := DEV_ROOT . "\Debug"
global TEMPLATE_DIR := DEV_ROOT . "\Templates"
global RBLX_WIN     := "ahk_exe RobloxPlayerBeta.exe"

EnsureDirs() {
    for d in [DEBUG_DIR, TEMPLATE_DIR] {
        if !DirExist(d)
            DirCreate(d)
    }
}

Now() => FormatTime(A_Now, "yyyyMMdd_HHmmss")

; ---------------------------------------------------------------
;  Roblox geometry.  Client coords are what FindText / PixelSearch
;  actually see, so every artifact records them.
; ---------------------------------------------------------------
RobloxInfo() {
    hwnd := WinExist(RBLX_WIN)
    if !hwnd
        return 0

    WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " hwnd)
    WinGetClientPos(&cx, &cy, &cw, &ch, "ahk_id " hwnd)

    dpi := A_ScreenDPI
    try dpi := DllCall("GetDpiForWindow", "ptr", hwnd, "uint")

    info := {}
    info.hwnd  := hwnd
    info.title := WinGetTitle("ahk_id " hwnd)
    info.wx := wx, info.wy := wy, info.ww := ww, info.wh := wh
    info.cx := cx, info.cy := cy, info.cw := cw, info.ch := ch
    info.dpi := dpi
    return info
}

; ---------------------------------------------------------------
;  JSON helpers (write-only; no parser needed)
; ---------------------------------------------------------------
JStr(s) {
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, '"', '\"')
    s := StrReplace(s, "`r", "")
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`t", "\t")
    return '"' . s . '"'
}

JInfo(info) {
    return '{"hwnd": ' . info.hwnd
        . ', "title": ' . JStr(info.title)
        . ', "window": {"x": ' . info.wx . ', "y": ' . info.wy
        . ', "w": ' . info.ww . ', "h": ' . info.wh . '}'
        . ', "client": {"x": ' . info.cx . ', "y": ' . info.cy
        . ', "w": ' . info.cw . ', "h": ' . info.ch . '}'
        . ', "screen": {"w": ' . A_ScreenWidth . ', "h": ' . A_ScreenHeight
        . ', "dpi": ' . info.dpi . '}}'
}

; ---------------------------------------------------------------
;  GDI+ helpers
; ---------------------------------------------------------------
CropBitmap(pSrc, x, y, w, h) {
    pOut := Gdip_CreateBitmap(w, h)
    G := Gdip_GraphicsFromImage(pOut)
    Gdip_DrawImage(G, pSrc, 0, 0, w, h, x, y, w, h)
    Gdip_DeleteGraphics(G)
    return pOut
}

; Green 100 px grid + coordinate labels, so coordinates can be read
; straight off the PNG instead of being guessed.
DrawGrid(pBmp, w, h, step) {
    G := Gdip_GraphicsFromImage(pBmp)
    if !G
        return
    pen := Gdip_CreatePen(0x6600FF00, 1)
    Gdip_SetTextRenderingHint(G, 3)   ; anti-alias

    Loop {
        x := step * A_Index
        if (x >= w)
            break
        Gdip_DrawLine(G, pen, x, 0, x, h)
        try Gdip_TextToGraphics(G, String(x), "x" . (x + 2) . " y1 cFF00FF00 s11", "Consolas")
    }
    Loop {
        y := step * A_Index
        if (y >= h)
            break
        Gdip_DrawLine(G, pen, 0, y, w, y)
        try Gdip_TextToGraphics(G, String(y), "x2 y" . (y + 1) . " cFF00FF00 s11", "Consolas")
    }

    Gdip_DeletePen(pen)
    Gdip_DeleteGraphics(G)
}

; ---------------------------------------------------------------
;  Capture the Roblox client area exactly as FindText sees it.
;  Returns the JSON sidecar path, or "" when Roblox is not running.
; ---------------------------------------------------------------
TakeSnapshot(prefix := "shot", drawGrid := true) {
    EnsureDirs()

    info := RobloxInfo()
    if !info
        return ""

    ts   := Now()
    base := DEBUG_DIR . "\" . prefix . "_" . ts
    raw  := base . "_raw.png"
    grid := base . "_grid.png"

    pToken := Gdip_Startup()
    if !pToken
        return ""

    ok := false
    errMsg := ""
    try {
        pBmp := Gdip_BitmapFromScreen(info.cx . "|" . info.cy . "|" . info.cw . "|" . info.ch)
        if (pBmp <= 0)
            throw Error("Gdip_BitmapFromScreen failed")

        Gdip_SaveBitmapToFile(pBmp, raw, 100)
        if (drawGrid) {
            DrawGrid(pBmp, info.cw, info.ch, 100)
            Gdip_SaveBitmapToFile(pBmp, grid, 100)
        }
        Gdip_DisposeImage(pBmp)
        ok := true
    } catch as e {
        errMsg := e.Message
    } finally {
        Gdip_Shutdown(pToken)
    }

    if !ok
        return ""

    json := "{`n"
    json .= '  "time": ' . JStr(ts) . ",`n"
    json .= '  "info": ' . JInfo(info) . ",`n"
    json .= '  "grid_step": ' . (drawGrid ? 100 : 0) . ",`n"
    json .= '  "raw_png": ' . JStr(raw) . ",`n"
    json .= '  "grid_png": ' . JStr(drawGrid ? grid : "") . "`n"
    json .= "}`n"
    FileAppend(json, base . ".json", "UTF-8")

    return base . ".json"
}
