; Experimental code is local to DEV. No PROD files or settings are written.
global SmartPlacementColor := -1
global SummerMinimumPlayers := 4
try SmartPlacementColor := Integer(IniRead(A_ScriptDir "\Settings\SmartPlacement.ini", "Preview", "Color", "-1"))
global SmartPlacementState := Map()
global SmartPreviewReference := 0



CalibrateSmartPlacement(*) {
    global rblxID, SmartPlacementColor
    if CardEngineBlocksInput() {
        ProcessLog("Smart: calibration deferred while a card event owns game input")
        return
    }
    if !WinActive(rblxID)
        return
    oldMouse := A_CoordModeMouse, oldPixel := A_CoordModePixel
    CoordMode "Mouse", "Screen"
    CoordMode "Pixel", "Screen"
    try {
        MouseGetPos(&x, &y)
        WinGetClientPos(&cx, &cy, &cw, &ch, rblxID)
        if (x < cx || x >= cx + cw || y < cy || y >= cy + ch)
            return
        color := PixelGetColor(x, y)
        r := (color >> 16) & 255, g := (color >> 8) & 255, b := color & 255
        if (g <= r || g <= b) {
            ProcessLog("Smart: point is not green; select a unit and hover a valid preview surface, then press F6")
            return
        }
        SmartPlacementColor := color
        IniWrite(Format("0x{:06X}", color), A_ScriptDir "\Settings\SmartPlacement.ini", "Preview", "Color")
        SendEvent("q") ; leave no placement ghost active before the next F2 setup
        ProcessLog("Smart: sampled preview color " Format("0x{:06X}", color) "; select Smart and start placement")
    } finally {
        CoordMode "Mouse", oldMouse
        CoordMode "Pixel", oldPixel
    }
}

GenerateSmartPoints() {
    global rblxID
    try WinGetClientPos(,, &cw, &ch, rblxID)
    catch {
        ProcessLog("Smart: client geometry unavailable; stopping candidate search")
        return []
    }
    if cw <= 0 || ch <= 0
        return []
    points := []
    ; All Smart types share Random search across the arena, outside HUD/hotbar.
    spacing := Max(20, Round(40 * cw / 800))
    loop 400 {
        x := Random(Ceil(cw * 0.12), Floor(cw * 0.88))
        y := Random(Ceil(ch * 0.22), Floor(ch * 0.78))
        crowded := false
        for point in points {
            if (x - point.x)**2 + (y - point.y)**2 < spacing**2 {
                crowded := true
                break
            }
        }
        if !crowded
            points.Push({x: x, y: y})
        if points.Length >= 40
            break
    }
    return points
}

SmartPointAllowed(x, y) {
    state:=SmartReadPreviewSample(x,y)
    return state="blue" || state="green"
}

ResetSmartPlacementState() {
    global SmartPlacementState,SmartPreviewReference
    SmartPlacementState := Map()
    SmartPreviewReference:=0
}

SmartPointIsRed(x, y) {
    state := SmartReadPreviewSample(x, y)
    return state = "red" || state = "interrupted"
}

SmartCapturePreviewReference(x,y,slot:=0) {
    global SmartPreviewReference,SmartPreviewUnitType
    SmartPreviewReference:=0
    SmartPreviewUnitType:=slot>=1 && slot<=6 ? GetUnitPlacementType(slot) : "Ground"
    return SmartReadPreviewSample(x,y,&details,true)="baseline"
}

SmartReadTerrainPixels(screenX,screenY,dx,dy,greenPalette,redPalette,&details) {
    oldPixelMode:=A_CoordModePixel
    CoordMode "Pixel","Screen"
    try {
        for offset in [[-dx,-dy],[dx,-dy],[0,0],[-dx,dy],[dx,dy]] {
            color:=PixelGetColor(screenX+offset[1],screenY+offset[2])
            g:=(color>>8)&255
            if SmartPreviewColorMatches(color,greenPalette)
                && g>=((color>>16)&255)+30 && g>=(color&255)+20
                details.fadedGreen++
            if SmartPreviewColorMatches(color,redPalette)
                details.red++
        }
    } finally {
        CoordMode "Pixel",oldPixelMode
    }
    details.green:=Max(details.green,details.fadedGreen)
}

