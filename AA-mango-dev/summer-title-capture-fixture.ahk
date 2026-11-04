#Requires AutoHotkey v2.0
#Include D:\Macro\AA mango\AA mango\Lib\FindText.ahk
global SummerMapPatterns := Map()
Assert(value, message) {
    if !value
        throw Error(message)
}
testPath := A_Temp "\aa-summer-append-" DllCall("GetCurrentProcessId") ".ahk"
try {
    Assert(ParseSummerTitleName("Puppet Island (Summer)") = "Puppet Island", "Unknown Summer map title must be retained")
    Assert(ParseSummerTitleName("Magic Hills (Summer)") = "Magic Hill", "Known title must retain canonical route")
    for bad in ["Summer Event Forecast", "Join Matchmaking", "Weather: Sunny", "Vote Start", "(Summer)", "Please enter this text"]
        Assert(ParseSummerTitleName(bad) = "", "Non-title rejected: " bad)
    original := "; existing patterns`r`nGreenie := 'keep me'`r`n"
    FileAppend(original, testPath, "UTF-8-RAW")
    pattern := "|<>*100$8." FindText().bit2base64("00000000" "00111100" "00100100" "00111100" "00000000")
    Assert(AppendSummerMapPattern("Puppet Island", pattern, testPath), "New binary pattern must append")
    saved := FileRead(testPath, "UTF-8")
    Assert(SubStr(saved, 1, StrLen(original)) = original, "Existing patterns must remain byte-for-byte text")
    Assert(InStr(saved, 'SummerMapPatterns["Puppet Island"] :='), "New pattern assignment must name actual map")
    Assert(!AppendSummerMapPattern("Puppet Island", pattern, testPath), "Duplicate must not overwrite")
    Assert(FileRead(testPath, "UTF-8") = saved, "Duplicate must leave file unchanged")
    for bad in ["bad`ncode", 'bad"name', "", "Weather: Sunny"] {
        try {
            AppendSummerMapPattern(bad, pattern, testPath)
            throw Error("Unsafe name accepted")
        } catch ValueError {
        }
    }
    try {
        AppendSummerMapPattern("Snowy Town", "not a binary pattern", testPath)
        throw Error("Invalid pattern accepted")
    } catch ValueError {
    }
    Assert(FileRead(testPath, "UTF-8") = saved, "Invalid input must not write")
    FileAppend("PASS Summer title recognition, append-only pattern persistence, duplicate and unsafe-input guards`n", "*")
} catch as err {
    FileAppend("FAIL " err.Message " @ " err.Line "`n", "*")
    ExitApp(1)
} finally {
    if FileExist(testPath)
        FileDelete(testPath)
}
ExitApp(0)
ParseSummerMapName(text) {
    ; Board/forecast in the hub must not be mistaken for a loading title.
    if RegExMatch(text, "i)summer\s+event|forecast|travelling\s+merchant")
        return ""
    aliases := Map("Planet Greenie", "planet\s+greenie", "Snowy Town", "snowy\s+town"
        , "Ant Kingdom", "ant\s+kingdom", "Magic Town", "magic\s+town"
        , "Magic Hill", "magic\s+hills?", "Navy Bay", "navy\s+bay"
        , "Fiend City", "fiend\s+city", "Spirit World", "spirit\s+world"
        , "Haunted Academy", "haunted\s+academy", "Space Center", "space\s+center"
        , "Mountain Temple", "mountain\s+temple", "Cursed Festival", "cursed\s+festival"
        , "Nightmare Train", "nightmare\s+train", "Air Craft", "air\s*craft"
        , "Hellish City", "hellish(?:\s+city)?", "Shibuya District", "shibuya(?:\s+district)?")
    found := ""
    for name, pattern in aliases {
        if RegExMatch(text, "i)\b" pattern "\b") {
            if (found != "")
                return ""
            found := name
        }
    }
    return found
}

ParseSummerTitleName(text) {
    text := Trim(RegExReplace(text, "\s+", " "))
    if RegExMatch(text, "i)summer\s+event|forecast|weather|matchmaking|please\s+enter|captcha")
        return ""
    known := ParseSummerMapName(text)
    if (known != "")
        return known
    ; Unknown maps need an explicit in-match Summer suffix, not a board name.
    if RegExMatch(text, "i)^([a-z][a-z0-9 '\-]{1,55}?)\s*[\[(]\s*summer\s*[\])]$", &title)
        return Trim(title[1])
    return ""
}

AppendSummerMapPattern(name, pattern, path := "") {
    global SummerMapPatterns
    if !RegExMatch(name, "^[A-Za-z][A-Za-z0-9 '\-]{1,55}$")
        throw ValueError("Invalid Summer map name")
    if !RegExMatch(pattern, "^\|<>\*\d{1,3}\$\d{1,3}\.[0-9A-Za-z+/]+$") || !IsObject(FindText().PicInfo(pattern))
        throw ValueError("Invalid binary Summer pattern")
    if (path = "")
        path := A_ScriptDir "\Lib\Image.ahk"
    if SummerMapPatterns.Has(name)
        return false
    assignment := 'SummerMapPatterns["' name '"] :='
    ; Check disk as well: no overwrite if another run already appended it.
    if InStr(FileRead(path, "UTF-8"), assignment)
        return false
    FileAppend("`r`n; Summer title captured " FormatTime(, "yyyy-MM-dd HH:mm:ss")
        . " (not tested movement)`r`n" assignment ' "' pattern '"' "`r`n", path, "UTF-8-RAW")
    SummerMapPatterns[name] := pattern
    return true
}
