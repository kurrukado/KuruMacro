#Include %A_ScriptDir%\Lib\Discord-Webhook-master\lib\WEBHOOK.ahk
#Include %A_ScriptDir%\Lib\AHKv2-Gdip-master\Gdip_All.ahk

global WebhookURLFile := "Settings\WebhookURL.txt"
global DiscordUserIDFile := "Settings\DiscordUSERID.txt"
global SendActivityLogsFile := "Settings\SendActivityLogs.txt"
global WebhookURL := ""  
global webhook := ""
global currentStreak := 0
global lastResult := "none"
global Wins := 0
global loss := 0
; GUI owns the selected mode; loading webhook support must not reset it.
global mode := IsSet(mode) ? mode : ""
global StartTime := A_TickCount 
global stageStartTime := A_TickCount
global macroStartTime := A_TickCount

if (!FileExist("Settings")) {
    DirCreate("Settings")
}

win_messages := [
            "clean victory secured 🏆",
            "macro going crazy rn fr 🔥",
            "stacking those Ws 📈",
            "another dub in the books 🎯",
            "back to back wins incoming 💫",
            "(˵ •̀ ᴗ – ˵ ) ✧",
            "♡‧₊˚✧ ૮ ˶ᵔ ᵕ ᵔ˶ ა ✧˚₊‧♡",
            "/)_/)`n(,,>.<)`n/ >❤️",
            "૮꒰ ˶• ༝ •˶꒱ა ♡",
            "✧｡٩(ˊᗜˋ )و✧*｡",
            "( •̯́ ₃ •̯̀)",
            "₍ᐢ•ﻌ•ᐢ₎*･ﾟ｡"
            "Bóng tối ôm trọn lấy bóng ma"
            "Thiên linh duy nhất hóa nhạt nhòa"
            "Ngai vàng còn nằm trong đất đá"
            "Đế vương năm ấy trở về nhà!!"

        ],
        lose_messages := [
            "next one is a win fr 💯",
            "just warming up 🔥",
            "next run is the one 🎮",
            "almost had it that time 🎯",
            "getting better each run 📈",
            "(╯°□°)╯︵ ┻━┻",
            "(ಠ益ಠ)",
            "(╥﹏╥)",
            "(⇀‸↼‶)",
            "(◣ _ ◢)",
            "<(ꐦㅍ _ㅍ)>"
            "Ê nha"
            "Ê má, thua hoài kìa lo chỉnh setting đi"
            "Ê!"
        ],
        ; Milestone messages (every 10th attempt)
        milestone_win_messages := [
        "milestone #{count} win secured! 🏆",
        "#{count} wins and counting! 📈",
        "#{count} wins in the books! 🔥",
        "reached #{count} wins! ⭐",
        "#{count} wins and still going strong! 💫"
        ],
        milestone_lose_messages := [
        "milestone #{count} loss... just bad luck, next time! 🍀",
        "#{count} losses, but we'll get 'em next time! 🤞",
        "reached #{count} losses... just one of those days! 🤷‍♂️",
        "hit #{count} losses, but we’ll turn it around soon! 🙌",
        "milestone #{count} loss, but no worries—next game is ours! 😎"
        ]
        ; Streak messages
        winstreak_messages := [
            "#{streak} win streak lets gooo 🏆",
            "on fire with #{streak} wins 🔥",
            "unstoppable #{streak} win streak 💫",
            "#{streak} wins in a row sheesh 📈",
            "#{streak} win streak going crazy 🌟"
            "(˵ •̀ ᴗ – ˵ ) ✧",
            "♡‧₊˚✧ ૮ ˶ᵔ ᵕ ᵔ˶ ა ✧˚₊‧♡",
            "/)_/)`n(,,>.<)`n/ >❤️",
            "૮꒰ ˶• ༝ •˶꒱ა ♡",
            "✧｡٩(ˊᗜˋ )و✧*｡",
            "( •̯́ ₃ •̯̀)"
        ],
        losestreak_messages := [
            "#{streak} runs of experience gained 📚",
            "#{streak} tries closer to victory 🎯",
            "learning from #{streak} attempts 💪",
            "#{streak} runs of practice secured 📈",
            "comeback loading after #{streak} 🔄"
            "(╯°□°)╯︵ ┻━┻",
            "(ಠ益ಠ)",
            "(╥﹏╥)",
            "(⇀‸↼‶)",
            "(◣ _ ◢)",
            "<(ꐦㅍ _ㅍ)>"
        ],
        ; Time-based messages
        long_win_messages := [
        "took #{time} but macro finally popped off 💪",
        "#{time} grind actually paid off wtf 😳",
        "pc earned its rest after #{time} 😴",
        "#{time} of pure skill 🔥",
        ],
        long_lose_messages := [
        "#{time} of valuable experience 📚",
        "#{time} of strategy learning 🧠",
        "#{time} closer to victory 🎯",
        "#{time} of practice makes perfect ⭐",
        "#{time} getting stronger 💪"
        ]