SmartReadPreviewSample(x, y, &details := 0, captureReference := false) {
    global rblxID,SmartPreviewReference,SmartPreviewUnitType
    hill:=IsSet(SmartPreviewUnitType) && SmartPreviewUnitType="Hill"
    static centerPalette:=[[0x05F469,45],[0x00FF00,30],[0x66F800,45]]
    static ringPalette:=[[0x05F469,45],[0x00FF00,30],[0x66F800,45],[0x00C200,30]]
    static fadedGreenPalette:=[[0x05F469,60],[0x00FF00,45],[0x66F800,60],[0x00C200,35]]
    ; Local blue unit-footprint outline supplements the existing green terrain
    ; checks. The outer range circle alone lies outside this bounded patch.
    static normalBluePalette:=[[0x35E5FF,70]],hillBluePalette:=[[0x35E5FF,80]]
    cyanPalette:=hill ? hillBluePalette : normalBluePalette
    static redPalette:=[[0xE83C78,35],[0xFF0000,35],[0xFF0055,35],[0xFF6C5E,25],[0xFF5003,30],[0xC20000,30]]
    details:={reason:"focus-lost",green:0,red:0,ringGreen:0,colors:[]}
    if !WinActive(rblxID) {
        SmartPreviewReference:=0
        return "interrupted"
    }
    details.reason:="geometry-unavailable"
    try WinGetClientPos(&cx,&cy,&cw,&ch,rblxID)
    catch
        return "interrupted"
    details.reason:="outside-arena"
    if x<cw*.12 || x>cw*.88 || y<ch*.22 || y>ch*.78
        return "unknown"
    hwnd:=WinExist(rblxID)
    dx:=Max(1,Round(4*cw/800)),dy:=Max(1,Round(4*ch/599))
    ; Search more of the blue footprint without expanding the terrain-red veto.
    ; Ground:40px, Hill:50px. Green terrain still uses its original sampling area.
    terrainRadius:=hill ? 50 : 20
    terrainRx:=Max(dx,Round(terrainRadius*cw/800)),terrainRy:=Max(dy,Round(terrainRadius*ch/599))
    rx:=Max(terrainRx,Round(40*cw/800)),ry:=Max(terrainRy,Round(40*ch/599))
    w:=2*rx+3,h:=2*ry+3
    details.reason:="capture-unavailable"
    screen:=DllCall("GetDC","Ptr",0,"Ptr"),memory:=0,bitmap:=0,previous:=0
    try {
        if !screen
            return "unknown"
        memory:=DllCall("CreateCompatibleDC","Ptr",screen,"Ptr")
        info:=Buffer(40,0)
        NumPut("UInt",40,"Int",w,"Int",-h,"UShort",1,"UShort",32,info)
        bitmap:=DllCall("CreateDIBSection","Ptr",screen,"Ptr",info,"UInt",0,"Ptr*",&bits:=0,"Ptr",0,"UInt",0,"Ptr")
        if !memory || !bitmap || !bits
            return "unknown"
        previous:=DllCall("SelectObject","Ptr",memory,"Ptr",bitmap,"Ptr")
        if !previous
            return "unknown"
        ; Pass2 confirms the color evidence using a fresh capture.
        loop 2 {
            pass:=A_Index
            WinGetClientPos(&nx,&ny,&nw,&nh,rblxID)
            if !WinActive(rblxID) || nx!=cx || ny!=cy || nw!=cw || nh!=ch {
                SmartPreviewReference:=0,details.reason:="view-interrupted"
                return "interrupted"
            }
            if !DllCall("BitBlt","Ptr",memory,"Int",0,"Int",0,"Int",w,"Int",h,"Ptr",screen,"Int",cx+x-rx-1,"Int",cy+y-ry-1,"UInt",0x00CC0020)
                return "unknown"
            DllCall("GdiFlush")
            if captureReference {
                pixels:=Buffer(w*h*4)
                DllCall("RtlMoveMemory","Ptr",pixels,"Ptr",bits,"UPtr",pixels.Size)
                SmartPreviewReference:={x:x,y:y,cx:cx,cy:cy,cw:cw,ch:ch,hwnd:hwnd,tick:A_TickCount,pixels:pixels}
                details.reason:="baseline"
                return "baseline"
            }
            details.green:=0,details.red:=0,details.ringGreen:=0,details.cyan:=0,details.fadedGreen:=0,details.colors:=[]
            for offset in [[-dx,-dy],[dx,-dy],[0,0],[-dx,dy],[dx,dy]] {
                details.colors.Push(Format("0x{:06X}",NumGet(bits,((ry+offset[2]+1)*w+rx+offset[1]+1)*4,"UInt") & 0xFFFFFF))
                green:=false,red:=false
                loop 3 {
                    py:=ry+offset[2]+A_Index-1
                    loop 3 {
                        px:=rx+offset[1]+A_Index-1
                        color:=NumGet(bits,(py*w+px)*4,"UInt") & 0xFFFFFF
                        if SmartPreviewColorMatches(color,centerPalette)
                            green:=true
                        if SmartPreviewColorMatches(color,redPalette)
                            red:=true
                    }
                }
                if red
                    details.red++
                if green && !red
                    details.green++
            }
            state:=details.red>0 ? "red" : details.green>=4 ? "green" : "unknown"
            ref:=IsSet(SmartPreviewReference) ? SmartPreviewReference : 0
            referenceCurrent:=IsObject(ref) && ref.x=x && ref.y=y && ref.cx=cx && ref.cy=cy && ref.cw=cw && ref.ch=ch
                && ref.hwnd=hwnd && ref.pixels.Size=w*h*4 && A_TickCount-ref.tick<=3500
            ; User rule: one observation of the local blue unit border wins
            ; over terrain green/red. No sector count, streak or second read.
            if referenceCurrent {
                loop w*h {
                    index:=(A_Index-1)*4,color:=NumGet(bits,index,"UInt") & 0xFFFFFF
                    if !SmartPreviewColorMatches(color,cyanPalette)
                        || SmartPreviewColorMatches(NumGet(ref.pixels,index,"UInt") & 0xFFFFFF,cyanPalette)
                        continue
                    px:=Mod(A_Index-1,w)-rx-1,py:=Floor((A_Index-1)/w)-ry-1
                    nx:=px*800/cw,ny:=py*599/ch
                    if nx*nx+ny*ny<36
                        continue ; only the border around the model, not its center
                    WinGetClientPos(&nx,&ny,&nw,&nh,rblxID)
                    if !WinActive(rblxID) || nx!=cx || ny!=cy || nw!=cw || nh!=ch {
                        SmartPreviewReference:=0,details.reason:="view-interrupted"
                        return "interrupted"
                    }
                    details.cyan:=1,details.reason:="blue-border"
                    return "blue"
                }
            }
            ; Direct pixel reads for pale/dim green only. Blue returned above
            ; without paying for these reads or waiting for green confirmation.
            strictGreen:=details.green
            SmartReadTerrainPixels(cx+x,cy+y,dx,dy,fadedGreenPalette,redPalette,&details)
            state:=details.red>0 ? "red" : details.green>=4 ? "green" : "unknown"
            if state="unknown" && referenceCurrent {
                ; Dense red veto applies across all three rings, including gaps.
                loop w*h {
                    px:=Mod(A_Index-1,w)-rx-1,py:=Floor((A_Index-1)/w)-ry-1
                    if Abs(px)>terrainRx+1 || Abs(py)>terrainRy+1
                        continue
                    index:=(A_Index-1)*4,color:=NumGet(bits,index,"UInt") & 0xFFFFFF
                    if SmartPreviewColorMatches(color,redPalette) {
                        state:="red",details.red:=1
                        break
                    }
                }
                if state!="red" {
                    for radius in (hill ? [12,20,32,44,50] : [12,16,20]) {
                        sx:=Max(1,Round(radius*cw/800)),sy:=Max(1,Round(radius*ch/599)),hits:=0
                        for offset in [[-sx,-sy],[0,-sy],[sx,-sy],[-sx,0],[sx,0],[-sx,sy],[0,sy],[sx,sy]] {
                            changedGreen:=false
                            loop 3 {
                                py:=ry+offset[2]+A_Index-1
                                loop 3 {
                                    px:=rx+offset[1]+A_Index-1,index:=(py*w+px)*4
                                    color:=NumGet(bits,index,"UInt") & 0xFFFFFF
                                    before:=NumGet(ref.pixels,index,"UInt") & 0xFFFFFF
                                    if SmartPreviewColorMatches(color,ringPalette) && !SmartPreviewColorMatches(before,ringPalette)
                                        changedGreen:=true
                                }
                            }
                            if changedGreen
                                hits++
                        }
                        details.ringGreen:=Max(details.ringGreen,hits)
                    }
                    if details.ringGreen>=6 {
                        if pass=1 {
                            continue
                        }
                        state:="green"
                    }
                }
            }
            WinGetClientPos(&nx,&ny,&nw,&nh,rblxID)
            if !WinActive(rblxID) || nx!=cx || ny!=cy || nw!=cw || nh!=ch {
                SmartPreviewReference:=0,details.reason:="focus-lost"
                return "interrupted"
            }
            details.reason:=state="green" && strictGreen<4 && details.fadedGreen>=4 ? "faded-green"
                : state="green" && details.green<4 ? "green-ring"
                : state="unknown" ? (details.green ? "partial-green" : "no-green-match") : state
            return state
        }
        return "unknown"
    } catch {
        details.reason:="capture-error"
        return "unknown"
    } finally {
        if previous
            DllCall("SelectObject","Ptr",memory,"Ptr",previous)
        if bitmap
            DllCall("DeleteObject","Ptr",bitmap)
        if memory
            DllCall("DeleteDC","Ptr",memory)
        if screen
            DllCall("ReleaseDC","Ptr",0,"Ptr",screen)
    }
}

