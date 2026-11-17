Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot '..\src\ImAwake.Language.psm1') -Force

function New-WorkDir {
    $dir = Join-Path $env:TEMP ('imawake-language-test-{0:yyyyMMddHHmmss}-{1}' -f (Get-Date), (Get-Random))
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $dir
}

function Write-LangFile([string]$Dir, [string]$Name, [string]$Body) {
    Set-Content -LiteralPath (Join-Path $Dir "$Name.psd1") -Value $Body -Encoding UTF8
}

Describe 'Import-TextTables' {
    It 'reads every language file by its name' {
        $dir = New-WorkDir
        try {
            Write-LangFile $dir 'en' "@{ A = 'one'; B = 'two' }"
            Write-LangFile $dir 'pt-BR' "@{ A = 'um'; B = 'dois' }"
            $tables = Import-TextTables $dir
            $tables['en']['A'] | Should Be 'one'
            $tables['pt-BR']['B'] | Should Be 'dois'
        }
        finally { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
    }
    It 'fills a key that a language misses from English' {
        $dir = New-WorkDir
        try {
            Write-LangFile $dir 'en' "@{ A = 'one'; B = 'two' }"
            Write-LangFile $dir 'pt-BR' "@{ A = 'um' }"
            $tables = Import-TextTables $dir
            $tables['pt-BR']['A'] | Should Be 'um'
            $tables['pt-BR']['B'] | Should Be 'two'
        }
        finally { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
    }
    It 'throws a clear error when the English file is missing' {
        $dir = New-WorkDir
        try {
            Write-LangFile $dir 'pt-BR' "@{ A = 'um' }"
            { Import-TextTables $dir } | Should Throw 'en.psd1'
        }
        finally { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
    }
    It 'reads the real language files of the app' {
        $tables = Import-TextTables (Join-Path $PSScriptRoot '..\src\lang')
        $tables.ContainsKey('en') | Should Be $true
        $tables['en']['ConfirmYes'] | Should Be 'yes'
    }
}

Describe 'Get-AvailableLanguages' {
    It 'puts English first and sorts the others' {
        $tables = @{ 'pt-BR' = @{}; 'en' = @{}; 'de' = @{} }
        (Get-AvailableLanguages $tables) -join ',' | Should Be 'en,de,pt-BR'
    }
    It 'stays a list when only English exists' {
        $list = Get-AvailableLanguages @{ en = @{} }
        ($list -is [array]) | Should Be $true
        $list.Count | Should Be 1
        $list[0] | Should Be 'en'
    }
}

Describe 'Language preference' {
    It 'gives nothing when the file is missing' {
        $dir = New-WorkDir
        try { Read-LanguagePreference (Join-Path $dir 'language.txt') | Should BeNullOrEmpty }
        finally { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
    }
    It 'gives nothing when the file is empty, so one bad file never stops the app' {
        $dir = New-WorkDir
        try {
            $path = Join-Path $dir 'language.txt'
            [IO.File]::WriteAllBytes($path, [byte[]]@())
            Read-LanguagePreference $path | Should BeNullOrEmpty
        }
        finally { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
    }
    It 'gives nothing when the file holds only blanks' {
        $dir = New-WorkDir
        try {
            $path = Join-Path $dir 'language.txt'
            Set-Content -LiteralPath $path -Value "  `r`n" -Encoding ASCII
            Read-LanguagePreference $path | Should BeNullOrEmpty
        }
        finally { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
    }
    It 'gives nothing when the content is not a language name' {
        $dir = New-WorkDir
        try {
            $path = Join-Path $dir 'language.txt'
            Set-Content -LiteralPath $path -Value 'not a language !!' -Encoding ASCII
            Read-LanguagePreference $path | Should BeNullOrEmpty
        }
        finally { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
    }
    It 'saves and reads the language back, and creates the folder' {
        $dir = New-WorkDir
        try {
            $path = Join-Path $dir 'sub\language.txt'
            Save-LanguagePreference $path 'pt-BR'
            Read-LanguagePreference $path | Should Be 'pt-BR'
        }
        finally { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
    }
    It 'saves one ASCII line with no BOM' {
        $dir = New-WorkDir
        try {
            $path = Join-Path $dir 'language.txt'
            Save-LanguagePreference $path 'en'
            $bytes = [IO.File]::ReadAllBytes($path)
            $bytes[0] | Should Be ([byte][char]'e')
        }
        finally { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
    }
    It 'throws when the file cannot be written, so the caller can log it' {
        $dir = New-WorkDir
        try {
            $blocker = Join-Path $dir 'blocker'
            Set-Content -LiteralPath $blocker -Value 'x'
            { Save-LanguagePreference (Join-Path $blocker 'language.txt') 'en' } | Should Throw
        }
        finally { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# Runs Body with LOCALAPPDATA pointing to a new temp folder, then restores it and deletes the folder.
function Invoke-WithLocalAppData([scriptblock]$Body) {
    $dir = New-WorkDir
    $old = $env:LOCALAPPDATA
    try {
        $env:LOCALAPPDATA = $dir
        & $Body $dir
    }
    finally {
        $env:LOCALAPPDATA = $old
        Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Get-LanguageSetup start language' {
    $srcDir = Join-Path $PSScriptRoot '..\src'
    It 'prefers the saved language over the Windows language' {
        Invoke-WithLocalAppData {
            Save-LanguagePreference (Get-LanguagePreferencePath) 'en'
            (Get-LanguageSetup $srcDir 'pt-BR').Language | Should Be 'en'
        }
    }
    It 'uses the Windows language when nothing is saved' {
        Invoke-WithLocalAppData {
            (Get-LanguageSetup $srcDir 'pt-BR').Language | Should Be 'pt-BR'
        }
    }
    It 'keeps going when the language file is locked, and says why' {
        Invoke-WithLocalAppData {
            $path = Get-LanguagePreferencePath
            Save-LanguagePreference $path 'en'
            $lock = [IO.File]::Open($path, 'Open', 'ReadWrite', 'None')
            try {
                $setup = Get-LanguageSetup $srcDir 'pt-BR'
                $setup.Language | Should Be 'pt-BR'
                $setup.PreferenceError | Should Match 'language choice not read from'
            }
            finally { $lock.Close() }
        }
    }
    It 'keeps going when language.txt is a folder' {
        Invoke-WithLocalAppData {
            New-Item -ItemType Directory -Force -Path (Get-LanguagePreferencePath) | Out-Null
            $setup = Get-LanguageSetup $srcDir 'pt-BR'
            $setup.Language | Should Be 'pt-BR'
            $setup.PreferenceError | Should BeNullOrEmpty
        }
    }
    It 'has no preference error when the file reads well' {
        Invoke-WithLocalAppData {
            Save-LanguagePreference (Get-LanguagePreferencePath) 'pt-BR'
            (Get-LanguageSetup $srcDir 'en-US').PreferenceError | Should BeNullOrEmpty
        }
    }
}

Describe 'Get-LanguageSetup' {
    It 'gives the tables, the language list, the start language and the preference path' {
        $dir = New-WorkDir
        $old = $env:LOCALAPPDATA
        try {
            $env:LOCALAPPDATA = $dir
            Save-LanguagePreference (Get-LanguagePreferencePath) 'en'
            $setup = Get-LanguageSetup (Join-Path $PSScriptRoot '..\src')
            $setup.Language | Should Be 'en'
            $setup.Available[0] | Should Be 'en'
            $setup.Tables.ContainsKey('en') | Should Be $true
            $setup.Preference | Should Be (Join-Path $dir 'ImAwake\language.txt')
        }
        finally {
            $env:LOCALAPPDATA = $old
            Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    It 'puts the language file under the ImAwake folder of LOCALAPPDATA' {
        $old = $env:LOCALAPPDATA
        try {
            $env:LOCALAPPDATA = 'C:\x'
            Get-LanguagePreferencePath | Should Be 'C:\x\ImAwake\language.txt'
        }
        finally { $env:LOCALAPPDATA = $old }
    }
}
