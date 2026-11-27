#Requires AutoHotkey v2.0

WorldCatalog() {
    static data := JSON.parse(FileRead(A_ScriptDir "\GameModeImages\WorldCards.json", "UTF-8"))
    return data
}

WorldMapNames(section) {
    names := []
    for entry in WorldCatalog()[section]
        names.Push(entry["name"])
    return names
}

WorldTextKey(text) => RegExReplace(StrLower(text), "[^a-z0-9]")

WorldCardEntry(name, section := "main") {
    key := WorldTextKey(name)
    for entry in WorldCatalog()[section] {
        if key = WorldTextKey(entry["name"]) || key = WorldTextKey(entry["title"])
            return entry
    }
    return 0
}

WorldViewValid(view) {
    global rblxID
    if !IsObject(view) || WinActive(rblxID) != view.window
        return false
    try WinGetClientPos(&x, &y, &w, &h, "ahk_id " view.window)
    catch TargetError
        return false
    return x = view.x && y = view.y && w = view.w && h = view.h
}

WorldImageFind(filename, view, region, width, height, &x := 0, &y := 0, variation := 45) {
    if !WorldViewValid(view)
        return false
    path := A_ScriptDir "\GameModeImages\" filename
    if !FileExist(path)
        return false
    oldMode := A_CoordModePixel
    CoordMode "Pixel", "Screen"
    try {
        found := ImageSearch(&px, &py, view.x + Round(region[1]*view.sx), view.y + Round(region[2]*view.sy)
            , view.x + Round(region[3]*view.sx), view.y + Round(region[4]*view.sy)
            , "*" variation " *TransBlack *w" Max(1,Round(width*view.sx)) " *h" Max(1,Round(height*view.sy)) " " path)
        if !found || !WorldViewValid(view)
            return false
        x := (px-view.x)/view.sx, y := (py-view.y)/view.sy
        return true
    } catch Error {
        return false
    } finally {
        CoordMode "Pixel", oldMode
    }
}

WorldSelectorState() {
    if !CapysGetClientBox(&cx, &cy, &cw, &ch, &window) || !WinActive("ahk_id " window)
        return 0
    view := {window:window, x:cx, y:cy, w:cw, h:ch, sx:cw/800, sy:ch/599, section:""}
    if !WorldImageFind("World_SelectWorld.png", view, [605,165,798,201], 93,20)
        return 0
    if WorldImageFind("World_MainToggle.png",view,[646,120,756,160],81,15)
        view.section := "main"
    else if WorldImageFind("World_LegendToggle.png",view,[646,120,756,160],84,15)
        view.section := "legend"
    return view.section != "" ? view : 0
}

WorldClick(view, x, y) {
    if !WorldViewValid(view)
        return false
    oldMode := A_CoordModeMouse
    CoordMode "Mouse", "Screen"
    try {
        FixClick(view.x+Round(x*view.sx),view.y+Round(y*view.sy))
        FixMove(view.x+Round(580*view.sx),view.y+Round(475*view.sy))
    } finally {
        CoordMode "Mouse", oldMode
    }
    return WorldViewValid(view)
}

WorldClearLobbyNotices(view) {
    return DismissInfiniteReturnNotice(view) && DismissWorldPromoNotice(view)
}

DismissInfiniteReturnNotice(view := 0) {
    if !IsObject(view)
        view := LobbyEntryView()
    if !WorldViewValid(view)
        return false
    if !WorldImageFind("World_InfiniteReturnNotice.png",view,[231,224,567,287],299,25)
        return WorldViewValid(view)
    if !WorldClick(view,400,343)
        return false
    Sleep(200)
    return WorldViewValid(view)
}

DismissWorldPromoNotice(view := 0) {
    if !IsObject(view)
        view := LobbyEntryView()
    if !WorldViewValid(view)
        return false
    if !WorldImageFind("World_PromoTitle.png",view,[585,200,780,257],143,20)
        return WorldViewValid(view)
    if !WorldClick(view,761,214)
        return false
    Sleep(200)
    return WorldViewValid(view)
}

