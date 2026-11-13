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

Import-Module (Join-Path $SourceDir 'ImAwake.Launch.psm1') -Force
Import-Module (Join-Path $SourceDir 'ImAwake.UserPath.psm1') -Force

$files = @(
    'ImAwake.ps1', 'ImAwake.Core.psm1', 'ImAwake.Frame.psm1', 'ImAwake.Power.psm1',
    'ImAwake.Cli.ps1', 'ImAwake.Launch.psm1', 'bin\imawake.cmd'
)
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
    $desktop = [Environment]::GetFolderPath('Desktop')
    $link = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $desktop 'ImAwake.lnk'))
    $link.TargetPath = $terminal
    $link.Arguments = Get-LaunchArguments $powershell (Join-Path $TargetDir 'ImAwake.ps1')
    $link.WorkingDirectory = $TargetDir
    $link.Description = 'ImAwake - keeps the PC awake while its window is open'
    $link.IconLocation = "$env:SystemRoot\System32\imageres.dll,96"
    $link.Save()
    $link.FullName
}

# Reads and writes the raw registry value: .NET's SetEnvironmentVariable would expand
# %VAR% entries and change the value type.
function Add-BinToUserPath {
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
    try {
        $raw = $key.GetValue('Path', $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        $new = Add-PathEntry $raw $binDir
        if ($null -eq $new) { return "The user PATH already has $binDir" }
        $kind = [Microsoft.Win32.RegistryValueKind]::ExpandString
        if ($null -ne $raw) { $kind = $key.GetValueKind('Path') }
        Save-PathBackup $raw
        $key.SetValue('Path', $new, $kind)
    }
    finally {
        $key.Close()
    }
    Send-EnvironmentChange
    "Added $binDir to the user PATH"
}

# Appends, so a second install keeps the first original value.
function Save-PathBackup($Raw) {
    New-Item -ItemType Directory -Force -Path (Split-Path $backupPath) | Out-Null
    Add-Content -Path $backupPath -Encoding UTF8 -Value ('{0:yyyy-MM-dd HH:mm:ss} {1}' -f (Get-Date), $Raw)
}

# Tells Explorer to reload the environment, so new terminal windows see the new PATH.
function Send-EnvironmentChange {
    if (-not ('ImAwakeInstall.Native' -as [type])) {
        Add-Type -Namespace ImAwakeInstall -Name Native -MemberDefinition @'
[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
'@
    }
    $result = [UIntPtr]::Zero
    $ok = [ImAwakeInstall.Native]::SendMessageTimeout([IntPtr]0xFFFF, 0x1A, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$result)
    if ($ok -eq [IntPtr]::Zero) {
        Write-Warning 'Windows did not confirm the PATH change. Sign out and in again if imawake is not found.'
    }
}

Copy-App
$shortcut = New-Shortcut
$pathResult = Add-BinToUserPath
"Installed to $TargetDir"
"Shortcut: $shortcut"
$pathResult
'Close every terminal window and open a new one to use the imawake command.'
