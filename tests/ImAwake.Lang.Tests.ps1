Set-StrictMode -Version Latest

$srcDir = Join-Path $PSScriptRoot '..\src'
$langDir = Join-Path $srcDir 'lang'
$base = Import-PowerShellDataFile -Path (Join-Path $langDir 'en.psd1')

function Get-Placeholders($Value) {
    $found = [regex]::Matches([string]$Value, '\{(\d+|app|cmd)\}') | ForEach-Object { $_.Value }
    (@($found) | Sort-Object -Unique) -join ','
}

function Get-AllStrings($Table) {
    foreach ($key in $Table.Keys) {
        foreach ($item in @($Table[$key])) { $item }
    }
}

Describe 'Language files' {
    It 'has the English base file' {
        Test-Path (Join-Path $langDir 'en.psd1') | Should Be $true
    }

    foreach ($file in (Get-ChildItem -Path $langDir -Filter '*.psd1')) {
        $name = $file.Name
        $table = Import-PowerShellDataFile -Path $file.FullName

        It "$name starts with a UTF-8 BOM, so Windows PowerShell 5.1 reads the accents right" {
            $bytes = [IO.File]::ReadAllBytes($file.FullName)
            ('{0:X2}{1:X2}{2:X2}' -f $bytes[0], $bytes[1], $bytes[2]) | Should Be 'EFBBBF'
        }
        It "$name has the same keys as en.psd1" {
            ($table.Keys | Sort-Object) -join ',' | Should Be (($base.Keys | Sort-Object) -join ',')
        }
        It "$name keeps the type of every value (text or list)" {
            foreach ($key in $base.Keys) {
                ($table[$key] -is [array]) | Should Be ($base[$key] -is [array])
            }
        }
        It "$name uses the same placeholders as en.psd1 in every text" {
            foreach ($key in $base.Keys) {
                if ($base[$key] -is [array]) { continue }
                "${key}: $(Get-Placeholders $table[$key])" | Should Be "${key}: $(Get-Placeholders $base[$key])"
            }
        }
        It "$name never holds the app name, which is never translated" {
            foreach ($text in (Get-AllStrings $table)) { $text | Should Not Match '(?i)imawake' }
        }
        It "$name has no empty text" {
            foreach ($text in (Get-AllStrings $table)) { [string]::IsNullOrWhiteSpace($text) | Should Be $false }
        }
    }
}

Describe 'Source files' {
    It 'keeps every src script and module ASCII (only the lang files hold other characters)' {
        $bad = @(Get-ChildItem -Path $srcDir -File -Recurse | Where-Object { $_.Extension -in '.ps1', '.psm1' } |
            Where-Object { @([IO.File]::ReadAllBytes($_.FullName) | Where-Object { $_ -ge 128 }).Count -gt 0 } |
            ForEach-Object { $_.Name })
        $bad -join ',' | Should Be ''
    }
}
