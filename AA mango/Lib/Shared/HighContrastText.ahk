; Shared OCR primitive used by CAPTCHA, unit panels and cards.
; Extracted without changing its implementation.

ReadHighContrastText(x, y, w, h, scale := 3, sourceDC := 0, greenOnly := false) {
    if (w <= 0 || h <= 0 || w > 4096 || h > 4096 || scale <= 0 || scale > 6)
        throw ValueError("Invalid OCR rectangle")
    screenDC := 0, memoryDC := 0, bitmap := 0, previous := 0
    try {
        if !sourceDC {
            screenDC := DllCall("user32\GetDC", "Ptr", 0, "Ptr")
            sourceDC := screenDC
        }
        if !sourceDC
            throw Error("OCR capture DC unavailable")
        memoryDC := DllCall("gdi32\CreateCompatibleDC", "Ptr", sourceDC, "Ptr")
        info := Buffer(40, 0)
        NumPut("UInt", 40, "Int", w, "Int", -h, "UShort", 1, "UShort", 32, info)
        bitmap := DllCall("gdi32\CreateDIBSection", "Ptr", sourceDC, "Ptr", info
            , "UInt", 0, "Ptr*", &bits := 0, "Ptr", 0, "UInt", 0, "Ptr")
        if (!memoryDC || !bitmap || !bits)
            throw Error("OCR bitmap unavailable")
        previous := DllCall("gdi32\SelectObject", "Ptr", memoryDC, "Ptr", bitmap, "Ptr")
        if (!previous || previous = -1)
            throw Error("OCR bitmap selection failed")
        if !DllCall("gdi32\BitBlt", "Ptr", memoryDC, "Int", 0, "Int", 0
            , "Int", w, "Int", h, "Ptr", sourceDC, "Int", x, "Int", y, "UInt", 0x00CC0020)
            throw Error("OCR capture failed")
        DllCall("gdi32\GdiFlush")
        loop w * h {
            offset := (A_Index - 1) * 4
            pixel := NumGet(bits, offset, "UInt")
            bright := Max(pixel & 255, (pixel >> 8) & 255, (pixel >> 16) & 255) >= 130
            if greenOnly {
                green := (pixel >> 8) & 255
                red := (pixel >> 16) & 255
                blue := pixel & 255
                bright := green >= 135 && green - red >= 65 && green - blue >= 30
            }
            NumPut("UInt", bright ? 0xFF000000 : 0xFFFFFFFF, bits, offset)
        }
        ; Deselect before OCR creates its own DC around the HBITMAP.
        DllCall("gdi32\SelectObject", "Ptr", memoryDC, "Ptr", previous)
        previous := 0
        return OCR.FromBitmap(bitmap, "en-US", scale).Text
    } finally {
        if (previous && previous != -1 && memoryDC)
            DllCall("gdi32\SelectObject", "Ptr", memoryDC, "Ptr", previous)
        if bitmap
            DllCall("gdi32\DeleteObject", "Ptr", bitmap)
        if memoryDC
            DllCall("gdi32\DeleteDC", "Ptr", memoryDC)
        if screenDC
            DllCall("user32\ReleaseDC", "Ptr", 0, "Ptr", screenDC)
    }
}
