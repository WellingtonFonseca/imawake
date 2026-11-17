Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot '..\src\ImAwake.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\src\ImAwake.Frame.psm1') -Force
$en = Import-PowerShellDataFile -Path (Join-Path $PSScriptRoot '..\src\lang\en.psd1')

$ansi = [regex]"$([char]27)\[[0-9;]*m"

function Get-PlainLines($Lines) {
    $Lines | ForEach-Object { $ansi.Replace($_, '') }
}

function New-View([bool]$Running = $true, [bool]$Fancy = $false, $ErrorText = $null, [bool]$Display = $true, [bool]$KeyPress = $false, [string]$Mode = 'run', [bool]$CanUninstall = $false) {
    [pscustomobject]@{
        Running = $Running; Display = $Display; KeyPress = $KeyPress; Elapsed = '1h 20min'
        Humor = 'Just resting my eyes...'; Spinner = '|'; Error = $ErrorText; Fancy = $Fancy; Mode = $Mode; CanUninstall = $CanUninstall; Text = $en; LanguageIndex = 1; LanguageCount = 2
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
        $text | Should Match '\[ \] Press F15 every minute \(keeps chat apps active\)'
        $text | Should Match 'f F15'
        $text | Should Match 'q quit'
    }
    It 'shows the F15 option on' {
        $text = (Get-PlainLines (Get-FrameLines (New-View -KeyPress $true) 80 24)) -join "`n"
        $text | Should Match '\[x\] Press F15 every minute'
    }
    It 'draws the paused screen' {
        $text = (Get-PlainLines (Get-FrameLines (New-View -Running $false) 80 24)) -join "`n"
        $text | Should Match 'Paused - your PC can sleep'
        $text | Should Match 'space resume'
        $text | Should Not Match 'Awake for'
        $text | Should Match 'zz Paused'
    }
    It 'draws the sleep glyph on the paused screen in fancy mode' {
        $text = (Get-PlainLines (Get-FrameLines (New-View -Running $false -Fancy $true) 80 24)) -join "`n"
        $text | Should Match ([regex]::Escape("$([char]::ConvertFromUtf32(0x1F4A4)) Paused"))
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

Describe 'Get-FrameLines row order' {
    It 'draws the title, then the options, then the help and the hint' {
        $lines = @(Get-PlainLines (Get-FrameLines (New-View -CanUninstall $true) 100 30))
        $title = [array]::FindIndex($lines, [Predicate[string]]{ param($l) $l -match 'ImAwake' })
        $option = [array]::FindIndex($lines, [Predicate[string]]{ param($l) $l -match 'Keep the PC from sleeping' })
        $help = [array]::FindIndex($lines, [Predicate[string]]{ param($l) $l -match 'space pause' })
        $hint = [array]::FindIndex($lines, [Predicate[string]]{ param($l) $l -match 'ctrl\+u uninstall' })
        ($title -ge 0) | Should Be $true
        ($title -lt $option) | Should Be $true
        ($option -lt $help) | Should Be $true
        ($help -lt $hint) | Should Be $true
    }
}

Describe 'Get-FrameLines for uninstall' {
    function Get-Text($View) { (Get-PlainLines (Get-FrameLines $View 120 30)) -join "`n" }
    It 'shows the ctrl+u hint on an installed copy' {
        Get-Text (New-View -CanUninstall $true) | Should Match 'ctrl\+u uninstall'
    }
    It 'hides the hint when the copy is not installed' {
        Get-Text (New-View) | Should Not Match 'ctrl\+u'
    }
    It 'shows the confirm prompt in place of the help rows' {
        $text = Get-Text (New-View -CanUninstall $true -Mode 'confirm-uninstall')
        $text | Should Match 'Uninstall ImAwake\?\s+y yes\s+.\s+n no'
        $text | Should Match 'Removes the app, the shortcut and the PATH entry'
        $text | Should Not Match 'q quit'
        $text | Should Not Match 'space pause'
    }
    It 'keeps the box size in the three views' {
        $views = @((New-View -KeyPress $true), (New-View -KeyPress $true -CanUninstall $true), (New-View -KeyPress $true -CanUninstall $true -Mode 'confirm-uninstall'))
        $sizes = $views | ForEach-Object {
            $lines = @(Get-PlainLines (Get-FrameLines $_ 120 30))
            $box = @($lines | Where-Object { $_.Trim() })
            '{0}x{1}' -f $box.Count, ($box | ForEach-Object { Get-DisplayWidth $_.Trim() } | Measure-Object -Maximum).Maximum
        }
        @($sizes | Select-Object -Unique).Count | Should Be 1
    }
}

Describe 'Format-ProgressBar' {
    It 'is empty at 0 of 12' { Format-ProgressBar 0 12 12 $false | Should BeExactly '[------------] 0/12' }
    It 'rounds the fill down at 5 of 12' { Format-ProgressBar 5 12 10 $false | Should BeExactly '[####------] 5/12' }
    It 'is full at 12 of 12' { Format-ProgressBar 12 12 10 $false | Should BeExactly '[##########] 12/12' }
    It 'is not full before the last step' { Format-ProgressBar 11 12 10 $false | Should BeExactly '[#########-] 11/12' }
    It 'is full for no steps' { Format-ProgressBar 0 0 4 $false | Should BeExactly '[####] 0/0' }
    It 'limits Done to Total and to zero' {
        Format-ProgressBar 13 12 10 $false | Should BeExactly '[##########] 12/12'
        Format-ProgressBar -3 12 10 $false | Should BeExactly '[----------] 0/12'
    }
    It 'uses block glyphs in fancy mode' {
        $full = [char]::ConvertFromUtf32(0x2588)
        $empty = [char]::ConvertFromUtf32(0x2591)
        Format-ProgressBar 1 2 4 $true | Should BeExactly "[$full$full$empty$empty] 1/2"
    }
}

Describe 'Get-UninstallFrameLines' {
    function New-UninstallView([int]$Done = 3, [int]$Total = 12, [bool]$Finished = $false, $Failed = @(), [bool]$Fancy = $false) {
        [pscustomobject]@{ Fancy = $Fancy; Done = $Done; Total = $Total; Current = 'Remove ImAwake.Core.psm1'; Finished = $Finished; Failed = $Failed; Text = $en }
    }
    function Get-UText($View, [int]$Width = 100) { (Get-PlainLines (Get-UninstallFrameLines $View $Width 30)) -join "`n" }
    It 'shows the title, the bar and the current step' {
        $text = Get-UText (New-UninstallView)
        $text | Should Match 'ImAwake uninstall'
        $text | Should Match '\[#######-{23}\] 3/12'
        $text | Should Match 'Removing: Remove ImAwake\.Core\.psm1'
        $text | Should Not Match 'Press any key'
    }
    It 'shows the done summary and what stays' {
        $text = Get-UText (New-UninstallView -Done 12 -Finished $true)
        $text | Should Match 'Done\. ImAwake is removed\.'
        $text | Should Match 'Kept: %LOCALAPPDATA%\\ImAwake'
        $text | Should Match 'Press any key to close'
    }
    It 'shows the failed steps, at most three' {
        $text = Get-UText (New-UninstallView -Done 12 -Finished $true -Failed @('a', 'b', 'c', 'd'))
        $text | Should Match 'Failed: 4 item'
        $text | Should Match '- a'
        $text | Should Match '- c'
        $text | Should Not Match '- d'
        $text | Should Not Match 'Done\.'
    }
    It 'says item for one failed step and items for more' {
        (Get-UText (New-UninstallView -Done 12 -Finished $true -Failed @('a'))) | Should Match 'Failed: 1 item\s'
        (Get-UText (New-UninstallView -Done 12 -Finished $true -Failed @('a', 'b'))) | Should Match 'Failed: 2 items\s'
    }
    It 'draws the words of the text table it gets' {
        $other = @{}
        foreach ($key in $en.Keys) { $other[$key] = $en[$key] }
        $other['UninstallDone'] = 'Pronto. {app} foi removido.'
        $view = New-UninstallView -Done 12 -Finished $true
        $view.Text = $other
        $text = Get-UText $view
        $text | Should Match 'Pronto\. ImAwake foi removido\.'
        $text | Should Match 'ImAwake uninstall'
    }
    It 'keeps every line inside the window' {
        $lines = @(Get-PlainLines (Get-UninstallFrameLines (New-UninstallView -Done 12 -Finished $true -Failed @('a')) 60 30))
        foreach ($line in $lines) { ((Get-DisplayWidth $line) -lt 60) | Should Be $true }
    }
}

Describe 'Get-FrameLines with another text table' {
    function New-OtherText {
        $other = @{}
        foreach ($key in $en.Keys) { $other[$key] = $en[$key] }
        $other['OptionScreen'] = 'Manter a tela ligada'
        $other['HelpQuit'] = 'sair'
        $other['ConfirmQuestion'] = 'Desinstalar {app}?'
        $other
    }
    It 'draws the words of the table, and the app name stays' {
        $view = New-View
        $view.Text = New-OtherText
        $text = (Get-PlainLines (Get-FrameLines $view 80 24)) -join "`n"
        $text | Should Match 'Manter a tela ligada'
        $text | Should Match 'q sair'
        $text | Should Match ' ImAwake'
    }
    It 'draws the uninstall question from the table' {
        $view = New-View -Mode 'confirm-uninstall' -CanUninstall $true
        $view.Text = New-OtherText
        $text = (Get-PlainLines (Get-FrameLines $view 80 24)) -join "`n"
        $text | Should Match 'Desinstalar ImAwake\?'
    }
}

Import-Module (Join-Path $PSScriptRoot '..\src\ImAwake.Language.psm1') -Force
$tables = Import-TextTables (Join-Path $PSScriptRoot '..\src\lang')

Describe 'Every screen in every language file' {
    foreach ($language in $tables.Keys) {
        $table = $tables[$language]

        It "$language draws the running and the paused screen with no leftover placeholder" {
            foreach ($running in $true, $false) {
                $view = New-View -Running $running -CanUninstall $true
                $view.Text = $table
                $text = (Get-PlainLines (Get-FrameLines $view 100 24)) -join "`n"
                $text | Should Not Match '\{'
                $text | Should Match 'ImAwake'
            }
        }
        It "$language draws the uninstall question with the y and n keys" {
            $view = New-View -Mode 'confirm-uninstall' -CanUninstall $true
            $view.Text = $table
            $text = (Get-PlainLines (Get-FrameLines $view 100 24)) -join "`n"
            $text | Should Not Match '\{'
            $text | Should Match 'ImAwake\s?[?\uFF1F]'
            $text | Should Match ' y '
            $text | Should Match ' n '
        }
        It "$language draws the uninstall screen, running and finished, with no leftover placeholder" {
            foreach ($finished in $false, $true) {
                $view = [pscustomobject]@{ Fancy = $false; Done = 5; Total = 12; Current = 'Remove x'; Finished = $finished; Failed = @('a', 'b'); Text = $table }
                $text = (Get-PlainLines (Get-UninstallFrameLines $view 100 30)) -join "`n"
                $text | Should Not Match '\{'
                $text | Should Match 'ImAwake'
            }
        }
        It "$language keeps the box size on a pause, on an installed copy and on the uninstall question" {
            $views = @(
                (New-View), (New-View -Running $false), (New-View -CanUninstall $true),
                (New-View -CanUninstall $true -Mode 'confirm-uninstall'), (New-View -KeyPress $true -CanUninstall $true)
            )
            $sizes = $views | ForEach-Object {
                $_.Text = $table
                $box = @((Get-PlainLines (Get-FrameLines $_ 140 30)) | Where-Object { $_.Trim() })
                '{0}x{1}' -f $box.Count, ($box | ForEach-Object { Get-DisplayWidth $_.Trim() } | Measure-Object -Maximum).Maximum
            }
            @($sizes | Select-Object -Unique).Count | Should Be 1
        }
        It "$language keeps every line inside a 21-column window" {
            $view = New-View -CanUninstall $true
            $view.Text = $table
            foreach ($line in @(Get-PlainLines (Get-FrameLines $view 21 24))) { ((Get-DisplayWidth $line) -lt 21) | Should Be $true }
        }
    }
}

Describe 'The language key in the help' {
    It 'shows l with its label in English, also on a copy that cannot uninstall' {
        $text = (Get-PlainLines (Get-FrameLines (New-View) 100 24)) -join "`n"
        $text | Should Match 'l language'
        $text | Should Not Match 'ctrl\+u'
    }
    It 'shows the label of the table it gets' {
        $other = @{}
        foreach ($key in $en.Keys) { $other[$key] = $en[$key] }
        $other['HelpLanguage'] = 'idioma'
        $view = New-View
        $view.Text = $other
        (Get-PlainLines (Get-FrameLines $view 100 24)) -join "`n" | Should Match 'l idioma'
    }
    It 'puts the language key before ctrl+u on the second help row' {
        $text = (Get-PlainLines (Get-FrameLines (New-View -CanUninstall $true) 100 24)) -join "`n"
        $text | Should Match 'l language \[\d+/\d+\]\s+\S\s+ctrl\+u uninstall'
    }
    It 'shows the position of the language in the list, as [n/x]' {
        $text = (Get-PlainLines (Get-FrameLines (New-View) 100 24)) -join "`n"
        $text | Should Match 'l language \[1/2\]'
    }
    It 'shows the position and the total the view gives' {
        $view = New-View
        $view.LanguageIndex = 10
        $view.LanguageCount = 12
        (Get-PlainLines (Get-FrameLines $view 100 24)) -join "`n" | Should Match 'l language \[10/12\]'
    }
    It 'keeps the position before ctrl+u' {
        $text = (Get-PlainLines (Get-FrameLines (New-View -CanUninstall $true) 100 24)) -join "`n"
        $text | Should Match 'l language \[1/2\]\s+\S\s+ctrl\+u uninstall'
    }
    It 'keeps the language key off the first help row' {
        $text = (Get-PlainLines (Get-FrameLines (New-View) 100 24)) -join "`n"
        $text | Should Match 'F15\s+\S\s+q quit'
    }
}
