; DEV presentation only. No game input, OCR, configuration writes or network calls.
#Include %A_ScriptDir%\Lib\AHKv2-Gdip-master\Gdip_All.ahk

class KuruMotion {
    static Popups := Map()
    static TickCallback := 0
    static FrameMs := 30
    static PopupInMs := 120
    static PopupOutMs := 80
    static TimelineMs := 100
    static HoverMs := 60

    static Enabled() {
        global CARD_ACTION_BUSY
        if IsSet(CARD_ACTION_BUSY) && CARD_ACTION_BUSY
            return false ; foreground game work takes precedence over decoration
        enabled := Buffer(4, 0)
        return DllCall("SystemParametersInfoW", "UInt", 0x1042, "UInt", 0, "Ptr", enabled, "UInt", 0)
            && NumGet(enabled, 0, "Int")
    }

    static Alpha(hwnd, value) {
        return DllCall("SetLayeredWindowAttributes", "Ptr", hwnd, "UInt", 0, "UChar", value, "UInt", 2)
    }

    static Place(hwnd, x, y) {
        DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", 0, "Int", x, "Int", y, "Int", 0, "Int", 0, "UInt", 0x15)
    }

    static Open(popup, options := "") {
        popup.Opt("+E0x80000")
        if this.Popups.Has(popup.Hwnd) {
            state := this.Popups[popup.Hwnd]
            try this.Place(popup.Hwnd, state.x, state.y)
            this.Popups.Delete(popup.Hwnd)
        }
        if !this.Enabled() {
            try this.Alpha(popup.Hwnd, 255)
            popup.Show(options)
            return
        }
        this.Alpha(popup.Hwnd, 200)
        popup.Show(options)
        WinGetPos(&x, &y,,, "ahk_id " popup.Hwnd)
        this.Popups[popup.Hwnd] := {gui: popup, x: x, y: y, start: A_TickCount, closing: false}
        this.Start()
    }

    static Close(popup, *) {
        if !this.Enabled() {
            popup.Hide()
            return true
        }
        if this.Popups.Has(popup.Hwnd) {
            previous := this.Popups[popup.Hwnd]
            x := previous.x, y := previous.y
        } else {
            WinGetPos(&x, &y,,, "ahk_id " popup.Hwnd)
        }
        this.Popups[popup.Hwnd] := {gui: popup, x: x, y: y, start: A_TickCount, closing: true}
        this.Start()
        return true
    }

    static Start() {
        if !IsObject(this.TickCallback)
            this.TickCallback := ObjBindMethod(this, "Tick")
        SetTimer(this.TickCallback, this.FrameMs)
    }

    static Tick() {
        finished := []
        for hwnd, state in this.Popups {
            try {
                if !DllCall("IsWindow", "Ptr", hwnd) {
                    finished.Push(hwnd)
                    continue
                }
                t := Min(1, (A_TickCount - state.start) / (state.closing ? this.PopupOutMs : this.PopupInMs))
                if !this.Enabled()
                    t := 1
                eased := 1 - (1-t)**3
                opacity := state.closing ? 1-eased : (200+55*eased)/255
                this.Alpha(hwnd, Round(255*opacity))
                if t >= 1 {
                    if state.closing
                        state.gui.Hide()
                    this.Place(hwnd, state.x, state.y)
                    this.Alpha(hwnd, 255)
                    finished.Push(hwnd)
                }
            } catch {
                ; Fail open rather than leaving a transparent, unusable dialog.
                try this.Alpha(hwnd, 255)
                finished.Push(hwnd)
            }
        }
        for hwnd in finished
            this.Popups.Delete(hwnd)
        if !this.Popups.Count
            SetTimer(this.TickCallback, 0)
    }
}

