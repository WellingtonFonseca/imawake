# The Windows calls of ImAwake: the power request, the F15 keypress and the console VT mode.
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
// MOUSEINPUT is the largest union member; without it cbSize is wrong and SendInput fails.
[StructLayout(LayoutKind.Sequential)]
public struct MOUSEINPUT { public int dx; public int dy; public uint mouseData; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }
[StructLayout(LayoutKind.Sequential)]
public struct KEYBDINPUT { public ushort wVk; public ushort wScan; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }
[StructLayout(LayoutKind.Explicit)]
public struct InputUnion { [FieldOffset(0)] public MOUSEINPUT mi; [FieldOffset(0)] public KEYBDINPUT ki; }
[StructLayout(LayoutKind.Sequential)]
public struct INPUT { public uint type; public InputUnion U; }
[DllImport("user32.dll", SetLastError = true)]
public static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);
// Key down, then key up (KEYEVENTF_KEYUP = 2); without the up event the key stays held.
public static INPUT[] NewKeyTap(ushort vk) {
    INPUT[] inputs = new INPUT[2];
    inputs[0].type = 1;
    inputs[0].U.ki.wVk = vk;
    inputs[1].type = 1;
    inputs[1].U.ki.wVk = vk;
    inputs[1].U.ki.dwFlags = 2;
    return inputs;
}
// Reads the error code here, because PowerShell work after the call can overwrite it.
public static uint TapKey(ushort vk, out int error) {
    uint sent = SendInput(2, NewKeyTap(vk), Marshal.SizeOf(typeof(INPUT)));
    error = Marshal.GetLastWin32Error();
    return sent;
}
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

# Taps F15 (VK 0x7E): it resets the Windows idle timer, and almost no keyboard or app uses it.
function Send-F15Key {
    $code = 0
    $sent = [ImAwake.Native]::TapKey(0x7E, [ref]$code)
    if ($sent -ne 2) {
        throw ('SendInput(F15) sent {0} of 2 events; Windows error {1}' -f $sent, $code)
    }
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

# One ImAwake per Windows session: the app holds this mutex while it runs, so it also tells
# that the app is gone. Gives the mutex, or $null when another process holds it.
# An abandoned mutex (the last owner was killed) is taken over. A mutex made by an elevated
# app refuses a normal process: that also means "runs".
function Lock-SingleInstance([int]$TimeoutMs = 0, [string]$Name = 'Local\ImAwake') {
    $mutex = $null
    try {
        $mutex = New-Object Threading.Mutex($false, $Name)
        if ($mutex.WaitOne($TimeoutMs)) { return $mutex }
    }
    catch [Threading.AbandonedMutexException] {
        return $mutex
    }
    catch [UnauthorizedAccessException] {
        return $null
    }
    if ($mutex) { $mutex.Dispose() }
    $null
}

function Unlock-SingleInstance($Mutex) {
    if (-not $Mutex) { return }
    $Mutex.ReleaseMutex()
    $Mutex.Dispose()
}

Export-ModuleMember -Function Lock-SingleInstance, Unlock-SingleInstance, Initialize-Native, Set-PowerState, Send-F15Key, Enable-VirtualTerminal
