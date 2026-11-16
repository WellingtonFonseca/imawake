Set-StrictMode -Version Latest

$installer = Join-Path $PSScriptRoot '..\scripts\install.ps1'
$srcDir = Join-Path $PSScriptRoot '..\src'
$powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

# Two guards keep the child installer off the real user setup:
# 1. A file with a syntax error stops it in Copy-App, before the shortcut and the PATH change.
# 2. LOCALAPPDATA points to an empty folder, so New-Shortcut cannot find wt.exe and throws
#    before the shortcut and the PATH write, even if guard 1 breaks.
Describe 'install.ps1 with a relative -SourceDir' {
    It 'loads the modules from the current folder and reaches the file check' {
        $work = Join-Path $env:TEMP ('imawake-install-test-{0:yyyyMMddHHmmss}-{1}' -f (Get-Date), (Get-Random))
        $realLocalAppData = $env:LOCALAPPDATA
        try {
            $source = Join-Path $work 'src'
            New-Item -ItemType Directory -Force -Path $source | Out-Null
            Copy-Item -Path (Join-Path $srcDir '*') -Destination $source -Recurse
            Set-Content -Path (Join-Path $source 'ImAwake.ps1') -Value 'function Broken {'
            $env:LOCALAPPDATA = Join-Path $work 'localappdata'

            Push-Location $work
            # Windows PowerShell 5.1 throws on the first stderr line of a native command
            # under 'Stop'; the test needs the full output instead.
            $ErrorActionPreference = 'Continue'
            try {
                $output = & $powershell -NoProfile -ExecutionPolicy Bypass -File $installer `
                    -SourceDir src -TargetDir (Join-Path $work 'target') 2>&1 | Out-String
                $exitCode = $LASTEXITCODE
            }
            finally {
                Pop-Location
            }

            # (?s): the child console wraps the long path onto a new line.
            $output | Should Match '(?s)syntax error in.*ImAwake\.ps1'
            $exitCode | Should Not Be 0
            Test-Path (Join-Path $work 'target') | Should Be $false
        }
        finally {
            $env:LOCALAPPDATA = $realLocalAppData
            Remove-Item -Recurse -Force -Path $work -ErrorAction SilentlyContinue
        }
    }
}
