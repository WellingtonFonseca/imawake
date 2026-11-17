# Pure rules of how ImAwake is launched and found: the Windows Terminal arguments,
# the match of a running app process, the status text and the CLI arguments.
# Shared by the imawake command and the installer, so the launch rule lives in one place.

Set-StrictMode -Version Latest

# Arguments for wt.exe: a NEW window (never a tab), so the app keeps its own taskbar entry.
function Get-LaunchArguments([string]$PowerShellPath, [string]$ScriptPath) {
    "-w new `"$PowerShellPath`" -NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
}

# Arguments for wt.exe to run the uninstaller in a new window. -d sets the start folder,
# because wt.exe ignores the working folder of its own process; the app folder must not be it.
function Get-UninstallArguments([string]$PowerShellPath, [string]$ScriptPath, [string]$WorkDir) {
    "-w new -d `"$WorkDir`" `"$PowerShellPath`" -NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
}

# True when a process command line runs exactly ScriptPath with -File.
# Anchored on the full path, so ImAwake.Cli.ps1 or a dev copy elsewhere never match.
function Test-AppCommandLine([string]$CommandLine, [string]$ScriptPath) {
    if ([string]::IsNullOrEmpty($CommandLine)) { return $false }
    $pattern = '-File\s+"?' + [regex]::Escape($ScriptPath) + '"?(\s|$)'
    [regex]::IsMatch($CommandLine, $pattern, [Text.RegularExpressions.RegexOptions]::IgnoreCase)
}

# "10:31" for a start today; the date too for an older start, because a bare time would mislead.
function Format-Since([datetime]$StartTime, [datetime]$Now) {
    if ($StartTime.Date -eq $Now.Date) { return '{0:HH:mm}' -f $StartTime }
    '{0:yyyy-MM-dd HH:mm}' -f $StartTime
}

function Resolve-CliAction([string[]]$Arguments) {
    $list = @($Arguments | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($list.Count -eq 0) { return 'here' }
    if ($list.Count -gt 1) { return 'usage-error' }
    $word = $list[0].ToLowerInvariant()
    if ($word -eq 'window') { return 'window' }
    if ($word -eq 'status') { return 'status' }
    if (@('help', '-h', '--help', '-?', '/?') -contains $word) { return 'help' }
    'usage-error'
}

Export-ModuleMember -Function Get-LaunchArguments, Get-UninstallArguments, Test-AppCommandLine, Format-Since, Resolve-CliAction
