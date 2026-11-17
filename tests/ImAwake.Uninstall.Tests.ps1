Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot '..\src\ImAwake.Uninstall.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\src\ImAwake.Setup.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\src\ImAwake.UserPath.psm1') -Force

$srcDir = Join-Path $PSScriptRoot '..\src'
$powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

function New-WorkDir {
    $dir = Join-Path $env:TEMP ('imawake-uninstall-test-{0:yyyyMMddHHmmss}-{1}' -f (Get-Date), (Get-Random))
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $dir
}

Describe 'Get-AppFiles' {
    It 'lists every file of src, so a new file is never left out of the install' {
        $inSrc = @(Get-ChildItem -Path $srcDir -File -Recurse | ForEach-Object {
            $_.FullName.Substring((Convert-Path $srcDir).Length + 1)
        })
        (@(Get-AppFiles) | Sort-Object) -join '|' | Should BeExactly (($inSrc | Sort-Object) -join '|')
    }
    It 'holds every module that the app and the uninstaller import' {
        $imports = Get-ChildItem -Path $srcDir -File | Where-Object { $_.Extension -in '.ps1', '.psm1' } |
            ForEach-Object { Select-String -Path $_.FullName -Pattern "ImAwake\.\w+\.psm1" -AllMatches } |
            ForEach-Object { $_.Matches | ForEach-Object { $_.Value } } | Sort-Object -Unique
        foreach ($name in $imports) { (@(Get-AppFiles) -contains $name) | Should Be $true }
    }
}

Describe 'Get-ShortcutPath' {
    It 'is ImAwake.lnk on the desktop, the file the installer makes' {
        Get-ShortcutPath | Should BeExactly (Join-Path ([Environment]::GetFolderPath('Desktop')) 'ImAwake.lnk')
    }
}

Describe 'Get-UninstallItems' {
    It 'does the PATH and the shortcut first, then the files' {
        $items = @(Get-UninstallItems)
        $items[0].Id | Should Be 'path'
        $items[1].Id | Should Be 'shortcut'
        $items[2].Id | Should Be 'file'
    }
    It 'ends with the modules, the marker, the uninstaller and the folders, in that order' {
        $ids = @(Get-UninstallItems | ForEach-Object { $_.Id })
        $tail = $ids[-4..-1] -join ','
        $tail | Should BeExactly 'marker,self,bin-folder,app-folder'
        $ids[-5] | Should Be 'module'
        $firstModule = [array]::IndexOf($ids, 'module')
        ($ids[0..($firstModule - 1)] | Where-Object { $_ -eq 'module' }) | Should BeNullOrEmpty
        @($ids | Where-Object { $_ -eq 'module' }).Count | Should Be @(Get-ModuleFiles).Count
    }
    It 'has one file or module step for each app file except the uninstaller' {
        $files = @(Get-UninstallItems | Where-Object { $_.Id -in 'file', 'module' } | ForEach-Object { $_.Name })
        $files.Count | Should Be (@(Get-AppFiles).Count - 1)
        ($files -contains 'uninstall.ps1') | Should Be $false
    }
}

Describe 'Test-KeepUninstaller' {
    It 'is true after a failed step' {
        Test-KeepUninstaller @([pscustomobject]@{ Status = 'ok' }, [pscustomobject]@{ Status = 'failed' }) | Should Be $true
    }
    It 'is false when every step is ok or skipped' {
        Test-KeepUninstaller @([pscustomobject]@{ Status = 'ok' }, [pscustomobject]@{ Status = 'skipped' }) | Should Be $false
    }
    It 'is false for no results' { Test-KeepUninstaller @() | Should Be $false }
}

Describe 'Test-InstalledCopy' {
    It 'needs the marker file' {
        $dir = New-WorkDir
        try {
            Test-InstalledCopy $dir | Should Be $false
            Set-Content -Path (Join-Path $dir (Get-MarkerName)) -Value 'x'
            Test-InstalledCopy $dir | Should Be $true
        }
        finally { Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
    }
}

# A copy of the source in a temp folder, so the test never touches the real install.
function New-FakeInstall([bool]$Marker, [string[]]$Skip = @()) {
    $dir = New-WorkDir
    foreach ($file in (Get-AppFiles)) {
        if ($Skip -contains $file) { continue }
        $target = Join-Path $dir $file
        New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
        Copy-Item -Path (Join-Path $srcDir $file) -Destination $target
    }
    if ($Marker) { Set-Content -Path (Join-Path $dir (Get-MarkerName)) -Value 'test' }
    $dir
}

# LOCALAPPDATA points to a temp folder for the child, so the test never writes to the real
# ImAwake log or PATH backup.
function Invoke-Uninstaller([string]$Dir) {
    $old = $ErrorActionPreference
    $realLocalAppData = $env:LOCALAPPDATA
    $ErrorActionPreference = 'Continue'
    $env:LOCALAPPDATA = Join-Path $Dir '..\imawake-test-localappdata'
    try {
        $output = & $powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Dir 'uninstall.ps1') -SkipUserState -Silent 2>&1 | Out-String
        @{ Output = $output; ExitCode = $LASTEXITCODE }
    }
    finally {
        $env:LOCALAPPDATA = $realLocalAppData
        $ErrorActionPreference = $old
        Remove-Item -Recurse -Force (Join-Path $Dir '..\imawake-test-localappdata') -ErrorAction SilentlyContinue
    }
}

