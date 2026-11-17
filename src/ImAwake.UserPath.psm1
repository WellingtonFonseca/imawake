# Pure rules for adding a folder to the user PATH text, and for taking it out again.
# Used by the installer and the uninstaller.

Set-StrictMode -Version Latest

# The compare form of one PATH entry: variables expanded, no spaces, no trailing \, lower case.
function Format-PathKey([string]$Entry) {
    [Environment]::ExpandEnvironmentVariables($Entry.Trim().Trim('"')).TrimEnd('\').ToLowerInvariant()
}

# Gives the new PATH text with Dir at the end, or $null when Dir is already there.
# The other entries stay as they are, %VAR% text included.
function Add-PathEntry([string]$Raw, [string]$Dir) {
    $key = Format-PathKey $Dir
    $entries = @(([string]$Raw) -split ';' | Where-Object { $_.Trim() })
    foreach ($entry in $entries) {
        if ((Format-PathKey $entry) -eq $key) { return $null }
    }
    if ([string]::IsNullOrEmpty($Raw)) { return $Dir }
    $Raw.TrimEnd(';') + ';' + $Dir
}

# Gives the PATH text without Dir, or $null when Dir is not there.
# The other entries stay as they are, %VAR% text included.
function Remove-PathEntry([string]$Raw, [string]$Dir) {
    $key = Format-PathKey $Dir
    $entries = @(([string]$Raw) -split ';' | Where-Object { $_.Trim() })
    $kept = @($entries | Where-Object { (Format-PathKey $_) -ne $key })
    if ($kept.Count -eq $entries.Count) { return $null }
    $kept -join ';'
}

Export-ModuleMember -Function Add-PathEntry, Remove-PathEntry