class KuruTimeline {
    __New(gui, x, y, width, height) {
        this.gui := gui, this.width := width, this.height := height
        this.scale := A_ScreenDPI/96
        this.entries := [], this.serial := 0, this.bitmapHandle := 0
        this.failed := false, this.disposed := false, this.painting := false
        this.running := false, this.duration := KuruMotion.TimelineMs, this.started := 0
        this.measurements := Map(), this.pendingRows := 0, this.pendingCount := 0
        this.tickCallback := ObjBindMethod(this, "Tick")
        this.flushCallback := ObjBindMethod(this, "Flush")
        this.sizeCallback := ObjBindMethod(this, "OnSize")
        this.dirty := false
        try {
            this.token := Gdip_Startup()
            this.family := Gdip_FontFamilyCreate("Segoe UI")
            if !this.family
                throw Error("Timeline font family unavailable")
            this.fonts := Map()
            for size in [11, 14, 17] {
                handle := 0
                DllCall("gdiplus\GdipCreateFont", "Ptr", this.family, "Float", size, "Int", 1, "Int", 2, "Ptr*", &handle)
                if !handle
                    throw Error("Could not create timeline font")
                this.fonts[size] := handle
            }
            this.format := Gdip_StringFormatCreate(0)
            if !this.format
                throw Error("Timeline text format unavailable")
            this.view := gui.Add("Picture", "x" x " y" y " w" width " h" height " +0xE")
            gui.OnEvent("Size", this.sizeCallback)
            this.exitCallback := ObjBindMethod(this, "Dispose")
            OnExit(this.exitCallback)
        } catch as err {
            this.Dispose()
            throw err
        }
    }

    QueueRefresh(rows, animate := false) {
        if this.failed || this.disposed
            return false
        this.pendingRows := rows
        this.pendingCount += animate ? 1 : 0
        if !this.HasOwnProp("flushPending") || !this.flushPending {
            this.flushPending := true
            SetTimer(this.flushCallback, -KuruMotion.FrameMs)
        }
        return true
    }

    Flush() {
        if this.disposed
            return
        rows := this.pendingRows, count := this.pendingCount
        this.pendingRows := 0, this.pendingCount := 0, this.flushPending := false
        if IsObject(rows) {
            try this.Refresh(rows, count > 0, Max(1, count))
            catch {
                this.failed := true, this.running := false
                SetTimer(this.tickCallback, 0)
                try this.view.Visible := false
                try LayoutProcessHistory()
            }
        }
    }

    Refresh(rows, animate := false, shiftCount := 1) {
        if this.failed || this.disposed
            return false
        now := A_TickCount
        previous := this.entries
        this.entries := []
        for index, row in rows {
            text := RegExReplace(row.Value, "^➤\s*", "")
            if text = ""
                break
            stamp := ""
            if animate && index > shiftCount && previous.Length >= index-shiftCount {
                id := previous[index-shiftCount].id, stamp := previous[index-shiftCount].stamp
                text := previous[index-shiftCount].text
            } else {
                id := ++this.serial
                if (!animate || index > 1) && RegExMatch(text, "^(.*?)\s+(\d{2}:\d{2})$", &match)
                    text := match[1], stamp := match[2]
                else if animate && index <= shiftCount
                    stamp := getElapsedTime()
            }
            this.entries.Push({id: id, text: text, stamp: stamp, y: 0, from: 0, height: 0})
        }
        this.Layout()
        for index, entry in this.entries
            entry.from := entry.y - (index = 1 ? 4 : 0)
        this.started := now
        this.running := animate && previous.Length && KuruMotion.Enabled()
            && DllCall("IsWindowVisible", "Ptr", this.gui.Hwnd)
            && !DllCall("IsIconic", "Ptr", this.gui.Hwnd)
        if DllCall("IsIconic", "Ptr", this.gui.Hwnd) {
            this.dirty := true
            SetTimer(this.tickCallback, 0)
            return true
        }
        this.dirty := false
        this.Draw(this.running ? 0 : 1)
        SetTimer(this.tickCallback, this.running ? KuruMotion.FrameMs : 0)
        return !this.failed
    }

    OnSize(gui, minMax, width, height) {
        if minMax != -1 && this.dirty && !this.disposed && !this.failed {
            this.dirty := false, this.running := false
            this.Draw(1)
        }
    }

