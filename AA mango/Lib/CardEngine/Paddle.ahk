; Isolated local Paddle bridge. Only the card-board ROI crosses this interface.
StartPaddleWorker() {
    global CARD_PADDLE_ENABLED
    if !CARD_PADDLE_ENABLED
        return false
    state := PaddleStartupState()
    if IsObject(state.request) || (state.alive && A_TickCount - state.checked < 1500)
        return state.alive
    if !state.registered {
        OnExit(PaddleCancelStartup)
        state.registered := true
    }
    try {
        health := ComObject("WinHttp.WinHttpRequest.5.1")
        health.SetTimeouts(100, 100, 100, 100)
        health.Open("GET", "http://127.0.0.1:48192/health", true)
        state.request := health, state.deadline := A_TickCount + 500
        health.Send()
        SetTimer(PaddlePollStartup, 50)
    } catch {
        if IsObject(state.request)
            try state.request.Abort()
        state.request := 0, state.alive := false
        SetTimer(PaddleLaunchWorker, -1)
    }
    return state.alive ; Availability hint only; card reads still verify readiness.
}

PaddleStartupState() {
    static state := {request: 0, deadline: 0, checked: 0, alive: false, started: 0, child: 0, registered: false}
    return state
}

PaddlePollStartup() {
    state := PaddleStartupState()
    if !IsObject(state.request) {
        SetTimer(PaddlePollStartup, 0)
        return
    }
    try {
        if !state.request.WaitForResponse(0) && A_TickCount < state.deadline
            return
        if state.request.WaitForResponse(0) && state.request.Status = 200
            && JSON.parse(state.request.ResponseText)["engine"] = "paddleocr" {
            state.alive := true, state.checked := A_TickCount, state.request := 0
            SetTimer(PaddlePollStartup, 0)
            return
        }
    }
    try state.request.Abort()
    state.request := 0, state.alive := false
    SetTimer(PaddlePollStartup, 0)
    PaddleLaunchWorker()
}

PaddleLaunchWorker() {
    state := PaddleStartupState()
    if state.child {
        ; An owned process that is still loading must not be started a second time.
        if DllCall("WaitForSingleObject", "Ptr", state.child, "UInt", 0) = 0x102
            return false
        DllCall("CloseHandle", "Ptr", state.child)
        state.child := 0
    }
    if state.started && A_TickCount - state.started < 10000
        return false
    root := A_ScriptDir "\Tools\PaddleCards"
    python := root "\python\python.exe"
    if !FileExist(python)
        python := root "\.venv\Scripts\python.exe"
    if !FileExist(python) || !FileExist(root "\worker.py") {
        ProcessLog("Card Paddle: runtime unavailable; using Windows OCR fallback")
        return false
    }
    state.started := A_TickCount
    try {
        Run('"' python '" "' root '\worker.py"', root, "Hide", &pid)
        state.child := DllCall("OpenProcess", "UInt", 0x100001, "Int", false, "UInt", pid, "Ptr")
    } catch {
        ProcessLog("Card Paddle: could not start local worker; using Windows OCR fallback")
    }
    return false
}

PaddleCancelStartup(*) {
    state := PaddleStartupState()
    SetTimer(PaddlePollStartup, 0)
    SetTimer(PaddleLaunchWorker, 0)
    if IsObject(state.request)
        try state.request.Abort()
    state.request := 0
    if state.child {
        PaddleCloseChild(state.child)
        state.child := 0
    }
}

PaddleCloseChild(handle, *) {
    DllCall("TerminateProcess", "Ptr", handle, "UInt", 0)
    DllCall("CloseHandle", "Ptr", handle)
}

