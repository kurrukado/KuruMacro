Welcome to Anime Adventure Macro - made by Kuru

To make this Macro basically works included:

Main.ahk - where to run the macro
Lib\Functions.ahk - a bridge between main file and GUI file
Lib\Image.ahk - store the image for searching up
Lib\GUI.ahk - for GUI and interact

There's also libraries files for macro function

Personal settings
Start Main.ahk with AutoHotkey v2. Save your own credentials through the JEV
and Discord panels, or copy the matching Settings\*.example.txt to its .txt
name and edit that local copy. See Settings\README.example.md.

Paddle card OCR (optional, Windows x64)
The macro can use Windows OCR immediately. For Paddle OCR, install 64-bit
Python 3.12 and run these PowerShell commands once from the AA mango folder.
The two English/mobile OCR models are included.

    cd .\Tools\PaddleCards
    py -3.12 -m venv .venv
    .\.venv\Scripts\python.exe -m pip install -r requirements.lock.txt
    .\.venv\Scripts\python.exe -m pip check
