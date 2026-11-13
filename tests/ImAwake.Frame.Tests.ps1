Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot '..\src\ImAwake.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\src\ImAwake.Frame.psm1') -Force

$ansi = [regex]"$([char]27)\[[0-9;]*m"

function Get-PlainLines($Lines) {
    $Lines | ForEach-Object { $ansi.Replace($_, '') }
}

function New-View([bool]$Running = $true, [bool]$Fancy = $false, $ErrorText = $null, [bool]$Display = $true) {
    [pscustomobject]@{
        Running = $Running; Display = $Display; Elapsed = '1h 20min'
        Humor = 'Just resting my eyes...'; Spinner = '|'; Error = $ErrorText; Fancy = $Fancy
    }
}

Describe 'Get-FrameLines' {
    It 'draws the running screen' {
        $text = (Get-PlainLines (Get-FrameLines (New-View) 80 24)) -join "`n"
        $text | Should Match '\| Awake for 1h 20min'
        $text | Should Match '"Just resting my eyes\.\.\."'
        $text | Should Match '\[x\] Keep the PC from sleeping'
        $text | Should Match '\[x\] Keep the screen on'
        $text | Should Match 'space pause'
        $text | Should Match 'd screen'
        $text | Should Match 'q quit'
    }
    It 'draws the paused screen' {
        $text = (Get-PlainLines (Get-FrameLines (New-View -Running $false) 80 24)) -join "`n"
        $text | Should Match 'Paused at 1h 20min - your PC can sleep'
        $text | Should Match 'space resume'
        $text | Should Not Match 'Awake for'
        $text | Should Match 'zz Paused'
    }
    It 'draws the sleep glyph on the paused screen in fancy mode' {
        $text = (Get-PlainLines (Get-FrameLines (New-View -Running $false -Fancy $true) 80 24)) -join "`n"
        $text | Should Match ([regex]::Escape("$([char]::ConvertFromUtf32(0x1F4A4)) Paused at"))
    }
    It 'shows the screen option off' {
        $text = (Get-PlainLines (Get-FrameLines (New-View -Display $false) 80 24)) -join "`n"
        $text | Should Match '\[ \] Keep the screen on'
    }
    It 'shows the error in red' {
        $lines = Get-FrameLines (New-View -ErrorText 'boom') 80 24
        ($lines -join "`n") | Should Match ([regex]::Escape("$([char]27)[38;2;229;83;75m! boom"))
    }
    It 'keeps every line inside the window and the box aligned' {
        foreach ($size in @(@(80, 24), @(40, 30), @(30, 10), @(120, 50))) {
            $plain = @(Get-PlainLines (Get-FrameLines (New-View -Fancy $true) $size[0] $size[1]))
            $boxRows = @($plain | Where-Object { $_.Trim() })
            foreach ($line in $plain) {
                (Get-DisplayWidth $line) | Should BeLessThan $size[0]
            }
            $widths = @($boxRows | ForEach-Object { Get-DisplayWidth $_.TrimStart() } | Select-Object -Unique)
            $widths.Count | Should Be 1
            $plain.Count | Should BeLessThan $size[1]
        }
    }
    It 'centers the box' {
        $plain = @(Get-PlainLines (Get-FrameLines (New-View) 120 40))
        $top = @($plain | Where-Object { -not $_.Trim() }).Count
        $top | Should BeGreaterThan 5
        $plain[$top] | Should Match '^ {20,}\+'
    }
    It 'uses rounded corners in fancy mode and plus signs otherwise' {
        $fancy = @(Get-PlainLines (Get-FrameLines (New-View -Fancy $true) 80 24)) -join ''
        $fancy | Should Match ([char]0x256D)
        $plain = @(Get-PlainLines (Get-FrameLines (New-View) 80 24)) -join ''
        $plain | Should Match '\+-+\+'
    }
}

Describe 'Limit-Text' {
    It 'keeps a short text' { Limit-Text 'abc' 5 | Should BeExactly 'abc' }
    It 'cuts a long text' { Limit-Text 'abcdef' 4 | Should BeExactly 'abcd' }
    It 'never splits a wide glyph' {
        $coffee = [char]::ConvertFromUtf32(0x2615)
        Limit-Text "a$coffee" 2 | Should BeExactly 'a'
    }
}
