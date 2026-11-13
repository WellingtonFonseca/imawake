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
