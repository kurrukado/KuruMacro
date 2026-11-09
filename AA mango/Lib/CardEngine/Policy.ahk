; Effects with explicit signs/numbers are authoritative over JEV and learned cache.
global CARD_READ_CONFLICTS := Map()
global CARD_OFFER_DEADLINE := 0
global CARD_ACTION_BUSY := false
global CARD_INPUT_BLOCKED := false

CardPriorityWeights() {
    static weights := 0
    if IsObject(weights)
        return weights
    weights := Map("Attack", 100, "Cooldown", 90, "Income", 60, "Range", 30
        , "EnemyHealth", 50, "EnemySpeed", 70, "EnemyDamage", 80
        , "PhysicalResistance", 10000, "MagicResistance", 10000)
    for key, fallback in weights {
        try {
            value := IniRead(A_ScriptDir "\Settings\CardPriorities.ini", "Weights", key, fallback)
            if (IsNumber(value) && value + 0 > 0 && value + 0 <= 100000)
                weights[key] := value + 0
        }
    }
    return weights
}

AnalyzeCardEffects(text) {
    result := {known: false, blocked: false, aiEligible: false, score: 0.0, resistance: 0
        , signature: "", reason: "no explicit effect"}
    if (Trim(text) = "") {
        result.blocked := true
        result.reason := "missing or conflicting OCR"
        return result
    }
    text := StrLower(StrReplace(StrReplace(text, Chr(0x2212), "-"), Chr(0xFF0B), "+"))
    text := RegExReplace(text, "\s+", " ")
    text := RegExReplace(text, "([+-]\s*\d+)\s*[¥￥]", "$1 yen")
    resistanceTitle := !!RegExMatch(text, "spellproof\s+enemies|resistant\s+enemies")
    stat := "(?:physical\s*resist(?:ance|ant)?|magic\s*resist(?:ance|ant)?|attack\s*speed|cooldown|spa|attack|damage|dmg|range|summer\s*pearls?|income|cash|yen|health|speed)"
    ; Normalize both '+13% Attack' and 'Attack +13%' without changing the sign.
    ; Protect forward effects before rewriting reverse notation: the next
    ; line's +50% must not attach to the previous line's SummerPearls label.
    forward := "[+-]\s*\d+(?:\.\d+)?\s*%?\s*(?:enemy\s*)?" stat "\b(*SKIP)(*F)|"
    text := RegExReplace(text, "i)" forward "((?:enemy\s*)?" stat ")\s*([+-])\s*(\d+(?:\.\d+)?)\s*%", "$2$3% $1")
    pattern := "i)([+-])\s*(\d+(?:\.\d+)?)\s*(%?)\s*(enemy\s*)?(" stat ")\b"
    weights := CardPriorityWeights()
    remaining := text, pos := 1, count := 0
    while RegExMatch(text, pattern, &m, pos) {
        amount := (m[1] = "-" ? -1 : 1) * (m[2] + 0)
        attribute := RegExReplace(m[5], "\s+", "")
        enemy := m[4] != ""
        weight := 0, key := "", isResistance := false
        if InStr(attribute, "physicalresist") {
            key := "PhysicalResistance", weight := -weights[key], isResistance := true
        } else if InStr(attribute, "magicresist") {
            key := "MagicResistance", weight := -weights[key], isResistance := true
        } else if (attribute = "cooldown" || attribute = "spa") {
            key := "Cooldown", weight := enemy ? weights[key] : -weights[key]
        } else if (attribute = "attack" || attribute = "damage" || attribute = "dmg" || attribute = "attackspeed") {
            key := enemy ? "EnemyDamage" : "Attack"
            weight := enemy ? -weights[key] : weights[key]
        } else if (attribute = "range" && !enemy) {
            key := "Range", weight := weights[key]
        } else if RegExMatch(attribute, "^(summerpearls?|income|cash|yen)$") {
            key := "Income", weight := weights[key]
        } else if (attribute = "health" && enemy) {
            key := "EnemyHealth", weight := -weights[key]
        } else if (attribute = "speed" && enemy) {
            key := "EnemySpeed", weight := -weights[key]
        }
        ; Resistance/currency also appear as plain signed amounts in saved screenshots.
        if (key != "" && (m[3] = "%" || isResistance || key = "Income")) {
            count++
            result.score += (key = "Income" && m[3] != "%" ? (amount > 0 ? 1 : -1) : amount) * weight / 100
            if (isResistance && amount > 0)
                result.resistance++
            result.signature .= key ":" amount ";"
            remaining := StrReplace(remaining, m[0], " ")
        }
        pos := m.Pos + m.Len
    }
    ; Partial OCR must not turn a mixed card into a pure buff.
    if (resistanceTitle && !InStr(result.signature, "Resistance")) {
        result.blocked := true
        result.reason := "resistance title without readable resistance effect"
        return result
    }
    if RegExMatch(remaining, "[+-]\s*\d|\d\s*%|physical\s*resist|magic\s*resist|spellproof|resistant\s+enemies") {
        ; Resistance titles are redundant only if their signed effect was parsed.
        remaining := RegExReplace(remaining, "i)spellproof\s+enemies|resistant\s+enemies", "")
        if RegExMatch(remaining, "[+-]\s*\d|\d\s*%|physical\s*resist|magic\s*resist") {
            if (!RegExMatch(remaining, "physical\s*resist|magic\s*resist")
                && RegExMatch(remaining, "[+-]\s*\d+(?:\.\d+)?\s*%\s*\p{L}{3,}")
                && !InStr(text, Chr(0xFFFD))) {
                result.aiEligible := true
                result.reason := "coherent new mechanic; AI classification required"
                return result ; do not use the partial local score
            }
            result.blocked := true
            result.reason := "unparsed signed effect or resistance"
            return result
        }
        if (count = 0) {
            result.blocked := true
            result.reason := "resistance effect unreadable"
            return result
        }
    }
    result.known := count > 0
    result.reason := result.known ? "explicit signed effects" : "needs local/JEV fallback"
    return result
}

CardEffectsAgree(a, b) {
    first := AnalyzeCardEffects(a), second := AnalyzeCardEffects(b)
    if (first.blocked || second.blocked)
        return false
    if (first.known != second.known)
        return false
    if first.known
        return first.signature = second.signature
    return CanonicalCardText(a) = CanonicalCardText(b)
}
