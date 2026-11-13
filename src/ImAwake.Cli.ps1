# The imawake command (called by bin\imawake.cmd).
#   imawake          runs ImAwake in this terminal, or says it already runs
#   imawake window   opens ImAwake in a new window, or says it already runs
#   imawake status   says whether ImAwake runs
# Exit codes: 0 ok / running, 1 not running, 2 wrong arguments, 3 failure.
# No param() block: with -File an unknown -switch would be a binding error with the wrong exit code.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'ImAwake.Launch.psm1') -Force

$script:CliArgs = @($args)
$script:AppScript = Join-Path $PSScriptRoot 'ImAwake.ps1'
$script:PowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$script:Terminal = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\wt.exe'

# Gives the start time of the running app, or $null. A process with higher rights has no
# readable command line; it is skipped and not counted.
function Get-AppStartTime {
    $running = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
        Where-Object { $_.ProcessId -ne $PID -and (Test-AppCommandLine $_.CommandLine $script:AppScript) } |
        Sort-Object CreationDate)
    if ($running.Count -eq 0) { return $null }
    $running[0].CreationDate
}

function Show-Usage {
    Write-Host 'Usage: imawake          run ImAwake in this terminal'
    Write-Host '       imawake window   open ImAwake in a new window'
    Write-Host '       imawake status   say whether ImAwake runs'
}

function Start-App {
    if (-not (Test-Path $script:Terminal)) {
        throw "Windows Terminal not found at $script:Terminal"
    }
    Start-Process -FilePath $script:Terminal -ArgumentList (Get-LaunchArguments $script:PowerShell $script:AppScript)
}

# True (after telling the user) when the app already runs, so no second copy starts.
function Test-AlreadyRunning {
    $start = Get-AppStartTime
    if (-not $start) { return $false }
    Write-Host "ImAwake is already running since $(Format-Since $start (Get-Date))."
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
    Write-Host 'ImAwake started in a new window.'
    0
}

function Invoke-Status {
    $start = Get-AppStartTime
    if ($start) {
        Write-Host "ImAwake is running since $(Format-Since $start (Get-Date))."
        return 0
    }
    Write-Host 'ImAwake is not running.'
    1
}

try {
    switch (Resolve-CliAction $script:CliArgs) {
        'here'   { $code = Invoke-Here }
        'window' { $code = Invoke-Window }
        'status' { $code = Invoke-Status }
        'help'   { Show-Usage; $code = 0 }
        default  {
            [Console]::Error.WriteLine("imawake: unknown arguments: $($script:CliArgs -join ' ')")
            Show-Usage
            $code = 2
        }
    }
}
catch {
    [Console]::Error.WriteLine("imawake failed: $_")
    $code = 3
}
exit $code
