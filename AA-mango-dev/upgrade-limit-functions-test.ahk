ParseUnitUpgradeLevel(text) {
    pattern := "i)\b(?:upgrade|upg)\s*(?:\[\s*(\d{1,2}|MAX)\s*\]|\(\s*(\d{1,2}|MAX)\s*\))"
    pos := RegExMatch(text, pattern, &match)
    if !pos {
        ; The measured gold UPG [0] header is read as "upgo" by Windows OCR.
        ; Limit glyph correction to an entire isolated UPG header, never prices,
        ; experience, card descriptions, or arbitrary words in the full panel.
        if RegExMatch(Trim(text), "i)^upg\s*[\[(]?\s*(max|o|i|l|\d{1,2})\s*[\])]?\s*$", &short) {
            value := StrLower(short[1])
            if (value = "max")
                return 21
            value := value = "o" ? "0" : (value = "i" || value = "l" ? "1" : value)
            return Integer(value) <= 20 ? Integer(value) : -1
        }
        return -1
    }
    ; Never choose between conflicting OCR labels.
    if RegExMatch(text, pattern, , pos + match.Len)
        return -1
    value := match[1] != "" ? match[1] : match[2]
    if (StrUpper(value) = "MAX")
        return 21
    level := Integer(value)
    return level <= 20 ? level : -1
}

ApplyUnitUpgradeLimit(limit, slot, readLevel := 0, pressUpgrade := 0) {
    if !readLevel
        readLevel := ReadUnitUpgradeLevel
    if !pressUpgrade
        pressUpgrade := PressUnitUpgrade
    Loop 3 {
        current := readLevel()
        if (current < 0) {
            ProcessLog("Slot " slot ": khong doc duoc Upgrade [n]; bo qua, khong nang mu")
            return false
        }
        if (current >= limit)
            return "limit"
        pressUpgrade()
        Sleep(200)
        confirmed := readLevel()
        if (confirmed < 0 || confirmed <= current) {
            ProcessLog("Slot " slot ": chua xac nhan tang bac; dung luot nang nay")
            return false
        }
        if (confirmed >= limit)
            return "limit"
    }
    return true
}
