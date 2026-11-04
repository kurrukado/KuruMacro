#Requires AutoHotkey v2.0
#SingleInstance Force

MsgBox("Đã chạy Tool!`n`nCách dùng:`n1. Vào Game, để lộ thanh Unit.`n2. Bấm phím [F1].`n3. Giữ chuột trái và KÉO bao quanh 6 ô Unit.`n4. Thả chuột ra để chụp và lấy tọa độ.`n`n[F2] = chụp toàn màn hình vào Logs\ (dùng để lấy ảnh thẻ bài).", "Hướng dẫn", "T10")

F1:: {
    SelectAndCapture()
}

F2:: {
    CaptureFullScreen()
}

Esc:: ExitApp

CaptureFullScreen() {
    if !DirExist(A_ScriptDir "\Logs")
        DirCreate(A_ScriptDir "\Logs")
    out := A_ScriptDir "\Logs\Screen_" FormatTime(, "yyyyMMdd_HHmmss") ".png"
    CaptureScreen(0, 0, A_ScreenWidth, A_ScreenHeight, out)
    MsgBox("Đã lưu ảnh toàn màn hình:`n" out, "Chụp màn hình")
}

SelectAndCapture() {
    ; 1. Tạo màn hình mờ che phủ toàn bộ (Overlay)
    Overlay := Gui("+AlwaysOnTop -Caption +ToolWindow +LastFound")
    Overlay.BackColor := "Black"
    WinSetTransparent(100, Overlay) ; Độ mờ 100/255

    ; Lấy kích thước màn hình
    MonitorGetWorkArea(1, &WL, &WT, &WR, &WB)
    Overlay.Show("x" WL " y" WT " w" (WR - WL) " h" (WB - WT))

    ; 2. Tạo khung dây đỏ (Selection Box)
    Box := Gui("+AlwaysOnTop -Caption +ToolWindow +LastFound +Owner" Overlay.Hwnd)
    Box.BackColor := "Red"
    WinSetTransparent(150, Box)

    ; 3. Đợi người dùng bấm chuột trái để bắt đầu kéo
    ToolTip "Giữ Chuột Trái và Kéo vùng cần chụp..."
    KeyWait "LButton", "D"
    MouseGetPos &startX, &startY

    ; 4. Vòng lặp cập nhật khung đỏ khi di chuyển chuột
    Box.Show("x" startX " y" startY " w0 h0 NoActivate")

    Loop {
        if !GetKeyState("LButton", "P") ; Nếu thả chuột ra thì dừng
            break

        MouseGetPos &curX, &curY

        ; Tính toán tọa độ x, y, w, h (Xử lý cả trường hợp kéo ngược từ dưới lên)
        if (curX < startX) {
            x := curX
            w := startX - curX
        } else {
            x := startX
            w := curX - startX
        }

        if (curY < startY) {
            y := curY
            h := startY - curY
        } else {
            y := startY
            h := curY - startY
        }

        ; Cập nhật khung đỏ
        Box.Move(x, y, w, h)
        Sleep 10
    }

    ; 5. Dọn dẹp GUI
    ToolTip ""
    Box.Destroy()
    Overlay.Destroy()

    ; 6. CHỤP ẢNH VỚI TỌA ĐỘ ĐÃ LẤY ĐƯỢC
    ; Kiểm tra nếu vùng chọn quá nhỏ (do click nhầm)
    if (w < 10 || h < 10) {
        MsgBox "Vùng chọn quá nhỏ, đã hủy bỏ."
        return
    }

    FileName := A_ScriptDir "\Captured.png"
    CaptureScreen(x, y, w, h, FileName)

    ; 7. HIỂN THỊ KẾT QUẢ ĐỂ BẠN COPY
    ResultMsg := "Đã chụp xong!`n`n"
    ResultMsg .= "TỌA ĐỘ CẦN COPY VÀO CODE (Nếu cần):`n"
    ResultMsg .= "X: " x "`n"
    ResultMsg .= "Y: " y "`n"
    ResultMsg .= "W: " w "`n"
    ResultMsg .= "H: " h

    ; Copy luôn vào Clipboard cho tiện
    A_Clipboard := "Global UnitX := " x "`nGlobal UnitY := " y "`nGlobal UnitW := " w "`nGlobal UnitH := " h

    MsgBox(ResultMsg "`n`n(Đã tự copy 4 dòng code tọa độ vào Clipboard)", "Kết quả")
    try Run(FileName)
}

CaptureScreen(x, y, w, h, outFile) {
    try {
        pToken := 0
        si := Buffer(24, 0)
        NumPut("UInt", 1, si)
        DllCall("gdiplus\GdiplusStartup", "Ptr*", &pToken, "Ptr", si, "Ptr", 0)

        hdcScreen := DllCall("GetDC", "Ptr", 0, "Ptr")
        hdcMem := DllCall("CreateCompatibleDC", "Ptr", hdcScreen, "Ptr")
        hbm := DllCall("CreateCompatibleBitmap", "Ptr", hdcScreen, "Int", w, "Int", h)
        hOld := DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hbm, "Ptr")

        DllCall("BitBlt", "Ptr", hdcMem, "Int", 0, "Int", 0, "Int", w, "Int", h, "Ptr", hdcScreen, "Int", x, "Int", y, "Int", 0x00CC0020)

        pBitmap := 0
        DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "Ptr", hbm, "Ptr", 0, "Ptr*", &pBitmap)

        CLSID := Buffer(16, 0)
        DllCall("ole32\CLSIDFromString", "WStr", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "Ptr", CLSID)
        DllCall("gdiplus\GdipSaveImageToFile", "Ptr", pBitmap, "WStr", outFile, "Ptr", CLSID, "Ptr", 0)

        DllCall("gdiplus\GdipDisposeImage", "Ptr", pBitmap)
        DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hOld)
        DllCall("DeleteObject", "Ptr", hbm)
        DllCall("DeleteDC", "Ptr", hdcMem)
        DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcScreen)
        DllCall("gdiplus\GdiplusShutdown", "Ptr", pToken)
    }
}

