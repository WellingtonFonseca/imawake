# Pure drawing of the ImAwake screen: a view model in, the screen lines (with ANSI colors) out.
# ASCII-only source for Windows PowerShell 5.1; glyphs come from code points.

Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'ImAwake.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'ImAwake.Text.psm1')

$script:Esc = [char]27
$script:Reset = "$script:Esc[0m"
$script:PaddingX = 3
$script:MinInnerWidth = 12

$script:Style = @{
    Plain  = ''
    Border = '38;2;212;136;43'
    Header = '1;38;2;212;136;43'
    Key    = '1;38;2;212;136;43'
    Status = '1'
    Awake  = '38;2;46;160;67'
    Paused = '1;38;2;139;148;158'
    Humor  = '3;38;2;139;148;158'
    Muted  = '38;2;139;148;158'
    Error  = '38;2;229;83;75'
}

function New-Segment([string]$Text, [string]$StyleName = 'Plain') {
    [pscustomobject]@{ Text = $Text; Style = $script:Style[$StyleName] }
}

function Get-BoxChars([bool]$Fancy) {
    if (-not $Fancy) {
        return @{ TL = '+'; TR = '+'; BL = '+'; BR = '+'; H = '-'; V = '|' }
    }
    @{
        TL = Get-Glyph 0x256D; TR = Get-Glyph 0x256E
        BL = Get-Glyph 0x2570; BR = Get-Glyph 0x256F
        H  = Get-Glyph 0x2500; V  = Get-Glyph 0x2502
    }
}

function Get-StatusSegments($View) {
    if (-not $View.Running) {
        $zzz = if ($View.Fancy) { Get-Glyph 0x1F4A4 } else { 'zz' }
        return @(New-Segment (Format-Text $View.Text 'StatusPaused' @($zzz)) 'Paused')
    }
    @(
        (New-Segment $View.Spinner 'Awake'),
        (New-Segment (' ' + (Format-Text $View.Text 'StatusAwake' @($View.Elapsed))) 'Status')
    )
}

# The key letters are code, not text: only the labels come from the language table.
function Get-HelpSegments([bool]$Running, $Text) {
    $pause = Format-Text $Text $(if ($Running) { 'HelpPause' } else { 'HelpResume' })
    $sep = '  {0}  ' -f (Get-Glyph 0x00B7)
    @(
        (New-Segment 'space' 'Key'), (New-Segment " $pause" 'Muted'), (New-Segment $sep 'Muted'),
        (New-Segment 'd' 'Key'), (New-Segment (' ' + (Format-Text $Text 'HelpScreen')) 'Muted'), (New-Segment $sep 'Muted'),
        (New-Segment 'f' 'Key'), (New-Segment (' ' + (Format-Text $Text 'HelpF15')) 'Muted'), (New-Segment $sep 'Muted'),
        (New-Segment 'q' 'Key'), (New-Segment (' ' + (Format-Text $Text 'HelpQuit')) 'Muted')
    )
}

# The second help row: the language key, then the uninstall key of an installed copy.
# It is not part of the first row, because the box must keep its width: a help row wider than
# the option rows would make the box jump on a pause or on the uninstall question.
function Get-MoreHelpSegments($View) {
    $Text = $View.Text
    $position = ' [{0}/{1}]' -f $View.LanguageIndex, $View.LanguageCount
    $row = @(
        (New-Segment 'l' 'Key'),
        (New-Segment (' ' + (Format-Text $Text 'HelpLanguage') + $position) 'Muted')
    )
    if (-not $View.CanUninstall) { return $row }
    $sep = '  {0}  ' -f (Get-Glyph 0x00B7)
    $row + @((New-Segment $sep 'Muted'), (New-Segment 'ctrl+u' 'Key'), (New-Segment (' ' + (Format-Text $Text 'HelpUninstall')) 'Muted'))
}

