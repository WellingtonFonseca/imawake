# Pure drawing of the ImAwake screen: a view model in, the screen lines (with ANSI colors) out.
# ASCII-only source for Windows PowerShell 5.1; glyphs come from code points.

Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'ImAwake.Core.psm1')

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
        return @(New-Segment "$zzz Paused at $($View.Elapsed) - your PC can sleep" 'Paused')
    }
    @(
        (New-Segment $View.Spinner 'Awake'),
        (New-Segment " Awake for $($View.Elapsed)" 'Status')
    )
}

function Get-HelpSegments([bool]$Running) {
    $pause = if ($Running) { 'pause' } else { 'resume' }
    $sep = '  {0}  ' -f (Get-Glyph 0x00B7)
    @(
        (New-Segment 'space' 'Key'), (New-Segment " $pause" 'Muted'), (New-Segment $sep 'Muted'),
        (New-Segment 'd' 'Key'), (New-Segment ' screen' 'Muted'), (New-Segment $sep 'Muted'),
        (New-Segment 'f' 'Key'), (New-Segment ' F15' 'Muted'), (New-Segment $sep 'Muted'),
        (New-Segment 'q' 'Key'), (New-Segment ' quit' 'Muted')
    )
}

function Get-Checkbox([bool]$On) {
    if ($On) { return '[x]' }
    '[ ]'
}

# The content rows of the box; each row is a list of segments.
function Get-ContentRows($View) {
    $coffee = if ($View.Fancy) { Get-Glyph 0x2615 } else { 'c[_]' }
    $errorRow = @()
    if ($View.Error) {
        $errorRow = @(New-Segment "! $($View.Error)" 'Error')
    }
    @(
        , @(New-Segment "$coffee ImAwake" 'Header')
        , @()
        , (Get-StatusSegments $View)
        , @(New-Segment ('"{0}"' -f $View.Humor) 'Humor')
        , @()
        , @(New-Segment "$(Get-Checkbox $true) Keep the PC from sleeping")
        , @(New-Segment "$(Get-Checkbox $View.Display) Keep the screen on")
        , @(New-Segment "$(Get-Checkbox $View.KeyPress) Press F15 every minute (keeps chat apps active)")
        , $errorRow
        , (Get-HelpSegments $View.Running)
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

# Gives the screen lines: the box centered in a Width x Height window.
# From 21 columns up, no line is wider than Width - 1, because writing the last cell
# makes the console scroll. Below that the box keeps its minimum width and wraps.
function Get-FrameLines($View, [int]$Width, [int]$Height) {
    $box = Get-BoxChars $View.Fancy
    $rows = Get-ContentRows $View
    $usable = [math]::Max($Width - 1, 1)
    $chrome = 2 + 2 * $script:PaddingX
    $natural = ($rows | ForEach-Object { Get-RowWidth $_ } | Measure-Object -Maximum).Maximum
    $inner = [int][math]::Max([math]::Min($natural, $usable - $chrome), $script:MinInnerWidth)

    $pad = ' ' * $script:PaddingX
    $side = Format-Border $box.V
    $blank = "$side$(' ' * ($inner + 2 * $script:PaddingX))$side"
    $lines = @(Format-Border "$($box.TL)$($box.H * ($inner + 2 * $script:PaddingX))$($box.TR)")
    $lines += $blank
    foreach ($row in $rows) {
        $cut = Limit-Row $row $inner
        $fill = ' ' * ($inner - (Get-RowWidth $cut))
        $lines += "$side$pad$(Format-Row $cut)$fill$pad$side"
    }
    $lines += $blank
    $lines += Format-Border "$($box.BL)$($box.H * ($inner + 2 * $script:PaddingX))$($box.BR)"

    Get-CenteredLines $lines ($inner + $chrome) $usable $Height
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

Export-ModuleMember -Function Get-FrameLines, Limit-Text
