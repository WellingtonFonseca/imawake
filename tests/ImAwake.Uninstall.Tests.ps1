Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot '..\src\ImAwake.Uninstall.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\src\ImAwake.Setup.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\src\ImAwake.UserPath.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\src\ImAwake.Language.psm1') -Force
$en = Import-PowerShellDataFile -Path (Join-Path $PSScriptRoot '..\src\lang\en.psd1')

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
        $items = @(Get-UninstallItems $en)
        $items[0].Id | Should Be 'path'
        $items[1].Id | Should Be 'shortcut'
        $items[2].Id | Should Be 'file'
    }
    It 'ends with the runtime files, the marker, the uninstaller and the folders, in that order' {
        $ids = @(Get-UninstallItems $en | ForEach-Object { $_.Id })
        $tail = $ids[-5..-1] -join ','
        $tail | Should BeExactly 'marker,self,lang-folder,bin-folder,app-folder'
        $ids[-6] | Should Be 'module'
        $firstModule = [array]::IndexOf($ids, 'module')
        ($ids[0..($firstModule - 1)] | Where-Object { $_ -eq 'module' }) | Should BeNullOrEmpty
        @($ids | Where-Object { $_ -eq 'module' }).Count | Should Be @(Get-RuntimeFiles).Count
    }
    It 'counts the language files as runtime files, so they stay after a failed step' {
        (@(Get-RuntimeFiles) -contains 'lang\en.psd1') | Should Be $true
        (@(Get-RuntimeFiles) -contains 'ImAwake.Core.psm1') | Should Be $true
        (@(Get-RuntimeFiles) -contains 'uninstall.ps1') | Should Be $false
    }
    It 'removes the lang folder as a folder step' {
        $step = @(Get-UninstallItems $en | Where-Object { $_.Id -eq 'lang-folder' })
        $step.Count | Should Be 1
        $step[0].Kind | Should Be 'folder'
        $step[0].Name | Should Be 'lang'
    }
    It 'takes every label from the text table' {
        $other = @{}
        foreach ($key in $en.Keys) { $other[$key] = $en[$key] }
        $other['ItemPath'] = 'Tirar bin do PATH'
        $other['ItemFile'] = 'Remover {0}'
        $items = @(Get-UninstallItems $other)
        $items[0].Label | Should Be 'Tirar bin do PATH'
        ($items | Where-Object { $_.Id -eq 'self' }).Label | Should Be 'Remover uninstall.ps1'
        ($items | Where-Object { $_.Name -eq 'ImAwake.Core.psm1' }).Label | Should Be 'Remover ImAwake.Core.psm1'
    }
    It 'gives every item a label with no leftover placeholder' {
        foreach ($item in (Get-UninstallItems $en)) {
            [string]::IsNullOrWhiteSpace($item.Label) | Should Be $false
            $item.Label | Should Not Match '\{'
        }
    }
    It 'has one file or module step for each app file except the uninstaller' {
        $files = @(Get-UninstallItems $en | Where-Object { $_.Id -in 'file', 'module' } | ForEach-Object { $_.Name })
        $files.Count | Should Be (@(Get-AppFiles).Count - 1)
        ($files -contains 'uninstall.ps1') | Should Be $false
    }
}