WorldScroll(view, direction, ticks := 2, actList := false) {
    if !WorldViewValid(view)
        return false
    oldMode := A_CoordModeMouse
    CoordMode "Mouse", "Screen"
    try {
        FixMove(view.x+Round((actList?285:700)*view.sx),view.y+Round(330*view.sy))
        loop ticks {
            if !WorldViewValid(view)
                return false
            if Mod(A_Index,2) = 1 && !WorldImageFind("World_SelectWorld.png",view,[605,165,798,201],93,20)
                return false
            SendEvent(direction = "up" ? "{WheelUp}" : "{WheelDown}")
            Sleep(40)
        }
        FixMove(view.x+Round(580*view.sx),view.y+Round(475*view.sy))
        Sleep(180)
    } finally {
        CoordMode "Mouse", oldMode
    }
    return WorldViewValid(view)
}

WorldReadRegion(view, x, y, w, h) {
    if !WorldViewValid(view)
        return 0
    try {
        result := OCR.FromRect(view.x+Round(x*view.sx),view.y+Round(y*view.sy)
            ,Round(w*view.sx),Round(h*view.sy),"en-US",3)
        return WorldViewValid(view) ? result : 0
    }
    return 0
}

WorldMapConfirmed(entry, view) {
    result := WorldReadRegion(view,229,171,341,30)
    if !IsObject(result)
        return false
    text := WorldTextKey(result.Text)
    name := WorldTextKey(entry["name"])
    if SubStr(text,1,StrLen(name)) = name
        return true
    try {
        text := WorldTextKey(ReadHighContrastText(view.x+Round(229*view.sx),view.y+Round(171*view.sy)
            ,Round(341*view.sx),Round(30*view.sy),3,0,false,true))
        if WorldViewValid(view) && SubStr(text,1,StrLen(name)) = name
            return true
    }
    titles := []
    for known in WorldCatalog()[view.section]
        titles.Push(known["title"])
    header := RegExReplace(result.Text,"i)\(\s*unit.*$","")
    return WorldViewValid(view) && SummerQuantumMatchName(header,titles) = entry["title"]
}

SelectWorldMap(name, section := "main") {
    entry := WorldCardEntry(name,section)
    if !IsObject(entry) {
        ProcessLog("World selection: map unavailable in " section ": " name)
        return false
    }
    view := WorldSelectorState()
    if !IsObject(view) {
        ProcessLog("World selection: Select World is not confirmed")
        return false
    }
    if !WorldClearLobbyNotices(view)
        return false
    if view.section != section {
        if !WorldClick(view,700,140)
            return false
        switchDeadline := A_TickCount+2000
        loop {
            Sleep(150)
            view := WorldSelectorState()
            if IsObject(view) && view.section = section
                break
            if A_TickCount >= switchDeadline {
                ProcessLog("World selection: category change was not confirmed")
                return false
            }
        }
    }

    if !WorldScroll(view,"up",20)
        return false
    deadline := A_TickCount+25000
    loop 12 {
        view := WorldSelectorState()
        if !IsObject(view) || view.section != section || A_TickCount >= deadline
            break
        if !WorldClearLobbyNotices(view)
            return false
        if WorldImageFind(entry["image"],view,[612,202,783,456],entry["width"],entry["height"],&x,&y) {
            ; The name strip is above the progress/record fields.
            if !WorldClick(view,x+Min(60,entry["width"]/2),y+8)
                return false
            loop 5 {
                Sleep(150)
                if WorldMapConfirmed(entry,view) {
                    ProcessLog("World selected: " entry["title"] " (" section ")")
                    return true
                }
                if !WorldViewValid(view)
                    return false
            }
            ProcessLog("World selection: detail header did not confirm " entry["title"])
            return false
        }
        if !WorldScroll(view,"down",2)
            return false
    }
    ProcessLog("World selection: card not found before timeout: " entry["title"])
    return false
}

