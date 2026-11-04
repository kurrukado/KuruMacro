#Requires AutoHotkey v2.0
#SingleInstance Off
#Warn All, Off
#Include D:\Macro\AA mango\AA mango\Lib\Discord-Webhook-master\lib\resources\JSON.ahk
#Include jev-card-functions-test.ahk
try {
    JEV_KEY := Trim(FileRead("D:\Macro\AA mango\AA mango\Settings\JevKey.txt", "UTF-8"))
    scores := JevScore(["All your units deal 25% more damage", "All your units have 5% less range"
        , "All enemies have 50% more health"], &ok)
    if !ok || scores.Length != 3 || Type(scores[1]) = "String" || Type(scores[2]) = "String"
        || Type(scores[3]) = "String" || !(scores[1] > 2 && scores[2] < 2 && scores[3] < scores[2])
        throw Error("Live buff scores missing or misordered")
    FileAppend("PASS live: buff=" scores[1] "; mild nerf=" scores[2] "; severe nerf=" scores[3]
        . "; ms=" JEV_LAST_MS "`n", "*")
    ExitApp(0)
} catch {
    FileAppend("FAIL: live card-text-only API smoke test`n", "*")
    ExitApp(1)
}
ProcessLog(text) {
    FileAppend(text "`n", "*")
}
FixClick(x, y) {
}
