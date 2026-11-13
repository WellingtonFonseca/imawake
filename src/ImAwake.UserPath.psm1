# Pure rule for adding a folder to the user PATH text. Used only by the installer.

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

Export-ModuleMember -Function Add-PathEntry
