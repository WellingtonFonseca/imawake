# The console screen of ImAwake: the alternate screen, the frame write and the window title.
# Shared by the app and the uninstaller, so both draw in the same way.
# ASCII-only source for Windows PowerShell 5.1.

Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'ImAwake.Power.psm1')

$script:Esc = [char]27
$script:LastFrame = ''
$script:LastSize = ''
$script:LastTitle = ''

function Enter-Screen {
    [Console]::OutputEncoding = New-Object Text.UTF8Encoding $false
    [Console]::TreatControlCAsInput = $true
    Enable-VirtualTerminal
    [Console]::Out.Write("$script:Esc[?1049h$script:Esc[?25l")
}

function Exit-Screen($Saved) {
    [Console]::Out.Write("$script:Esc[?25h$script:Esc[?1049l")
    [Console]::TreatControlCAsInput = $Saved.CtrlC
    [Console]::OutputEncoding = $Saved.Encoding
    $Host.UI.RawUI.WindowTitle = $Saved.Title
}

# Text outside the app screen (the command, the fatal error) goes through the console code page,
# which is an OEM page with no Cyrillic or Chinese. This sets UTF-8 and gives back the old encoding
# for Restore-Output. The console code page is shared with the parent shell, so the caller must restore it.
# With both streams redirected the reader decodes the bytes and no console is touched: it gives $null.
function Use-Utf8Output {
    if ([Console]::IsOutputRedirected -and [Console]::IsErrorRedirected) { return $null }
    $previous = [Console]::OutputEncoding
    [Console]::OutputEncoding = New-Object Text.UTF8Encoding $false
    $previous
}

function Restore-Output($Previous) {
    if ($Previous) { [Console]::OutputEncoding = $Previous }
}

# The console state to restore with Exit-Screen. It throws with no console.
function Get-ScreenState {
    @{
        Title    = $Host.UI.RawUI.WindowTitle
        Encoding = [Console]::OutputEncoding
        CtrlC    = [Console]::TreatControlCAsInput
    }
}

# Forces the next Write-Lines to draw everything again.
function Reset-Frame {
    $script:LastFrame = ''
}

# Writes the lines only when they differ from the last write.
function Write-Lines($Lines, [int]$Width, [int]$Height) {
    $size = "${Width}x$Height"
    if ($size -ne $script:LastSize) {
        [Console]::Out.Write("$script:Esc[2J")
        $script:LastSize = $size
        $script:LastFrame = ''
    }
    $frame = "$script:Esc[H" + (($Lines | ForEach-Object { "$_$script:Esc[K" }) -join "`r`n") + "$script:Esc[J"
    if ($frame -eq $script:LastFrame) { return }
    [Console]::Out.Write($frame)
    $script:LastFrame = $frame
}

function Set-Title([string]$Title) {
    if ($Title -eq $script:LastTitle) { return }
    $Host.UI.RawUI.WindowTitle = $Title
    $script:LastTitle = $Title
}

Export-ModuleMember -Function Use-Utf8Output, Restore-Output, Get-ScreenState, Enter-Screen, Exit-Screen, Reset-Frame, Write-Lines, Set-Title
