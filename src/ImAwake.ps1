# ImAwake: keeps Windows awake while this window is open.
# Close the window, or press q, and Windows can sleep again.
# Even if the process is killed, Windows drops its power request.

param(
    # Plain ASCII frame for a console font without the box and emoji glyphs.
    [switch]$Plain
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'ImAwake.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ImAwake.Frame.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ImAwake.Power.psm1') -Force

$script:Esc = [char]27
$script:LoopDelayMs = 100
$script:LogPath = Join-Path $env:LOCALAPPDATA 'ImAwake\imawake.log'
$script:LastFrame = ''
$script:LastSize = ''
$script:LastTitle = ''

function Write-Log([string]$Message) {
    try {
        New-Item -ItemType Directory -Force -Path (Split-Path $script:LogPath) | Out-Null
        $line = '{0:yyyy-MM-dd HH:mm:ss} {1}' -f (Get-Date), $Message
        Add-Content -Path $script:LogPath -Value $line -Encoding UTF8
    }
    catch {
        [Console]::Error.WriteLine("ImAwake could not write the log $($script:LogPath): $_")
        # The message lands inside the frame; a full redraw removes it.
        $script:LastFrame = ''
    }
}

$script:SetPower = { param($Flags) Set-PowerState $Flags }
$script:Log = { param($Message) Write-Log $Message }

function Step-State($State, [string]$Action, [long]$NowMs) {
    Invoke-Transition $State $Action $NowMs $script:SetPower $script:Log
}

function Write-Screen($State, [long]$NowMs, [bool]$Fancy) {
    $width = [Console]::WindowWidth
    $height = [Console]::WindowHeight
    $size = "${width}x$height"
    if ($size -ne $script:LastSize) {
        [Console]::Out.Write("$script:Esc[2J")
        $script:LastSize = $size
        $script:LastFrame = ''
    }
    Set-Title (Get-WindowTitle $State $NowMs)
    $lines = Get-FrameLines (Get-ViewModel $State $NowMs $Fancy) $width $height
    $frame = "$script:Esc[H" + (($lines | ForEach-Object { "$_$script:Esc[K" }) -join "`r`n") + "$script:Esc[J"
    if ($frame -eq $script:LastFrame) { return }
    [Console]::Out.Write($frame)
    $script:LastFrame = $frame
}

function Set-Title([string]$Title) {
    if ($Title -eq $script:LastTitle) { return }
    $Host.UI.RawUI.WindowTitle = $Title
    $script:LastTitle = $Title
}

# Drains every pending key; gives the new state and whether to quit.
function Read-Keys($State, [long]$NowMs) {
    while ([Console]::KeyAvailable) {
        $action = Get-KeyAction ([Console]::ReadKey($true))
        if ($action -eq 'none') { continue }
        $State = Step-State $State $action $NowMs
        if ($action -eq 'quit') { return @{ State = $State; Quit = $true } }
    }
    @{ State = $State; Quit = $false }
}

function Start-Loop([bool]$Fancy) {
    $clock = [Diagnostics.Stopwatch]::StartNew()
    $state = Step-State (New-AwakeState) 'toggle-pause' 0
    while ($true) {
        $now = $clock.ElapsedMilliseconds
        $read = Read-Keys $state $now
        $state = $read.State
        if ($read.Quit) { return }
        Write-Screen $state $now $Fancy
        Start-Sleep -Milliseconds $script:LoopDelayMs
    }
}

function Enter-Screen {
    [Console]::OutputEncoding = New-Object Text.UTF8Encoding $false
    [Console]::TreatControlCAsInput = $true
    Enable-VirtualTerminal
    [Console]::Out.Write("$script:Esc[?1049h$script:Esc[?25l")
}

function Exit-Screen($Saved) {
    [Console]::Out.Write("$script:Esc[?25h$script:Esc[?1049l")
    [Console]::TreatControlCAsInput = $Saved.CtrlC
    [Console]::OutputEncoding = $Saved.Encoding
    $Host.UI.RawUI.WindowTitle = $Saved.Title
}

# A fatal error stays on screen until a key press; otherwise the window closes and hides it.
function Show-Fatal($ErrorRecord) {
    Write-Log "fatal: $ErrorRecord`n$($ErrorRecord.ScriptStackTrace)"
    [Console]::Error.WriteLine("ImAwake stopped: $ErrorRecord")
    [Console]::Error.WriteLine("Log: $script:LogPath")
    [Console]::Error.WriteLine('Press any key to close.')
    [Console]::ReadKey($true) | Out-Null
}

# One ImAwake per Windows session: a second window (shortcut or imawake command) would
# hide that the first one still holds the PC awake.
function Lock-SingleInstance {
    $mutex = New-Object Threading.Mutex($false, 'Local\ImAwake')
    try {
        if ($mutex.WaitOne(0)) { return $mutex }
    }
    catch [Threading.AbandonedMutexException] {
        # The last ImAwake was killed; this process now owns the mutex.
        return $mutex
    }
    $mutex.Dispose()
    $null
}

# A mutex made by an elevated ImAwake can refuse a normal one; that also means "already running".
function Get-SingleInstance {
    try {
        return Lock-SingleInstance
    }
    catch [UnauthorizedAccessException] {
        return $null
    }
}

$instance = Get-SingleInstance
if (-not $instance) {
    Write-Host 'ImAwake is already running elsewhere. Closing in 5 seconds.'
    Start-Sleep -Seconds 5
    exit 0
}

$saved = @{
    Title    = $Host.UI.RawUI.WindowTitle
    Encoding = [Console]::OutputEncoding
    CtrlC    = [Console]::TreatControlCAsInput
}
$fancy = (-not $Plain) -and [bool]$env:WT_SESSION
$failure = $null
try {
    Initialize-Native
    Write-Log 'start'
    Enter-Screen
    Start-Loop $fancy
}
catch {
    $failure = $_
}
finally {
    try { Set-PowerState (Get-PowerFlags (New-AwakeState)) | Out-Null }
    catch { Write-Log "release at exit failed: $_" }
    $instance.ReleaseMutex()
    $instance.Dispose()
    Exit-Screen $saved
    Write-Log 'stop'
}
if ($failure) {
    Show-Fatal $failure
    exit 1
}
