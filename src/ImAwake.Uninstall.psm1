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

function New-UninstallItem([string]$Id, [string]$Label, [string]$Kind, [string]$Name, [bool]$KeepOnFailure = $false) {
    [pscustomobject]@{ Id = $Id; Label = $Label; Kind = $Kind; Name = $Name; KeepOnFailure = $KeepOnFailure }
}

# The steps in the order uninstall.ps1 runs them. The modules, the marker and the uninstaller
# go last and stay after a failed step (KeepOnFailure), so a second run can finish.
function Get-UninstallItems {
    $items = @(
        New-UninstallItem 'path' 'Remove bin from the user PATH' 'path' ''
        New-UninstallItem 'shortcut' 'Remove the desktop shortcut' 'shortcut' ''
    )
    $modules = Get-ModuleFiles
    foreach ($file in (Get-AppFiles | Where-Object { $_ -ne 'uninstall.ps1' -and $_ -notin $modules })) {
        $items += New-UninstallItem 'file' "Remove $file" 'file' $file
    }
    foreach ($file in $modules) {
        $items += New-UninstallItem 'module' "Remove $file" 'file' $file $true
    }
    $items += New-UninstallItem 'marker' 'Remove the install marker' 'file' (Get-MarkerName) $true
    $items += New-UninstallItem 'self' 'Remove uninstall.ps1' 'file' 'uninstall.ps1' $true
    $items += New-UninstallItem 'bin-folder' 'Remove the bin folder' 'folder' 'bin'
    $items += New-UninstallItem 'app-folder' 'Remove the app folder' 'folder' ''
    $items
}

# True when an earlier step failed: the uninstaller stays for a second run.
function Test-KeepUninstaller($Results) {
    foreach ($result in @($Results)) {
        if ($result.Status -eq 'failed') { return $true }
    }
    $false
}

# Runs one step through the effects and gives its status: ok, skipped or a thrown error.
function Invoke-UninstallStep($Item, $Results, [string]$AppDir, [hashtable]$Effects) {
    if ($Item.KeepOnFailure -and (Test-KeepUninstaller $Results)) { return 'skipped' }
    $path = if ($Item.Name) { Join-Path $AppDir $Item.Name } else { $AppDir }
    switch ($Item.Kind) {
        'path'     { return [string](& $Effects.RemovePath) }
        'shortcut' { return [string](& $Effects.RemoveShortcut) }
        'file'     { return [string](& $Effects.RemoveFile $path) }
        'folder'   { return [string](& $Effects.RemoveFolder $path) }
    }
}

# A failed step does not stop the next ones: it is logged and the run goes on.
function Get-UninstallResult($Item, $Results, [string]$AppDir, [hashtable]$Effects) {
    try {
        [pscustomobject]@{ Label = $Item.Label; Status = (Invoke-UninstallStep $Item $Results $AppDir $Effects); Reason = '' }
    }
    catch {
        & $Effects.Log "$($Item.Label) failed: $_"
        [pscustomobject]@{ Label = $Item.Label; Status = 'failed'; Reason = "$_" }
    }
}

function Get-UninstallView($Items, $Results, [bool]$Finished, [bool]$Fancy) {
    $done = @($Results).Count
    $current = if ($done -lt $Items.Count) { $Items[$done].Label } else { '' }
    [pscustomobject]@{
        Fancy = $Fancy; Done = $done; Total = $Items.Count; Current = $current; Finished = $Finished
        Failed = @($Results | Where-Object { $_.Status -eq 'failed' } | ForEach-Object { $_.Label })
    }
}

# Runs every step with the effects of the host (real registry and console, or fakes in a test),
# then shows the final view, reports the results and waits for a key. Gives the final view.
function Invoke-Uninstall([object[]]$Items, [string]$AppDir, [hashtable]$Effects, [bool]$Fancy) {
    $results = @()
    foreach ($item in $Items) {
        & $Effects.Show (Get-UninstallView $Items $results $false $Fancy)
        $results += Get-UninstallResult $item $results $AppDir $Effects
    }
    $view = Get-UninstallView $Items $results $true $Fancy
    & $Effects.Show $view
    & $Effects.Report $results
    & $Effects.WaitKey
    $view
}

Export-ModuleMember -Function Get-ShortcutPath, Get-AppFiles, Get-ModuleFiles, Get-MarkerName, Test-InstalledCopy, Get-UninstallItems, Test-KeepUninstaller, Invoke-Uninstall, Get-UninstallResult, Get-UninstallView
