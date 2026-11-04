FixClick(x, y, LR := "Left") {
    MouseMove(x, y)
    MouseMove(1, 0, , "R")
    MouseClick(LR, -1, 0, , , , "R")
    Sleep(50)
}

FixMove(x, y) {
    MouseMove(x, y)
    MouseMove(1, 0, , "R")
    MouseMove(-1, 0, , "R")
    Sleep(60)
}
