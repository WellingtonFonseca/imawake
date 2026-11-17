Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot '..\src\ImAwake.Core.psm1') -Force

function New-Key([ConsoleKey]$Key, [char]$Char = [char]0, [switch]$Ctrl) {
    New-Object ConsoleKeyInfo $Char, $Key, $false, $false, ([bool]$Ctrl)
}

# Gives a list and a scriptblock that records each call in that list.
function New-Recorder {
    $calls = New-Object Collections.ArrayList
    $calls, { param($x) [void]$calls.Add($x) }.GetNewClosure()
}

$noLog = { param($m) }

function New-RunningState([long]$StartMs = 0) {
    Start-AwakeClock (New-AwakeState) $StartMs
}

$coffee = [char]::ConvertFromUtf32(0x2615)
$sleeping = [char]::ConvertFromUtf32(0x1F634)
$dash = [char]::ConvertFromUtf32(0x2013)

Describe 'New-AwakeState' {
    It 'starts stopped, with the screen option on and no time' {
        $s = New-AwakeState
        $s.Running | Should Be $false
        $s.Display | Should Be $true
        Get-ActiveMs $s 99999 | Should Be 0
        $s.Error | Should BeNullOrEmpty
    }
    It 'starts with F15 off and never pressed' {
        $s = New-AwakeState
        $s.KeyPress | Should Be $false
        $s.LastKeyMs | Should BeNullOrEmpty
    }
}

Describe 'Active time' {
    It 'counts while running' {
        $s = New-RunningState 1000
        Get-ActiveMs $s 61000 | Should Be 60000
    }
    It 'freezes while paused and goes on after resume' {
        $s = New-RunningState 0
        $s = Stop-AwakeClock $s 600000
        Get-ActiveMs $s 9999999 | Should Be 600000
        $s = Start-AwakeClock $s 2400000
        Get-ActiveMs $s 2700000 | Should Be 900000
    }
    It 'ignores a second start and a second stop' {
        $s = New-RunningState 0
        $s = Start-AwakeClock $s 300000
        Get-ActiveMs $s 600000 | Should Be 600000
        $s = Stop-AwakeClock $s 600000
        $s = Stop-AwakeClock $s 1200000
        Get-ActiveMs $s 1200000 | Should Be 600000
    }
    It 'never changes the state it receives' {
        $s = New-AwakeState
        $null = Start-AwakeClock $s 0
        $s.Running | Should Be $false
    }
}

Describe 'Get-PowerFlags' {
    It 'releases the request when stopped' {
        Get-PowerFlags (New-AwakeState) | Should Be 2147483648
    }
    It 'holds system and display when running with the screen option' {
        Get-PowerFlags (New-RunningState) | Should Be 2147483651
    }
    It 'holds only the system when the screen option is off' {
        $s = New-RunningState
        $s.Display = $false
        Get-PowerFlags $s | Should Be 2147483649
    }
    It 'releases the request when stopped even with the screen option on' {
        $s = Stop-AwakeClock (New-RunningState) 10
        Get-PowerFlags $s | Should Be 2147483648
    }
}

Describe 'Get-KeyAction' {
    It 'maps space to toggle-pause' { Get-KeyAction (New-Key Spacebar ' ') | Should Be 'toggle-pause' }
    It 'maps d to toggle-display' { Get-KeyAction (New-Key D 'd') | Should Be 'toggle-display' }
    It 'maps q to quit' { Get-KeyAction (New-Key Q 'q') | Should Be 'quit' }
    It 'maps Esc to quit' { Get-KeyAction (New-Key Escape) | Should Be 'quit' }
    It 'maps Ctrl+C to quit' { Get-KeyAction (New-Key C -Ctrl) | Should Be 'quit' }
    It 'ignores Ctrl with another key' { Get-KeyAction (New-Key D -Ctrl) | Should Be 'none' }
    It 'maps f to toggle-keypress' { Get-KeyAction (New-Key F 'f') | Should Be 'toggle-keypress' }
    It 'ignores Ctrl+F' { Get-KeyAction (New-Key F -Ctrl) | Should Be 'none' }
    It 'ignores other keys' { Get-KeyAction (New-Key X 'x') | Should Be 'none' }
}

