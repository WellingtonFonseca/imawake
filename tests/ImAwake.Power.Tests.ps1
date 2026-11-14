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
