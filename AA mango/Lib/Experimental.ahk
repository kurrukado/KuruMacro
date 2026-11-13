; Smart placement and other opt-in helpers.
global SmartPlacementColor := -1
global SummerMinimumPlayers := 4
try SmartPlacementColor := Integer(IniRead(A_ScriptDir "\Settings\SmartPlacement.ini", "Preview", "Color", "-1"))
global SmartPlacementState := Map()
global SmartPreviewReference := 0
global SmartHillRegions := 0, SmartHillBefore := 0, SmartHillRevision := 0



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

GenerateSmartPoints(&scale := 0, slot := 0) {
    global rblxID
    try WinGetClientPos(,, &cw, &ch, rblxID)
    catch {
        ProcessLog("Smart: client geometry unavailable; stopping candidate search")
        return []
    }
    if cw <= 0 || ch <= 0
        return []
    minX := Ceil(cw * 0.12), maxX := Floor(cw * 0.88)
    minY := Ceil(ch * 0.22), maxY := Floor(ch * 0.78)
    if minX > maxX || minY > maxY
        return []
    scale := {x: cw / 800, y: ch / 599}
    points := []
    ; Standard placement camera: feet project slightly below the client center.
    ; Ground/Farm/Hybrid stay local even after exhausting a batch. Only Hill
    ; expands beyond the player's immediate surroundings to seek platforms.
    centerX := cw/2, centerY := ch*0.55
    kind := slot >= 1 && slot <= 6 ? GetUnitPlacementType(slot) : ""
    hill := kind = "Hill"
    ; Rings are [inner, outer] pairs in reference pixels. Ground/Farm/Hybrid stay
    ; local; only Hill expands beyond the player's immediate surroundings.
    ; Farm walks the widest ring first and works inward, so farms fill the
    ; outside of the placement area instead of hugging the player.
    bands := [[0,24],[24,48],[48,72],[72,96]]
    if hill
        bands := [[0,24],[24,48],[48,72],[72,96],[96,175],[175,250],[250,400]]
    else if kind = "Farm"
        bands := [[72,96],[48,72],[24,48],[0,24]]
    for band in bands {
        inner := band[1], outer := band[2]
        added := 0
        loop 160 {
            radius := Sqrt(Random(inner*inner, outer*outer))
            angle := Mod(A_Index, 2) ? Random(0,359) : Random(0,3)*90 + Random(-10,10)
            angle *= 0.0174532925199433
            point := {x: Round(centerX + Cos(angle)*radius*scale.x), y: Round(centerY + Sin(angle)*radius*scale.y)}
            actualRadius2 := ((point.x-centerX)/scale.x)**2 + ((point.y-centerY)/scale.y)**2
            if actualRadius2 > outer*outer || actualRadius2 < inner*inner
                continue
            if point.x < minX || point.x > maxX || point.y < minY || point.y > maxY
                continue
            if SmartPlacementTooClose(points, point, scale, outer <= 48 ? 8 : outer <= 110 ? 12 : 24)
                continue
            points.Push(point)
            if ++added >= 8
                break
        }
    }
    if hill {
        hints := SmartHillRegionPoints(slot)
        if hints.Length {
            ordered := hints.Clone()
            for point in points {
                if !SmartPlacementTooClose(ordered, point, scale, 8)
                    ordered.Push(point)
            }
            return ordered
        }
    }
    return points
}