Describe 'Get-NextState' {
    It 'pauses a running state and resets the timer' {
        $next = Get-NextState (New-RunningState 0) 'toggle-pause' 60000
        $next.Running | Should Be $false
        Get-ActiveMs $next 999999 | Should Be 0
    }
    It 'resumes a paused state with the timer from zero' {
        $paused = Get-NextState (New-RunningState 0) 'toggle-pause' 60000
        $next = Get-NextState $paused 'toggle-pause' 120000
        $next.Running | Should Be $true
        Get-ActiveMs $next 180000 | Should Be 60000
    }
    It 'flips the screen option and keeps the clock' {
        $next = Get-NextState (New-RunningState 0) 'toggle-display' 5000
        $next.Display | Should Be $false
        $next.Running | Should Be $true
    }
    It 'stops the clock on quit and keeps the time' {
        $next = Get-NextState (New-RunningState 0) 'quit' 5000
        $next.Running | Should Be $false
        Get-ActiveMs $next 999999 | Should Be 5000
    }
    It 'turns F15 on and makes a press due, keeping the clock and the screen option' {
        $s = New-RunningState 1000
        $s.LastKeyMs = 500
        $next = Get-NextState $s 'toggle-keypress' 5000
        $next.KeyPress | Should Be $true
        $next.LastKeyMs | Should BeNullOrEmpty
        $next.Running | Should Be $true
        $next.ResumedAtMs | Should Be 1000
        $next.Display | Should Be $true
    }
    It 'turns F15 off on the second toggle' {
        $s = Get-NextState (New-RunningState 0) 'toggle-keypress' 0
        $s = Get-NextState $s 'toggle-keypress' 0
        $s.KeyPress | Should Be $false
    }
    It 'keeps the state on an unknown action' {
        $s = New-RunningState 0
        $next = Get-NextState $s 'none' 5000
        $next.Running | Should Be $true
        $next.Display | Should Be $true
    }
}

Describe 'Invoke-Transition' {
    It 'applies the new flags and moves to the next state' {
        $applied, $set = New-Recorder
        $next = Invoke-Transition (New-AwakeState) 'toggle-pause' 0 $set $noLog
        $next.Running | Should Be $true
        $applied.Count | Should Be 1
        $applied[0] | Should Be 2147483651
    }
    It 'skips the Windows call when the flags do not change' {
        $applied, $set = New-Recorder
        $next = Invoke-Transition (New-AwakeState) 'toggle-display' 0 $set $noLog
        $next.Display | Should Be $false
        $applied.Count | Should Be 0
    }
    It 'keeps the old state with the error when the Windows call fails' {
        $logged, $log = New-Recorder
        $fail = { param($f) throw 'denied' }
        $running = New-RunningState 0
        $kept = Invoke-Transition $running 'toggle-pause' 5000 $fail $log
        $kept.Running | Should Be $true
        $kept.Error | Should Be 'denied'
        $logged[0] | Should Match "action 'toggle-pause' failed: denied"
    }
    It 'makes no Windows call for toggle-keypress' {
        $applied, $set = New-Recorder
        $next = Invoke-Transition (New-RunningState 0) 'toggle-keypress' 0 $set $noLog
        $next.KeyPress | Should Be $true
        $applied.Count | Should Be 0
    }
    It 'clears an old error on the next transition' {
        $s = New-RunningState 0
        $s.Error = 'old'
        $next = Invoke-Transition $s 'toggle-pause' 5000 { param($f) } $noLog
        $next.Error | Should BeNullOrEmpty
    }
}