    Layout() {
        bitmap := Gdip_CreateBitmap(1, 1), graphics := Gdip_GraphicsFromImage(bitmap)
        try {
            y := 10
            for index, entry in this.entries {
                size := index = 1 ? 17 : 14
                key := this.width "|" size "|" entry.text
                if !this.measurements.Has(key) {
                    CreateRectF(&rect, 0, 0, this.width-67, 10000)
                    measured := StrSplit(Gdip_MeasureString(graphics, entry.text, this.fonts[size], this.format, &rect), "|")
                    if measured.Length < 4 || Number(measured[4]) <= 0
                        throw Error("Timeline text measurement failed")
                    if this.measurements.Count >= 256 {
                        for oldest in this.measurements {
                            this.measurements.Delete(oldest)
                            break
                        }
                    }
                    this.measurements[key] := Max(size+4, Ceil(Number(measured[4]))+4)
                }
                entry.height := this.measurements[key] + (entry.stamp != "" ? 19 : 0)
                if index = 1
                    entry.height += 24
                entry.y := y
                y += entry.height + (index = 1 ? 15 : 12)
            }
        } finally {
            Gdip_DeleteGraphics(graphics)
            Gdip_DisposeImage(bitmap)
        }
    }

    Tick() {
        if this.failed || this.disposed || !DllCall("IsWindowVisible", "Ptr", this.gui.Hwnd)
            || DllCall("IsIconic", "Ptr", this.gui.Hwnd) {
            this.running := false
            SetTimer(this.tickCallback, 0)
            return
        }
        t := Min(1, (A_TickCount-this.started)/this.duration)
        if !KuruMotion.Enabled()
            t := 1
        this.Draw(t)
        if t >= 1 {
            this.running := false
            SetTimer(this.tickCallback, 0)
        }
    }

    Draw(t) {
        if this.painting || this.disposed
            return
        this.painting := true
        bitmap := 0, graphics := 0
        try {
            bitmap := Gdip_CreateBitmap(Round(this.width*this.scale), Round(this.height*this.scale))
            graphics := Gdip_GraphicsFromImage(bitmap)
            if !bitmap || !graphics
                throw Error("Timeline surface unavailable")
            DllCall("gdiplus\GdipSetPageUnit", "Ptr", graphics, "Int", 2)
            DllCall("gdiplus\GdipScaleWorldTransform", "Ptr", graphics, "Float", this.scale, "Float", this.scale, "Int", 0)
            Gdip_SetSmoothingMode(graphics, 4)
            Gdip_SetTextRenderingHint(graphics, 4)
            Gdip_GraphicsClear(graphics, 0xFF292F3E)
            Gdip_SetClipRect(graphics, 0, 0, this.width, this.height)
            pen := Gdip_CreatePen(0xFF525C6D, 1)
            try Gdip_DrawLine(graphics, pen, 14, 23, 14, this.VisibleBottom())
            finally Gdip_DeletePen(pen)
            eased := 1-(1-t)**3
            for index, entry in this.entries {
                if entry.y+entry.height > this.height-8 && index > 1
                    break
                y := this.running ? entry.from+(entry.y-entry.from)*eased : entry.y
                alpha := 1 ; new text is readable immediately; only the newest card moves
                opacity := Round(255*alpha)<<24
                if index = 1 {
                    this.Fill(graphics, opacity|0x30463C, 29, y, this.width-42, entry.height, 7)
                    this.Fill(graphics, opacity|0x92EEAA, 29, y+5, 3, Max(1, entry.height-10))
                    dot := Gdip_BrushCreateSolid(opacity|0x92EEAA)
                    try Gdip_FillEllipse(graphics, dot, 8, y+15, 12, 12)
                    finally Gdip_DeleteBrush(dot)
                    x := 42, textY := y+12
                } else {
                    dot := Gdip_BrushCreateSolid(0xFFADB9CD)
                    try Gdip_FillEllipse(graphics, dot, 10, y+5, 8, 8)
                    finally Gdip_DeleteBrush(dot)
                    x := 33, textY := y
                }
                if entry.stamp != "" {
                    this.Text(graphics, entry.stamp, x, textY, 11, opacity|(index = 1 ? 0x9BE5AE : 0xADB9CD), 18)
                    textY += 19
                }
                this.Text(graphics, entry.text, x, textY, index = 1 ? 17 : 14,
                    opacity|(index = 1 ? 0xA5F2B8 : 0xDCE3EE), entry.height)
            }
            handle := Gdip_CreateHBITMAPFromBitmap(bitmap, 0xFF292F3E)
            if !handle
                throw Error("Timeline bitmap unavailable")
            previousHandle := this.bitmapHandle
            old := DllCall("SendMessageW", "Ptr", this.view.Hwnd, "UInt", 0x172, "Ptr", 0, "Ptr", handle, "Ptr")
            if old
                DllCall("DeleteObject", "Ptr", old)
            ; Static controls may own an alpha-bitmap copy distinct from the supplied handle.
            if previousHandle && previousHandle != old
                DllCall("DeleteObject", "Ptr", previousHandle)
            this.bitmapHandle := handle
        } catch {
            this.failed := true
            this.running := false
            SetTimer(this.tickCallback, 0)
            try this.view.Visible := false
            ; The host retains its native-text fallback and original log/file path.
            try LayoutProcessHistory()
        } finally {
            if graphics
                Gdip_DeleteGraphics(graphics)
            if bitmap
                Gdip_DisposeImage(bitmap)
            this.painting := false
        }
    }

