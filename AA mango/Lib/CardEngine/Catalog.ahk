; Card engine: Catalog. Runtime behavior preserved during extraction.

NormalizeCardName(s) {
    s := Trim(StrLower(s))
    ; Keep the effect sign: Damage +20% and Damage -20% must not share a cache key.
    s := RegExReplace(s, "\+(?=\s*\d)", " plus ")
    s := RegExReplace(s, "[-\x{2212}](?=\s*\d)", " minus ")
    return RegExReplace(s, "[\s\p{P}\p{S}]", "")
}

LoadCardTable(force := false) {
    global CARD_TABLE, CARD_LEARNED, CARD_UNKNOWN_SCORE

    if (IsObject(CARD_TABLE) && !force)
        return CARD_TABLE

    CARD_TABLE := Map()
    CARD_LEARNED := Map()

    path := A_ScriptDir "\Settings\Cards.txt"
    if !FileExist(path)
        return CARD_TABLE

    for line in StrSplit(FileRead(path, "UTF-8"), "`n", "`r") {
        line := Trim(line)
        if (line = "" || SubStr(line, 1, 1) = "#")
            continue

        parts := StrSplit(line, "|")
        if (parts.Length < 3)
            continue

        name := Trim(parts[1])
        typ := StrLower(Trim(parts[2]))
        raw := Trim(parts[3])
        key := NormalizeCardName(name)
        if (key = "" || !IsNumber(raw) || raw + 0 < -100 || raw + 0 > 100
            || !InStr("|buff|nerf|mixed|", "|" typ "|")
            || (typ = "buff" && raw + 0 <= 0) || (typ = "nerf" && raw + 0 >= 0))
            continue

        CARD_TABLE[key] := {name: name, type: typ
            , score: IsNumber(raw) ? raw + 0 : CARD_UNKNOWN_SCORE
            , learned: parts.Length >= 4 && RegExMatch(Trim(parts[4]), "i)^jev\b")}
    }
    return CARD_TABLE
}

LearnCardLine(name, typ, score, note) {
    global CARD_TABLE, CARD_LEARNED, CARD_LEARNING

    if (!CARD_LEARNING)
        return

    key := NormalizeCardName(name)
    if (key = "")
        return
    if (CARD_LEARNED.Has(key) && (CARD_LEARNED[key] != "unknown" || typ = "unknown"))
        return
    CARD_LEARNED[key] := typ

    ; OCR is data, never a new record or field in the local cache.
    name := RegExReplace(name, "[|\r\n\t]", " ")

    path := A_ScriptDir "\Settings\Cards.txt"
    if !FileExist(path)
        FileAppend("# Cards.txt - thuoc tinh the bai`n"
            . "# Format: <ten the> | <type> | <score> | <ghi chu>`n"
            . "#   type : buff | nerf | mixed | unknown`n"
            . "#   score: -100..100  (buff duong, nerf am)`n"
            . "# Ten khong phan biet hoa thuong, bo qua dau cau.`n", path, "UTF-8")

    FileAppend(name " | " typ " | " score " | " note "`n", path, "UTF-8")

    if (IsObject(CARD_TABLE) && typ != "unknown") {
        CARD_TABLE[key] := {name: name, type: typ, score: score}
    }
}

LearnCard(name) {
    LearnCardLine(name, "unknown", 0, "auto")
}

LearnCardScore(name, jevScore) {
    lvScore := Round((jevScore - 2) * 50)
    typ := (jevScore >= 2.5) ? "buff" : ((jevScore <= 1.5) ? "nerf" : "mixed")
    LearnCardLine(name, typ, lvScore, "jev " Round(jevScore, 2))
}

CardScore(name, &typ := "") {
    global CARD_UNKNOWN_SCORE
    policy := AnalyzeCardEffects(name)
    if policy.blocked {
        typ := "unknown"
        return CARD_UNKNOWN_SCORE
    }
    if policy.known {
        typ := policy.score > 0 ? "buff" : (policy.score < 0 ? "nerf" : "mixed")
        return policy.score
    }
    table := LoadCardTable(), key := NormalizeCardName(name)
    if (key != "" && table.Has(key) && !(HasProp(table[key], "learned") && table[key].learned)) {
        typ := table[key].type
        return table[key].score
    }
    typ := "unknown"
    return CARD_UNKNOWN_SCORE
}