Describe 'Format-Elapsed' {
    $cases = @(
        @{ Ms = -60000; Text = '0s' },
        @{ Ms = 0; Text = '0s' },
        @{ Ms = 999; Text = '0s' },
        @{ Ms = 1000; Text = '1s' },
        @{ Ms = 59999; Text = '59s' },
        @{ Ms = 60000; Text = '1min' },
        @{ Ms = 300000; Text = '5min' },
        @{ Ms = 3599000; Text = '59min' },
        @{ Ms = 3600000; Text = '1h 00min' },
        @{ Ms = 3900000; Text = '1h 05min' },
        @{ Ms = 94830000; Text = '26h 20min' }
    )
    It 'formats <Ms> ms as <Text>' -TestCases $cases {
        param($Ms, $Text)
        Format-Elapsed $Ms | Should BeExactly $Text
    }
}

Describe 'Get-WindowTitle' {
    It 'shows seconds in the first minute' {
        Get-WindowTitle (New-RunningState 0) 42000 | Should BeExactly "$coffee I'm awake! $dash 42s"
    }
    It 'still shows seconds at 59999 ms' {
        Get-WindowTitle (New-RunningState 0) 59999 | Should BeExactly "$coffee I'm awake! $dash 59s"
    }
    It 'switches to minutes at 60000 ms' {
        Get-WindowTitle (New-RunningState 0) 60000 | Should BeExactly "$coffee I'm awake! $dash 1min"
    }
    It 'shows minutes under one hour' {
        Get-WindowTitle (New-RunningState 0) 420000 | Should BeExactly "$coffee I'm awake! $dash 7min"
    }
    It 'shows hours and minutes' {
        Get-WindowTitle (New-RunningState 0) 4800000 | Should BeExactly "$coffee I'm awake! $dash 1h20"
    }
    It 'pads the minutes' {
        Get-WindowTitle (New-RunningState 0) 7380000 | Should BeExactly "$coffee I'm awake! $dash 2h03"
    }
    It 'says paused when stopped' {
        Get-WindowTitle (New-AwakeState) 0 | Should BeExactly "$sleeping ImAwake (paused)"
    }
}

Describe 'Get-HumorLine' {
    $cases = @(
        @{ Ms = -1000; Line = "I'm awake! I'm awake!" },
        @{ Ms = 179999; Line = "I'm awake! I'm awake!" },
        @{ Ms = 180000; Line = 'Just resting my eyes...' },
        @{ Ms = 360000; Line = 'I was listening, I swear.' },
        @{ Ms = 540000; Line = 'Yes, I agree with the last point.' },
        @{ Ms = 720000; Line = "I'm awake! I'm awake!" }
    )
    It 'gives <Line> at <Ms> ms' -TestCases $cases {
        param($Ms, $Line)
        Get-HumorLine $Ms | Should BeExactly $Line
    }
}

Describe 'Get-SpinnerFrame' {
    It 'moves every 250 ms' {
        Get-SpinnerFrame 0 $false | Should Be '|'
        Get-SpinnerFrame 249 $false | Should Be '|'
        Get-SpinnerFrame 250 $false | Should Be '/'
        Get-SpinnerFrame 1000 $false | Should Be '|'
    }
    It 'uses braille dots in fancy mode' {
        Get-SpinnerFrame 0 $true | Should Be ([char]0x280B).ToString()
        Get-SpinnerFrame 2500 $true | Should Be ([char]0x280B).ToString()
    }
    It 'freezes while paused, because the active time freezes' {
        $paused = Stop-AwakeClock (New-RunningState 0) 250
        $a = (Get-ViewModel $paused 1000 $false).Spinner
        $b = (Get-ViewModel $paused 5000 $false).Spinner
        $a | Should Be $b
    }
}

Describe 'Get-DisplayWidth' {
    It 'counts ASCII as one cell each' { Get-DisplayWidth 'abc' | Should Be 3 }
    It 'counts the coffee glyph as two cells' { Get-DisplayWidth "$coffee x" | Should Be 4 }
    It 'counts an emoji outside the BMP as two cells' { Get-DisplayWidth "$sleeping" | Should Be 2 }
    It 'counts box drawing as one cell' { Get-DisplayWidth ([char]0x2500).ToString() | Should Be 1 }
}

