Set-StrictMode -Version Latest
$screenPath = (Resolve-Path (Join-Path $PSScriptRoot '..\src\ImAwake.Screen.psm1')).Path
Import-Module $screenPath -Force
$powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

# Only the paths that need no console: the console code page itself is not testable here.
Describe 'Restore-Output' {
    It 'leaves the encoding alone when it gets $null' {
        $before = [Console]::OutputEncoding.CodePage
        Restore-Output $null
        [Console]::OutputEncoding.CodePage | Should Be $before
    }
}

Describe 'Use-Utf8Output' {
    It 'does nothing and gives $null when output and error are both redirected' {
        $command = 'Import-Module ''' + $screenPath + '''; if ($null -eq (Use-Utf8Output)) { ''null'' } else { ''set'' }'
        $output = & $powershell -NoProfile -ExecutionPolicy Bypass -Command $command 2>&1 | Out-String
        $output.Trim() | Should Be 'null'
    }
}
