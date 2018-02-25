#Import-Module PSScriptAnalyzer
$ruleName = "PSPossibleIncorrectUsageOfAssignmentOperator"

Describe "PossibleIncorrectUsageOfComparisonOperator" {
    Context "When there are violations" {
        It "assignment inside if statement causes warning" {
            $warnings = Invoke-ScriptAnalyzer -ScriptDefinition 'if ($a=$b){}' | Where-Object {$_.RuleName -eq $ruleName}
            $warnings.Count | Should -Be 1
        }

        It "assignment inside if statement causes warning when when wrapped in command expression" {
            $warnings = Invoke-ScriptAnalyzer -ScriptDefinition 'if ($a=($b)){}' | Where-Object {$_.RuleName -eq $ruleName}
            $warnings.Count | Should -Be 1
        }

        It "assignment inside if statement causes warning when wrapped in expression" {
            $warnings = Invoke-ScriptAnalyzer -ScriptDefinition 'if ($a="$b"){}' | Where-Object {$_.RuleName -eq $ruleName}
            $warnings.Count | Should -Be 1
        }

        It "assignment inside elseif statement causes warning" {
            $warnings = Invoke-ScriptAnalyzer -ScriptDefinition 'if ($a -eq $b){}elseif($a = $b){}' | Where-Object {$_.RuleName -eq $ruleName}
            $warnings.Count | Should -Be 1
        }

        It "double equals inside if statement causes warning" {
            $warnings = Invoke-ScriptAnalyzer -ScriptDefinition 'if ($a == $b){}' | Where-Object {$_.RuleName -eq $ruleName}
            $warnings.Count | Should -Be 1
        }

        It "double equals inside if statement causes warning when wrapping it in command expresion" {
            $warnings = Invoke-ScriptAnalyzer -ScriptDefinition 'if ($a == ($b)){}' | Where-Object {$_.RuleName -eq $ruleName}
            $warnings.Count | Should -Be 1
        }

        It "double equals inside if statement causes warning when wrapped in expression" {
            $warnings = Invoke-ScriptAnalyzer -ScriptDefinition 'if ($a == "$b"){}' | Where-Object {$_.RuleName -eq $ruleName}
            $warnings.Count | Should -Be 1
        }
    }

    Context "When there are no violations" {
        It "returns no violations when correct equality operator is used" {
            $warnings = Invoke-ScriptAnalyzer -ScriptDefinition 'if ($a -eq $b){ }' | Where-Object {$_.RuleName -eq $ruleName}
            $warnings.Count | Should -Be 0
        }

        It "returns no violations when using implicit clang style suppresion" {
            $warnings = Invoke-ScriptAnalyzer -ScriptDefinition 'if ( ($a -eq $b) ){ }' | Where-Object {$_.RuleName -eq $ruleName}
            $warnings.Count | Should -Be 0
        }

        It "returns no violations when using an InvokeMemberExpressionAst like a .net method on the RHS" {
            $warnings = Invoke-ScriptAnalyzer -ScriptDefinition 'if ($a = [System.IO.Path]::GetTempFileName()){ }' | Where-Object {$_.RuleName -eq $ruleName}
            $warnings.Count | Should -Be 0
        }

        It "returns no violations when there is an InvokeMemberExpressionAst on the RHS that looks like a variable" {
            $warnings = Invoke-ScriptAnalyzer -ScriptDefinition 'if ($a = $PSCmdlet.GetVariableValue($foo)){ }' | Where-Object {$_.RuleName -eq $ruleName}
            $warnings.Count | Should -Be 0
        }

        It "returns no violations when using an expression like a Binaryexpressionastast on the RHS" {
            $warnings = Invoke-ScriptAnalyzer -ScriptDefinition 'if ($a = $b -match $c){ }' | Where-Object {$_.RuleName -eq $ruleName}
            $warnings.Count | Should -Be 0
        }

        It "returns no violations when there is a command on the RHS" {
            $warnings = Invoke-ScriptAnalyzer -ScriptDefinition 'if ($a = Get-ChildItem){ }' | Where-Object {$_.RuleName -eq $ruleName}
            $warnings.Count | Should -Be 0
        }

        It "returns no violations when there is a command on the RHS wrapped in an expression" {
            $warnings = Invoke-ScriptAnalyzer -ScriptDefinition 'if ($a = (Get-ChildItem)){ }' | Where-Object {$_.RuleName -eq $ruleName}
            $warnings.Count | Should -Be 0
        }
    }
}