# The two last rows of the box while the uninstall question shows.
function Get-ConfirmRows($Text) {
    $sep = '  {0}  ' -f (Get-Glyph 0x00B7)
    @(
        , @(
            (New-Segment ((Format-Text $Text 'ConfirmQuestion') + '  ') 'Error'),
            (New-Segment 'y' 'Key'), (New-Segment (' ' + (Format-Text $Text 'ConfirmYes')) 'Muted'), (New-Segment $sep 'Muted'),
            (New-Segment 'n' 'Key'), (New-Segment (' ' + (Format-Text $Text 'ConfirmNo')) 'Muted')
        )
        , @(New-Segment (Format-Text $Text 'ConfirmNote') 'Muted')
    )
}

function Get-Checkbox([bool]$On) {
    if ($On) { return '[x]' }
    '[ ]'
}

# The rows above the footer: the title, the status and the options.
function Get-BodyRows($View) {
    $coffee = if ($View.Fancy) { Get-Glyph 0x2615 } else { 'c[_]' }
    $errorRow = @()
    if ($View.Error) {
        $errorRow = @(New-Segment "! $($View.Error)" 'Error')
    }
    @(
        , @(New-Segment "$coffee $(Get-AppName)" 'Header')
        , @()
        , (Get-StatusSegments $View)
        , @(New-Segment ('"{0}"' -f $View.Humor) 'Humor')
        , @()
        , @(New-Segment "$(Get-Checkbox $true) $(Format-Text $View.Text 'OptionSleep')")
        , @(New-Segment "$(Get-Checkbox $View.Display) $(Format-Text $View.Text 'OptionScreen')")
        , @(New-Segment "$(Get-Checkbox $View.KeyPress) $(Format-Text $View.Text 'OptionKeyPress')")
        , $errorRow
    )
}

# The two last rows: the uninstall question, or the help row and the uninstall hint.
# Both give two rows, so the box height never changes.
function Get-FooterRows($View) {
    if ($View.Mode -eq 'confirm-uninstall') { return Get-ConfirmRows $View.Text }
    @(
        , (Get-HelpSegments $View.Running $View.Text)
        , @(Get-MoreHelpSegments $View)
    )
}

function Get-RowWidth($Segments) {
    $width = 0
    foreach ($segment in $Segments) { $width += Get-DisplayWidth $segment.Text }
    $width
}

# Cuts a row to MaxWidth cells, so the row fits the box.
function Limit-Row($Segments, [int]$MaxWidth) {
    $result = @()
    $left = $MaxWidth
    foreach ($segment in $Segments) {
        if ($left -le 0) { break }
        $text = Limit-Text $segment.Text $left
        $left -= Get-DisplayWidth $text
        $result += [pscustomobject]@{ Text = $text; Style = $segment.Style }
    }
    , $result
}

function Limit-Text([string]$Text, [int]$MaxWidth) {
    if ((Get-DisplayWidth $Text) -le $MaxWidth) { return $Text }
    $elements = [Globalization.StringInfo]::GetTextElementEnumerator($Text)
    $out = ''
    while ($elements.MoveNext()) {
        $next = $out + $elements.GetTextElement()
        if ((Get-DisplayWidth $next) -gt $MaxWidth) { break }
        $out = $next
    }
    $out
}

function Format-Row($Segments) {
    $line = ''
    foreach ($segment in $Segments) {
        if ($segment.Style) {
            $line += "$script:Esc[$($segment.Style)m$($segment.Text)$script:Reset"
            continue
        }
        $line += $segment.Text
    }
    $line
}

function Format-Border([string]$Text) {
    "$script:Esc[$($script:Style.Border)m$Text$script:Reset"
}

# Gives the screen lines: the rows in a box, centered in a Width x Height window.
# From 21 columns up, no line is wider than Width - 1, because writing the last cell
# makes the console scroll. Below that the box keeps its minimum width and wraps.
function Get-BoxLines($Rows, [bool]$Fancy, [int]$Width, [int]$Height) {
    $box = Get-BoxChars $Fancy
    $usable = [math]::Max($Width - 1, 1)
    $chrome = 2 + 2 * $script:PaddingX
    $natural = ($Rows | ForEach-Object { Get-RowWidth $_ } | Measure-Object -Maximum).Maximum
    $inner = [int][math]::Max([math]::Min($natural, $usable - $chrome), $script:MinInnerWidth)

    $pad = ' ' * $script:PaddingX
    $side = Format-Border $box.V
    $blank = "$side$(' ' * ($inner + 2 * $script:PaddingX))$side"
    $lines = @(Format-Border "$($box.TL)$($box.H * ($inner + 2 * $script:PaddingX))$($box.TR)")
    $lines += $blank
    foreach ($row in $Rows) {
        $cut = Limit-Row $row $inner
        $fill = ' ' * ($inner - (Get-RowWidth $cut))
        $lines += "$side$pad$(Format-Row $cut)$fill$pad$side"
    }
    $lines += $blank
    $lines += Format-Border "$($box.BL)$($box.H * ($inner + 2 * $script:PaddingX))$($box.BR)"

    Get-CenteredLines $lines ($inner + $chrome) $usable $Height
}