Describe 'Get-UninstallItems data' {
    It 'keeps on failure exactly the modules, the marker and the uninstaller' {
        $keep = @(Get-UninstallItems $en | Where-Object { $_.KeepOnFailure } | ForEach-Object { $_.Id } | Sort-Object -Unique)
        $keep -join ',' | Should BeExactly 'marker,module,self'
    }
    It 'gives every item a kind' {
        foreach ($item in (Get-UninstallItems $en)) { ($item.Kind -in 'path', 'shortcut', 'file', 'folder') | Should Be $true }
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
function Invoke-Uninstaller([string]$Dir, [byte[]]$LanguageFileBytes = $null) {
    $old = $ErrorActionPreference
    $realLocalAppData = $env:LOCALAPPDATA
    $ErrorActionPreference = 'Continue'
    $env:LOCALAPPDATA = Join-Path $Dir '..\imawake-test-localappdata'
    try {
        # The saved language wins over the Windows language, so the output never depends on this PC.
        $languageFile = Join-Path $env:LOCALAPPDATA 'ImAwake\language.txt'
        Save-LanguagePreference $languageFile 'en'
        if ($null -ne $LanguageFileBytes) { [IO.File]::WriteAllBytes($languageFile, $LanguageFileBytes) }
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
    It 'stops with a clear message and removes nothing when the language files are missing' {
        $dir = New-FakeInstall $true @('lang\en.psd1', 'lang\pt-BR.psd1')
        try {
            $run = Invoke-Uninstaller $dir
            $run.ExitCode | Should Be 1
            $run.Output | Should Match 'could not read its language files'
            Test-Path (Join-Path $dir 'ImAwake.ps1') | Should Be $true
            Test-Path (Join-Path $dir (Get-MarkerName)) | Should Be $true
        }
        finally { Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
    }
    It 'ignores an empty language file and still uninstalls' {
        $dir = New-FakeInstall $true
        try {
            $run = Invoke-Uninstaller $dir -LanguageFileBytes ([byte[]]@())
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

# Effects that record each call; a key can be replaced to force a failure.
function New-FakeEffects($Calls, [hashtable]$Override = @{}) {
    $effects = @{
        RemovePath     = { $Calls.Add('path') | Out-Null; 'ok' }.GetNewClosure()
        RemoveShortcut = { $Calls.Add('shortcut') | Out-Null; 'ok' }.GetNewClosure()
        RemoveFile     = { param($Path) $Calls.Add("file:$Path") | Out-Null; 'ok' }.GetNewClosure()
        RemoveFolder   = { param($Path) $Calls.Add("folder:$Path") | Out-Null; 'ok' }.GetNewClosure()
        Show           = { param($View) $Calls.Add("show:$($View.Done)") | Out-Null }.GetNewClosure()
        Report         = { param($Results) $Calls.Add('report') | Out-Null }.GetNewClosure()
        WaitKey        = { $Calls.Add('wait') | Out-Null }.GetNewClosure()
        Log            = { param($Message) $Calls.Add("log:$Message") | Out-Null }.GetNewClosure()
    }
    foreach ($key in $Override.Keys) { $effects[$key] = $Override[$key] }
    $effects
}

Describe 'Invoke-Uninstall with fake effects' {
    $appDir = 'C:\Fake\App'
    It 'runs every step in order and shows the final view last' {
        $calls = New-Object Collections.ArrayList
        $items = @(Get-UninstallItems $en)
        $view = Invoke-Uninstall $items $appDir (New-FakeEffects $calls) $false $en
        $view.Done | Should Be $items.Count
        $view.Total | Should Be $items.Count
        $view.Finished | Should Be $true
        @($view.Failed).Count | Should Be 0
        $steps = @($calls | Where-Object { $_ -notlike 'show:*' -and $_ -ne 'report' -and $_ -ne 'wait' })
        $steps.Count | Should Be $items.Count
        $steps[0] | Should Be 'path'
        $steps[1] | Should Be 'shortcut'
        @($calls | Where-Object { $_ -like 'show:*' }).Count | Should Be ($items.Count + 1)
        ($calls[-3..-1]) -join ',' | Should BeExactly "show:$($items.Count),report,wait"
    }
    It 'passes full paths to the file and folder effects' {
        $calls = New-Object Collections.ArrayList
        Invoke-Uninstall @(Get-UninstallItems $en) $appDir (New-FakeEffects $calls) $false $en | Out-Null
        ($calls -contains 'file:C:\Fake\App\ImAwake.Core.psm1') | Should Be $true
        ($calls -contains 'file:C:\Fake\App\uninstall.ps1') | Should Be $true
        ($calls -contains 'folder:C:\Fake\App\bin') | Should Be $true
        ($calls -contains 'folder:C:\Fake\App') | Should Be $true
    }
    It 'fails one step, logs it, keeps the uninstaller and its modules, and still tries the folders' {
        $calls = New-Object Collections.ArrayList
        $fail = { param($Path) if ($Path -like '*ImAwake.Cli.ps1') { throw 'locked' }; 'ok' }
        $view = Invoke-Uninstall @(Get-UninstallItems $en) $appDir (New-FakeEffects $calls @{ RemoveFile = $fail }) $false $en
        @($view.Failed).Count | Should Be 1
        $view.Failed[0] | Should Be 'Remove ImAwake.Cli.ps1'
        (@($calls | Where-Object { $_ -like 'log:*locked*' }).Count) | Should Be 1
        ($calls -contains 'file:C:\Fake\App\uninstall.ps1') | Should Be $false
        ($calls -contains 'file:C:\Fake\App\ImAwake.Core.psm1') | Should Be $false
        ($calls -contains 'file:C:\Fake\App\installed.txt') | Should Be $false
        ($calls -contains 'folder:C:\Fake\App\bin') | Should Be $true
        ($calls -contains 'folder:C:\Fake\App') | Should Be $true
    }
    It 'gives each result a single string status' {
        $calls = New-Object Collections.ArrayList
        $items = @(Get-UninstallItems $en)
        $results = @()
        foreach ($item in $items) {
            $result = Get-UninstallResult $item $results $appDir (New-FakeEffects $calls)
            ($result.Status -is [string]) | Should Be $true
            $results += $result
        }
    }
}

Describe 'ImAwake.Cli.ps1 with no language files' {
    It 'says so and exits with 3, the failure code' {
        $dir = New-FakeInstall $true @('lang\en.psd1', 'lang\pt-BR.psd1')
        $old = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $output = & $powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $dir 'ImAwake.Cli.ps1') status 2>&1 | Out-String
            $LASTEXITCODE | Should Be 3
            $output | Should Match 'could not read the language files'
        }
        finally {
            $ErrorActionPreference = $old
            Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
        }
    }
}