ReadUnitDeploymentCount(slot) {
    global rblxID
    static tokens:="|<0/1>FFFFFF-505050$25.00207U3Urw1lzy9lzXUtzlksTksQ3sQQ1yCC0z7C0Tz70Czb0773U1U0U08|<1/1>FFFFFF-505050$22.00E0M3UnUCDy9lzs7DzUsTC3UQsQ1nVk7CC0Qss1nb076Q0A0U08|<0/2>FFFFFF-505050$29.00200S0C7Vz0Qzby9lziC3bbQQCC6ksQ8RVlk1vXXUDb7C0wDwQ3zjtkDz73UDy02002|<1/2>FFFFFF-505050$26.00E01UC7Us3bwy9lzjUQwvsCC6C3V3XVk1ssQ1wCC0w3XUTwtkDz6Q1zk2002|<2/2>FFFFFF-505050$29.00200S0C7Vy0Qzby9lziS3bbMQCC6lkQ8Q7Vk1sy3UDXkC0wDyQ3zzxkDzzvUDy02002|<0/3>FFFFFF-505050$29.00200S0C7Vz0Qzry9lziC3V7QQC0yksQ1tVlk3vXXU0z7C3VzwQ3zDtk7y73U3k02002|<1/3>FFFFFF-505050$26.00E01UC7Us3byy9lzjUQ8vsC0yC3UD3Vk3ssQ07CC3VnXUTstk7y6Q0S02002|<2/3>FFFFFF-505050$29.00200S0C7Vy0Qzry9lziS3V7MQC0ylkQ1s7Vk3sy3U0vkC3VzyQ3zTxk7yzvU3k02002|<3/3>FFFFFF-505050$30.001007U3VsTs3byTsb7y8s72C3sC0y3kC0w3sQ0y0QQ07sQsC7Tss7yTtk7y7Vk1s00U00U|<0/4>FFFFFF-505050$28.00200w0QMrw1lbzlCCTXUstyC73bksQAT3XVzyCC7zstkDzz701rws0773U0A04008|<1/4>FFFFFF-505050$25.00E030QMnUCAzlCCTs77Dw73bC3VXb3VznVkztlkDwss0CQs076Q01U4008|<2/4>FFFFFF-505050$28.00200w0QMrs1lbzlCCTbUstwC73blkQAQD3VznsC7zS1kDzzb01zys07zvU0A04008|<3/4>FFFFFF-505050$29.00100D076BzUCAvz4stmC1lnVw73b3kC6C7ksTw1lkzz3b0zryC03jws077Vk0601002|<4/4>FFFFFF-505050$28.00200lUQMnC1lbQtCCRnUstrC73bMsQATzXVzzyC7zTtkDw3b01kCs070PU0A04008"
    if slot<1 || slot>6 || !WinActive(rblxID) || !UnitActionAllowed()
        return -1
    try {
        WinGetClientPos(&cx,&cy,&cw,&ch,rblxID)
        left:=Round((205+(slot-1)*64)*cw/800)
        found:=false,capture:=1
        ; Prefer the closest glyph match; never mix a loose match with an exact
        ; match (0 and3 can otherwise become ambiguous after UI antialiasing).
        for tolerance in [0,0.02,0.04,0.06,0.08,0.10] {
            found:=FindText(&px,&py,cx+left,cy+Round(498*ch/599),cx+left+Round(70*cw/800),cy+Round(530*ch/599),tolerance,tolerance,tokens,capture,1,0,20,10,1,cw/800,ch/599)
            capture:=0
            if found
                break
        }
        counts:=Map()
        if found {
            for hit in found {
                if RegExMatch(hit.id,"^([0-4])/[1-4]$",&m)
                    counts[Integer(m[1])]:=true
            }
        }
        WinGetClientPos(&nx,&ny,&nw,&nh,rblxID)
        if !WinActive(rblxID) || !UnitActionAllowed() || nx!=cx || ny!=cy || nw!=cw || nh!=ch
            return -1
        if counts.Count=1 {
            for count in counts
                return count
        }
    }
    return -1
}