    VisibleBottom() {
        bottom := 23
        for index, entry in this.entries {
            if entry.y+entry.height > this.height-8 && index > 1
                break
            bottom := Min(this.height-8, entry.y+entry.height-6)
        }
        return bottom
    }

    Text(graphics, text, x, y, size, color, height) {
        CreateRectF(&rect, x, y, this.width-67, height)
        brush := Gdip_BrushCreateSolid(color)
        try Gdip_DrawString(graphics, text, this.fonts[size], this.format, brush, &rect)
        finally Gdip_DeleteBrush(brush)
    }

    Fill(graphics, color, x, y, width, height, radius := 0) {
        brush := Gdip_BrushCreateSolid(color)
        try {
            if radius
                Gdip_FillRoundedRectangle(graphics, brush, x, y, width, height, radius)
            else
                Gdip_FillRectangle(graphics, brush, x, y, width, height)
        } finally Gdip_DeleteBrush(brush)
    }

    __Delete() {
        try this.Dispose()
    }

    Dispose(*) {
        if this.disposed
            return
        this.disposed := true
        SetTimer(this.tickCallback, 0)
        SetTimer(this.flushCallback, 0)
        this.pendingRows := 0
        try this.gui.OnEvent("Size", this.sizeCallback, 0)
        detached := 0
        if this.HasOwnProp("view")
            try detached := DllCall("SendMessageW", "Ptr", this.view.Hwnd, "UInt", 0x172, "Ptr", 0, "Ptr", 0, "Ptr")
        if detached && detached != this.bitmapHandle
            DllCall("DeleteObject", "Ptr", detached)
        if this.bitmapHandle
            DllCall("DeleteObject", "Ptr", this.bitmapHandle)
        if this.HasOwnProp("fonts") {
            for size, font in this.fonts
                Gdip_DeleteFont(font)
        }
        if this.HasOwnProp("format")
            Gdip_DeleteStringFormat(this.format)
        if this.HasOwnProp("family") && this.family
            Gdip_DeleteFontFamily(this.family)
        if this.HasOwnProp("token") && this.token
            try Gdip_Shutdown(this.token)
    }

}

class KuruButtons {
    static Controls := Map()
    static Owners := Map()
    static Ready := false
    static Hot := 0
    static LeaveCallback := 0
    static LeaveMessage := 0
    static Fades := Map()
    static FadeCallback := 0
    static ParentCallback := 0
    static Parents := Map()

