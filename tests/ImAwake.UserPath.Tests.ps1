Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot '..\src\ImAwake.UserPath.psm1') -Force

$bin = Join-Path $env:USERPROFILE 'Apps\ImAwake\bin'
$five = 'C:\a;%USERPROFILE%\AppData\Local\Microsoft\WindowsApps;C:\b;C:\c;C:\d'

Describe 'Add-PathEntry' {
    It 'appends to a value with five entries and keeps them as they are' {
        Add-PathEntry $five $bin | Should BeExactly "$five;$bin"
    }
    It 'gives $null when the entry is already there' {
        Add-PathEntry "$five;$bin" $bin | Should BeNullOrEmpty
    }
    It 'treats a trailing backslash, another case and spaces as the same entry' {
        Add-PathEntry "C:\a; $($bin.ToUpperInvariant())\ ;C:\b" $bin | Should BeNullOrEmpty
    }
    It 'treats a quoted entry as the same folder' {
        Add-PathEntry "C:\a;`"$bin`"" $bin | Should BeNullOrEmpty
    }
    It 'treats a %USERPROFILE% entry as the same folder' {
        Add-PathEntry 'C:\a;%USERPROFILE%\Apps\ImAwake\bin' $bin | Should BeNullOrEmpty
    }
    It 'does not leave a double separator when the value ends in ;' {
        Add-PathEntry 'C:\a;C:\b;' $bin | Should BeExactly "C:\a;C:\b;$bin"
    }
    It 'gives only the folder for an empty or missing value' {
        Add-PathEntry '' $bin | Should BeExactly $bin
        Add-PathEntry $null $bin | Should BeExactly $bin
    }
    It 'does not treat the parent folder as the same entry' {
        Add-PathEntry 'C:\a;%USERPROFILE%\Apps\ImAwake' $bin | Should BeExactly "C:\a;%USERPROFILE%\Apps\ImAwake;$bin"
    }
}

Describe 'Remove-PathEntry' {
    It 'removes the entry and keeps the others as they are' {
        Remove-PathEntry "$five;$bin" $bin | Should BeExactly $five
    }
    It 'removes an entry in the middle' {
        Remove-PathEntry "C:\a;$bin;%USERPROFILE%\x" $bin | Should BeExactly 'C:\a;%USERPROFILE%\x'
    }
    It 'matches a trailing backslash, another case and spaces' {
        Remove-PathEntry "C:\a; $($bin.ToUpperInvariant())\ ;C:\b" $bin | Should BeExactly 'C:\a;C:\b'
    }
    It 'matches a quoted entry' {
        Remove-PathEntry "C:\a;`"$bin`"" $bin | Should BeExactly 'C:\a'
    }
    It 'matches a %USERPROFILE% entry' {
        Remove-PathEntry 'C:\a;%USERPROFILE%\Apps\ImAwake\bin;C:\b' $bin | Should BeExactly 'C:\a;C:\b'
    }
    It 'removes a duplicate too' {
        Remove-PathEntry "$bin;C:\a;$bin" $bin | Should BeExactly 'C:\a'
    }
    It 'gives $null when the entry is absent' {
        Remove-PathEntry $five $bin | Should BeNullOrEmpty
        Remove-PathEntry '' $bin | Should BeNullOrEmpty
        Remove-PathEntry $null $bin | Should BeNullOrEmpty
    }
    It 'gives an empty text when it was the only entry' {
        $result = Remove-PathEntry $bin $bin
        ($null -ne $result) | Should Be $true
        $result | Should BeExactly ''
    }
    It 'leaves no double or trailing separator' {
        Remove-PathEntry "C:\a;$bin;" $bin | Should BeExactly 'C:\a'
    }
    It 'does not remove the parent folder' {
        Remove-PathEntry (Split-Path $bin) $bin | Should BeNullOrEmpty
    }
}
