Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot '..\src\ImAwake.Text.psm1') -Force

$available = @('en', 'pt-BR')

Describe 'Format-Text' {
    It 'gives the text of the key' {
        Format-Text @{ A = 'hello' } 'A' | Should Be 'hello'
    }
    It 'fills the app name and the command name' {
        Format-Text @{ A = 'Run {cmd} for {app}' } 'A' | Should Be 'Run imawake for ImAwake'
    }
    It 'fills the positional arguments' {
        Format-Text @{ A = 'Awake for {0} ({1})' } 'A' @('5min', 'ok') | Should Be 'Awake for 5min (ok)'
    }
    It 'fills the app name and the arguments together' {
        Format-Text @{ A = '{app}: {0}' } 'A' @('x') | Should Be 'ImAwake: x'
    }
    It 'keeps braces when there are no arguments' {
        Format-Text @{ A = 'a {0} b' } 'A' | Should Be 'a {0} b'
    }
    It 'throws a clear error for a missing key' {
        { Format-Text @{ A = 'x' } 'Missing' } | Should Throw "Missing text key 'Missing'"
    }
    It 'never lets a language change the app name' {
        (Format-Text @{ A = '{app}' } 'A') | Should Be 'ImAwake'
    }
}

Describe 'Get-AppName' {
    It 'is ImAwake' {
        Get-AppName | Should BeExactly 'ImAwake'
    }
}

Describe 'Get-CommandName' {
    It 'is imawake' {
        Get-CommandName | Should BeExactly 'imawake'
    }
}

Describe 'Resolve-Language' {
    It 'uses the saved language when it exists' {
        Resolve-Language 'pt-BR' 'en-US' $available | Should Be 'pt-BR'
    }
    It 'ignores a saved language that does not exist' {
        Resolve-Language 'xx' 'pt-BR' $available | Should Be 'pt-BR'
    }
    It 'matches the exact culture name' {
        Resolve-Language $null 'pt-BR' $available | Should Be 'pt-BR'
    }
    It 'prefers the exact culture over another language with the same two-letter code' {
        Resolve-Language $null 'pt-PT' @('en', 'pt-BR', 'pt-PT') | Should Be 'pt-PT'
    }
    It 'matches by the two-letter code' {
        Resolve-Language $null 'pt-PT' $available | Should Be 'pt-BR'
    }
    It 'matches an English culture' {
        Resolve-Language $null 'en-US' $available | Should Be 'en'
    }
    It 'falls back to English for an unknown culture' {
        Resolve-Language $null 'de-DE' $available | Should Be 'en'
    }
    It 'falls back to English for empty input' {
        Resolve-Language '' '' $available | Should Be 'en'
    }
    It 'ignores the case of the saved name' {
        Resolve-Language 'PT-br' 'en-US' $available | Should Be 'pt-BR'
    }
}

Describe 'Get-NextLanguage' {
    It 'moves to the next language' {
        Get-NextLanguage 'en' $available | Should Be 'pt-BR'
    }
    It 'wraps around to the first language' {
        Get-NextLanguage 'pt-BR' $available | Should Be 'en'
    }
    It 'gives the current language back when the list is empty, so the key never throws' {
        Get-NextLanguage 'en' @() | Should Be 'en'
    }
    It 'starts from the first language when the current one is unknown' {
        Get-NextLanguage 'xx' $available | Should Be 'en'
    }
}

Describe 'Select-PluralKey' {
    It 'gives the one key for 1' {
        Select-PluralKey 1 'One' 'Many' | Should Be 'One'
    }
    It 'gives the many key for other numbers' {
        Select-PluralKey 4 'One' 'Many' | Should Be 'Many'
        Select-PluralKey 0 'One' 'Many' | Should Be 'Many'
    }
}