SmartHillCaptureGrid() {
    global rblxID
    if SmartPreviewInterrupted(true)
        return 0
    screen := 0, memory := 0, bitmap := 0, previous := 0
    try {
        WinGetClientPos(&cx, &cy, &cw, &ch, rblxID)
        if cw <= 0 || ch <= 0
            return 0
        left := Ceil(cw*.12), top := Ceil(ch*.22)
        w := Floor(cw*.88)-left+1, h := Floor(ch*.78)-top+1
        stepX := Max(1,Round(12*cw/800)), stepY := Max(1,Round(12*ch/599))
        screen := DllCall("GetDC", "Ptr", 0, "Ptr")
        memory := DllCall("CreateCompatibleDC", "Ptr", screen, "Ptr")
        info := Buffer(40,0)
        NumPut("UInt",40,"Int",w,"Int",-h,"UShort",1,"UShort",32,info)
        bitmap := DllCall("CreateDIBSection","Ptr",screen,"Ptr",info,"UInt",0,"Ptr*",&bits:=0,"Ptr",0,"UInt",0,"Ptr")
        if !screen || !memory || !bitmap || !bits
            return 0
        previous := DllCall("SelectObject","Ptr",memory,"Ptr",bitmap,"Ptr")
        if !previous || !DllCall("BitBlt","Ptr",memory,"Int",0,"Int",0,"Int",w,"Int",h,"Ptr",screen,"Int",cx+left,"Int",cy+top,"UInt",0x00CC0020)
            return 0
        DllCall("GdiFlush")
        cols := Floor((w-1)/stepX)+1, rows := Floor((h-1)/stepY)+1
        colors := []
        loop rows {
            row := A_Index-1
            loop cols
                colors.Push(NumGet(bits,(row*stepY*w+(A_Index-1)*stepX)*4,"UInt") & 0xFFFFFF)
        }
        WinGetClientPos(&nx,&ny,&nw,&nh,rblxID)
        if SmartPreviewInterrupted(true) || nx!=cx || ny!=cy || nw!=cw || nh!=ch
            return 0
        return {colors:colors, cols:cols, rows:rows, left:left, top:top, stepX:stepX, stepY:stepY
            , view:WinExist(rblxID) "," cx "," cy "," cw "," ch, tick:A_TickCount}
    } catch {
        return 0
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

SmartHillGreen(color) {
    r := (color>>16)&255, g := (color>>8)&255, b := color&255
    return g >= 100 && g-r >= 45 && g-b >= 30
}

SmartHillColorDelta(a,b) {
    return Abs(((a>>16)&255)-((b>>16)&255)) + Abs(((a>>8)&255)-((b>>8)&255)) + Abs((a&255)-(b&255))
}

SmartHillBuildRegions(before, after) {
    if before.view != after.view || before.colors.Length != after.colors.Length
        return []
    mask := Map(), points := []
    for index,color in after.colors {
        old := before.colors[index]
        if SmartHillGreen(color) && (!SmartHillGreen(old) || SmartHillColorDelta(color,old)>=100)
            mask[index] := true
    }
    ; Keep actual interior cells, never fill a rectangle across holes or edges.
    for index in mask {
        col := Mod(index-1,after.cols), row := Floor((index-1)/after.cols)
        neighbors := (col>0 && mask.Has(index-1)) + (col<after.cols-1 && mask.Has(index+1))
            + (row>0 && mask.Has(index-after.cols)) + (row<after.rows-1 && mask.Has(index+after.cols))
        if neighbors < 3
            continue
        points.Push({x:after.left+col*after.stepX, y:after.top+row*after.stepY})
    }
    ; Uniformly retain coverage across all visible platforms within a small cap.
    if points.Length > 128 {
        reduced := []
        loop 128
            reduced.Push(points[Floor((A_Index-1)*points.Length/128)+1])
        return reduced
    }
    return points
}

SmartHillSceneMatches(a,b) {
    if a.view != b.view || a.colors.Length != b.colors.Length
        return false
    changed := 0, sampled := 0
    loop Ceil(a.colors.Length/7) {
        index := (A_Index-1)*7+1
        sampled++
        if SmartHillColorDelta(a.colors[index],b.colors[index])>100
            changed++
    }
    return changed <= sampled*.30
}

SmartPrepareHillRegions() {
    global SmartHillRegions, SmartHillBefore, SmartHillRevision
    SmartHillBefore := 0
    current := SmartHillCaptureGrid()
    if !IsObject(current) {
        SmartHillRegions := 0
        return
    }
    if IsObject(SmartHillRegions) && A_TickCount-SmartHillRegions.tick < 10000
        && SmartHillSceneMatches(SmartHillRegions.before,current)
        return
    SmartHillRegions := 0
    SmartHillBefore := current
}

SmartCollectHillRegions() {
    global SmartHillRegions, SmartHillBefore, SmartHillRevision
    before := SmartHillBefore, SmartHillBefore := 0
    if !IsObject(before) || A_TickCount-before.tick > 3500
        return
    after := SmartHillCaptureGrid()
    if !IsObject(after) || after.view != before.view
        return
    points := SmartHillBuildRegions(before,after)
    SmartHillRevision++
    SmartHillRegions := {points:points, before:before, tick:A_TickCount, version:SmartHillRevision}
    ProcessLog("Smart Hill: cached " points.Length " green interior candidates; preview still required")
}

SmartHillRegionVersion(slot) {
    global SmartHillRegions, rblxID
    if slot<1 || slot>6 || GetUnitPlacementType(slot)!="Hill" || !IsObject(SmartHillRegions)
        return 0
    if SmartPreviewInterrupted(true) || A_TickCount-SmartHillRegions.tick >= 10000 {
        SmartHillRegions := 0
        return 0
    }
    try {
        WinGetClientPos(&cx,&cy,&cw,&ch,rblxID)
        if (WinExist(rblxID) "," cx "," cy "," cw "," ch) != SmartHillRegions.before.view {
            SmartHillRegions := 0
            return 0
        }
        return SmartHillRegions.version
    }
    return 0
}

SmartHillRegionPoints(slot) {
    global SmartHillRegions
    if !SmartHillRegionVersion(slot)
        return []
    points := SmartHillRegions.points.Clone()
    ; Randomize within the mask so one edge is not tested first on every pass.
    loop points.Length {
        index := Random(A_Index,points.Length)
        temp := points[A_Index], points[A_Index] := points[index], points[index] := temp
    }
    return points
}

SmartPlacementTooClose(points, candidate, scale, distance := 24) {
    for point in points {
        dx := (point.x - candidate.x) / scale.x
        dy := (point.y - candidate.y) / scale.y
        if dx*dx + dy*dy < distance*distance
            return true
    }
    return false
}

SmartPlacementGeometry() {
    global rblxID
    try {
        WinGetClientPos(&x, &y, &w, &h, rblxID)
        return w > 0 && h > 0 ? x "," y "," w "," h : ""
    }
    return ""
}

SmartRememberPoint(points, point, temporary := false) {
    ; Bound pass-local memory. No bitmap or OCR result is retained.
    points.Push({x: point.x, y: point.y, until: temporary ? A_TickCount + 15000 : 0})
    if points.Length > 256
        points.RemoveAt(1)
}

SmartRecentPoint(points, point, scale) {
    index := points.Length
    while index > 0 {
        previous := points[index]
        if previous.until && A_TickCount >= previous.until
            points.RemoveAt(index)
        else if ((previous.x-point.x)/scale.x)**2 + ((previous.y-point.y)/scale.y)**2 < 8**2
            return true
        index--
    }
    return false
}

FindSmartPlacementPanel() {
    global rblxID
    ; User-approved UPG image is primary; red X remains an alternate marker.
    ; Restrict both to the unit panel, never arbitrary dialogs elsewhere.
    static header := "|<UPGUser>FFCC00-504940$27.000000000MPs733TXyMPCQX3Mr0MP6nn3TaSMPwslaM3aDn0DkMM0s000000000U"
    static closeX := "|<UnitCloseX>FFFFFF-323232$23.00000000000000000000A1U0Q700wS00zk00zU00y003y00DS00wS01UQ0000000000000001"
    oldPixelMode := A_CoordModePixel
    CoordMode "Pixel", "Screen"
    try {
        WinGetClientPos(&cx, &cy, &cw, &ch, rblxID)
        sx := cw/800, sy := ch/599
        if sx <= 0 || sy <= 0
            return false
        headerFound := FindText(,, cx + Round(135*sx), cy + Round(217*sy), cx + Round(188*sx), cy + Round(275*sy)
            , 0.15, 0.15, header, 1, 0, 0, 20, 10, 1, sx, sy)
        if !headerFound {
            if !FindText(&buttonX, &buttonY, cx + Round(240*sx), cy + Round(180*sy), cx + Round(310*sx), cy + Round(260*sy)
                , 0.15, 0.15, closeX, 1, 0, 0, 20, 10, 1, sx, sy)
                return false
            redButton := false
            for offset in [-9, 9] {
                color := PixelGetColor(buttonX + Round(offset*sx), buttonY)
                if ((color>>16)&255) >= 140 && ((color>>8)&255) < 110 && (color&255) < 110
                    redButton := true
            }
            if !redButton
                return false
        }
        WinGetClientPos(&nx, &ny, &nw, &nh, rblxID)
        return WinActive(rblxID) && nx = cx && ny = cy && nw = cw && nh = ch
    } catch {
        return false
    } finally {
        CoordMode "Pixel", oldPixelMode
    }
    return false
}

WaitForSmartPlacement(deadline, settleUntil := 0) {
    global rblxID, mode, CARD_OFFER_ACTIVE
    ; Leave time for the final native image match and Windows timer rounding.
    scanUntil := deadline - 75
    moved := false
    while A_TickCount < scanUntil {
        if !WinActive(rblxID)
            return "uncertain"
        if mode = "Summer Event" && (CARD_OFFER_ACTIVE || CardScreenVisible(true))
            return "card-interrupted"
        ; Keep the mouse at the clicked point throughout the settling delay.
        ; Then move only (no click) to remove hover labels before recognition.
        if !moved && A_TickCount >= settleUntil {
            try {
                WinGetClientPos(,, &cw, &ch, rblxID)
                FixMove(Round(638*cw/800), Round(500*ch/599))
            }
            moved := true
        }
        if A_TickCount >= settleUntil && FindSmartPlacementPanel() && A_TickCount < deadline
            return true
        remaining := scanUntil - A_TickCount
        if remaining > 0
            Sleep(Min(60, remaining))
    }
    return false
}

SmartPointAllowed(x, y) {
    state:=SmartReadPreviewSample(x,y)
    return state="blue" || state="green"
}

ResetSmartPlacementState() {
    global SmartPlacementState,SmartPreviewReference,SmartHillRegions,SmartHillBefore
    SmartPlacementState := Map()
    SmartPreviewReference:=0
    SmartHillRegions:=0, SmartHillBefore:=0
}

SmartPointIsRed(x, y) {
    state := SmartReadPreviewSample(x, y)
    return state = "red" || state = "interrupted"
}

SmartCapturePreviewReference(x,y,slot:=0) {
    global SmartPreviewReference,SmartPreviewUnitType
    SmartPreviewReference:=0
    SmartPreviewUnitType:=slot>=1 && slot<=6 ? GetUnitPlacementType(slot) : "Ground"
    ready := SmartReadPreviewSample(x,y,&details,true)="baseline"
    if ready && SmartPreviewUnitType="Hill"
        SmartPrepareHillRegions()
    return ready
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
        masks := "|<1>*180$9.zy1kDlyDlyDlyDlyDlyDlzw|<2>*180$10.zzVs1X3yDszXwTXwTXwTU20DzU|<3>*180$11.zz0C0TszXyDwDsDyDwTsnV07kzzw|<6>*180$11.zzzzzz3k3XzDyzx1s1nljXT6QQ0y7zzzzU"
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
