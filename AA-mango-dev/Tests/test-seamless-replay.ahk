#Requires AutoHotkey v2.0

; Mock UI controls
class MockBox {
    __New(visible, val) {
        this.Visible := visible
        this.Value := val
    }
}

global NextLevelBox := MockBox(false, 0)
global ReturnLobbyBox := MockBox(true, 0)
global MatchMaking := MockBox(true, 0)
global mode := "Story"

; Extract functions under test from GameMango
ChooseResultRoute(matchmaking := 0) {
    global ReturnLobbyBox, NextLevelBox, mode
    ; Rule cứng: Đối với Matchmaking, bắt buộc luôn Return to Lobby để ghép trận mới
    if (matchmaking)
        return "lobby"
    ; Chế độ Story có tick Next Level: ưu tiên sang màn tiếp theo
    if (IsSet(NextLevelBox) && NextLevelBox.Visible && NextLevelBox.Value)
        return "next_level"
    ; Khi người dùng chủ động tick Return To Lobby (Solo)
    if (IsSet(ReturnLobbyBox) && ReturnLobbyBox.Visible && ReturnLobbyBox.Value)
        return "lobby"
    ; Mặc định chơi Solo: tận dụng Seamless Replay (BETA) tái khởi động tại chỗ
    return "replay"
}

ClassifyResultScreen(text) {
    if RegExMatch(text, "i)choose\s+a\s+card|the\s+weather\s+shifts")
        return ""
    if (RegExMatch(text, "i)xp\s+progress") && RegExMatch(text, "i)total\s+time|waves\s+completed")
        && RegExMatch(text, "i)\bnext\b"))
        return "summary"
    if (RegExMatch(text, "i)return\s+to\s+lobby") && RegExMatch(text, "i)\b(replay|retry)\b|next\s+(level|room)|waiting\s+for\s+players"))
        return "choices"
    return ""
}

; 1. Test ClassifyResultScreen
testCases := [
    ["XP Progress Total Time:14:29 Waves Completed:28 Next", "summary"],
    ["DEFEAT XP Progress Total Time:3:01 Next", "summary"],
    ["Return to lobby Replay Waiting for Players:0/1", "choices"],
    ["Return to lobby Retry", "choices"],
    ["Return to lobby Next Level", "choices"],
    ["Return to lobby Next Room", "choices"],
    ["Settings Gameplay Teleport back to Spawn Return to Lobby", ""],
    ["Choose a card XP Progress Total Time Next", ""],
    ["Vote start Wave 2 Enemy health", ""]
]

for tc in testCases {
    res := ClassifyResultScreen(tc[1])
    if (res != tc[2]) {
        FileAppend("FAIL ClassifyResultScreen: expected " tc[2] ", got " res " for text: " tc[1] "`n", "*")
        ExitApp(1)
    }
}

; 2. Test ChooseResultRoute Hard Rule for Matchmaking
; Case A: Hard Rule: When Matchmaking = 1, MUST return 'lobby' regardless of ReturnLobbyBox or NextLevelBox
MatchMaking.Value := 1
ReturnLobbyBox.Visible := true
ReturnLobbyBox.Value := 0
NextLevelBox.Visible := true
NextLevelBox.Value := 1
if (ChooseResultRoute(MatchMaking.Value) != "lobby" || ChooseResultRoute(1) != "lobby") {
    FileAppend("FAIL Case A: Matchmaking hard rule MUST be 'lobby'`n", "*")
    ExitApp(1)
}

; Case B: Solo (Matchmaking = 0) with ReturnLobbyBox = 1 -> must lobby
MatchMaking.Value := 0
ReturnLobbyBox.Visible := true
ReturnLobbyBox.Value := 1
NextLevelBox.Visible := false
NextLevelBox.Value := 0
if (ChooseResultRoute(MatchMaking.Value) != "lobby") {
    FileAppend("FAIL Case B: Solo ReturnToLobby checked should be 'lobby'`n", "*")
    ExitApp(1)
}

; Case C: Solo Story mode with Next Level (NextLevelBox.Visible = 1, Value = 1) -> must next_level
MatchMaking.Value := 0
NextLevelBox.Visible := true
NextLevelBox.Value := 1
ReturnLobbyBox.Visible := false
ReturnLobbyBox.Value := 0
if (ChooseResultRoute(MatchMaking.Value) != "next_level") {
    FileAppend("FAIL Case C: NextLevel checked should be 'next_level'`n", "*")
    ExitApp(1)
}

; Case D: Solo mode default (NextLevelBox = 0, ReturnLobbyBox = 0) -> must replay (Seamless Replay)
MatchMaking.Value := 0
NextLevelBox.Visible := false
NextLevelBox.Value := 0
ReturnLobbyBox.Visible := true
ReturnLobbyBox.Value := 0
if (ChooseResultRoute(MatchMaking.Value) != "replay") {
    FileAppend("FAIL Case D: Solo default should be 'replay'`n", "*")
    ExitApp(1)
}

FileAppend("ALL HARD-RULE MATCHMAKING & SEAMLESS REPLAY UNIT TESTS PASSED!`n", "*")
ExitApp(0)