CalculateElapsedTime(startTime) {
    elapsedTimeMs := A_TickCount - startTime
    elapsedTimeSec := Floor(elapsedTimeMs / 1000)
    elapsedHours := Floor(elapsedTimeSec / 3600)
    elapsedMinutes := Floor(Mod(elapsedTimeSec, 3600) / 60)
    elapsedSeconds := Mod(elapsedTimeSec, 60)
    return Format("{:02}:{:02}:{:02}", elapsedHours, elapsedMinutes, elapsedSeconds)
}

; Function to update streak
UpdateStreak(isWin) {
    global currentStreak, lastResult
    
    ; Initialize lastResult if it doesn't exist
    if (!IsSet(lastResult)) {
        lastResult := "none"
    }
    
    if (isWin) {
        if (lastResult = "win")
            currentStreak += 1
        else
            currentStreak := 1
    } else {
        if (lastResult = "lose")
            currentStreak -= 1
        else
            currentStreak := -1
    }
    
    lastResult := isWin ? "win" : "lose"
}

SendWebhookWithTime(isWin, stageLength) {
    global currentStreak, Wins, loss, WebhookURLFile, macroStartTime, mode, ModeDropdown
    
    ; Update streak
    UpdateStreak(isWin)

    if (!FileExist(WebhookURLFile)) {
        ProcessLog("No webhook configured - skipping webhook")
        return
    }

    WebhookURL := Trim(FileRead(WebhookURLFile, "UTF-8"))
    if !(WebhookURL ~= 'i)^https?:\/\/(?:(?:canary|ptb)\.)?discord(?:app)?\.com\/api\/(?:v\d+\/)?webhooks\/\d+\/[\w-]+(?:\?[^\s#]*)?$') {
        ProcessLog("Invalid webhook URL - skipping webhook")
        return
    }

    ; Calculate macro runtime (total session time)
    macroLength := FormatStageTime(A_TickCount - macroStartTime)
    mapName := GetCurrentMapName()
    modeName := (IsSet(mode) && mode != "") ? mode : (IsSet(ModeDropdown) ? ModeDropdown.Text : "Unknown")

    ; Build Capys-style rich embed fields
    fields := [
        {name: "Map", value: (mapName != "" ? mapName : "Unknown"), inline: true},
        {name: "Mode", value: (modeName != "" ? modeName : "Default"), inline: true},
        {name: "Wins / Losses", value: Wins " / " loss, inline: true},
        {name: "Session Time", value: macroLength, inline: true},
        {name: "Stage Length", value: (stageLength != "" ? stageLength : "Not available"), inline: true},
        {name: "Current Streak", value: (currentStreak > 0 ? currentStreak " Win Streak" : Abs(currentStreak) " Loss Streak"), inline: true}
    ]

    ; Send webhook with Capys color scheme (Victory = 0x70B68C, Defeat = 0xE47F85)
    WebhookScreenshot(
        isWin ? "You Won :D" : "You Lost D:",
        "",
        isWin ? 0x70B68C : 0xE47F85,
        isWin ? "win" : "lose",
        fields
    )
}

SendBanner() {
    global DiscordUserID, StartTime

    ; Calculate how long it took to find the unit
    ElapsedTimeMs := A_TickCount - StartTime
    ElapsedTimeSec := Floor(ElapsedTimeMs / 1000)
    ElapsedHours := Floor(ElapsedTimeSec / 3600)
    ElapsedMinutes := Floor(Mod(ElapsedTimeSec, 3600) / 60)
    Runtime := Format("{:02}h {:02}m", ElapsedHours, ElapsedMinutes)

    bannerUnitName := "Special Unit"
    if FileExist("Settings\BannerUnit.txt") {
        bannerUnitName := Trim(FileRead("Settings\BannerUnit.txt", "UTF-8"))
        if (bannerUnitName == "")
            bannerUnitName := "Special Unit"
    }

    fields := [
        {name: "Found Unit", value: bannerUnitName, inline: true},
        {name: "Time Taken", value: Runtime, inline: true}
    ]

    WebhookScreenshot(
        "🎉 Special Unit Found! 🎉",
        "Banner unit detected during summon!",
        0xFFD700,
        "special",
        fields,
        "https://cdn.discordapp.com/emojis/1502975382209691699.gif?size=128"
    )
}

