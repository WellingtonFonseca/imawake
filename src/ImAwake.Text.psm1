# Pure text helpers of ImAwake: fill a text, pick a language, pick a plural key.
# No file, console or clock. The language tables come in as data, read by the language loader module.
# ASCII-only source for Windows PowerShell 5.1; the translated text lives in src\lang\*.psd1.

Set-StrictMode -Version Latest

# The app name is never translated: a language file holds the token, never the name.
$script:AppName = 'ImAwake'
$script:CommandName = 'imawake'
$script:DefaultLanguage = 'en'

# Gives the text of Key with {app} and {cmd} filled, then the positional {0}, {1} from FormatArgs.
# A text with no FormatArgs keeps its braces as they are.
function Format-Text($Text, [string]$Key, [object[]]$FormatArgs = @()) {
    if (-not $Text.ContainsKey($Key)) { throw "Missing text key '$Key'" }
    $value = ([string]$Text[$Key]).Replace('{app}', $script:AppName).Replace('{cmd}', $script:CommandName)
    if ($FormatArgs.Count -eq 0) { return $value }
    $value -f $FormatArgs
}

# Saved choice first, then the Windows culture (exact name, then the two-letter code), then English.
function Resolve-Language([string]$Saved, [string]$UiCultureName, [string[]]$Available) {
    $exact = @($Available | Where-Object { $_ -ieq $Saved })
    if ($Saved -and $exact.Count -gt 0) { return $exact[0] }
    $exact = @($Available | Where-Object { $_ -ieq $UiCultureName })
    if ($UiCultureName -and $exact.Count -gt 0) { return $exact[0] }
    $code = ($UiCultureName -split '-')[0]
    $sameCode = @($Available | Where-Object { ($_ -split '-')[0] -ieq $code })
    if ($code -and $sameCode.Count -gt 0) { return $sameCode[0] }
    $script:DefaultLanguage
}

# The next language in the list, and the first one after the last or after an unknown one.
function Get-NextLanguage([string]$Current, [string[]]$Available) {
    if (@($Available).Count -eq 0) { return $Current }
    $index = [array]::IndexOf($Available, $Current)
    $Available[($index + 1) % $Available.Count]
}

function Select-PluralKey([int]$Count, [string]$OneKey, [string]$ManyKey) {
    if ($Count -eq 1) { return $OneKey }
    $ManyKey
}

function Get-AppName { $script:AppName }

function Get-CommandName { $script:CommandName }

Export-ModuleMember -Function Get-AppName, Get-CommandName, Format-Text, Resolve-Language, Get-NextLanguage, Select-PluralKey
