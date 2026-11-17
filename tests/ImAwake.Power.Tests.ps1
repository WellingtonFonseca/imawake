# Integration test: calls the real Windows API. It holds the request only for a moment
# and releases it at the end, also on a failure.
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot '..\src\ImAwake.Power.psm1') -Force

$continuous = [uint32]2147483648
$system = [uint32]2147483649
$systemAndDisplay = [uint32]2147483651

Describe 'Set-PowerState (real Windows call)' {
    Initialize-Native
    try {
        It 'holds the flags it sets, as the next call reports' {
            Set-PowerState $systemAndDisplay | Out-Null
            Set-PowerState $system | Should Be $systemAndDisplay
            Set-PowerState $continuous | Should Be $system
        }
        It 'loads the native type only once' {
            { Initialize-Native } | Should Not Throw
        }
    }
    finally {
        Set-PowerState $continuous | Out-Null
    }
}

Describe 'Set-PowerState thread guard' {
    It 'refuses a call from another thread' {
        InModuleScope ImAwake.Power {
            $script:PowerThreadId = -1
            try {
                { Set-PowerState ([uint32]2147483648) } | Should Throw 'belongs to thread -1'
            }
            finally {
                $script:PowerThreadId = $null
            }
        }
    }
}

Describe 'Send-F15Key (real Windows call)' {
    Initialize-Native
    It 'gives INPUT the size Windows expects' {
        $expected = if ([IntPtr]::Size -eq 8) { 40 } else { 28 }
        [Runtime.InteropServices.Marshal]::SizeOf([type][ImAwake.Native+INPUT]) | Should Be $expected
    }
    It 'builds an F15 key down followed by an F15 key up' {
        $tap = [ImAwake.Native]::NewKeyTap(0x7E)
        $tap.Count | Should Be 2
        $tap[0].type | Should Be 1
        $tap[0].U.ki.wVk | Should Be 0x7E
        $tap[0].U.ki.dwFlags | Should Be 0
        $tap[1].type | Should Be 1
        $tap[1].U.ki.wVk | Should Be 0x7E
        $tap[1].U.ki.dwFlags | Should Be 2
    }
    # Presses F15 on the real desktop; apps ignore it. Fails on a locked or non-interactive session.
    It 'sends the key down and the key up' {
        { Send-F15Key } | Should Not Throw
    }
}

# A second thread holds the mutex: a mutex belongs to the thread that took it.
function Start-MutexHolder([string]$Name, [bool]$Release) {
    $signal = New-Object Threading.EventWaitHandle($false, [Threading.EventResetMode]::ManualReset, "$Name-signal")
    $ps = [powershell]::Create()
    [void]$ps.AddScript({
        param($mutexName, $signalName, $release)
        $m = New-Object Threading.Mutex($false, $mutexName)
        [void]$m.WaitOne()
        [void][Threading.EventWaitHandle]::OpenExisting($signalName).Set()
        if ($release) { Start-Sleep -Seconds 30 }
    }).AddArgument($Name).AddArgument("$Name-signal").AddArgument($Release)
    $async = $ps.BeginInvoke()
    @{ Ps = $ps; Async = $async; Signal = $signal }
}

Describe 'Lock-SingleInstance' {
    function New-MutexName { 'Local\ImAwakeTest-{0}-{1}' -f (Get-Date -Format 'yyyyMMddHHmmss'), (Get-Random) }
    It 'gives the mutex for a free name, and Unlock-SingleInstance frees it' {
        $name = New-MutexName
        $first = Lock-SingleInstance 0 $name
        ($first -is [Threading.Mutex]) | Should Be $true
        Unlock-SingleInstance $first
        $second = Lock-SingleInstance 0 $name
        ($second -is [Threading.Mutex]) | Should Be $true
        Unlock-SingleInstance $second
    }
    It 'gives $null while another thread holds the mutex' {
        $name = New-MutexName
        $holder = Start-MutexHolder $name $true
        try {
            $holder.Signal.WaitOne(5000) | Should Be $true
            Lock-SingleInstance 0 $name | Should BeNullOrEmpty
        }
        finally {
            $holder.Ps.Stop()
            $holder.Ps.Dispose()
        }
    }
    It 'takes over a mutex that the last owner never released' {
        $name = New-MutexName
        $holder = Start-MutexHolder $name $false
        $holder.Signal.WaitOne(5000) | Should Be $true
        $holder.Ps.EndInvoke($holder.Async)
        $holder.Ps.Dispose()
        $mutex = Lock-SingleInstance 0 $name
        try { ($mutex -is [Threading.Mutex]) | Should Be $true }
        finally { Unlock-SingleInstance $mutex }
    }
    It 'does nothing for a null mutex' { { Unlock-SingleInstance $null } | Should Not Throw }
}