PaddleCaptureBoard() {
    global rblxID
    WinGetClientPos(&cx, &cy, &cw, &ch, rblxID)
    if cw < 400 || ch < 299 || cw > 3200 || ch > 2396
        throw ValueError("Unsupported card capture dimensions")
    x := cx + Round(143*cw/800), y := cy + Round(210*ch/599)
    w := Round(515*cw/800), h := Round(195*ch/599)
    screen := DllCall("GetDC", "Ptr", 0, "Ptr"), memory := 0, bitmap := 0, previous := 0
    try {
        memory := DllCall("CreateCompatibleDC", "Ptr", screen, "Ptr")
        info := Buffer(40, 0)
        NumPut("UInt", 40, "Int", w, "Int", -h, "UShort", 1, "UShort", 32, info)
        bitmap := DllCall("CreateDIBSection", "Ptr", screen, "Ptr", info, "UInt", 0, "Ptr*", &bits := 0, "Ptr", 0, "UInt", 0, "Ptr")
        if !memory || !bitmap || !bits
            throw Error("Card ROI allocation failed")
        previous := DllCall("SelectObject", "Ptr", memory, "Ptr", bitmap, "Ptr")
        if !DllCall("BitBlt", "Ptr", memory, "Int", 0, "Int", 0, "Int", w, "Int", h, "Ptr", screen, "Int", x, "Int", y, "UInt", 0x00CC0020)
            throw Error("Card ROI capture failed")
        DllCall("GdiFlush")
        image := Buffer(54+w*h*4, 0)
        NumPut("UShort", 0x4D42, image), NumPut("UInt", image.Size, image, 2), NumPut("UInt", 54, image, 10)
        DllCall("RtlMoveMemory", "Ptr", image.Ptr+14, "Ptr", info, "UPtr", 40)
        DllCall("RtlMoveMemory", "Ptr", image.Ptr+54, "Ptr", bits, "UPtr", w*h*4)
        DllCall("Crypt32\CryptBinaryToStringW", "Ptr", image, "UInt", image.Size, "UInt", 0x40000001, "Ptr", 0, "UInt*", &chars := 0)
        encoded := Buffer(chars*2)
        if !DllCall("Crypt32\CryptBinaryToStringW", "Ptr", image, "UInt", image.Size, "UInt", 0x40000001, "Ptr", encoded, "UInt*", &chars)
            throw Error("Card ROI encoding failed")
        return StrGet(encoded)
    } finally {
        if previous
            DllCall("SelectObject", "Ptr", memory, "Ptr", previous)
        if bitmap
            DllCall("DeleteObject", "Ptr", bitmap)
        if memory
            DllCall("DeleteDC", "Ptr", memory)
        if screen
            DllCall("ReleaseDC", "Ptr", 0, "Ptr", screen)
    }
}

PaddleReadCardNames(budgetMs, onlySlot := 0) {
    global rblxID, CARD_READ_CONFLICTS, CARD_PADDLE_ENABLED
    if !CARD_PADDLE_ENABLED
        return 0 ; ReadCardNames uses the Windows OCR path.
    static sequence := 0, lastUnavailable := 0, readyUntil := 0
    if !WinActive(rblxID) || !CardScreenVisible(true) || budgetMs < 100
        return ["", "", ""]
    started := A_TickCount, names := ["", "", ""]
    if A_TickCount >= readyUntil {
    try {
        health := ComObject("WinHttp.WinHttpRequest.5.1")
        health.SetTimeouts(100, 100, 100, 100)
        health.Open("GET", "http://127.0.0.1:48192/health", false), health.Send()
        state := JSON.parse(health.ResponseText)
        if health.Status != 200 || state["engine"] != "paddleocr" || !state["ready"]
            throw Error("Paddle is warming up")
        readyUntil := A_TickCount + 1500
    } catch {
        try StartPaddleWorker()
        if A_TickCount - lastUnavailable > 10000 {
            ProcessLog("Card Paddle: unavailable or warming up; using Windows OCR fallback")
            lastUnavailable := A_TickCount
        }
        return 0
    }
    }
    request := 0
    try {
        id := A_TickCount "-" (++sequence)
        body := JSON.stringify({id: id, offer: PaddleOfferKey(), image: PaddleCaptureBoard(), onlySlot: onlySlot})
        request := ComObject("WinHttp.WinHttpRequest.5.1")
        request.SetTimeouts(100, 100, 200, Max(100, budgetMs))
        request.Open("POST", "http://127.0.0.1:48192/cards", true)
        request.SetRequestHeader("Content-Type", "application/json"), request.Send(body)
        lastVisual := started
        while !request.WaitForResponse(0) {
            if A_TickCount - started >= budgetMs || !WinActive(rblxID) {
                request.Abort()
                return names
            }
            if A_TickCount - lastVisual >= 100 {
                lastVisual := A_TickCount
                if !CardScreenVisible(true) {
                    request.Abort()
                    return names
                }
            }
            Sleep(15)
        }
        if request.Status != 200 {
            readyUntil := 0
            return names
        }
        if A_TickCount - started >= budgetMs || !WinActive(rblxID) || !CardScreenVisible(true)
            return names
        result := JSON.parse(request.ResponseText)
        if result["id"] != id || !(result["names"] is Array) || result["names"].Length != 3
            return names
        for slot, text in result["names"] {
            if Type(text) != "String"
                return ["", "", ""]
            names[slot] := SubStr(Trim(text), 1, 500)
            if text = "" && (!onlySlot || slot = onlySlot)
                CARD_READ_CONFLICTS[slot] := true
        }
        return names
    } catch {
        readyUntil := 0
        if IsObject(request)
            try request.Abort()
        return names
    }
}

PaddleOfferKey() {
    global CARD_MATCH, CARD_OFFER_DEADLINE
    if !IsSet(CARD_OFFER_DEADLINE) || CARD_OFFER_DEADLINE <= 0
        return "" ; standalone/unknown offers never share OCR results
    owner := DllCall("GetCurrentProcessId") ""
    if IsSet(CARD_MATCH) && CARD_MATCH is Map && CARD_MATCH.Has("id")
        owner := CARD_MATCH["id"]
    return owner ":" CARD_OFFER_DEADLINE
}