SmartPreviewPromptVisible(x,y) {
    ; Compatibility helper for point recovery: colors only, no text/key icons.
    ; Never called by the pixel reader itself.
    if SmartPreviewInterrupted(true)
        return false
    state:=SmartReadPreviewSample(x,y,&details)
    return !SmartPreviewInterrupted(true) && (state="blue" || state="green"
        || (details.HasProp("cyan") && details.cyan>0) || details.ringGreen>0)
}

SmartPreviewColorMatches(color, palette) {
    for entry in palette {
        target := entry[1], tolerance := entry[2]
        if Abs(((color >> 16) & 255) - ((target >> 16) & 255)) <= tolerance
            && Abs(((color >> 8) & 255) - ((target >> 8) & 255)) <= tolerance
            && Abs((color & 255) - (target & 255)) <= tolerance
            return true
    }
    return false
}

SmartPressSlotKey(slot, physicalKey := false) {
    if slot < 1 || slot > 6 || SmartPreviewInterrupted(true) || !UnitActionAllowed()
        return false
    oldDelay := A_KeyDelay, oldDuration := A_KeyDuration
    try {
        ; Reuse the old 120 ms selection wait INSIDE the Event keystroke.
        ; A sleep after an immediate key-up cannot make a game see the key-down.
        SetKeyDelay(oldDelay, 120)
        key := String(slot)
        if physicalKey {
            scanCode := GetKeySC(key)
            if !scanCode
                return false
            key := "sc" Format("{:03X}", scanCode)
        }
        SendEvent("{" key "}")
    } catch {
        ProcessLog("Smart: slot " slot " keyboard input failed; preview recovery deferred")
        return false
    } finally {
        SetKeyDelay(oldDelay, oldDuration)
    }
    return !SmartPreviewInterrupted(true) && UnitActionAllowed()
}