Describe 'uninstall.ps1' {
    It 'removes the whole folder, itself included' {
        $dir = New-FakeInstall $true
        try {
            $run = Invoke-Uninstaller $dir
            $run.ExitCode | Should Be 0
            Test-Path $dir | Should Be $false
        }
        finally { Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
    }
    It 'removes nothing without the marker' {
        $dir = New-FakeInstall $false
        try {
            $run = Invoke-Uninstaller $dir
            $run.ExitCode | Should Be 1
            $run.Output | Should Match 'Not an installed copy'
            Test-Path (Join-Path $dir 'ImAwake.ps1') | Should Be $true
        }
        finally { Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
    }
    It 'keeps the uninstaller and its modules after a failed step, and a second run finishes' {
        $dir = New-FakeInstall $true
        $lock = $null
        try {
            $lock = [IO.File]::Open((Join-Path $dir 'ImAwake.Cli.ps1'), 'Open', 'Read', 'None')
            $first = Invoke-Uninstaller $dir
            $first.ExitCode | Should Be 3
            Test-Path (Join-Path $dir 'uninstall.ps1') | Should Be $true
            Test-Path (Join-Path $dir 'ImAwake.Core.psm1') | Should Be $true
            Test-Path (Join-Path $dir (Get-MarkerName)) | Should Be $true
            $lock.Close()
            $lock = $null
            $second = Invoke-Uninstaller $dir
            $second.ExitCode | Should Be 0
            Test-Path $dir | Should Be $false
        }
        finally {
            if ($lock) { $lock.Close() }
            Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
        }
    }
    It 'keeps a file the user added and the folder that holds it' {
        $dir = New-FakeInstall $true
        try {
            Set-Content -Path (Join-Path $dir 'notes.txt') -Value 'mine'
            $run = Invoke-Uninstaller $dir
            $run.ExitCode | Should Be 0
            Test-Path (Join-Path $dir 'notes.txt') | Should Be $true
            Test-Path (Join-Path $dir 'ImAwake.ps1') | Should Be $false
            Test-Path (Join-Path $dir 'uninstall.ps1') | Should Be $false
        }
        finally { Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
    }
}

Describe 'Edit-UserPath' {
    function New-TestKey {
        $name = 'Software\ImAwakeTest-{0}-{1}' -f (Get-Date -Format 'yyyyMMddHHmmss'), (Get-Random)
        $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($name)
        $key.SetValue('Path', '%USERPROFILE%\x;C:\bin', [Microsoft.Win32.RegistryValueKind]::ExpandString)
        $key.Close()
        $name
    }
    It 'writes the new text with the same kind, keeps %VAR% and saves a backup' {
        $name = New-TestKey
        $dir = New-WorkDir
        try {
            $backup = Join-Path $dir 'backup.txt'
            $changed = Edit-UserPath { param($raw) Remove-PathEntry $raw 'C:\bin' } $backup $name -NoBroadcast
            $changed | Should Be $true
            $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($name)
            $key.GetValue('Path', $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames) | Should BeExactly '%USERPROFILE%\x'
            $key.GetValueKind('Path') | Should Be ([Microsoft.Win32.RegistryValueKind]::ExpandString)
            $key.Close()
            (Get-Content $backup -Raw) | Should Match '%USERPROFILE%\\x;C:\\bin'
        }
        finally {
            [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKey($name, $false)
            Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
        }
    }
    It 'writes nothing and gives $false when the change gives $null' {
        $name = New-TestKey
        $dir = New-WorkDir
        try {
            $backup = Join-Path $dir 'backup.txt'
            (Edit-UserPath { param($raw) $null } $backup $name -NoBroadcast) | Should Be $false
            Test-Path $backup | Should Be $false
        }
        finally {
            [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKey($name, $false)
            Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
        }
    }
}
