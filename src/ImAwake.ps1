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
Import-Module (Join-Path $PSScriptRoot 'ImAwake.Screen.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ImAwake.Uninstall.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ImAwake.Launch.psm1') -Force

$script:LoopDelayMs = 200
$script:UninstallRequested = $false
$script:LogPath = Join-Path $env:LOCALAPPDATA 'ImAwake\imawake.log'

function Write-Log([string]$Message) {
    try {
        New-Item -ItemType Directory -Force -Path (Split-Path $script:LogPath) | Out-Null
        $line = '{0:yyyy-MM-dd HH:mm:ss} {1}' -f (Get-Date), $Message
        Add-Content -Path $script:LogPath -Value $line -Encoding UTF8
    }
    catch {
        [Console]::Error.WriteLine("ImAwake could not write the log $($script:LogPath): $_")
        # The message lands inside the frame; a full redraw removes it.
        Reset-Frame
    }
}

$script:SetPower = { param($Flags) Set-PowerState $Flags }
$script:Log = { param($Message) Write-Log $Message }
$script:PressKey = { Send-F15Key }

function Step-State($State, [string]$Action, [long]$NowMs) {
    Invoke-Transition $State $Action $NowMs $script:SetPower $script:Log
}

function Step-KeyPress($State, [long]$NowMs) {
    Invoke-KeyPressTick $State $NowMs $script:PressKey $script:Log
}

function Write-Screen($State, [long]$NowMs, [bool]$Fancy) {
    $width = [Console]::WindowWidth
    $height = [Console]::WindowHeight
    Set-Title (Get-WindowTitle $State $NowMs)
    Write-Lines (Get-FrameLines (Get-ViewModel $State $NowMs $Fancy) $width $height) $width $height
}

# Drains every pending key; gives the new state and whether to quit or uninstall.
# The confirm state of this pass picks the key map, because one drain can hold Ctrl+U and then y.
function Read-Keys($State, [long]$NowMs) {
    while ([Console]::KeyAvailable) {
        $action = Get-KeyAction ([Console]::ReadKey($true)) $State.Confirm
        if ($action -eq 'none') { continue }
        $State = Step-State $State $action $NowMs
        if ($action -eq 'quit') { return @{ State = $State; Quit = $true; Uninstall = $false } }
        if ($action -eq 'uninstall') { return @{ State = $State; Quit = $true; Uninstall = $true } }
    }
    @{ State = $State; Quit = $false; Uninstall = $false }
}

# Sets $script:UninstallRequested when the user chose to uninstall. A flag, not a return
# value: stray output from the loop must never start an uninstall.
function Start-Loop([bool]$Fancy) {
    $clock = [Diagnostics.Stopwatch]::StartNew()
    $initial = New-AwakeState
    $initial.CanUninstall = Test-InstalledCopy $PSScriptRoot
    $state = Step-State $initial 'toggle-pause' 0
    while ($true) {
        $now = $clock.ElapsedMilliseconds
        $read = Read-Keys $state $now
        $state = $read.State
        if ($read.Quit) {
            $script:UninstallRequested = [bool]$read.Uninstall
            return
        }
        $state = Step-KeyPress $state $now
        Write-Screen $state $now $Fancy
        Start-Sleep -Milliseconds $script:LoopDelayMs
    }
}

# Opens uninstall.ps1 in a new window. The app is gone by then: power and mutex are released.
function Start-Uninstall {
    $script = Join-Path $PSScriptRoot 'uninstall.ps1'
    $powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $terminal = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\wt.exe'
    Write-Log 'uninstall started'
    if (Test-Path $terminal) {
        Start-Process -FilePath $terminal -WorkingDirectory $env:TEMP `
            -ArgumentList (Get-UninstallArguments $powershell $script $env:TEMP)
        return
    }
    Start-Process -FilePath $powershell -WorkingDirectory $env:TEMP `
        -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$script`"")
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
if ($script:UninstallRequested) {
    try { Start-Uninstall }
    catch {
        Show-Fatal $_
        exit 1
    }
}