SmartPreviewInterrupted(force := false) {
    global rblxID, mode, CARD_OFFER_ACTIVE
    return !WinActive(rblxID) || CARD_OFFER_ACTIVE || CardEngineBlocksInput()
        || (mode = "Summer Event" && CardScreenVisible(force))
}

SmartWaitPreviewReady(x, y, timeoutMs := 1200, &details := 0) {
    deadline := A_TickCount + timeoutMs, greens := 0, reds := 0
    details := {reason: "no-samples", green: 0, red: 0, colors: []}
    while A_TickCount < deadline {
        if SmartPreviewInterrupted()
            return "interrupted"
        state := SmartReadPreviewSample(x, y, &details)
        if state = "interrupted"
            return state
        if state="blue" {
            if SmartPreviewInterrupted(true)
                return "interrupted"
            details.reason:="blue-border"
            return "ready"
        }
        greens := state = "green" ? greens + 1 : 0
        reds := state = "red" ? reds + 1 : 0
        ; Three fresh observations after FixMove; elapsed time alone is not readiness.
        if greens >= 3
            return "ready"
        if reds >= 3
            return "blocked"
        Sleep(40)
    }
    return "unreadable" ; Missing/unknown/late preview is not rejected terrain.
}

SmartTerrainForSlot(slot) {
    global SmartPlacementState
    if !SmartPlacementState.Has(slot)
        SmartPlacementState[slot] := {failures: 0}
    return "Preview" ; Unit preview, rather than a tag-specific branch, decides terrain.
}

