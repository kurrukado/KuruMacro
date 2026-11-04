#Requires AutoHotkey v2.0
#SingleInstance Off
#NoTrayIcon
global JevKeyBox := {Value: "  offline-test-key  "}
global JevKeyStatus := {Text: ""}
global JEV_KEY := "old-cache"
try {
    Assert(SaveJevSettings(), "save succeeds")
    Assert(JEV_KEY = "offline-test-key", "cache updated and trimmed")
    Assert(FileRead(A_ScriptDir "\Settings\JevKey.txt", "UTF-8") = JEV_KEY, "disk matches cache")
    Assert(JevKeyStatus.Text = "Key saved", "safe success message")
    JevKeyBox.Value := "replacement-test-key"
    Assert(SaveJevSettings(), "replacement succeeds")
    Assert(FileRead(A_ScriptDir "\Settings\JevKey.txt", "UTF-8") = "replacement-test-key", "replacement has no stale suffix")
    tempPath := A_ScriptDir "\Settings\JevKey.txt." DllCall("GetCurrentProcessId") ".tmp"
    DirCreate(tempPath)
    JevKeyBox.Value := "failed-test-key"
    Assert(!SaveJevSettings(), "write failure reported")
    Assert(JEV_KEY = "replacement-test-key", "failed save preserves cache")
    Assert(FileRead(A_ScriptDir "\Settings\JevKey.txt", "UTF-8") = JEV_KEY, "failed save preserves file")
    Assert(JevKeyStatus.Text = "Could not save key", "failure never prints key")
    DirDelete(tempPath)
    JevKeyBox.Value := "  "
    Assert(SaveJevSettings(), "clear succeeds")
    Assert(JEV_KEY = "" && FileRead(A_ScriptDir "\Settings\JevKey.txt", "UTF-8") = "", "clear empties file and cache")
    maskedGui := Gui()
    maskedInput := maskedGui.Add("Edit", "Password", "offline-test-key")
    Assert((WinGetStyle(maskedInput.Hwnd) & 0x20) != 0, "ES_PASSWORD applied")
    maskedGui.Destroy()
    FileAppend("PASS: 13 persistence, failure, clear, and password assertions`n", "*")
    ExitApp(0)
} catch as err {
    FileAppend("FAIL: " err.Message "`n", "*")
    ExitApp(1)
}
Assert(condition, message) {
    if !condition
        throw Error(message)
}
SaveJevSettings(*) {
    global JevKeyBox, JevKeyStatus, JEV_KEY

    key := Trim(JevKeyBox.Value)
    keyPath := A_ScriptDir "\Settings\JevKey.txt"
    tempPath := keyPath "." DllCall("GetCurrentProcessId") ".tmp"
    try {
        ; Replace only after the entire new key has been written successfully.
        DirCreate(A_ScriptDir "\Settings")
        keyFile := FileOpen(tempPath, "w", "UTF-8-RAW")
        try keyFile.Write(key)
        finally keyFile.Close()
        FileMove(tempPath, keyPath, true)
        JEV_KEY := key
        JevKeyBox.Value := key
        JevKeyStatus.Text := key = "" ? "Key cleared" : "Key saved"
        return true
    } catch {
        try FileDelete(tempPath)
        ; Do not include exception text: it could contain credentials.
        JevKeyStatus.Text := "Could not save key"
        return false
    }
}

