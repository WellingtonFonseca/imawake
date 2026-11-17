# Hand-made mutation test. It breaks one thing at a time (the list is mutants.psd1), runs the
# tests that cover it, and prints only the mutants that SURVIVE (the tests stayed green) and
# one summary line. Exit code 0: every mutant was killed. 1: a mutant survived or did not apply.
# Each mutant works alone in its own folder, a copy of the code, and the folder is deleted at the
# end. Several mutants run at the same time. Start it with scripts/mutate.sh.
param(
    [string]$Root = (Split-Path $PSScriptRoot),
    [int]$Jobs = 4,
    [int]$TimeoutSec = 180
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Occurrences([string]$Text, [string]$Part) {
    $Text.Split(@($Part), [StringSplitOptions]::None).Count - 1
}

# Breaks one thing in the copy. Gives an error text, or $null when the change was applied.
# The file keeps its BOM (the language files need it) and its line endings.
function Set-Mutation([string]$Dir, $Mutant) {
    $path = Join-Path $Dir $Mutant.File
    if (-not (Test-Path -LiteralPath $path)) { return "file $($Mutant.File) not found" }
    $bytes = [IO.File]::ReadAllBytes($path)
    $hasBom = ($bytes.Length -ge 3) -and ($bytes[0] -eq 0xEF) -and ($bytes[1] -eq 0xBB) -and ($bytes[2] -eq 0xBF)
    $text = [IO.File]::ReadAllText($path)
    $count = Get-Occurrences $text $Mutant.Old
    if ($count -ne 1) { return "the text to break is in $($Mutant.File) $count times, not once" }
    [IO.File]::WriteAllText($path, $text.Replace($Mutant.Old, $Mutant.New), (New-Object Text.UTF8Encoding $hasBom))
    $null
}

# Stops a process and waits for it to end, so it no longer locks files in the folder to delete.
# The process may end by itself between the check and the kill: that is not an error.
function Stop-MutantProcess($Process) {
    try {
        if (-not $Process.HasExited) { $Process.Kill() }
        [void]$Process.WaitForExit(5000)
    }
    catch { Write-Warning "could not stop process $($Process.Id): $_" }
}

# Starts the covering test files in a child process, in the mutant folder. The folder is the
# work folder, so the relative test paths and the tests' own ..\src paths are the mutant's.
function Start-MutantTests([string]$Dir, [string[]]$Tests) {
    $list = ($Tests | ForEach-Object { "'tests\$_'" }) -join ','
    $command = "Import-Module Pester -RequiredVersion 3.4.0; Invoke-Pester -Script @($list) -EnableExit -Quiet"
    $process = Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"$command`"" `
        -WorkingDirectory $Dir -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput (Join-Path $Dir 'mutant-out.txt') -RedirectStandardError (Join-Path $Dir 'mutant-err.txt')
    # Reading Handle keeps the exit code readable after the process ends (Windows PowerShell 5.1).
    $null = $process.Handle
    $process
}

# The tests must pass on the code with no change. Without this check a broken setup (no Pester,
# a wrong test path) makes every mutant fail and the run reports "0 survived" by mistake.
function Assert-Baseline([string]$Dir, [string[]]$Tests, [int]$TimeoutSec) {
    foreach ($part in 'src', 'tests', 'scripts') { Copy-Item -Path (Join-Path $Root $part) -Destination $Dir -Recurse }
    $process = Start-MutantTests $Dir $Tests
    if (-not $process.WaitForExit($TimeoutSec * 1000)) {
        Stop-MutantProcess $process
        throw "baseline run: the tests did not end in $TimeoutSec s, so no mutant was run"
    }
    if ($process.ExitCode -ne 0) {
        $detail = (Get-Content -LiteralPath (Join-Path $Dir 'mutant-err.txt') -ErrorAction SilentlyContinue | Select-Object -First 5) -join ' | '
        throw "baseline run: the tests fail on the code with no change (exit $($process.ExitCode)), so no mutant was run. $detail"
    }
}

$mutants = @((Import-PowerShellDataFile -Path (Join-Path $PSScriptRoot 'mutants.psd1')).Mutants)
$base = Join-Path $env:TEMP ('imawake-mutate-{0}-{1}' -f $PID, (Get-Random))
$problems = New-Object System.Collections.ArrayList
$survivors = New-Object System.Collections.ArrayList
$running = New-Object System.Collections.ArrayList
$next = 0

try {
    $allTests = @($mutants | ForEach-Object { $_.Tests } | Sort-Object -Unique)
    $baselineDir = Join-Path $base 'baseline'
    New-Item -ItemType Directory -Force -Path $baselineDir | Out-Null
    Assert-Baseline $baselineDir $allTests $TimeoutSec
    while ($next -lt $mutants.Count -or $running.Count -gt 0) {
        while ($running.Count -lt $Jobs -and $next -lt $mutants.Count) {
            $number = $next + 1
            $mutant = $mutants[$next]
            $next++
            $dir = Join-Path $base "m$number"
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
            foreach ($part in 'src', 'tests', 'scripts') { Copy-Item -Path (Join-Path $Root $part) -Destination $dir -Recurse }
            $problem = Set-Mutation $dir $mutant
            if ($problem) {
                [void]$problems.Add("#$number $($mutant.Label): $problem")
                continue
            }
            [void]$running.Add(@{ Number = $number; Mutant = $mutant; Process = (Start-MutantTests $dir $mutant.Tests); Started = Get-Date })
        }
        Start-Sleep -Milliseconds 200
        foreach ($job in @($running)) {
            $exited = $job.Process.HasExited
            if (-not $exited -and ((Get-Date) - $job.Started).TotalSeconds -le $TimeoutSec) { continue }
            [void]$running.Remove($job)
            # A process that ended decides by its exit code, even near the time limit. One that still
            # runs after the limit counts as killed: a hang is a change in behavior the tests noticed.
            if (-not $exited) { Stop-MutantProcess $job.Process; continue }
            if ($job.Process.ExitCode -eq 0) {
                [void]$survivors.Add("#$($job.Number) SURVIVED  $($job.Mutant.Label)  [$($job.Mutant.File)]")
            }
        }
    }
}
finally {
    foreach ($job in @($running)) { Stop-MutantProcess $job.Process }
    Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
}

$survivors | Sort-Object | ForEach-Object { $_ }
$problems | Sort-Object | ForEach-Object { $_ }
'mutants: {0}, survived: {1}, not applied: {2}' -f $mutants.Count, $survivors.Count, $problems.Count
if ($survivors.Count -gt 0 -or $problems.Count -gt 0) { exit 1 }
exit 0