TestWebhook() {
    global macroStartTime, Wins, loss, currentStreak, mode, ModeDropdown
    macroLength := FormatStageTime(A_TickCount - macroStartTime)
    mapName := GetCurrentMapName()
    modeName := (IsSet(mode) && mode != "") ? mode : (IsSet(ModeDropdown) ? ModeDropdown.Text : "Test")

    fields := [
        {name: "Map", value: (mapName != "" ? mapName : "Test Map"), inline: true},
        {name: "Mode", value: (modeName != "" ? modeName : "Test Mode"), inline: true},
        {name: "Wins / Losses", value: Wins " / " loss, inline: true},
        {name: "Session Time", value: macroLength, inline: true},
        {name: "Status", value: "Webhook connected successfully!", inline: true}
    ]

    WebhookScreenshot(
        "Webhook Test",
        "Test report generated by Kuru Macro (Capys style).",
        0xE4BB66,
        "test",
        fields,
        "https://cdn.discordapp.com/emojis/1502975382209691699.gif?size=128"
    )
}

WebhookSettings() { 
    if FileExist(WebhookURLFile)
        WebhookURLBox.Value := FileRead(WebhookURLFile, "UTF-8")

    if FileExist(DiscordUserIDFile)
        DiscordUserIDBox.Value := FileRead(DiscordUserIDFile, "UTF-8")

    if FileExist(SendActivityLogsFile)
        SendActivityLogsBox.Value := (FileRead(SendActivityLogsFile, "UTF-8") = "1")
}

SaveWebhookSettings(showMsg := true) {
    url := Trim(WebhookURLBox.Value)
    if (url != "" && !(url ~= 'i)^https?:\/\/(?:(?:canary|ptb)\.)?discord(?:app)?\.com\/api\/(?:v\d+\/)?webhooks\/\d+\/[\w-]+(?:\?[^\s#]*)?$')) {
        MsgBox("Invalid Webhook URL! Please enter a valid Discord webhook URL.", "Error", "+0x1000")
        WebhookURLBox.Value := ""
        return false
    }

    rawId := Trim(DiscordUserIDBox.Value)
    parsedId := ""
    if (rawId != "") {
        if RegExMatch(rawId, "^(?:<@!?([0-9]{17,20})>|([0-9]{17,20}))$", &match)
            parsedId := match[1] != "" ? match[1] : match[2]
        else {
            MsgBox("Invalid Discord User ID! Please enter a valid numeric ID (17-20 digits) or keep it empty.", "Error", "+0x1000")
            DiscordUserIDBox.Value := ""
            return false
        }
    }

    ProcessLog("Saving Webhook Configuration")
    
    if FileExist(WebhookURLFile)
        FileDelete(WebhookURLFile)
    if FileExist(DiscordUserIDFile)
        FileDelete(DiscordUserIDFile)
    if FileExist(SendActivityLogsFile)
        FileDelete(SendActivityLogsFile)

    FileAppend(url, WebhookURLFile, "UTF-8")
    FileAppend(parsedId, DiscordUserIDFile, "UTF-8")
    FileAppend(SendActivityLogsBox.Value ? "1" : "0", SendActivityLogsFile, "UTF-8")
    
    if (showMsg)
        MsgBox("Webhook settings saved successfully!", "Success", "T2")
    return true
}

TextWebhook() {
    global lastlog, WebhookURLFile
    if (!FileExist(WebhookURLFile))
        return
    url := Trim(FileRead(WebhookURLFile, "UTF-8"))
    if !(url ~= 'i)^https?:\/\/(?:(?:canary|ptb)\.)?discord(?:app)?\.com\/api\/(?:v\d+\/)?webhooks\/\d+\/[\w-]+')
        return

    try {
        wh := WebHookBuilder(url)
        myEmbed := EmbedBuilder()
            .setTitle("")
            .setDescription("[" FormatTime(A_Now, "hh:mm tt") "] " lastlog)
            .setColor(0x0077ff)

        wh.send({
            content: "",
            embeds: [myEmbed],
            files: []
        })
    } catch as err {
        ; Silent fail to prevent loop freezes
    }
}

WebhookLog() {
    if (!FileExist(WebhookURLFile))
        return
    TextWebhook()
}

