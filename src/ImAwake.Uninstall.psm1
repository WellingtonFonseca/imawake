# Pure rules of the uninstall: which files the app has, the steps in order, and when the
# uninstaller keeps itself. Shared by the installer, the app and uninstall.ps1, so the
# file list lives in one place.

Set-StrictMode -Version Latest

# Every file the installer copies to the app folder (paths relative to it).
function Get-AppFiles {
    @(
        'ImAwake.ps1', 'ImAwake.Core.psm1', 'ImAwake.Frame.psm1', 'ImAwake.Power.psm1',
        'ImAwake.Screen.psm1', 'ImAwake.Setup.psm1', 'ImAwake.Uninstall.psm1',
        'ImAwake.UserPath.psm1', 'ImAwake.Launch.psm1', 'ImAwake.Cli.ps1',
        'uninstall.ps1', 'bin\imawake.cmd'
    )
}

# The desktop shortcut the installer makes and the uninstaller removes: one definition, so
# the two never point to different files.
function Get-ShortcutPath {
    Join-Path ([Environment]::GetFolderPath('Desktop')) 'ImAwake.lnk'
}

# The files uninstall.ps1 imports. They go after the other files and stay after a failed
# step, so the script can run again.
function Get-ModuleFiles {
    @(Get-AppFiles | Where-Object { $_ -like 'ImAwake.*.psm1' })
}

# The marker the installer writes last. Only an installed copy has it, so a repository
# checkout never uninstalls anything.
function Get-MarkerName { 'installed.txt' }

function Test-InstalledCopy([string]$AppDir) {
    Test-Path -LiteralPath (Join-Path $AppDir (Get-MarkerName))
}

# The steps in the order uninstall.ps1 runs them. The marker and the uninstaller go last,
# so a failure before them leaves a copy that can run the uninstall again.
function Get-UninstallItems {
    $items = @(
        [pscustomobject]@{ Id = 'path'; Label = 'Remove bin from the user PATH'; Name = '' }
        [pscustomobject]@{ Id = 'shortcut'; Label = 'Remove the desktop shortcut'; Name = '' }
    )
    $modules = Get-ModuleFiles
    foreach ($file in (Get-AppFiles | Where-Object { $_ -ne 'uninstall.ps1' -and $_ -notin $modules })) {
        $items += [pscustomobject]@{ Id = 'file'; Label = "Remove $file"; Name = $file }
    }
    foreach ($file in $modules) {
        $items += [pscustomobject]@{ Id = 'module'; Label = "Remove $file"; Name = $file }
    }
    $items += [pscustomobject]@{ Id = 'marker'; Label = 'Remove the install marker'; Name = (Get-MarkerName) }
    $items += [pscustomobject]@{ Id = 'self'; Label = 'Remove uninstall.ps1'; Name = 'uninstall.ps1' }
    $items += [pscustomobject]@{ Id = 'bin-folder'; Label = 'Remove the bin folder'; Name = 'bin' }
    $items += [pscustomobject]@{ Id = 'app-folder'; Label = 'Remove the app folder'; Name = '' }
    $items
}

# True when an earlier step failed: the uninstaller stays for a second run.
function Test-KeepUninstaller($Results) {
    foreach ($result in @($Results)) {
        if ($result.Status -eq 'failed') { return $true }
    }
    $false
}

Export-ModuleMember -Function Get-ShortcutPath, Get-AppFiles, Get-ModuleFiles, Get-MarkerName, Test-InstalledCopy, Get-UninstallItems, Test-KeepUninstaller
