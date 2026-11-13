# The Windows calls of ImAwake: the power request and the console VT mode.
# SetThreadExecutionState holds its state per thread. The app is one single-threaded
# loop, so every call comes from one thread; a guard checks it, because a call from
# another thread would leave the first request held or released by mistake.

Set-StrictMode -Version Latest

$script:PowerThreadId = $null

function Initialize-Native {
    if ('ImAwake.Native' -as [type]) { return }
    Add-Type -Namespace ImAwake -Name Native -MemberDefinition @'
[DllImport("kernel32.dll", SetLastError = true)]
public static extern uint SetThreadExecutionState(uint esFlags);
[DllImport("kernel32.dll", SetLastError = true)]
public static extern IntPtr GetStdHandle(int nStdHandle);
[DllImport("kernel32.dll", SetLastError = true)]
public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
[DllImport("kernel32.dll", SetLastError = true)]
public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
'@
}

# Sets the flags and gives the flags that were active before the call.
function Set-PowerState([uint32]$Flags) {
    $threadId = [Threading.Thread]::CurrentThread.ManagedThreadId
    if ($null -eq $script:PowerThreadId) { $script:PowerThreadId = $threadId }
    if ($threadId -ne $script:PowerThreadId) {
        throw "power call from thread $threadId; the request belongs to thread $script:PowerThreadId"
    }
    $previous = [ImAwake.Native]::SetThreadExecutionState($Flags)
    if ($previous -eq 0) {
        $code = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        throw ('SetThreadExecutionState(0x{0:X8}) failed with Windows error {1}' -f $Flags, $code)
    }
    [uint32]$previous
}

# Turns on ANSI escape handling. powershell.exe does not always do it in a classic console window.
function Enable-VirtualTerminal {
    $stdout = [ImAwake.Native]::GetStdHandle(-11)
    $mode = [uint32]0
    if (-not [ImAwake.Native]::GetConsoleMode($stdout, [ref]$mode)) {
        throw ('GetConsoleMode failed with Windows error {0}' -f [Runtime.InteropServices.Marshal]::GetLastWin32Error())
    }
    if (-not [ImAwake.Native]::SetConsoleMode($stdout, ($mode -bor 4))) {
        throw ('SetConsoleMode failed with Windows error {0}' -f [Runtime.InteropServices.Marshal]::GetLastWin32Error())
    }
}

Export-ModuleMember -Function Initialize-Native, Set-PowerState, Enable-VirtualTerminal
