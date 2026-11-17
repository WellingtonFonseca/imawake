# The mutants of scripts/mutate.ps1: one change each. Old must appear exactly once in File.
# Tests lists the test files that cover the change; the mutant is killed when one of them fails.
# A mutant that survives is a gap: write the missing test, then run scripts/mutate.sh again.
# Single quotes only; an apostrophe is written twice.
@{
    Mutants = @(
        @{ Label = 'Format-Text: app token not filled'; File = 'src/ImAwake.Text.psm1'; Tests = @('ImAwake.Text.Tests.ps1', 'ImAwake.Core.Tests.ps1', 'ImAwake.Frame.Tests.ps1', 'ImAwake.Lang.Tests.ps1')
           Old = '.Replace(''{app}'', $script:AppName)'
           New = '.Replace(''{app}'', ''X'')' }
        @{ Label = 'Format-Text: cmd token not filled'; File = 'src/ImAwake.Text.psm1'; Tests = @('ImAwake.Text.Tests.ps1', 'ImAwake.Core.Tests.ps1', 'ImAwake.Frame.Tests.ps1', 'ImAwake.Lang.Tests.ps1')
           Old = '.Replace(''{cmd}'', $script:CommandName)'
           New = '.Replace(''{cmd}'', ''X'')' }
        @{ Label = 'Format-Text: no-args branch'; File = 'src/ImAwake.Text.psm1'; Tests = @('ImAwake.Text.Tests.ps1', 'ImAwake.Core.Tests.ps1', 'ImAwake.Frame.Tests.ps1', 'ImAwake.Lang.Tests.ps1')
           Old = 'if ($FormatArgs.Count -eq 0) { return $value }'
           New = 'if ($FormatArgs.Count -eq 99) { return $value }' }
        @{ Label = 'Format-Text: missing key not detected'; File = 'src/ImAwake.Text.psm1'; Tests = @('ImAwake.Text.Tests.ps1', 'ImAwake.Core.Tests.ps1', 'ImAwake.Frame.Tests.ps1', 'ImAwake.Lang.Tests.ps1')
           Old = 'if (-not $Text.ContainsKey($Key)) { throw'
           New = 'if ($false) { throw' }
        @{ Label = 'Resolve-Language: saved choice ignored'; File = 'src/ImAwake.Text.psm1'; Tests = @('ImAwake.Text.Tests.ps1', 'ImAwake.Core.Tests.ps1', 'ImAwake.Frame.Tests.ps1', 'ImAwake.Lang.Tests.ps1')
           Old = 'if ($Saved -and $exact.Count -gt 0)'
           New = 'if ($Saved -and $exact.Count -gt 5)' }
        @{ Label = 'Resolve-Language: exact culture ignored'; File = 'src/ImAwake.Text.psm1'; Tests = @('ImAwake.Text.Tests.ps1', 'ImAwake.Core.Tests.ps1', 'ImAwake.Frame.Tests.ps1', 'ImAwake.Lang.Tests.ps1')
           Old = 'if ($UiCultureName -and $exact.Count -gt 0)'
           New = 'if ($UiCultureName -and $exact.Count -gt 5)' }
        @{ Label = 'Resolve-Language: two-letter match ignored'; File = 'src/ImAwake.Text.psm1'; Tests = @('ImAwake.Text.Tests.ps1', 'ImAwake.Core.Tests.ps1', 'ImAwake.Frame.Tests.ps1', 'ImAwake.Lang.Tests.ps1')
           Old = 'if ($code -and $sameCode.Count -gt 0)'
           New = 'if ($code -and $sameCode.Count -gt 5)' }
        @{ Label = 'Resolve-Language: saved case-sensitive'; File = 'src/ImAwake.Text.psm1'; Tests = @('ImAwake.Text.Tests.ps1', 'ImAwake.Core.Tests.ps1', 'ImAwake.Frame.Tests.ps1', 'ImAwake.Lang.Tests.ps1')
           Old = '$_ -ieq $Saved'
           New = '$_ -ceq $Saved' }
        @{ Label = 'Get-NextLanguage: no wrap'; File = 'src/ImAwake.Text.psm1'; Tests = @('ImAwake.Text.Tests.ps1', 'ImAwake.Core.Tests.ps1', 'ImAwake.Frame.Tests.ps1', 'ImAwake.Lang.Tests.ps1')
           Old = '% $Available.Count'
           New = '% 99' }
        @{ Label = 'Select-PluralKey: wrong number'; File = 'src/ImAwake.Text.psm1'; Tests = @('ImAwake.Text.Tests.ps1', 'ImAwake.Core.Tests.ps1', 'ImAwake.Frame.Tests.ps1', 'ImAwake.Lang.Tests.ps1')
           Old = 'if ($Count -eq 1) { return $OneKey }'
           New = 'if ($Count -eq 2) { return $OneKey }' }
        @{ Label = 'Import-TextTables: no English fallback'; File = 'src/ImAwake.Language.psm1'; Tests = @('ImAwake.Language.Tests.ps1', 'ImAwake.Uninstall.Tests.ps1')
           Old = 'if (-not $table.ContainsKey($key))'
           New = 'if ($false)' }
        @{ Label = 'Get-AvailableLanguages: English twice'; File = 'src/ImAwake.Language.psm1'; Tests = @('ImAwake.Language.Tests.ps1', 'ImAwake.Uninstall.Tests.ps1')
           Old = 'Where-Object { $_ -ne ''en'' }'
           New = 'Where-Object { $_ -ne ''xx'' }' }
        @{ Label = 'Read-LanguagePreference: pattern too strict'; File = 'src/ImAwake.Language.psm1'; Tests = @('ImAwake.Language.Tests.ps1', 'ImAwake.Uninstall.Tests.ps1')
           Old = '{2,3}(-'
           New = '{9,9}(-' }
        @{ Label = 'Read-LanguagePreference: missing file'; File = 'src/ImAwake.Language.psm1'; Tests = @('ImAwake.Language.Tests.ps1', 'ImAwake.Uninstall.Tests.ps1')
           Old = 'if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }'
           New = 'if ($false) { return $null }' }
        @{ Label = 'Save-LanguagePreference: BOM written'; File = 'src/ImAwake.Language.psm1'; Tests = @('ImAwake.Language.Tests.ps1', 'ImAwake.Uninstall.Tests.ps1')
           Old = 'New-Object Text.ASCIIEncoding'
           New = 'New-Object Text.UTF8Encoding $true' }
        @{ Label = 'Get-LanguagePreferencePath: wrong file name'; File = 'src/ImAwake.Language.psm1'; Tests = @('ImAwake.Language.Tests.ps1', 'ImAwake.Uninstall.Tests.ps1')
           Old = '''ImAwake\language.txt'''
           New = '''ImAwake\lang.txt''' }
        @{ Label = 'Core: l key does nothing'; File = 'src/ImAwake.Core.psm1'; Tests = @('ImAwake.Core.Tests.ps1', 'ImAwake.Frame.Tests.ps1')
           Old = '([ConsoleKey]::L)        { return ''cycle-language'' }'
           New = '([ConsoleKey]::L)        { return ''none'' }' }
        @{ Label = 'Core: language does not change'; File = 'src/ImAwake.Core.psm1'; Tests = @('ImAwake.Core.Tests.ps1', 'ImAwake.Frame.Tests.ps1')
           Old = '$next.Language = Get-NextLanguage $State.Language $State.Languages'
           New = '$next.Language = $State.Language' }
        @{ Label = 'Get-HumorLine: always first line'; File = 'src/ImAwake.Core.psm1'; Tests = @('ImAwake.Core.Tests.ps1', 'ImAwake.Frame.Tests.ps1')
           Old = '% $Lines.Count'
           New = '% 1' }
        @{ Label = 'Frame: plural swapped'; File = 'src/ImAwake.Frame.psm1'; Tests = @('ImAwake.Frame.Tests.ps1')
           Old = '''UninstallFailedOne'' ''UninstallFailedMany'''
           New = '''UninstallFailedMany'' ''UninstallFailedOne''' }
        @{ Label = 'Frame: ctrl+u hint shown wrongly'; File = 'src/ImAwake.Frame.psm1'; Tests = @('ImAwake.Frame.Tests.ps1')
           Old = 'if (-not $View.CanUninstall) { return $row }'
           New = 'if ($View.CanUninstall) { return $row }' }
        @{ Label = 'Frame: header lost app name'; File = 'src/ImAwake.Frame.psm1'; Tests = @('ImAwake.Frame.Tests.ps1')
           Old = '(New-Segment "$coffee $(Get-AppName)" ''Header'')'
           New = '(New-Segment "$coffee X" ''Header'')' }
        @{ Label = 'Uninstall: language files not runtime files'; File = 'src/ImAwake.Uninstall.psm1'; Tests = @('ImAwake.Uninstall.Tests.ps1')
           Old = '-or $_ -like ''lang\*.psd1'''
           New = '-or $_ -like ''lang\*.xxx''' }
        @{ Label = 'Uninstall: wrong lang folder name'; File = 'src/ImAwake.Uninstall.psm1'; Tests = @('ImAwake.Uninstall.Tests.ps1')
           Old = '''folder'' ''lang'''
           New = '''folder'' ''langx''' }
        @{ Label = 'uninstall.ps1: wrong language folder'; File = 'src/uninstall.ps1'; Tests = @('ImAwake.Uninstall.Tests.ps1')
           Old = 'Get-LanguageSetup $appDir'
           New = 'Get-LanguageSetup $env:TEMP' }
        @{ Label = 'Core: language position counted from 0'; File = 'src/ImAwake.Core.psm1'; Tests = @('ImAwake.Core.Tests.ps1', 'ImAwake.Frame.Tests.ps1')
           Old = 'LanguageIndex = [array]::IndexOf(@($State.Languages), $State.Language) + 1'
           New = 'LanguageIndex = [array]::IndexOf(@($State.Languages), $State.Language)' }
        @{ Label = 'Frame: language position and total swapped'; File = 'src/ImAwake.Frame.psm1'; Tests = @('ImAwake.Frame.Tests.ps1')
           Old = ''' [{0}/{1}]'''
           New = ''' [{1}/{0}]''' }
        @{ Label = 'Read-LanguagePreference: empty file throws'; File = 'src/ImAwake.Language.psm1'; Tests = @('ImAwake.Language.Tests.ps1', 'ImAwake.Uninstall.Tests.ps1')
           Old = '([IO.File]::ReadAllText($Path)).Trim()'
           New = '(Get-Content -LiteralPath $Path -Raw).Trim()' }
        @{ Label = 'Get-NextLanguage: empty list throws'; File = 'src/ImAwake.Text.psm1'; Tests = @('ImAwake.Text.Tests.ps1')
           Old = 'if (@($Available).Count -eq 0) { return $Current }'
           New = 'if ($false) { return $Current }' }
        @{ Label = 'uninstall.ps1: language failure not handled'; File = 'src/uninstall.ps1'; Tests = @('ImAwake.Uninstall.Tests.ps1')
           Old = 'Stop-WithMessage "$(Get-AppName) could not read its language files: $_" ''Press any key to close.'''
           New = 'Write-Log "ignored: $_"' }
        @{ Label = 'Get-LanguageSetup: unreadable choice stops the host'; File = 'src/ImAwake.Language.psm1'; Tests = @('ImAwake.Language.Tests.ps1')
           Old = 'catch { $problem = "language choice not read from ${path}: $_" }'
           New = 'catch { throw }' }
        @{ Label = 'Read-LanguagePreference: a folder is read as a file'; File = 'src/ImAwake.Language.psm1'; Tests = @('ImAwake.Language.Tests.ps1')
           Old = 'if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }'
           New = 'if (-not (Test-Path -LiteralPath $Path)) { return $null }' }
    )
}
