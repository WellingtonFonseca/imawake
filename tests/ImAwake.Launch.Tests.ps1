Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot '..\src\ImAwake.Launch.psm1') -Force

$app = 'C:\Users\welli\Apps\ImAwake\ImAwake.ps1'
$ps = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'

Describe 'Get-LaunchArguments' {
    It 'gives the exact shortcut arguments: a new window and full paths' {
        Get-LaunchArguments $ps $app |
            Should BeExactly "-w new `"$ps`" -NoProfile -ExecutionPolicy Bypass -File `"$app`""
    }
}

Describe 'Test-AppCommandLine' {
    It 'matches the quoted path' {
        Test-AppCommandLine "`"$ps`" -NoProfile -ExecutionPolicy Bypass -File `"$app`"" $app | Should Be $true
    }
    It 'matches the unquoted path at the end' {
        Test-AppCommandLine "powershell.exe -File $app" $app | Should Be $true
    }
    It 'matches the path followed by more arguments' {
        Test-AppCommandLine "powershell.exe -File $app -Plain" $app | Should Be $true
    }
    It 'matches the path in another case' {
        Test-AppCommandLine "powershell.exe -file $($app.ToUpperInvariant())" $app | Should Be $true
    }
    It 'rejects the CLI script in the same folder' {
        Test-AppCommandLine 'powershell.exe -File "C:\Users\welli\Apps\ImAwake\ImAwake.Cli.ps1"' $app | Should Be $false
    }
    It 'rejects the same file name in another folder' {
        Test-AppCommandLine 'powershell.exe -File "C:\Temp\imawake-dev\src\ImAwake.ps1"' $app | Should Be $false
    }
    It 'rejects a path that only starts the same' {
        Test-AppCommandLine "powershell.exe -File ${app}x" $app | Should Be $false
    }
    It 'rejects a missing command line' {
        Test-AppCommandLine $null $app | Should Be $false
        Test-AppCommandLine '' $app | Should Be $false
    }
}

Describe 'Format-Since' {
    $now = Get-Date -Year 2026 -Month 11 -Day 13 -Hour 15 -Minute 0 -Second 0
    It 'gives only the time for a start today' {
        Format-Since $now.Date.AddHours(10).AddMinutes(31) $now | Should BeExactly '10:31'
    }
    It 'adds the date for a start on another day' {
        Format-Since $now.Date.AddDays(-1).AddHours(23).AddMinutes(5) $now | Should BeExactly '2026-11-12 23:05'
    }
}

Describe 'Resolve-CliAction' {
    $cases = @(
        @{ Words = @(); Action = 'here' },
        @{ Words = @(''); Action = 'here' },
        @{ Words = @('window'); Action = 'window' },
        @{ Words = @('Window'); Action = 'window' },
        @{ Words = @('status'); Action = 'status' },
        @{ Words = @('STATUS'); Action = 'status' },
        @{ Words = @('help'); Action = 'help' },
        @{ Words = @('-?'); Action = 'help' },
        @{ Words = @('/?'); Action = 'help' },
        @{ Words = @('--help'); Action = 'help' },
        @{ Words = @('foo'); Action = 'usage-error' },
        @{ Words = @('-foo'); Action = 'usage-error' },
        @{ Words = @('status', 'now'); Action = 'usage-error' }
    )
    It 'maps <Words> to <Action>' -TestCases $cases {
        param($Words, $Action)
        Resolve-CliAction $Words | Should Be $Action
    }
    It 'maps no arguments at all to here' {
        Resolve-CliAction $null | Should Be 'here'
    }
}
