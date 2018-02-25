
$directory = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module -Verbose PSScriptAnalyzer
$testRootDirectory = Split-Path -Parent $directory
Import-Module (Join-Path $testRootDirectory 'PSScriptAnalyzerTestHelper.psm1')
$sa = Get-Command Get-ScriptAnalyzerRule

$singularNouns = "PSUseSingularNouns" # this rule does not exist for coreclr version
$approvedVerbs = "PSUseApprovedVerbs"
$cmdletAliases = "PSAvoidUsingCmdletAliases"
$dscIdentical = "PSDSCUseIdenticalParametersForDSC"

Describe "Test available parameters" {
    $params = $sa.Parameters
    Context "Name parameter" {
        It "has a RuleName parameter" {
            $params.ContainsKey("Name") | Should BeTrue
        }

        It "accepts string" {
            $params["Name"].ParameterType.FullName | Should -Be "System.String[]"
        }
    }

    Context "RuleExtension parameters" {
        It "has a RuleExtension parameter" {
            $params.ContainsKey("CustomRulePath") | Should BeTrue
        }

        It "accepts string array" {
            $params["CustomRulePath"].ParameterType.FullName | Should -Be "System.String[]"
        }

		It "takes CustomizedRulePath parameter as an alias of CustomRulePath parameter" {
			$params.CustomRulePath.Aliases.Contains("CustomizedRulePath") | Should BeTrue
		}
    }

}

Describe "Test Name parameters" {
    Context "When used correctly" {
        It "works with 1 name" {
            $rule = Get-ScriptAnalyzerRule -Name $cmdletAliases
            $rule | Should -HaveCount 1
            $rule[0].RuleName | Should -Be $cmdletAliases
        }

        It "works for DSC Rule" {
            $rule = Get-ScriptAnalyzerRule -Name $dscIdentical
            $rule | Should -HaveCount 1
            $rule[0].RuleName | Should -Be $dscIdentical
        }

        It "works with 2 names" {
            $rules = Get-ScriptAnalyzerRule -Name $approvedVerbs, $cmdletAliases
            $rules | Should -HaveCount 2
            ($rules | Where-Object {$_.RuleName -eq $cmdletAliases}) | Should -HaveCount 1
            ($rules | Where-Object {$_.RuleName -eq $approvedVerbs}) | Should -HaveCount 1
        }

        It "get Rules with no parameters supplied" {
			$defaultRules = Get-ScriptAnalyzerRule
            $expectedNumRules = 54
            if ((Test-PSEditionCoreClr) -or (Test-PSVersionV3) -or (Test-PSVersionV4))
            {
                # for PSv3 PSAvoidGlobalAliases is not shipped because
                # it uses StaticParameterBinder.BindCommand which is
                # available only on PSv4 and above
                # for PowerShell Core, PSUseSingularNouns is not
                # shipped because it uses APIs that are not present
                # in dotnet core.

                $expectedNumRules--                
            }
			$defaultRules | Should -HaveCount $expectedNumRules
		}

        It "is a positional parameter" {
            $rules = Get-ScriptAnalyzerRule "PSAvoidUsingCmdletAliases"
            $rules | Should -HaveCount 1
        }
    }

    Context "When used incorrectly" {
        It "1 incorrect name" {
            $rule = Get-ScriptAnalyzerRule -Name "This is a wrong name"
            $rule | Should -HaveCount 0
        }

        It "1 incorrect and 1 correct" {
            $rule = Get-ScriptAnalyzerRule -Name $cmdletAliases, "This is a wrong name"
            $rule | Should -HaveCount 1
            $rule[0].RuleName | Should -Be $cmdletAliases
        }
    }
}

Describe "Test RuleExtension" {
    $community = "CommunityAnalyzerRules"
    $measureRequired = "Measure-RequiresModules"
    Context "When used correctly" {

		$expectedNumCommunityRules = 10
		if ($PSVersionTable.PSVersion -ge [Version]'4.0.0')
		{
			$expectedNumCommunityRules = 12
		}
        It "with the module folder path" {
            $ruleExtension = Get-ScriptAnalyzerRule -CustomizedRulePath $directory\CommunityAnalyzerRules | Where-Object {$_.SourceName -eq $community}
            $ruleExtension | Should -HaveCount $expectedNumCommunityRules
        }

        It "with the psd1 path" {
            $ruleExtension = Get-ScriptAnalyzerRule -CustomizedRulePath $directory\CommunityAnalyzerRules\CommunityAnalyzerRules.psd1 | Where-Object {$_.SourceName -eq $community}
            $ruleExtension | Should -HaveCount $expectedNumCommunityRules

        }

        It "with the psm1 path" {
            $ruleExtension = Get-ScriptAnalyzerRule -CustomizedRulePath $directory\CommunityAnalyzerRules\CommunityAnalyzerRules.psm1 | Where-Object {$_.SourceName -eq $community}
            $ruleExtension | Should -HaveCount $expectedNumCommunityRules
        }

        It "with Name of a built-in rules" {
            $ruleExtension = Get-ScriptAnalyzerRule -CustomizedRulePath $directory\CommunityAnalyzerRules\CommunityAnalyzerRules.psm1 -Name $singularNouns
            $ruleExtension | Should -HaveCount 0
        }

        It "with Names of built-in, DSC and non-built-in rules" {
            $ruleExtension = Get-ScriptAnalyzerRule -CustomizedRulePath $directory\CommunityAnalyzerRules\CommunityAnalyzerRules.psm1 -Name $singularNouns, $measureRequired, $dscIdentical
            $ruleExtension | Should -HaveCount 1
            ($ruleExtension | Where-Object {$_.RuleName -eq $measureRequired}) | Should -HaveCount 1
            ($ruleExtension | Where-Object {$_.RuleName -eq $singularNouns}) | Should -HaveCount 0
            ($ruleExtension | Where-Object {$_.RuleName -eq $dscIdentical}) | Should -HaveCount 0
        }
    }

    Context "When used incorrectly" {
        It "file cannot be found" {
            try
            {
                Get-ScriptAnalyzerRule -CustomRulePath "Invalid CustomRulePath"
            }
            catch
            {
                $Error[0].FullyQualifiedErrorId | Should -Match "PathNotFound,Microsoft.Windows.PowerShell.ScriptAnalyzer.Commands.GetScriptAnalyzerRuleCommand"
            }
        }

    }
}

Describe "TestSeverity" {
    It "filters rules based on the specified rule severity" {
        $rules = Get-ScriptAnalyzerRule -Severity Error
        $rules | Should -HaveCount 6
    }

    It "filters rules based on multiple severity inputs"{
        $rules = Get-ScriptAnalyzerRule -Severity Error,Information
        $rules | Should -HaveCount 15
    }

        It "takes lower case inputs" {
        $rules = Get-ScriptAnalyzerRule -Severity error
        $rules | Should -HaveCount 6
    }
}

Describe "TestWildCard" {
    It "filters rules based on the -Name wild card input" {
        $rules = Get-ScriptAnalyzerRule -Name PSDSC*
        $rules | Should -HaveCount 7
    }

    It "filters rules based on wild card input and severity"{
        $rules = Get-ScriptAnalyzerRule -Name PSDSC*　-Severity Information
        $rules | Should -HaveCount 4
    }
}