    static Apply(gui) {
        if !this.Ready {
            this.DrawCallback := ObjBindMethod(this, "Draw")
            this.MoveCallback := ObjBindMethod(this, "MouseMove")
            this.LeaveCallback := ObjBindMethod(this, "CheckLeave")
            this.LeaveMessage := ObjBindMethod(this, "MouseLeave")
            this.FadeCallback := ObjBindMethod(this, "FadeTick")
            this.ParentCallback := CallbackCreate(ObjBindMethod(this, "WindowProc"), "F", 6)
            OnMessage(0x200, this.MoveCallback)
            OnMessage(0x2A3, this.LeaveMessage)
            this.Ready := true
        }
        if !this.Parents.Has(gui.Hwnd) {
            if !DllCall("comctl32\SetWindowSubclass", "Ptr", gui.Hwnd, "Ptr", this.ParentCallback, "UPtr", 0x4B555255, "UPtr", 0)
                throw Error("Could not attach native button renderer")
            this.Parents[gui.Hwnd] := true
        }
        for control in gui {
            if control.Type != "Button" || this.Controls.Has(control.Hwnd)
                continue
            this.Controls[control.Hwnd] := control
            this.Owners[control.Hwnd] := gui.Hwnd
            ; BM_SETSTYLE avoids AHK treating the owner-draw bit as a new default button.
            DllCall("SendMessageW", "Ptr", control.Hwnd, "UInt", 0xF4, "Ptr", 0xB, "Ptr", true)
            DllCall("InvalidateRect", "Ptr", control.Hwnd, "Ptr", 0, "Int", true)
        }
    }

    static WindowProc(hwnd, message, wParam, lParam, subclassId, refData) {
        if message = 0x2B {
            result := this.Draw(wParam, lParam)
            if result = 1
                return 1
        }
        if message = 0x82 {
            removed := []
            for controlHwnd, owner in this.Owners {
                if owner = hwnd
                    removed.Push(controlHwnd)
            }
            for controlHwnd in removed {
                this.Controls.Delete(controlHwnd), this.Owners.Delete(controlHwnd)
                if this.Fades.Has(controlHwnd)
                    this.Fades.Delete(controlHwnd)
                if this.Hot = controlHwnd {
                    this.Hot := 0
                    SetTimer(this.LeaveCallback, 0)
                }
            }
            if !this.Fades.Count
                SetTimer(this.FadeCallback, 0)
            DllCall("comctl32\RemoveWindowSubclass", "Ptr", hwnd, "Ptr", this.ParentCallback, "UPtr", subclassId)
            if this.Parents.Has(hwnd)
                this.Parents.Delete(hwnd)
        }
        return DllCall("comctl32\DefSubclassProc", "Ptr", hwnd, "UInt", message, "Ptr", wParam, "Ptr", lParam, "Ptr")
    }

    static MouseMove(*) {
        MouseGetPos(,,, &control, 2)
        hot := this.Controls.Has(control) ? control : 0
        if hot = this.Hot
            return
        previous := this.Hot
        fromColors := Map()
        for hwnd in [previous, hot] {
            if hwnd
                fromColors[hwnd] := this.Color(hwnd)
        }
        this.Hot := hot
        for hwnd in [previous, hot] {
            if !hwnd
                continue
            accent := this.Controls[hwnd].Text = "Save"
            target := hwnd = hot ? (accent ? 0x507B60 : 0x444F65) : (accent ? 0x426550 : 0x363E50)
            if KuruMotion.Enabled()
                this.Fades[hwnd] := {from: fromColors[hwnd], target: target, start: A_TickCount}
            else if this.Fades.Has(hwnd)
                this.Fades.Delete(hwnd)
            DllCall("InvalidateRect", "Ptr", hwnd, "Ptr", 0, "Int", true)
        }
        if this.Fades.Count
            SetTimer(this.FadeCallback, KuruMotion.FrameMs)
        ; Native leave notification avoids polling the cursor throughout a hover.
        SetTimer(this.LeaveCallback, hot && !this.TrackLeave(hot) ? 100 : 0)
    }

    static TrackLeave(hwnd) {
        event := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
        NumPut("UInt", event.Size, "UInt", 2, "Ptr", hwnd, event)
        return DllCall("TrackMouseEvent", "Ptr", event)
    }

    static MouseLeave(wParam, lParam, message, hwnd) {
        if hwnd = this.Hot
            this.MouseMove()
    }

    static CheckLeave() {
        this.MouseMove()
    }

