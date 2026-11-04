#Requires AutoHotkey v2.0 

InfiniteMovement() {
    ProcessLog("Moving to Infinite...")
    FixClick(26, 360) ;open Area
    Sleep(500)
    if (ImageSearch(&x, &y, 198, 274, 600, 367, "*50 " A_ScriptDir "\Images\StoryMode.png")) {
        FixClick(x, y)
    }
    Sleep(500)
    SendInput("{w down}") ;move up
    Sleep(4000)
    SendInput("{w up}")
    Sleep(500)
    Send("{a down}") ;move to room
    Sleep(1000)
    SendInput("{a up}")
    CreateMatch() ;click Create
    Sleep(700)
    SelectMap() ;click Infinte Act
    Sleep(700)
    FixClick(340, 480) ;click inf act
    Sleep(700)
    ChooseDifficult() ;click difficult
    Sleep(700)
    FixClick(510, 480) ;click choose
    Sleep(700)
    FixClick(660, 460) ;click Start
}

InfiniteMode() {
    ProcessLog("Moving to: " ModeDropdown.Text "mode")
    InfiniteMovement()
    RestartStage()
}

WinterMovement() {
    ProcessLog("Moving to Winter Event...")
    FixClick(26, 360) ;open Area
    Sleep(500)
    if (ImageSearch(&x, &y, 198, 274, 600, 367, "*50 " A_ScriptDir "\Images\WinterMode.png")) {
        FixClick(x, y)
    }
    Sleep(1000)
    loop 3 { ; open event page
        Send("{E}")
        Sleep(500)
    }
    FixClick(353, 596) ;dialog
    Sleep(500)
    FixClick(240, 475) ;create
    Sleep(1000)
    FixClick(512, 479) ; choose
    Sleep(500)
    FixClick(665, 456) ;click start
    Sleep(500)
}
WinterMode() {
    ProcessLog("Moving to: " ModeDropdown.Text "mode")
    WinterMovement()
    RestartStage()
}