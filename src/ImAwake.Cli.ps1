# The imawake command (called by bin\imawake.cmd).
#   imawake          runs ImAwake in this terminal, or says it already runs
#   imawake window   opens ImAwake in a new window, or says it already runs
#   imawake status   says whether ImAwake runs
# Exit codes: 0 ok / running, 1 not running, 2 wrong arguments, 3 failure.
# No param() block: with -File an unknown -switch would be a binding error with the wrong exit code.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'ImAwake.Launch.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ImAwake.Text.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ImAwake.Language.psm1') -Force

$script:CliArgs = @($args)
$script:AppScript = Join-Path $PSScriptRoot 'ImAwake.ps1'
$script:PowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$script:Terminal = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\wt.exe'
# No text table without the language files, so this one message is plain English.
try { $script:Language = Get-LanguageSetup $PSScriptRoot }
catch {
    [Console]::Error.WriteLine("$(Get-CommandName) failed: could not read the language files: $_")
    exit 3
}
$script:Text = $script:Language.Tables[$script:Language.Language]
if ($script:Language.PreferenceError) { [Console]::Error.WriteLine("$(Get-CommandName): $($script:Language.PreferenceError)") }

# Gives the start time of the running app, or $null. A process with higher rights has no
# readable command line; it is skipped and not counted.
function Get-AppStartTime {
    $running = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
        Where-Object { $_.ProcessId -ne $PID -and (Test-AppCommandLine $_.CommandLine $script:AppScript) } |
        Sort-Object CreationDate)
    if ($running.Count -eq 0) { return $null }
    $running[0].CreationDate
}

# The command words stay as they are; the words around them come from the language table.
function Show-Usage {
    $cmd = Get-CommandName
    $line = '{0,-7}{1,-17}{2}'
    Write-Host ($line -f (Format-Text $script:Text 'CliUsage'), $cmd, (Format-Text $script:Text 'CliUsageRun'))
    Write-Host ($line -f '', "$cmd window", (Format-Text $script:Text 'CliUsageWindow'))
    Write-Host ($line -f '', "$cmd status", (Format-Text $script:Text 'CliUsageStatus'))
}

function Start-App {
    if (-not (Test-Path $script:Terminal)) {
        throw (Format-Text $script:Text 'CliNoTerminal' @($script:Terminal))
    }
    Start-Process -FilePath $script:Terminal -ArgumentList (Get-LaunchArguments $script:PowerShell $script:AppScript)
}

# True (after telling the user) when the app already runs, so no second copy starts.
function Test-AlreadyRunning {
    $start = Get-AppStartTime
    if (-not $start) { return $false }
    Write-Host (Format-Text $script:Text 'CliAlreadyRunning' @(Format-Since $start (Get-Date)))
    $true
}

# Runs the app as a child process in this console; it gets the same window and keys.
# Start-Process, not &: the caller captures this function's output, and & would then
# redirect the app's stdout to a pipe, so the app would have no console to draw on.
function Invoke-Here {
    if (Test-AlreadyRunning) { return 0 }
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$script:AppScript`""
    $app = Start-Process -FilePath $script:PowerShell -ArgumentList $arguments -NoNewWindow -Wait -PassThru
    $app.ExitCode
}

function Invoke-Window {
    if (Test-AlreadyRunning) { return 0 }
    Start-App
    Write-Host (Format-Text $script:Text 'CliStarted')
    0
}

function Invoke-Status {
    $start = Get-AppStartTime
    if ($start) {
        Write-Host (Format-Text $script:Text 'CliRunning' @(Format-Since $start (Get-Date)))
        return 0
    }
    Write-Host (Format-Text $script:Text 'CliNotRunning')
    1
}

try {
    switch (Resolve-CliAction $script:CliArgs) {
        'here'   { $code = Invoke-Here }
        'window' { $code = Invoke-Window }
        'status' { $code = Invoke-Status }
        'help'   { Show-Usage; $code = 0 }
        default  {
            [Console]::Error.WriteLine((Format-Text $script:Text 'CliUnknownArgs' @($script:CliArgs -join ' ')))
            Show-Usage
            $code = 2
        }
    }
}
catch {
    [Console]::Error.WriteLine((Format-Text $script:Text 'CliFailed' @("$_")))
    $code = 3
}
exit $code