    static Color(hwnd) {
        if this.Fades.Has(hwnd) {
            fade := this.Fades[hwnd]
            t := Min(1, (A_TickCount-fade.start)/KuruMotion.HoverMs)
            t := 1-(1-t)**3
            color := 0
            for shift in [0, 8, 16] {
                a := (fade.from>>shift)&255, b := (fade.target>>shift)&255
                color |= Round(a+(b-a)*t)<<shift
            }
            return color
        }
        accent := this.Controls[hwnd].Text = "Save"
        return hwnd = this.Hot ? (accent ? 0x507B60 : 0x444F65) : (accent ? 0x426550 : 0x363E50)
    }

    static FadeTick() {
        completed := []
        for hwnd, fade in this.Fades {
            if A_TickCount-fade.start >= KuruMotion.HoverMs || !KuruMotion.Enabled() || !DllCall("IsWindow", "Ptr", hwnd)
                completed.Push(hwnd)
            DllCall("InvalidateRect", "Ptr", hwnd, "Ptr", 0, "Int", true)
        }
        for hwnd in completed
            this.Fades.Delete(hwnd)
        if !this.Fades.Count
            SetTimer(this.FadeCallback, 0)
    }

    static Bgr(rgb) => ((rgb&255)<<16)|(rgb&0xFF00)|((rgb>>16)&255)

    static Draw(wParam, lParam, *) {
        hwnd := NumGet(lParam, A_PtrSize = 8 ? 24 : 20, "Ptr")
        if !this.Controls.Has(hwnd)
            return
        control := this.Controls[hwnd]
        dc := NumGet(lParam, A_PtrSize = 8 ? 32 : 24, "Ptr")
        offset := A_PtrSize = 8 ? 40 : 28
        x := NumGet(lParam, offset, "Int"), y := NumGet(lParam, offset+4, "Int")
        right := NumGet(lParam, offset+8, "Int"), bottom := NumGet(lParam, offset+12, "Int")
        state := NumGet(lParam, 16, "UInt")
        save := DllCall("SaveDC", "Ptr", dc)
        accent := control.Text = "Save"
        color := state&1 ? 0x25313D : this.Color(hwnd)
        brush := DllCall("CreateSolidBrush", "UInt", this.Bgr(color), "Ptr")
        pen := DllCall("CreatePen", "Int", 0, "Int", 1, "UInt", this.Bgr(accent ? 0x648C6D : 0x59657B), "Ptr")
        try {
            background := DllCall("CreateSolidBrush", "UInt", this.Bgr(0x242937), "Ptr")
            try DllCall("FillRect", "Ptr", dc, "Ptr", lParam+offset, "Ptr", background)
            finally DllCall("DeleteObject", "Ptr", background)
            DllCall("SelectObject", "Ptr", dc, "Ptr", brush)
            DllCall("SelectObject", "Ptr", dc, "Ptr", pen)
            DllCall("RoundRect", "Ptr", dc, "Int", x, "Int", y, "Int", right-1, "Int", bottom-1, "Int", 9, "Int", 9)
            font := DllCall("SendMessageW", "Ptr", hwnd, "UInt", 0x31, "Ptr", 0, "Ptr", 0, "Ptr")
            DllCall("SelectObject", "Ptr", dc, "Ptr", font)
            DllCall("SetBkMode", "Ptr", dc, "Int", 1)
            DllCall("SetTextColor", "Ptr", dc, "UInt", this.Bgr(state&4 ? 0x8C97A9 : 0xE9EDF5))
            rect := Buffer(16, 0)
            NumPut("Int", x+4, "Int", y+(state&1 ? 1 : 0), "Int", right-4, "Int", bottom, rect)
            DllCall("DrawTextW", "Ptr", dc, "Str", control.Text, "Int", -1, "Ptr", rect, "UInt", 0x825)
            if state&0x10 {
                NumPut("Int", x+3, "Int", y+3, "Int", right-4, "Int", bottom-4, rect)
                DllCall("DrawFocusRect", "Ptr", dc, "Ptr", rect)
            }
        } finally {
            DllCall("RestoreDC", "Ptr", dc, "Int", save)
            DllCall("DeleteObject", "Ptr", brush)
            DllCall("DeleteObject", "Ptr", pen)
        }
        return 1
    }
}
