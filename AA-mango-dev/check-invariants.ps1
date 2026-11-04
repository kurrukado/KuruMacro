# check-invariants.ps1 - validate Main.ahk + guard the project invariants.
# Run after every PROD edit:
#   powershell -ExecutionPolicy Bypass -File "D:\Macro\AA-mango-dev\check-invariants.ps1"
# Exit 0 = all good. Exit 1 = at least one hard invariant failed.

$ErrorActionPreference = 'Stop'

$root = 'D:\Macro\AA mango'
$ahk  = 'C:\Users\thoan\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe'

$failures = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

function Fail([string]$message) { $script:failures.Add($message) }
function Warn([string]$message) { $script:warnings.Add($message) }

# ---------------------------------------------------------------- 1. validate
# AutoHotkey64 is a GUI-subsystem exe; a plain pipeline can return before it
# exits and leave $LASTEXITCODE unset. Start-Process -Wait is reliable.
$validateOut = Join-Path $env:TEMP 'aa-invariants-validate.out'
$validateErr = Join-Path $env:TEMP 'aa-invariants-validate.err'
Remove-Item $validateOut, $validateErr -ErrorAction SilentlyContinue
$mainPath = Join-Path $root 'Main.ahk'
$validateProc = Start-Process -FilePath $ahk `
    -ArgumentList "/ErrorStdOut /Validate `"$mainPath`"" `
    -Wait -PassThru -NoNewWindow `
    -RedirectStandardOutput $validateOut -RedirectStandardError $validateErr
$validateExit = $validateProc.ExitCode
$validate = @()
if (Test-Path $validateOut) { $validate += Get-Content $validateOut -Raw }
if (Test-Path $validateErr) { $validate += Get-Content $validateErr -Raw }
$validate = $validate | Where-Object { $_ -and $_.Trim() -ne '' }
if ($validateExit -ne 0) {
    Fail "Validate Main.ahk failed (exit=$validateExit): $validate"
}

# ---------------------------------------------------------------- read sources
$main = Get-Content (Join-Path $root 'Main.ahk') -Raw
$func = Get-Content (Join-Path $root 'Lib\Functions.ahk') -Raw
$game = Get-Content (Join-Path $root 'Lib\GameMango.ahk') -Raw
$gui  = Get-Content (Join-Path $root 'Lib\GUI.ahk') -Raw

# ---------------------------------------------------------------- 2. input mode
if ($main -notmatch 'SendMode\s+"Event"') {
    Fail 'Main.ahk is missing SendMode "Event"'
}

# ---------------------------------------------------------------- 3. CAPTCHA auto-solve
if ($func -notmatch 'CaptchaDetect\s*\(') {
    Fail 'CaptchaDetect definition is missing from Lib\Functions.ahk'
}
$captchaCalls = ([regex]::Matches($game, 'CaptchaDetect\s*\(')).Count
if ($captchaCalls -lt 2) {
    Fail "CaptchaDetect call sites in GameMango.ahk = $captchaCalls (expected >= 2: FindMatch + Summer)"
}
if ($func -match 'Sending number') {
    Fail 'Functions.ahk logs CAPTCHA contents ("Sending number")'
}
if ($func -match 'ProcessLog\([^)]*\bnumber\b') {
    Fail 'Functions.ahk may log a CAPTCHA value via ProcessLog'
}

# ---------------------------------------------------------------- 4. mode list
$expectedModes = @(
    'Infinite', 'Story', 'Portal', 'Daily Infinite Quest', 'Farm',
    'Legend', 'Raid', 'Infinity Castle', 'Dungeon', 'Summer Event'
)
$modeLine = (Select-String -Path (Join-Path $root 'Lib\GUI.ahk') -Pattern 'global ModeDropdown' | Select-Object -First 1).Line
if (-not $modeLine) {
    Fail 'ModeDropdown definition not found in Lib\GUI.ahk'
} else {
    foreach ($mode in $expectedModes) {
        if ($modeLine -notmatch [regex]::Escape('"' + $mode + '"')) {
            Fail "ModeDropdown is missing mode: $mode"
        }
    }
}

# ---------------------------------------------------------------- 5. click engine
$mouseClickCount = ([regex]::Matches($func, 'MouseClick\s*\(')).Count
if ($mouseClickCount -ne 1) {
    Fail "MouseClick( appears $mouseClickCount times in Functions.ahk (expected exactly 1, inside FixClick)"
}

# ---------------------------------------------------------------- 6. git hygiene
if (Test-Path 'D:\Macro\.git') {
    $tracked = & git -C 'D:\Macro' ls-files 2>$null
    $forbidden = @(
        'AA mango/Settings/',
        'AA mango/Logs/',
        'AA-mango-dev/Debug/',
        'AA-mango-dev/backup/'
    )
    foreach ($path in $forbidden) {
        if ($tracked -match [regex]::Escape($path)) {
            Fail "Git tracks a forbidden path: $path"
        }
    }
}

# ---------------------------------------------------------------- 7. docs
if (-not (Test-Path 'D:\Macro\AGENTS.md')) {
    Fail 'D:\Macro\AGENTS.md is missing'
}
if (Test-Path 'D:\Macro\AgentOnly.md') {
    Warn 'AgentOnly.md exists again; AGENTS.md says the label table is retired'
}

# ---------------------------------------------------------------- report
Write-Host '== check-invariants =='
if ($validate) {
    Write-Host ("validate : exit=$validateExit, output: " + ($validate -join ' '))
} else {
    Write-Host "validate : exit=$validateExit, clean"
}
Write-Host ("captcha  : definition=yes, call sites=$captchaCalls")
Write-Host ("modes    : " + $expectedModes.Count + " checked")
Write-Host ("clicks   : MouseClick=(x$mouseClickCount)")

foreach ($message in $warnings) {
    Write-Host ("WARN: " + $message)
}

if ($failures.Count -gt 0) {
    foreach ($message in $failures) {
        Write-Host ("FAIL: " + $message)
    }
    Write-Host ("RESULT: FAIL (" + $failures.Count + " invariant(s))")
    exit 1
}

Write-Host 'RESULT: PASS'
exit 0
