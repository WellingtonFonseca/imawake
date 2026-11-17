# Removes ImAwake: the bin folder from the user PATH, the desktop shortcut and the app files,
# then this script and the folders. Press ctrl+u in ImAwake to start it, or run it by hand
# from another folder. The log, the PATH backup and the saved language in %LOCALAPPDATA%\ImAwake stay.
# -SkipUserState and -Silent are for tests: no PATH, no shortcut, no mutex; no screen, no wait.
param(
    [switch]$SkipUserState,
    [switch]$Silent
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Set-Location alone does not change the process folder; a locked cwd stops the folder delete.
Set-Location $env:TEMP
[Environment]::CurrentDirectory = $env:TEMP

$appDir = $PSScriptRoot
foreach ($name in 'Frame', 'Power', 'Screen', 'Setup', 'Uninstall', 'UserPath', 'Launch', 'Text', 'Language') {
    Import-Module (Join-Path $appDir "ImAwake.$name.psm1") -Force
}

$logPath = Join-Path $env:LOCALAPPDATA 'ImAwake\imawake.log'
$backupPath = Join-Path $env:LOCALAPPDATA 'ImAwake\path-backup.txt'
$binDir = Join-Path $appDir 'bin'

function Write-Log([string]$Message) {
    try {
        New-Item -ItemType Directory -Force -Path (Split-Path $logPath) | Out-Null
        Add-Content -Path $logPath -Encoding UTF8 -Value ('{0:yyyy-MM-dd HH:mm:ss} uninstall: {1}' -f (Get-Date), $Message)
    }
    catch {
        [Console]::Error.WriteLine("ImAwake could not write the log ${logPath}: $_")
    }
}

function Remove-PathStep {
    if ($SkipUserState) { return 'skipped' }
    $changed = Edit-UserPath { param($raw) Remove-PathEntry $raw $binDir } $backupPath
    if ($changed) { return 'ok' }
    'skipped'
}

# Deletes the shortcut only when it starts this app, never another file with the same name.
function Remove-ShortcutStep {
    if ($SkipUserState) { return 'skipped' }
    $path = Get-ShortcutPath
    if (-not (Test-Path -LiteralPath $path)) { return 'skipped' }
    $link = (New-Object -ComObject WScript.Shell).CreateShortcut($path)
    if (-not (Test-AppCommandLine $link.Arguments (Join-Path $appDir 'ImAwake.ps1'))) { return 'skipped' }
    Remove-Item -LiteralPath $path -Force
    'ok'
}

function Remove-FileStep([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return 'skipped' }
    Remove-Item -LiteralPath $Path -Force
    'ok'
}

# Removes the folder only when it is empty: a file the user added stays.
function Remove-FolderStep([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return 'skipped' }
    if (@(Get-ChildItem -LiteralPath $Path -Force).Count -gt 0) { return 'skipped' }
    Remove-Item -LiteralPath $Path -Force
    'ok'
}

function Write-View($View) {
    $width = [Console]::WindowWidth
    $height = [Console]::WindowHeight
    Write-Lines (Get-UninstallFrameLines $View $width $height) $width $height
}

# The real effects of this host. -Silent turns the screen and the key wait into nothing and
# prints one line per step instead; -SkipUserState turns the PATH and shortcut steps into skips.
$effects = @{
    RemovePath     = { Remove-PathStep }
    RemoveShortcut = { Remove-ShortcutStep }
    RemoveFile     = { param($Path) Remove-FileStep $Path }
    RemoveFolder   = { param($Path) Remove-FolderStep $Path }
    Show           = { param($View) if (-not $Silent) { Write-View $View } }
    Report         = { param($Results) if ($Silent) { $Results | ForEach-Object { Write-Host ('{0}: {1}' -f $_.Status, $_.Label) } } }
    WaitKey        = { if (-not $Silent) { [Console]::ReadKey($true) | Out-Null } }
    Log            = { param($Message) Write-Log $Message }
}

# A message the user must read: the window may close at once when it ends.
function Stop-WithMessage([string]$Message, [string]$Prompt) {
    $previous = Use-Utf8Output
    try {
        $Message
        if (-not $Silent) {
            $Prompt
            [Console]::ReadKey($true) | Out-Null
        }
    }
    finally { Restore-Output $previous }
    exit 1
}

# The tables are read once, before any file goes: the language files are removed near the end.
# With no tables there is no text, so this one message is plain English, and nothing is removed.
try { $language = Get-LanguageSetup $appDir }
catch {
    Write-Log "language files failed: $_"
    Stop-WithMessage "$(Get-AppName) could not read its language files: $_" 'Press any key to close.'
}
$text = $language.Tables[$language.Language]
if ($language.PreferenceError) { Write-Log $language.PreferenceError }
$pressKey = Format-Text $text 'PressAnyKeyMsg'

if (-not (Test-InstalledCopy $appDir)) {
    Stop-WithMessage (Format-Text $text 'UninstallNotInstalled') $pressKey
}

# The app holds the mutex while it runs, so waiting for it also waits for the app to exit.
$mutex = $null
if (-not $SkipUserState) {
    $mutex = Lock-SingleInstance 10000
    if (-not $mutex) {
        Stop-WithMessage (Format-Text $text 'UninstallStillRuns') $pressKey
    }
}

# The console state is read only with a screen: with no console, these reads throw.
$saved = $null
$view = $null
try {
    if (-not $Silent) {
        $saved = Get-ScreenState
        Initialize-Native
        Enter-Screen
    }
    $view = Invoke-Uninstall @(Get-UninstallItems $text) $appDir $effects ([bool]$env:WT_SESSION) $text
}
finally {
    if ($saved) { Exit-Screen $saved }
    Unlock-SingleInstance $mutex
}
if ($view.Failed.Count -gt 0) { exit 3 }
exit 0