function Get-FrameLines($View, [int]$Width, [int]$Height) {
    Get-BoxLines (@(Get-BodyRows $View) + @(Get-FooterRows $View)) $View.Fancy $Width $Height
}

function Get-CenteredLines([string[]]$Lines, [int]$BoxWidth, [int]$Usable, [int]$Height) {
    $left = ' ' * [math]::Max([math]::Floor(($Usable - $BoxWidth) / 2), 0)
    $top = [int][math]::Max([math]::Floor(($Height - $Lines.Count) / 2), 0)
    $out = @('') * $top
    foreach ($line in $Lines) { $out += "$left$line" }
    if ($Height -gt 0 -and $out.Count -gt $Height - 1) {
        $out = $out[0..([math]::Max($Height - 2, 0))]
    }
    , $out
}

# "[#####-----] 5/12": the fill is rounded down, so the bar is full only when all steps are done.
function Format-ProgressBar([int]$Done, [int]$Total, [int]$Width, [bool]$Fancy) {
    $doneClamped = [math]::Min([math]::Max($Done, 0), [math]::Max($Total, 0))
    $fill = $Width
    if ($Total -gt 0) { $fill = [int][math]::Floor($Width * $doneClamped / $Total) }
    $full = if ($Fancy) { Get-Glyph 0x2588 } else { '#' }
    $empty = if ($Fancy) { Get-Glyph 0x2591 } else { '-' }
    '[{0}{1}] {2}/{3}' -f ($full * $fill), ($empty * ($Width - $fill)), $doneClamped, [math]::Max($Total, 0)
}

# The rows of the uninstall screen: View has Fancy, Done, Total, Current, Finished, Failed and Text.
function Get-UninstallRows($View) {
    $coffee = if ($View.Fancy) { Get-Glyph 0x2615 } else { 'c[_]' }
    $rows = @(
        , @(New-Segment "$coffee $(Format-Text $View.Text 'UninstallHeader')" 'Header')
        , @()
        , @(New-Segment (Format-ProgressBar $View.Done $View.Total 30 $View.Fancy) 'Status')
    )
    if (-not $View.Finished) {
        $rows += , @(New-Segment (Format-Text $View.Text 'UninstallRemoving' @($View.Current)) 'Muted')
        return $rows
    }
    $failed = @($View.Failed)
    if ($failed.Count -eq 0) {
        $rows += , @(New-Segment (Format-Text $View.Text 'UninstallDone') 'Awake')
    }
    else {
        $rows += , @(New-Segment (Format-Text $View.Text (Select-PluralKey $failed.Count 'UninstallFailedOne' 'UninstallFailedMany') @($failed.Count)) 'Error')
        foreach ($label in ($failed | Select-Object -First 3)) {
            $rows += , @(New-Segment "- $label" 'Error')
        }
    }
    $rows += , @()
    $rows += , @(New-Segment (Format-Text $View.Text 'UninstallKept') 'Muted')
    $rows += , @(New-Segment (Format-Text $View.Text 'PressAnyKeyRow') 'Muted')
    $rows
}

function Get-UninstallFrameLines($View, [int]$Width, [int]$Height) {
    Get-BoxLines (Get-UninstallRows $View) $View.Fancy $Width $Height
}

Export-ModuleMember -Function Get-FrameLines, Get-BoxLines, Get-UninstallFrameLines, Format-ProgressBar, Limit-Text
