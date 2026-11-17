# Installs ImAwake for the current user: copies the app, makes the desktop shortcut
# and puts the bin folder (only imawake.cmd) on the user PATH.
# bin is separate because PowerShell would run ImAwake.ps1 itself for "imawake"
# if the app folder were on PATH.
param(
    [Parameter(Mandatory = $true)][string]$SourceDir,
    [string]$TargetDir = (Join-Path $env:USERPROFILE 'Apps\ImAwake')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Windows PowerShell 5.1 looks up a relative module path such as src\X.psm1 only in
# PSModulePath, not in the current folder, so the README command needs a full path.
$SourceDir = Convert-Path -LiteralPath $SourceDir

Import-Module (Join-Path $SourceDir 'ImAwake.Launch.psm1') -Force
Import-Module (Join-Path $SourceDir 'ImAwake.UserPath.psm1') -Force
Import-Module (Join-Path $SourceDir 'ImAwake.Setup.psm1') -Force
Import-Module (Join-Path $SourceDir 'ImAwake.Uninstall.psm1') -Force

$files = Get-AppFiles
$binDir = Join-Path $TargetDir 'bin'
$powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$backupPath = Join-Path $env:LOCALAPPDATA 'ImAwake\path-backup.txt'

function Test-Syntax([string]$Path) {
    if ($Path -notmatch '\.psm?1$') { return }
    $tokens = $null
    $errors = $null
    [Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors) {
        throw "syntax error in ${Path}: $($errors[0].Message) (line $($errors[0].Extent.StartLineNumber))"
    }
}

# Checks every file before copying any, so a bad file never leaves a mix of old and new versions.
function Copy-App {
    foreach ($file in $files) { Test-Syntax (Join-Path $SourceDir $file) }
    foreach ($file in $files) {
        $target = Join-Path $TargetDir $file
        New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
        Copy-Item -Path (Join-Path $SourceDir $file) -Destination $target -Force
    }
}

function New-Shortcut {
    $terminal = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\wt.exe'
    if (-not (Test-Path $terminal)) {
        throw "Windows Terminal not found at $terminal"
    }
    $link = (New-Object -ComObject WScript.Shell).CreateShortcut((Get-ShortcutPath))
    $link.TargetPath = $terminal
    $link.Arguments = Get-LaunchArguments $powershell (Join-Path $TargetDir 'ImAwake.ps1')
    $link.WorkingDirectory = $TargetDir
    $link.Description = 'ImAwake - keeps the PC awake while its window is open'
    $link.IconLocation = "$env:SystemRoot\System32\imageres.dll,96"
    $link.Save()
    $link.FullName
}

function Add-BinToUserPath {
    $changed = Edit-UserPath { param($raw) Add-PathEntry $raw $binDir } $backupPath
    if (-not $changed) { return "The user PATH already has $binDir" }
    "Added $binDir to the user PATH"
}

# Written last, and an old marker is removed before the copy, so a copy that stopped in
# the middle has no marker. The app and uninstall.ps1 uninstall only a folder that has it.
function Clear-Marker {
    Remove-Item -LiteralPath (Join-Path $TargetDir (Get-MarkerName)) -Force -ErrorAction SilentlyContinue
}

function Write-Marker {
    Set-Content -Path (Join-Path $TargetDir (Get-MarkerName)) -Encoding ASCII `
        -Value ('Installed {0:yyyy-MM-dd HH:mm:ss} from {1}' -f (Get-Date), $SourceDir)
}

Clear-Marker
Copy-App
Write-Marker
$shortcut = New-Shortcut
$pathResult = Add-BinToUserPath
"Installed to $TargetDir"
"Shortcut: $shortcut"
$pathResult
'Close every terminal window and open a new one to use the imawake command.'
