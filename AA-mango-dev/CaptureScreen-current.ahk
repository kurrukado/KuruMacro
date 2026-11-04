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
