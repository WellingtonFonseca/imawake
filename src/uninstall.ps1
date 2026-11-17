# Removes ImAwake: the bin folder from the user PATH, the desktop shortcut and the app files,
# then this script and the folders. Press ctrl+u in ImAwake to start it, or run it by hand
# from another folder. The log and the PATH backup in %LOCALAPPDATA%\ImAwake stay.
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
foreach ($name in 'Frame', 'Power', 'Screen', 'Setup', 'Uninstall', 'UserPath', 'Launch') {
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
    $changed = Edit-UserPath { param($raw) Remove-PathEntry $raw $binDir } $backupPath
    if ($changed) { return 'ok' }
    'skipped'
}

# Deletes the shortcut only when it starts this app, never another file with the same name.
function Remove-ShortcutStep {
    $path = Get-ShortcutPath
    if (-not (Test-Path -LiteralPath $path)) { return 'skipped' }
    $link = (New-Object -ComObject WScript.Shell).CreateShortcut($path)
    if (-not (Test-AppCommandLine $link.Arguments (Join-Path $appDir 'ImAwake.ps1'))) { return 'skipped' }
    Remove-Item -LiteralPath $path -Force
    'ok'
}

function Remove-FileStep([string]$Name) {
    $path = Join-Path $appDir $Name
    if (-not (Test-Path -LiteralPath $path)) { return 'skipped' }
    Remove-Item -LiteralPath $path -Force
    'ok'
}

# Removes the folder only when it is empty: a file the user added stays.
function Remove-FolderStep([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return 'skipped' }
    if (@(Get-ChildItem -LiteralPath $Path -Force).Count -gt 0) { return 'skipped' }
    Remove-Item -LiteralPath $Path -Force
    'ok'
}

function Invoke-Step([pscustomobject]$Item, $Results) {
    $keep = ($Item.Id -in 'module', 'marker', 'self') -and (Test-KeepUninstaller $Results)
    if ($keep) { return 'skipped' }
    switch ($Item.Id) {
        'path'       { if ($SkipUserState) { return 'skipped' }; return Remove-PathStep }
        'shortcut'   { if ($SkipUserState) { return 'skipped' }; return Remove-ShortcutStep }
        'bin-folder' { return Remove-FolderStep $binDir }
        'app-folder' { return Remove-FolderStep $appDir }
        default      { return Remove-FileStep $Item.Name }
    }
}

function Get-Result([pscustomobject]$Item, $Results) {
    try {
        [pscustomobject]@{ Label = $Item.Label; Status = (Invoke-Step $Item $Results); Reason = '' }
    }
    catch {
        Write-Log "$($Item.Label) failed: $_"
        [pscustomobject]@{ Label = $Item.Label; Status = 'failed'; Reason = "$_" }
    }
}

function Get-View($Items, $Results, [bool]$Finished, [bool]$Fancy) {
    $done = @($Results).Count
    $current = if ($done -lt $Items.Count) { $Items[$done].Label } else { '' }
    [pscustomobject]@{
        Fancy = $Fancy; Done = $done; Total = $Items.Count; Current = $current; Finished = $Finished
        Failed = @($Results | Where-Object { $_.Status -eq 'failed' } | ForEach-Object { $_.Label })
    }
}

function Write-View($View) {
    $width = [Console]::WindowWidth
    $height = [Console]::WindowHeight
    Write-Lines (Get-UninstallFrameLines $View $width $height) $width $height
}

function Invoke-Uninstall([bool]$Fancy) {
    $items = @(Get-UninstallItems)
    $results = @()
    foreach ($item in $items) {
        if (-not $Silent) { Write-View (Get-View $items $results $false $Fancy) }
        $results += Get-Result $item $results
    }
    $view = Get-View $items $results $true $Fancy
    if ($Silent) {
        $results | ForEach-Object { Write-Host ('{0}: {1}' -f $_.Status, $_.Label) }
        return $view
    }
    Write-View $view
    [Console]::ReadKey($true) | Out-Null
    $view
}

# A message the user must read: the window may close at once when it ends.
function Stop-WithMessage([string]$Message) {
    $Message
    if (-not $Silent) {
        'Press any key to close.'
        [Console]::ReadKey($true) | Out-Null
    }
    exit 1
}

if (-not (Test-InstalledCopy $appDir)) {
    Stop-WithMessage 'Not an installed copy of ImAwake. Nothing removed.'
}

# The app holds this mutex while it runs, so it also tells that the app has exited.
# An elevated app makes a mutex that a normal process cannot open; that also means "runs".
$mutex = $null
if (-not $SkipUserState) {
    $owned = $false
    try {
        $mutex = New-Object Threading.Mutex($false, 'Local\ImAwake')
        $owned = $mutex.WaitOne(10000)
    }
    catch [Threading.AbandonedMutexException] { $owned = $true }
    catch [UnauthorizedAccessException] { $owned = $false }
    if (-not $owned) {
        Stop-WithMessage 'ImAwake still runs. Close it and try again.'
    }
}

# The console state is read only with a screen: with no console, these reads throw.
$saved = $null
$view = $null
try {
    if (-not $Silent) {
        $saved = @{
            Title    = $Host.UI.RawUI.WindowTitle
            Encoding = [Console]::OutputEncoding
            CtrlC    = [Console]::TreatControlCAsInput
        }
        Initialize-Native
        Enter-Screen
    }
    $view = Invoke-Uninstall ([bool]$env:WT_SESSION)
}
finally {
    if ($saved) { Exit-Screen $saved }
    if ($mutex) { $mutex.ReleaseMutex(); $mutex.Dispose() }
}
if ($view.Failed.Count -gt 0) { exit 3 }
exit 0
