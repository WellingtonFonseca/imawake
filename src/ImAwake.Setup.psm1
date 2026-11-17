# The user PATH in the registry: one edit with a backup and the change broadcast.
# Shared by the installer and the uninstaller. The pure text rules are in ImAwake.UserPath.psm1.

Set-StrictMode -Version Latest

# Appends, so a second run keeps the first original value.
function Save-PathBackup($Raw, [string]$BackupPath) {
    New-Item -ItemType Directory -Force -Path (Split-Path $BackupPath) | Out-Null
    Add-Content -Path $BackupPath -Encoding UTF8 -Value ('{0:yyyy-MM-dd HH:mm:ss} {1}' -f (Get-Date), $Raw)
}

# Tells Explorer to reload the environment, so new terminal windows see the new PATH.
function Send-EnvironmentChange {
    if (-not ('ImAwakeSetup.Native' -as [type])) {
        Add-Type -Namespace ImAwakeSetup -Name Native -MemberDefinition @'
[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
'@
    }
    $result = [UIntPtr]::Zero
    $ok = [ImAwakeSetup.Native]::SendMessageTimeout([IntPtr]0xFFFF, 0x1A, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$result)
    if ($ok -eq [IntPtr]::Zero) {
        Write-Warning 'Windows did not confirm the PATH change. Sign out and in again if imawake is not found.'
    }
}

# Reads the raw PATH value (no %VAR% expansion), asks Change for the new text and writes it
# with the same value kind. Change gives $null for "nothing to do". Gives $true when it wrote.
# .NET's SetEnvironmentVariable would expand %VAR% entries and change the value type.
function Edit-UserPath([scriptblock]$Change, [string]$BackupPath, [string]$KeyPath = 'Environment', [switch]$NoBroadcast) {
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($KeyPath, $true)
    try {
        $raw = $key.GetValue('Path', $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        $new = & $Change $raw
        if ($null -eq $new) { return $false }
        $kind = [Microsoft.Win32.RegistryValueKind]::ExpandString
        if ($null -ne $raw) { $kind = $key.GetValueKind('Path') }
        Save-PathBackup $raw $BackupPath
        $key.SetValue('Path', $new, $kind)
    }
    finally {
        $key.Close()
    }
    if (-not $NoBroadcast) { Send-EnvironmentChange }
    $true
}

Export-ModuleMember -Function Edit-UserPath
