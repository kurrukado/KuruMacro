#Requires AutoHotkey v2.0
#Warn All, Off
#Include D:\Macro\AA mango\AA mango\Lib\OCR-main\Lib\OCR.ahk
global rblxID := "ahk_exe RobloxPlayerBeta.exe"
try {
    if !SummerVerificationVisible()
        throw Error("Manual-verification title not detected")
    FileAppend("PASS manual verification title gate; challenge area excluded`n", "*")
    ExitApp(0)
} catch as err {
    FileAppend("FAIL " err.Message "`n", "*")
    ExitApp(1)
}
SummerVerificationVisible() {
    global rblxID
    WinGetClientPos(&cx, &cy,,, rblxID)
    ; Only the title/instruction strip, excluding the challenge and entry field.
    prompt := OCR.FromRect(cx + 200, cy + 175, 400, 70, "en-US", 2).Text
    return !!RegExMatch(prompt, "i)captcha|please enter this text")
}
