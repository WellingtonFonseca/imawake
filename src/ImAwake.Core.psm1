# Pure logic of ImAwake: state, time, texts and the frame.
# No console, no Windows API, no clock reads: the shell passes NowMs in.
# The file stays ASCII because Windows PowerShell 5.1 reads a file without a BOM as ANSI;
# every glyph is built from its code point.

Set-StrictMode -Version Latest

$script:HumorIntervalMs = 180000
$script:SpinnerStepMs = 250
# Under one minute, so chat apps that mark you away after 1 min of idle time never do.
$script:KeyPressIntervalMs = 59000
$script:KeyPressErrorPrefix = 'F15 keypress failed: '

# SetThreadExecutionState flags (winbase.h).
$script:EsContinuous = [uint32]2147483648
$script:EsSystemRequired = [uint32]1
$script:EsDisplayRequired = [uint32]2

$script:HumorLines = @(
    "I'm awake! I'm awake!",
    'Just resting my eyes...',
    'I was listening, I swear.',
    'Yes, I agree with the last point.'
)

function Get-Glyph([int]$CodePoint) {
    [char]::ConvertFromUtf32($CodePoint)
}

$script:Glyph = @{
    Coffee   = Get-Glyph 0x2615
    Sleeping = Get-Glyph 0x1F634
    EnDash   = Get-Glyph 0x2013
}

# Code points inside the BMP that a terminal draws two cells wide.
$script:WideCodePoints = @(0x2615)

function New-AwakeState {
    [pscustomobject]@{
        Running       = $false
        Display       = $true
        AccumulatedMs = [long]0
        ResumedAtMs   = [long]0
        KeyPress      = $false
        LastKeyMs     = $null
        Error         = $null
    }
}

function Copy-AwakeState($State) {
    $State.PSObject.Copy()
}

function Get-ActiveMs($State, [long]$NowMs) {
    if (-not $State.Running) {
        return [long]$State.AccumulatedMs
    }
    [long]($State.AccumulatedMs + ($NowMs - $State.ResumedAtMs))
}

function Start-AwakeClock($State, [long]$NowMs) {
    $next = Copy-AwakeState $State
    if ($next.Running) {
        return $next
    }
    $next.Running = $true
    $next.ResumedAtMs = $NowMs
    $next
}

function Stop-AwakeClock($State, [long]$NowMs) {
    $next = Copy-AwakeState $State
    if (-not $next.Running) {
        return $next
    }
    $next.AccumulatedMs = Get-ActiveMs $State $NowMs
    $next.Running = $false
    $next
}

# ES_CONTINUOUS alone releases the request; it is the value for a paused state.
function Get-PowerFlags($State) {
    if (-not $State.Running) {
        return $script:EsContinuous
    }
    $flags = $script:EsContinuous -bor $script:EsSystemRequired
    if ($State.Display) {
        $flags = $flags -bor $script:EsDisplayRequired
    }
    [uint32]$flags
}

function Get-KeyAction([ConsoleKeyInfo]$Key) {
    $ctrl = ($Key.Modifiers -band [ConsoleModifiers]::Control) -ne 0
    if ($ctrl -and $Key.Key -eq [ConsoleKey]::C) { return 'quit' }
    if ($ctrl) { return 'none' }
    switch ($Key.Key) {
        ([ConsoleKey]::Spacebar) { return 'toggle-pause' }
        ([ConsoleKey]::D)        { return 'toggle-display' }
        ([ConsoleKey]::F)        { return 'toggle-keypress' }
        ([ConsoleKey]::Q)        { return 'quit' }
        ([ConsoleKey]::Escape)   { return 'quit' }
    }
    'none'
}

# Gives the state the action asks for. The shell applies its power flags,
# and keeps the old state when the Windows call fails.
function Get-NextState($State, [string]$Action, [long]$NowMs) {
    switch ($Action) {
        'toggle-pause' {
            if ($State.Running) { return Stop-AwakeClock $State $NowMs }
            return Start-AwakeClock $State $NowMs
        }
        'toggle-display' {
            $next = Copy-AwakeState $State
            $next.Display = -not $State.Display
            return $next
        }
        'toggle-keypress' {
            $next = Copy-AwakeState $State
            $next.KeyPress = -not $State.KeyPress
            # A null time makes the first press due at once, as feedback for the user.
            $next.LastKeyMs = $null
            return $next
        }
        'quit' { return Stop-AwakeClock $State $NowMs }
    }
    Copy-AwakeState $State
}

# Moves to the next state and applies its power flags through SetPower.
# When SetPower throws, the old state stays with the error, so the screen
# never says "awake" while Windows can sleep.
function Invoke-Transition($State, [string]$Action, [long]$NowMs, [scriptblock]$SetPower, [scriptblock]$Log) {
    $next = Get-NextState $State $Action $NowMs
    $next.Error = $null
    $flags = Get-PowerFlags $next
    if ($flags -eq (Get-PowerFlags $State)) { return $next }
    try {
        & $SetPower $flags | Out-Null
        return $next
    }
    catch {
        & $Log "action '$Action' failed: $_"
        $kept = Copy-AwakeState $State
        $kept.Error = "$_"
        return $kept
    }
}

