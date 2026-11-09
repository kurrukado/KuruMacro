; Card engine: Decision. Runtime behavior preserved during extraction.

ChooseCard(names, &reason := "", deadlineTick := 0) {
    global JEV_LAST_MS, CARD_READ_CONFLICTS, CARD_READ_BUDGET_MS, JEV_LAST_DETAILS, CARD_LAST_ANALYSIS
    JEV_LAST_MS := 0
    if !(names is Array) || names.Length != 3 {
        reason := "invalid offer"
        return 0
    }
    scores := [], policies := [], origins := [], unknown := false
    for i, text in names {
        policy := AnalyzeCardEffects(text)
        if (CARD_READ_CONFLICTS.Has(i) && CARD_READ_CONFLICTS[i]) {
            policy.blocked := true
            policy.reason := "raw/contrast conflict, capture failure or read budget exhausted"
        }
        policies.Push(policy)
        if policy.blocked {
            ProcessLog("Card policy: slot " i " excluded: " policy.reason)
            scores.Push(""), origins.Push("ambiguous")
            continue
        }
        value := CardScore(text, &typ)
        if (typ = "unknown") {
            cached := CardMemoryLookup(text)
            if IsObject(cached) {
                scores.Push(cached.score), origins.Push("memory:" cached.source)
                policy.resistance := Max(policy.resistance, cached.resistance)
            } else {
                scores.Push(""), origins.Push("unknown"), unknown := true
            }
        } else {
            scores.Push(value), origins.Push(policy.known ? "signed-effects" : "manual-local")
            if policy.known
                CardMemoryStoreLocal(text, policy)
        }
    }
    remaining := deadlineTick > 0 ? Max(0, deadlineTick - A_TickCount - 1750) : 0
    if (unknown && (deadlineTick = 0 || remaining > 0)) {
        js := JevScore(names, &jok, remaining)
        if (jok && js.Length = 3) {
            for i, text in names {
                if (!policies[i].blocked && origins[i] = "unknown" && Type(js[i]) != "String") {
                    scores[i] := (js[i] - 2) * 50
                    origins[i] := "jev-new-mechanic"
                    if (JEV_LAST_DETAILS.Length >= i) {
                        detail := JEV_LAST_DETAILS[i]
                        policies[i].resistance := Max(policies[i].resistance, detail.resistance)
                        CardMemoryStoreAI(names[i], detail)
                    }
                }
            }
        }
    }
    CARD_LAST_ANALYSIS := []
    for i, value in scores
        CARD_LAST_ANALYSIS.Push({slot: i, source: origins[i], score: value, resistance: policies[i].resistance, effects: policies[i].signature})
    best := 0, bestResistance := 999, bestScore := 0
    for i, score in scores {
        if Type(score) = "String"
            continue
        resistance := policies[i].resistance
        ProcessLog("Card policy: slot " i ", source=" origins[i] ", resistance=" resistance ", weighted=" Round(score, 2))
        if (!best || resistance < bestResistance || (resistance = bestResistance && score > bestScore)) {
            best := i, bestResistance := resistance, bestScore := score
        }
    }
    reason := best ? origins[best] "; resistance=" bestResistance "; weighted=" Round(bestScore, 2) : "no coherent card"
    return best
}
