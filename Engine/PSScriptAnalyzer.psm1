#
# Script module for module 'PSScriptAnalyzer'
#
Set-StrictMode -Version Latest

# Set up some helper variables to make it easier to work with the module
$PSModule = $ExecutionContext.SessionState.Module
$PSModuleRoot = $PSModule.ModuleBase

# Import the appropriate nested binary module based on the current PowerShell version
$binaryModuleRoot = $PSModuleRoot


if (($PSVersionTable.Keys -contains "PSEdition") -and ($PSVersionTable.PSEdition -ne 'Desktop')) {
    $binaryModuleRoot = Join-Path -Path $PSModuleRoot -ChildPath 'coreclr'
}
else {
    if ($PSVersionTable.PSVersion -lt [Version]'5.0') {
        $binaryModuleRoot = Join-Path -Path $PSModuleRoot -ChildPath 'PSv3'
    }
}

$binaryModulePath = Join-Path -Path $binaryModuleRoot -ChildPath 'Microsoft.PowerShell.ScriptAnalyzer.dll'
$binaryModule = Import-Module -Name $binaryModulePath -PassThru

# When the module is unloaded, remove the nested binary module that was loaded with it
$PSModule.OnRemove = {
    Remove-Module -ModuleInfo $binaryModule
}

if (Get-Command Register-ArgumentCompleter -ErrorAction Ignore) {
    $settingPresetCompleter = {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParmeter)

        [Microsoft.PowerShell.ScriptAnalyzer.Settings]::GetSettingPresets() | `
            Where-Object {$_ -like "$wordToComplete*"} | `
            ForEach-Object { New-Object System.Management.Automation.CompletionResult $_ }
    }

    @('Invoke-ScriptAnalyzer', 'Invoke-Formatter') | ForEach-Object {
        Register-ArgumentCompleter -CommandName $_ `
            -ParameterName 'Settings' `
            -ScriptBlock $settingPresetCompleter

    }

    Function RuleNameCompleter {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParmeter)

        Get-ScriptAnalyzerRule *$wordToComplete* | `
            ForEach-Object { New-Object System.Management.Automation.CompletionResult $_.RuleName }
    }

    Register-ArgumentCompleter -CommandName 'Invoke-ScriptAnalyzer' -ParameterName 'IncludeRule' -ScriptBlock $Function:RuleNameCompleter
    Register-ArgumentCompleter -CommandName 'Invoke-ScriptAnalyzer' -ParameterName 'ExcludeRule' -ScriptBlock $Function:RuleNameCompleter
    Register-ArgumentCompleter -CommandName 'Get-ScriptAnalyzerRule' -ParameterName 'Name' -ScriptBlock $Function:RuleNameCompleter
}