SelectWorldAct(actName, section := "main") {
    infinite := actName = "Infinity" || actName = "Infinite"
    if !infinite && !RegExMatch(actName,"i)^Act ([1-6])$",&number)
        return false
    if section = "legend" && infinite
        return false
    wanted := infinite ? "infinite" : (section = "legend" ? "legendstage" : "act") number[1]
    view := WorldSelectorState()
    if !IsObject(view) || view.section != section
        return false
    if section = "legend" {
        act := Integer(number[1])
        if !WorldScroll(view,"up",3,true)
            return false
        if act = 6 {
            if !WorldScroll(view,"down",3,true)
                return false
            region := [244,361,328,403]
        } else {
            if !WorldImageFind("World_LegendAct1.png",view,[244,218,328,252],70,15,&firstX,&firstY)
                return false
            row := firstY + Round(34.5*(act-1))
            region := [244,row-4,328,row+19]
        }
        if !WorldImageFind("World_LegendAct" act ".png",view,region,70,15,&actX,&actY) {
            ProcessLog("World selection: legend act button unavailable: " actName)
            return false
        }
        if !WorldClick(view,285,actY+7)
            return false
        loop 4 {
            Sleep(150)
            heading := WorldReadRegion(view,365,214,195,40)
            if (IsObject(heading) && RegExMatch(WorldTextKey(heading.Text),"stage" act "(?![0-9])"))
                || (act >= 5 && WorldImageFind("World_LegendHeading" act ".png",view,[379,210,532,254],128,23,,,30)) {
                ProcessLog("World act selected: " actName " (legend)")
                return true
            }
        }
        ProcessLog("World selection: legend act was not confirmed: " actName)
        return false
    }
    if !WorldScroll(view,"up",8,true)
        return false

    loop 4 {
        result := WorldReadRegion(view,242,214,96,190)
        if !IsObject(result)
            return false
        for line in result.Lines {
            key := WorldTextKey(line.Text)
            if key != wanted && !InStr(key,wanted)
                continue
            if !WorldClick(view,285,214+(line.y+line.h/2)/view.sy)
                return false
            loop 4 {
                Sleep(150)
                heading := WorldReadRegion(view,365,214,195,40)
                if IsObject(heading) && InStr(WorldTextKey(heading.Text),wanted) {
                    ProcessLog("World act selected: " actName " (" section ")")
                    return true
                }
            }
            ProcessLog("World selection: act heading did not confirm " actName)
            return false
        }
        if !WorldScroll(view,"down",2,true)
            return false
    }
    ProcessLog("World selection: act unavailable: " actName)
    return false
}

WorldStartSolo() {
    view := WorldSelectorState()
    if !IsObject(view) || !WorldImageFind("World_StageSelect.png",view,[340,413,460,456],61,24,&x,&y) {
        ProcessLog("World start: Select button is not confirmed")
        return false
    }
    if !WorldClick(view,x+30,y+12)
        return false

    clickedPlayHere := false
    deadline := A_TickCount + 6000
    while A_TickCount < deadline && WorldViewValid(view) {
        if WorldImageFind("World_StageReady.png",view,[22,187,209,230],150,18)
            && WorldImageFind("World_StageStart.png",view,[323,435,480,491],88,31,&x,&y) {
            if !WorldClick(view,x+44,y+15)
                return false
            loop 12 {
                Sleep(150)
                if !WorldViewValid(view)
                    return false
                if !WorldImageFind("World_StageStart.png",view,[323,435,480,491],88,31) {
                    ProcessLog("World start: room Start confirmed")
                    return true
                }
            }
            break
        }
        if !clickedPlayHere && WorldImageFind("World_StageMatchPrompt.png",view,[218,204,580,272],338,43)
            && WorldImageFind("World_StagePlayHere.png",view,[271,328,398,380],109,29,&x,&y) {
            if !WorldClick(view,x+54,y+14)
                return false
            clickedPlayHere := true
        }
        Sleep(150)
    }
    ProcessLog("World start: room did not confirm Start before timeout")
    return false
}