function Test-KeyPressDue($State, [long]$NowMs) {
    if (-not $State.KeyPress -or -not $State.Running) { return $false }
    if ($null -eq $State.LastKeyMs) { return $true }
    ($NowMs - $State.LastKeyMs) -ge $script:KeyPressIntervalMs
}

# Presses the key through PressKey when a press is due.
# A failure also records the time, so the retry waits a full interval
# instead of logging on every loop. A success clears only an F15 error,
# so a power error stays on the screen.
function Invoke-KeyPressTick($State, [long]$NowMs, [scriptblock]$PressKey, [scriptblock]$Log) {
    if (-not (Test-KeyPressDue $State $NowMs)) { return $State }
    $next = Copy-AwakeState $State
    $next.LastKeyMs = $NowMs
    try {
        & $PressKey | Out-Null
        if ($next.Error -and $next.Error.StartsWith($script:KeyPressErrorPrefix)) { $next.Error = $null }
    }
    catch {
        $next.Error = "$script:KeyPressErrorPrefix$_"
        & $Log $next.Error
    }
    $next
}

function Split-HoursMinutes([long]$Ms) {
    $totalMinutes = [long][math]::Floor([math]::Max($Ms, 0) / 60000)
    @([long][math]::Floor($totalMinutes / 60), [long]($totalMinutes % 60))
}

function Format-Elapsed([long]$Ms) {
    $h, $m = Split-HoursMinutes $Ms
    if ($h -eq 0) { return '{0}min' -f $m }
    '{0}h {1:00}min' -f $h, $m
}

function Get-WindowTitle($State, [long]$NowMs) {
    if (-not $State.Running) {
        return '{0} ImAwake (paused)' -f $script:Glyph.Sleeping
    }
    $h, $m = Split-HoursMinutes (Get-ActiveMs $State $NowMs)
    $time = if ($h -eq 0) { '{0}min' -f $m } else { '{0}h{1:00}' -f $h, $m }
    "{0} I'm awake! {1} {2}" -f $script:Glyph.Coffee, $script:Glyph.EnDash, $time
}

# The line follows the active time, not chance, so it never jumps between redraws.
function Get-HumorLine([long]$ActiveMs) {
    $index = [long][math]::Floor([math]::Max($ActiveMs, 0) / $script:HumorIntervalMs) % $script:HumorLines.Count
    $script:HumorLines[$index]
}

function Get-SpinnerFrames([bool]$Fancy) {
    if ($Fancy) {
        return @(0x280B, 0x2819, 0x2839, 0x2838, 0x283C, 0x2834, 0x2826, 0x2827, 0x2807, 0x280F) |
            ForEach-Object { Get-Glyph $_ }
    }
    @('|', '/', '-', '\')
}

# Driven by the active time, so the spinner freezes on pause with no extra state.
function Get-SpinnerFrame([long]$ActiveMs, [bool]$Fancy) {
    $frames = @(Get-SpinnerFrames $Fancy)
    $frames[[long][math]::Floor([math]::Max($ActiveMs, 0) / $script:SpinnerStepMs) % $frames.Count]
}

function Get-DisplayWidth([string]$Text) {
    $width = 0
    for ($i = 0; $i -lt $Text.Length; $i++) {
        if ([char]::IsHighSurrogate($Text[$i])) {
            $width += 2
            $i++
            continue
        }
        if ($script:WideCodePoints -contains [int]$Text[$i]) { $width += 2; continue }
        $width += 1
    }
    $width
}

# Everything the frame needs, already turned into text.
function Get-ViewModel($State, [long]$NowMs, [bool]$Fancy) {
    $activeMs = Get-ActiveMs $State $NowMs
    [pscustomobject]@{
        Running = [bool]$State.Running
        Display = [bool]$State.Display
        KeyPress = [bool]$State.KeyPress
        Elapsed = Format-Elapsed $activeMs
        Humor   = Get-HumorLine $activeMs
        Spinner = Get-SpinnerFrame $activeMs $Fancy
        Error   = $State.Error
        Fancy   = $Fancy
    }
}

Export-ModuleMember -Function New-AwakeState, Get-ActiveMs, Start-AwakeClock, Stop-AwakeClock,
    Get-PowerFlags, Get-KeyAction, Get-NextState, Invoke-Transition, Test-KeyPressDue, Invoke-KeyPressTick, Format-Elapsed, Get-WindowTitle,
    Get-HumorLine, Get-SpinnerFrame, Get-DisplayWidth, Get-ViewModel, Get-Glyph