SmartRecordPlacementOutcome(slot, outcome) {
    global SmartPlacementState
    SmartTerrainForSlot(slot)
    state := SmartPlacementState[slot]
    if outcome = true {
        state.failures := 0
        return false
    }
    if outcome = false
        state.failures++
    return false
}

SmartPlacementResourceBlocked() {
    ; Read only after a failed placement, not continuously during the match.
    text := SummerReadUI()
    return !!RegExMatch(text, "i)not\s+enough\s+(?:money|yen|cash)|insufficient\s+(?:funds|money)|(?:cannot|can't)\s+afford")
}






ReadSummerVotePlayers() {
    global rblxID
    try {
        WinGetClientPos(&cx, &cy, &cw, &ch, rblxID)
        sx := cw / 800, sy := ch / 599
        ; Counter below the title in the supplied Vote Start screenshot.
        text := ""
        try text := Trim(OCR.FromRect(cx + Round(375*sx), cy + Round(65*sy), Round(65*sx), Round(27*sy), "en-US", 3).Text)
        if RegExMatch(text, "^([0-6])\s*/\s*([1-6])$", &m) && Integer(m[1]) <= Integer(m[2])
            return Integer(m[2])
        ; Windows OCR drops the short fraction even when it is clearly visible.
        ; Measured white digit masks; search ONLY the denominator, never votes cast.
        masks := "|<1>*180$9.zy1kDlyDlyDlyDlyDlyDlzw|<2>*180$10.zzVs1X3yDszXwTXwTXwTU20DzU|<3>*180$11.zz0C0TszXyDwDsDyDwTsnV07kzzw"
        if (matches := FindText(&px, &py, cx + Round(400*sx), cy + Round(65*sy), cx + Round(425*sx), cy + Round(90*sy), 0, 0, masks, 1, 0, 0, 20, 10, 1, sx, sy))
            return Integer(matches[1].id)
    }
    return 0 ; Unknown OCR never causes a lobby return.
}