WebhookScreenshot(title, description := "", color := 0x70B68C, status := "", fields := "", customThumb := "") {
    if (!FileExist(WebhookURLFile))
        return
    url := Trim(FileRead(WebhookURLFile, "UTF-8"))
    if !(url ~= 'i)^https?:\/\/(?:(?:canary|ptb)\.)?discord(?:app)?\.com\/api\/(?:v\d+\/)?webhooks\/\d+\/[\w-]+')
        return

    global DiscordUserIDFile, wins, loss, currentStreak, stageStartTime, rblxID

    ; Parse Discord User ID if configured
    UserIDSent := ""
    if FileExist(DiscordUserIDFile) {
        rawId := Trim(FileRead(DiscordUserIDFile, "UTF-8"))
        if (rawId != "") {
            if RegExMatch(rawId, "^(?:<@!?([0-9]{17,20})>|([0-9]{17,20}))$", &match) {
                id := match[1] != "" ? match[1] : match[2]
                UserIDSent := "<@" id ">"
            }
        }
    }

    ; Footer messages
    footerMessages := Map(
        "win", win_messages,
        "lose", lose_messages,
        "milestone_win", milestone_win_messages,
        "milestone_lose", milestone_lose_messages,
        "winstreak", winstreak_messages,
        "losestreak", losestreak_messages,
        "long_win", long_win_messages,
        "long_lose", long_lose_messages
    )

    ReplaceVars(text, vars) {
        for key, value in vars {
            text := StrReplace(text, "#{" key "}", value)
        }
        return text
    }

    footerText := ""
    if (status = "win") {
        if (Mod(wins, 5) = 0 && wins > 0)
            footerText := ReplaceVars(footerMessages["milestone_win"][Random(1, footerMessages["milestone_win"].Length)], Map("count", wins))
        else if (currentStreak >= 3)
            footerText := ReplaceVars(footerMessages["winstreak"][Random(1, footerMessages["winstreak"].Length)], Map("streak", currentStreak))
        else
            footerText := win_messages[Random(1, win_messages.Length)]
    } else if (status = "lose") {
        if (Mod(loss, 5) = 0 && loss > 0)
            footerText := ReplaceVars(footerMessages["milestone_lose"][Random(1, footerMessages["milestone_lose"].Length)], Map("count", loss))
        else if (currentStreak <= -3)
            footerText := ReplaceVars(footerMessages["losestreak"][Random(1, footerMessages["losestreak"].Length)], Map("streak", Abs(currentStreak)))
        else
            footerText := lose_messages[Random(1, lose_messages.Length)]
    } else {
        footerText := "Capybara Session Report"
    }

    ; Initialize GDI+ and capture exact Roblox window client area
    pToken := Gdip_Startup()
    if !pToken {
        ProcessLog("Webhook: GDI+ startup failed; skipping screenshot")
        return
    }

    pBitmap := 0
    try {
        targetWin := WinExist(rblxID) ? rblxID : (WinExist("ahk_exe RobloxPlayerBeta.exe") ? "ahk_exe RobloxPlayerBeta.exe" : WinExist("Roblox"))
        if (targetWin) {
            WinGetClientPos(&cx, &cy, &cw, &ch, targetWin)
            if (cw > 100 && ch > 100)
                pBitmap := Gdip_BitmapFromScreen(cx "|" cy "|" cw "|" ch)
            else
                pBitmap := Gdip_BitmapFromScreen()
        } else {
            pBitmap := Gdip_BitmapFromScreen()
        }

        myEmbed := EmbedBuilder()
        myEmbed.setTitle(title)
        if (description != "")
            myEmbed.setDescription(description)
        myEmbed.setColor(color)

        ; Thumbnail (Capys GIFs)
        thumbUrl := customThumb != "" ? customThumb
            : (status = "win" ? "https://cdn.discordapp.com/emojis/1502975382209691699.gif?size=128"
            : (status = "lose" ? "https://media.giphy.com/media/mtUlcBh7V0qm5TLYYD/giphy.gif"
            : (status = "test" ? "https://cdn.discordapp.com/emojis/1502975382209691699.gif?size=128" : "")))
        if (thumbUrl != "")
            myEmbed.setThumbnail({url: thumbUrl})

        ; Fields (grid layout)
        if (IsObject(fields) && fields is Array && fields.Length > 0)
            myEmbed.addFields(fields)

        myEmbed.setFooter({text: footerText " • Kuru Macro"})
        myEmbed.setTimeStamp()

        files := []
        if (pBitmap) {
            attachment := AttachmentBuilder(pBitmap)
            myEmbed.setImage(attachment)
            files.Push(attachment)
        }

        wh := WebHookBuilder(url)
        wh.send({
            content: UserIDSent,
            embeds: [myEmbed],
            files: files
        })
        ProcessLog("Webhook report sent successfully (" . title . ")")
    } catch as err {
        ProcessLog("Webhook delivery failed: " . err.Message . ". Macro continuing.")
    } finally {
        if (pBitmap)
            Gdip_DisposeImage(pBitmap)
        Gdip_Shutdown(pToken)
    }
}
