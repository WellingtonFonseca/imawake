# Installs ImAwake for the current user: copies the app and makes a desktop shortcut.
# The shortcut opens a NEW Windows Terminal window (-w new), never a tab of an open one,
# so the app keeps its own window in the taskbar.
param(
    [Parameter(Mandatory = $true)][string]$SourceDir,
    [string]$TargetDir = (Join-Path $env:USERPROFILE 'Apps\ImAwake')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$files = @('ImAwake.ps1', 'ImAwake.Core.psm1', 'ImAwake.Frame.psm1', 'ImAwake.Power.psm1')

function Test-Syntax([string]$Path) {
    $tokens = $null
    $errors = $null
    [Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors) {
        throw "syntax error in ${Path}: $($errors[0].Message) (line $($errors[0].Extent.StartLineNumber))"
    }
}

# Checks every file before copying any, so a bad file never leaves a mix of old and new versions.
function Copy-App {
    $sources = @($files | ForEach-Object { Join-Path $SourceDir $_ })
    foreach ($source in $sources) { Test-Syntax $source }
    New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null
    foreach ($source in $sources) { Copy-Item -Path $source -Destination $TargetDir -Force }
}

function New-Shortcut {
    $terminal = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\wt.exe'
    if (-not (Test-Path $terminal)) {
        throw "Windows Terminal not found at $terminal"
    }
    $script = Join-Path $TargetDir 'ImAwake.ps1'
    $desktop = [Environment]::GetFolderPath('Desktop')
    $link = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $desktop 'ImAwake.lnk'))
    $link.TargetPath = $terminal
    # Full path: Windows Terminal resolves a bare powershell.exe through PATH, which can lack System32.
    $powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $link.Arguments = "-w new `"$powershell`" -NoProfile -ExecutionPolicy Bypass -File `"$script`""
    $link.WorkingDirectory = $TargetDir
    $link.Description = 'ImAwake - keeps the PC awake while its window is open'
    $link.IconLocation = "$env:SystemRoot\System32\imageres.dll,96"
    $link.Save()
    $link.FullName
}

Copy-App
$shortcut = New-Shortcut
"Installed to $TargetDir"
"Shortcut: $shortcut"
