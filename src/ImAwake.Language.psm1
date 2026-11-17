# Reads the language files and the saved language choice. This module touches the disk and
# the Windows culture, so the pure modules (Core, Frame, Text) never import it: the host
# loads the tables once and passes them in.
# ASCII-only source for Windows PowerShell 5.1; the translated text lives in src\lang\*.psd1.

Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'ImAwake.Text.psm1')

# A language name as Windows writes it: "en", "pt-BR". Anything else in the file is ignored.
$script:LanguageNamePattern = '^[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8})*$'

# Gives @{ en = @{...}; 'pt-BR' = @{...} }. A key that a language misses comes from English,
# because a missing key in a hashtable gives $null under StrictMode and would show as an empty row.
function Import-TextTables([string]$LangDir) {
    $english = Join-Path $LangDir 'en.psd1'
    if (-not (Test-Path -LiteralPath $english)) { throw "Language file en.psd1 not found in $LangDir" }
    $base = Import-PowerShellDataFile -LiteralPath $english
    $tables = @{}
    foreach ($file in (Get-ChildItem -LiteralPath $LangDir -Filter '*.psd1')) {
        $table = Import-PowerShellDataFile -LiteralPath $file.FullName
        foreach ($key in $base.Keys) {
            if (-not $table.ContainsKey($key)) { $table[$key] = $base[$key] }
        }
        $tables[$file.BaseName] = $table
    }
    $tables
}

# English first, because it is the default; the other languages follow in name order.
# This is the order the language key cycles through.
function Get-AvailableLanguages($Tables) {
    $others = @($Tables.Keys | Where-Object { $_ -ne 'en' } | Sort-Object)
    # The leading comma keeps a one-language list an array: PowerShell 5.1 unrolls it to a string otherwise.
    , (@('en') + $others)
}

# Gives the saved language name, or $null when the file is missing or holds anything else.
function Read-LanguagePreference([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    # ReadAllText gives '' for an empty file. Get-Content -Raw gives $null there, also after a
    # [string] cast in Windows PowerShell 5.1, and .Trim() on $null throws.
    $value = ([IO.File]::ReadAllText($Path)).Trim()
    if ($value -match $script:LanguageNamePattern) { return $value }
    $null
}

# One ASCII line with no BOM. A failure throws, so the host logs it with the path and goes on.
function Save-LanguagePreference([string]$Path, [string]$Language) {
    New-Item -ItemType Directory -Force -Path (Split-Path $Path) -ErrorAction Stop | Out-Null
    [IO.File]::WriteAllText($Path, $Language, (New-Object Text.ASCIIEncoding))
}

# The Windows display language. Windows Terminal and the code page do not change it.
function Get-SystemCultureName {
    (Get-UICulture).Name
}

# Where the choice is saved, next to the log. The app, the command and the uninstaller share it.
function Get-LanguagePreferencePath {
    Join-Path $env:LOCALAPPDATA 'ImAwake\language.txt'
}

# Everything a host needs at start: the tables, the language list, the start language and the
# preference path. Tables is @{ en = @{...}; 'pt-BR' = @{...} }; the host reads Tables[Language].
# The culture name is a parameter, so a test never depends on the PC it runs on.
# The saved choice is only a preference: a locked or unreadable file never stops a host. The
# reason comes back in PreferenceError (or $null) and the host logs it.
function Get-LanguageSetup([string]$AppDir, [string]$UiCultureName = (Get-SystemCultureName)) {
    $tables = Import-TextTables (Join-Path $AppDir 'lang')
    $available = Get-AvailableLanguages $tables
    $path = Get-LanguagePreferencePath
    $saved = $null
    $problem = $null
    try { $saved = Read-LanguagePreference $path }
    catch { $problem = "language choice not read from ${path}: $_" }
    @{
        Tables          = $tables
        Available       = $available
        Language        = Resolve-Language $saved $UiCultureName $available
        Preference      = $path
        PreferenceError = $problem
    }
}

Export-ModuleMember -Function Import-TextTables, Get-AvailableLanguages, Read-LanguagePreference,
    Save-LanguagePreference, Get-SystemCultureName, Get-LanguagePreferencePath,
    Get-LanguageSetup
