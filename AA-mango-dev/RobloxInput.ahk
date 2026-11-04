#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Event"
#Include FixClick-current.ahk
target := "ahk_exe RobloxPlayerBeta.exe"
WinActivate(target)
WinWaitActive(target,, 3)
CoordMode "Mouse", "Client"
if (A_Args.Length = 3 && A_Args[1] = "click") {
    FixClick(Integer(A_Args[2]), Integer(A_Args[3]))
} else if (A_Args.Length = 3 && A_Args[1] = "walk") {
    key := A_Args[2], duration := Integer(A_Args[3])
    if !RegExMatch(key, "^[wasd]$") || duration < 1 || duration > 5000
        ExitApp(2)
    try {
        SendEvent("{" key " down}")
        Sleep(duration)
    } finally {
        SendEvent("{" key " up}")
    }
} else if (A_Args.Length = 2 && A_Args[1] = "tap") {
    if !RegExMatch(A_Args[2], "^[q1-6r]$")
        ExitApp(2)
    SetKeyDelay(50, 50)
    SendEvent("{" A_Args[2] "}")
} else if (A_Args.Length = 2 && A_Args[1] = "zoom") {
    steps := Integer(A_Args[2])
    if (Abs(steps) > 20)
        ExitApp(2)
    FixMove(400, 300)
    Loop Abs(steps) {
        SendEvent(steps > 0 ? "{WheelDown}" : "{WheelUp}")
        Sleep(60)
    }
} else {
    ExitApp(2)
}
Sleep(300)
ExitApp(0)