ReturnSummerLowPlayers() {
    global rblxID, ShowUpgradeUIOnLeftImg, mode, MatchMaking
    if (mode != "Summer Event" || !MatchMaking.Value)
        return false
    ; Reuse the existing measured settings navigation, without the Wave 40 gate.


    oldMouseMode := A_CoordModeMouse

    CoordMode "Mouse", "Client"

    settingsOpened := false

    targetImg := IsSet(ShowUpgradeUIOnLeftImg) ? ShowUpgradeUIOnLeftImg : "Images\ShowUpgradeUIOnLeft_Text.png"

    try {

        FixClick(26, 570) ; open settings

        settingsOpened := true

        Sleep(700)



        ; The panel reopens wherever it was last scrolled, so reset to the top
        ; before stepping down. FixMove is required: Roblox ignores wheel input
        ; until it has processed a fresh mouse-move at that position.

        FixMove(400, 300)

        Sleep(150)

        loop 10 {

            SendInput("{WheelUp}")

            Sleep(110)

        }

        Sleep(1200)

        WinActivate(rblxID)

        Sleep(200)



        ; "Return to Lobby" sits two rows below "Show Upgrade UI on left", so
        ; locate that row and offset to its button. The row also has to sit high
        ; enough for the button underneath to still be inside the panel.

        foundX := 0

        foundY := 0

        ready := false

        loop 16 {

            if ImageSearch(&foundX, &foundY, 200, 150, 620, 460, "*60 " targetImg) {

                if (foundY <= 290) {

                    probeX := foundX

                    probeY := foundY

                    Sleep(650)

                    if (ImageSearch(&foundX, &foundY, 200, 150, 620, 460, "*60 " targetImg)

                        && foundX = probeX && foundY = probeY && foundY <= 290) {

                        ready := true

                        break

                    }

                }

            }

            FixMove(400, 300)

            SendInput("{WheelDown}")

            Sleep(320)

        }



        if !ready {

            ProcessLog("Could not find 'Show Upgrade UI on left' in Settings")

            return false

        }



        ; Measured on the live panel: the toggle centre is foundY + 27 and the
        ; Return to Lobby button sits another 109px below that.

        lobbyX := foundX + 287

        lobbyY := foundY + 136



        WinActivate(rblxID)

        Sleep(150)

        FixClick(lobbyX, lobbyY)

        Sleep(1800)

        settingsOpened := false

        ProcessLog("Clicked Return to Lobby")

        return CheckLobby()

    } finally {

        if (settingsOpened) {

            FixClick(581, 157) ; close settings

            Sleep(250)

        }

        CoordMode "Mouse", oldMouseMode

    }



    return false

}




OpenRegularPlayArea() {
    global rblxID
    if !WinActive(rblxID)
        return false
    WinGetClientPos(&cx, &cy, &cw, &ch, rblxID)
    oldMouse := A_CoordModeMouse
    CoordMode "Mouse", "Screen"
    try {
        ui := OCR.FromRect(cx, cy, cw, ch, "en-US", 2)
        target := 0
        try target := ui.FindString("Play Area")
        if !IsObject(target) {
            areas := ui.FindString("Areas")
            if !WinActive(rblxID)
                return false
            FixClick(cx + Round(areas.x + areas.w/2), cy + Round(areas.y + areas.h/2))
            deadline := A_TickCount + 5000
            while (A_TickCount < deadline && WinActive(rblxID)) {
                ui := OCR.FromRect(cx, cy, cw, ch, "en-US", 2)
                try target := ui.FindString("Play Area")
                if IsObject(target)
                    break
                Sleep(150)
            }
        }
        if !IsObject(target) || !WinActive(rblxID) {
            ProcessLog("Regular modes: Play Area not detected; navigation stopped")
            return false
        }
        FixClick(cx + Round(target.x + target.w/2), cy + Round(target.y + target.h/2))
        ProcessLog("Regular modes: selected Areas -> Play Area")
        deadline := A_TickCount + 8000
        while (A_TickCount < deadline && WinActive(rblxID)) {
            text := SummerReadUI()
            if RegExMatch(text, "i)select\s+world|\bempty\b") {
                ProcessLog("Regular modes: Play Area arrival confirmed")
                return true
            }
            Sleep(200)
        }
        ProcessLog("Regular modes: Play Area arrival not confirmed; movement skipped")
    } catch {
        ProcessLog("Regular modes: Areas route could not be read; navigation stopped")
    } finally {
        CoordMode "Mouse", oldMouse
    }
    return false
}