Describe 'Get-ViewModel' {
    It 'turns the state into text' {
        $s = New-RunningState 0
        $s.Error = 'boom'
        $v = Get-ViewModel $s 4800000 $false
        $v.Running | Should Be $true
        $v.Display | Should Be $true
        $v.Elapsed | Should Be '1h 20min'
        $v.Humor | Should Be 'I was listening, I swear.'
        $v.Error | Should Be 'boom'
        $v.Fancy | Should Be $false
        $v.KeyPress | Should Be $false
    }
    It 'shows F15 on' {
        $s = Get-NextState (New-RunningState 0) 'toggle-keypress' 0
        (Get-ViewModel $s 0 $false).KeyPress | Should Be $true
    }
}

function New-KeyPressState([long]$StartMs = 0, $LastKeyMs = $null) {
    $s = Get-NextState (New-RunningState $StartMs) 'toggle-keypress' $StartMs
    $s.LastKeyMs = $LastKeyMs
    $s
}

Describe 'Test-KeyPressDue' {
    It 'is false with F15 off' {
        Test-KeyPressDue (New-RunningState 0) 999999 | Should Be $false
    }
    It 'is false while paused, even when a press is due' {
        $s = Stop-AwakeClock (New-KeyPressState 0) 1000
        Test-KeyPressDue $s 999999 | Should Be $false
    }
    It 'is true when running with F15 on and never pressed' {
        Test-KeyPressDue (New-KeyPressState 0) 0 | Should Be $true
    }
    It 'is false 1 ms before 59 s' {
        Test-KeyPressDue (New-KeyPressState 0 1000) 59999 | Should Be $false
    }
    It 'is true at 59 s' {
        Test-KeyPressDue (New-KeyPressState 0 1000) 60000 | Should Be $true
    }
    It 'waits for the rest of the 59 s after a short pause' {
        $s = New-KeyPressState 0 1000
        $s = Stop-AwakeClock $s 10000
        $s = Start-AwakeClock $s 20000
        Test-KeyPressDue $s 59999 | Should Be $false
        Test-KeyPressDue $s 60000 | Should Be $true
    }
}

Describe 'Invoke-KeyPressTick' {
    It 'presses once and records the time' {
        $pressed, $press = New-Recorder
        $next = Invoke-KeyPressTick (New-KeyPressState 0) 7000 $press $noLog
        $pressed.Count | Should Be 1
        $next.LastKeyMs | Should Be 7000
    }
    It 'does not press when not due' {
        $pressed, $press = New-Recorder
        $next = Invoke-KeyPressTick (New-KeyPressState 0 1000) 2000 $press $noLog
        $pressed.Count | Should Be 0
        $next.LastKeyMs | Should Be 1000
    }
    It 'does not press while paused' {
        $pressed, $press = New-Recorder
        $s = Stop-AwakeClock (New-KeyPressState 0) 1000
        $null = Invoke-KeyPressTick $s 999999 $press $noLog
        $pressed.Count | Should Be 0
    }
    It 'keeps F15 on with the error when the press throws, and waits 59 s to retry' {
        $logged, $log = New-Recorder
        $next = Invoke-KeyPressTick (New-KeyPressState 0) 7000 { throw 'blocked' } $log
        $next.Error | Should Match 'F15 keypress failed: blocked'
        $next.LastKeyMs | Should Be 7000
        $next.KeyPress | Should Be $true
        $logged.Count | Should Be 1
        $logged[0] | Should Match 'F15 keypress failed: blocked'
    }
    It 'clears its own F15 error on the next success' {
        $s = Invoke-KeyPressTick (New-KeyPressState 0) 7000 { throw 'blocked' } $noLog
        $next = Invoke-KeyPressTick $s 66000 { } $noLog
        $next.Error | Should BeNullOrEmpty
    }
    It 'keeps a power error on success' {
        $s = New-KeyPressState 0
        $s.Error = 'SetThreadExecutionState failed'
        $next = Invoke-KeyPressTick $s 7000 { } $noLog
        $next.Error | Should Be 'SetThreadExecutionState failed'
    }
    It 'never changes the state it receives' {
        $s = New-KeyPressState 0
        $null = Invoke-KeyPressTick $s 7000 { } $noLog
        $s.LastKeyMs | Should BeNullOrEmpty
    }
}
